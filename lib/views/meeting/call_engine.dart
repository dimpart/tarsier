import 'dart:async';
import 'dart:typed_data';

import 'package:dim_flutter/dim_flutter.dart';


/// The voice call engine: wires the audio pipeline (mic recorder ->
/// payload codec -> magpie sender, magpie receiver -> payload codec ->
/// speaker player) and drives the data-plane transitions.
///
/// The engine starts when both sides enter CONNECTING (after the
/// accept/start exchange) and stops on hang-up; while running it also
/// observes the data plane - the first probe PONG back means reached.
class CallEngine implements MagpieClientDelegate {
  CallEngine({
    required this.peer,
    required this.localId,
    required this.meetingKey,
    Map<int, Uint8List>? keys,
    Map? media,
  }) : _directionKeys = keys ?? {1: meetingKey, 2: meetingKey}, _media = media;

  final ID peer;

  /// 1 = initiator, 2 = receiver
  final int localId;
  final Uint8List meetingKey;

  /// direction keys per senderId: {1: K_1, 2: K_2} derived via HKDF by
  /// the signaling layer (protocol.md section 5.1)
  final Map<int, Uint8List> _directionKeys;

  /// the negotiated media params {'codec', 'rate', 'channels'}: both
  /// outbound encoders follow it (signaling.md section 3); null lets the
  /// codec decide on its own
  final Map? _media;

  MicRecorder? _mic;
  PcmSpeaker? _speaker;
  PayloadCodec? _codec;
  bool _running = false;

  /// called when the data plane is ready (the first probe PONG came back):
  /// the upper layer flips the state to 'connected'
  void Function()? onDataPlaneReady;

  /// my own port info changed mid-call: the upper layer pushes it to the
  /// peer via the 'update' act (signaling.md section 8)
  void Function()? onPortInfoUpdated;

  /// Forces the codec's PCM16 fuse: used when the negotiation ended
  /// without Opus (either side lacks it), so no encoder is built even on
  /// a locally capable device.
  static OpusGateway? _pcm16OpusFactory({required int sampleRate, required int channels}) => null;

  Future<void> start() async {
    if (_running) {
      return;
    }
    _running = true;
    _codec = PayloadCodec(
      localId: localId,
      keys: _directionKeys,
      // negotiation ended without Opus: force the PCM16 pass-through
      opusFactory: _media?['codec'] == 'pcm16' ? _pcm16OpusFactory : null,
    );
    // bring the Opus path up (idempotent; on failure the codec falls
    // back to the PCM16 pass-through by itself)
    await _codec!.init();
    // speaker: decode inbound frames and play them out
    _speaker = PcmSpeaker();
    await _speaker!.start();
    // mic: capture -> encode -> send (RX only without the permission)
    _mic = MicRecorder();
    _mic!.onFrame = _onMicFrame;
    bool permitted = await _mic!.start();
    if (!permitted) {
      Log.warning('no microphone permission, RX only');
    }
    // observe the data plane
    MagpieClient.instance.delegate = this;
  }

  Future<void> stop() async {
    if (identical(MagpieClient.instance.delegate, this)) {
      MagpieClient.instance.delegate = null;
    }
    await _mic?.stop();
    _mic = null;
    await _speaker?.stop();
    _speaker = null;
    _codec?.destroy();
    _codec = null;
    _running = false;
  }

  void _onMicFrame(Uint8List pcm) {
    final codec = _codec;
    if (codec == null) {
      return;
    }
    VoiceFrame frame = VoiceFrame(
      pcm: pcm,
      sampleRate: PayloadFormat.defaultSampleRate,
      channels: PayloadFormat.defaultChannels,
      senderId: localId,
      time: DateTime.now(),
    );
    Uint8List? payload = codec.encodeFrame(frame);
    if (payload == null) {
      Log.warning('failed to encode voice frame');
      return;
    }
    MagpieClient.instance.sendFrame(payload, receiver: peer);
  }

  // MagpieClientDelegate

  @override
  void onPacketReceived(Packet packet, MagPipe? pipe, MagLink link, {required ID sender}) {
    if (!sender.isSameAs(peer)) {
      return; // signaling of another meeting
    }
    if (packet.command != MagpieClient.commandVoMP) {
      return; // plain DATA: not a media frame
    }
    final codec = _codec;
    if (codec == null) {
      return;
    }
    VoiceFrame? frame = codec.decodeFrame(packet.payload);
    if (frame == null) {
      return; // KEEPALIVE or malformed
    }
    _speaker?.push(frame.pcm);
  }

  @override
  void onSelfUpdated() {
    onPortInfoUpdated?.call();
  }

  @override
  void onPipelinesReady(ID did) {
    if (did.isSameAs(peer)) {
      onDataPlaneReady?.call();
    }
  }

}
