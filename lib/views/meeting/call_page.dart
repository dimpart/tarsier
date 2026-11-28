import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:dim_flutter/dim_flutter.dart';

import 'call_controller.dart';


/// Voice call window.
///
/// Swipe gestures & back button are blocked by the [PopScope]; this
/// window can only be left by the cancel / reject / hang-up buttons,
/// and it closes itself 1 second after the call is ended (controlled
/// by [CallController], which is also the single source of the states).
class CallPage extends StatefulWidget {
  const CallPage({super.key});

  @override
  State<StatefulWidget> createState() => _CallPageState();
}

class _CallPageState extends State<CallPage> {
  final CallController _controller = CallController();

  CallState? _previous;
  DateTime? _connectedTime;
  Timer? _timer;
  bool _muted = false;
  bool _speakerOn = false;

  // up/down bandwidth: previous cumulative counters + formatted speeds
  int? _lastUp;
  int? _lastDown;
  String _upSpeed = '';
  String _downSpeed = '';

  CallState get _state => _controller.state;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onStateChanged);
    _syncState();
  }

  @override
  void dispose() {
    _controller.removeListener(_onStateChanged);
    _timer?.cancel();
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) {
      setState(() {
        _syncState();
      });
    }
  }

  void _syncState() {
    CallState current = _state;
    if (current == CallState.connected) {
      if (_previous == CallState.connecting) {
        // connection established (first time), start timing
        _connectedTime = DateTime.now();
      }
      if (_previous == CallState.connecting || _previous == CallState.reconnecting) {
        _timer?.cancel();
        _timer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) {
            setState(() {
              // refresh the talking duration + the up/down bandwidth
              _pollSpeed();
            });
          }
        });
      }
    } else if (_previous == CallState.connected) {
      // talking broken, stop timing (resumable after reconnected)
      _timer?.cancel();
    }
    _previous = current;
  }

  String get _duration {
    DateTime? since = _connectedTime;
    if (since == null) {
      return '00:00';
    }
    int seconds = DateTime.now().difference(since).inSeconds;
    String mm = (seconds ~/ 60).toString().padLeft(2, '0');
    String ss = (seconds % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  String get _statusText {
    switch (_state) {
      case CallState.inviting:
        return 'Calling...'.tr;
      case CallState.waiting:
        return 'Incoming Voice Call'.tr;
      case CallState.connecting:
        return 'Connecting...'.tr;
      case CallState.connected:
        return _duration;
      case CallState.reconnecting:
        return 'Network Unstable, Reconnecting...'.tr;
      case CallState.ended:
        return 'Call Ended'.tr;
      default:
        return '';
    }
  }

  /// Path display while talking, one line per direction (the two ends
  /// rank their pipes independently, so they may differ):
  ///   '↓ Direct'  - the path the peer sends on (my incoming)
  ///   '↑ Direct'  - my own send path
  /// Polled every second, so a mid-call path change shows up here.
  String get _connectionText {
    ID? peer = _controller.peer;
    if (peer == null) {
      return '';
    }
    bool? outbound = MagpieClient.instance.isDirect(peer.withoutTerminal());
    bool? inbound = MagpieClient.instance.inboundDirect;
    if (outbound == null && inbound == null) {
      return '';
    }
    String line(bool direct, String speed) => [
      direct ? 'Direct' : 'Bridged',
      'Encrypted',
      speed,
    ].where((part) => part.isNotEmpty).join(' · ');
    final lines = <String>[];
    if (inbound != null) {
      lines.add('↓ ${line(inbound, _downSpeed)}');
    }
    if (outbound != null) {
      lines.add('↑ ${line(outbound, _upSpeed)}');
    }
    return lines.join('\n');
  }

  /// Fixed-height slot at the top of the window: keeps the layout
  /// stable while the label is not ready yet.
  Widget _connectionLabel() {
    String text = _state == CallState.connected ? _connectionText : '';
    if (text.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 8),
      child: Text(text,
        textAlign: TextAlign.left,
        style: TextStyle(
          fontSize: 12,
          color: CupertinoColors.white.withValues(alpha: 0.55),
        ),
      ),
    );
  }

  /// Snapshot the cumulative wire counters and turn the deltas into
  /// formatted speeds (bytes/s over the last second).
  void _pollSpeed() {
    int up = MagpieClient.instance.uplinkBytes;
    int down = MagpieClient.instance.downlinkBytes;
    int? prevUp = _lastUp;
    int? prevDown = _lastDown;
    _lastUp = up;
    _lastDown = down;
    if (prevUp != null && up >= prevUp) {
      _upSpeed = _formatSpeed(up - prevUp);
    }
    if (prevDown != null && down >= prevDown) {
      _downSpeed = _formatSpeed(down - prevDown);
    }
  }

  static String _formatSpeed(int bytes) {
    if (bytes >= 1024) {
      return '${(bytes / 1024.0).toStringAsFixed(1)} KB/s';
    }
    return '$bytes B/s';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF3A3A3C), Color(0xFF1C1C1E)],
            ),
          ),
          child: SafeArea(
            child: Column(children: [
              _connectionLabel(),
              const Spacer(),
              _avatar(),
              const SizedBox(height: 24),
              _title(),
              const SizedBox(height: 12),
              Text(_statusText,
                style: const TextStyle(
                  fontSize: 15,
                  color: CupertinoColors.white,
                ),
              ),
              const Spacer(),
              _tray(),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _title() {
    ID? peer = _controller.peer;
    Conversation? info = peer == null ? null : Conversation.fromID(peer);
    const style = TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: CupertinoColors.white,
    );
    if (info == null) {
      return Text(peer?.toString() ?? '',
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    return NameLabel(info, style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
  }

  Widget _avatar() {
    ID? peer = _controller.peer;
    if (peer == null) {
      return const SizedBox.shrink();
    }
    const double size = 128;
    Widget avatar = Container(
      width: size,
      height: size,
      color: const Color(0xFF48484A),
      child: AvatarFactory().getAvatarView(peer, width: size, height: size, fit: BoxFit.cover),
    );
    avatar = ClipOval(child: avatar);
    // breathing halo while the call is not talking yet: dialing, ringing,
    // connecting and reconnecting
    bool connecting = _state == CallState.inviting
        || _state == CallState.waiting
        || _state == CallState.connecting
        || _state == CallState.reconnecting;
    if (connecting) {
      return _HaloView(size: size, child: avatar);
    }
    return avatar;
  }

  Widget _tray() {
    Widget buttons;
    switch (_state) {
      case CallState.waiting:
        buttons = Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _circleAction(
            icon: Icons.call_end,
            background: _kCriticalColor,
            title: 'Reject'.tr,
            onTap: _controller.reject,
          ),
          _circleAction(
            icon: Icons.call,
            background: _kNormalColor,
            title: 'Accept'.tr,
            onTap: _controller.accept,
          ),
        ]);
        break;
      case CallState.connected:
        buttons = Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _circleAction(
            icon: _muted ? Icons.mic_off : Icons.mic,
            background: _muted ? _kToggledColor : _kNormalActionColor,
            iconColor: _muted ? _kCriticalColor : CupertinoColors.white,
            title: 'Mute'.tr,
            onTap: () => setState(() => _muted = !_muted),
          ),
          _circleAction(
            icon: Icons.call_end,
            background: _kCriticalColor,
            title: 'Hang Up'.tr,
            onTap: _controller.hangUp,
          ),
          _circleAction(
            icon: _speakerOn ? Icons.volume_up : Icons.volume_off,
            background: _speakerOn ? _kToggledColor : _kNormalActionColor,
            iconColor: _speakerOn ? _kNormalColor : CupertinoColors.white,
            title: 'Speaker'.tr,
            onTap: () => setState(() => _speakerOn = !_speakerOn),
          ),
        ]);
        break;
      case CallState.inviting:
      case CallState.connecting:
      case CallState.reconnecting:
        buttons = _circleAction(
          icon: Icons.call_end,
          background: _kCriticalColor,
          title: 'Cancel'.tr,
          onTap: _controller.cancel,
        );
        break;
      default: // ended: no button, auto closing
        buttons = const SizedBox.shrink();
        break;
    }
    // fixed height to keep the layout stable on every state
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: SizedBox(height: 110, child: Center(child: buttons)),
    );
  }

  Widget _circleAction({
    required IconData icon,
    required Color background,
    required String title,
    VoidCallback? onTap,
    Color iconColor = CupertinoColors.white,
  }) {
    const double size = 72;
    return Semantics(
      button: true,
      label: title,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: background, shape: BoxShape.circle),
          child: IconButton(
            icon: Icon(icon, size: 30, color: iconColor),
            onPressed: onTap,
          ),
        ),
        const SizedBox(height: 6),
        Text(title,
          style: const TextStyle(
            fontSize: 13,
            color: CupertinoColors.white,
          ),
        ),
      ]),
    );
  }

}

const Color _kCriticalColor = Color(0xFFFF3B30);
const Color _kNormalColor = Color(0xFF34C759);
const Color _kNormalActionColor = Color(0xFF48484A);
const Color _kToggledColor = Color(0xFFE8E8E8);


/// Breathing halo around the avatar while waiting for the peer.
class _HaloView extends StatefulWidget {
  const _HaloView({required this.child, required this.size});

  final Widget child;
  final double size;

  @override
  State<StatefulWidget> createState() => _HaloViewState();
}

class _HaloViewState extends State<_HaloView> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );

  @override
  void initState() {
    super.initState();
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, child) {
      double t = _controller.value;
      double size = widget.size * (1 + 0.2 * t);
      return Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: CupertinoColors.white.withValues(alpha: 0.2 * (1 - t)),
            ),
          ),
          widget.child,
        ],
      );
    },
  );

}
