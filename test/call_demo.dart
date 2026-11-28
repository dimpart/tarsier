import 'dart:async';

import 'package:flutter/material.dart';

import 'package:dim_flutter/dim_flutter.dart';

import 'package:tarsier/views/meeting/call_controller.dart';


/// Demo entry for the voice call UI:
///
///   flutter run -t test/call_demo.dart
///
/// It auto-plays the full calling cycle so you can watch the window
/// without touching anything; the play buttons stay for manual play.
void main() {
  Log.level = Log.DEBUG;
  // register the ID helpers before parsing identifiers
  LibraryLoader().run();
  runApp(const GetMaterialApp(home: _DemoHome()));
}

class _DemoHome extends StatefulWidget {
  const _DemoHome();

  @override
  State<StatefulWidget> createState() => _DemoHomeState();
}

class _DemoHomeState extends State<_DemoHome> {
  final CallController _controller = CallController();
  Timer? _timer;
  String _title = 'Voice Call Demo';
  int _tapCount = 0;

  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 3), _autoPlay);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _autoPlay() {
    // one full cycle: 1 -> 3 -> 4 -> 5 -> 4 -> 6 (auto close)
    _play('Auto demo');
    _timer = Timer.periodic(const Duration(seconds: 22), (_) => _play('Auto demo'));
  }

  void _play(String action) {
    setState(() => _title = '$action #${++_tapCount}: step1 calling');
    // State 1: dial out
    _controller.call(ID.parse('moky@anywhere')!);
    Timer(const Duration(seconds: 1), () {
      setState(() => _title = '$action #$_tapCount: step2 call returned');
    });
    // State 1 -> 3: accepted by the peer
    Timer(const Duration(seconds: 4), () {
      setState(() => _title = '$action #$_tapCount: step3 answered');
      _controller.answered();
    });
    // State 3 -> 4: connection established
    Timer(const Duration(seconds: 6), () => _controller.connected());
    // State 4 -> 5: connection lost
    Timer(const Duration(seconds: 10), () => _controller.connectionLost());
    // State 5 -> 4: reconnected
    Timer(const Duration(seconds: 13), () => _controller.connected());
    // State 4 -> 6: hung up (auto close after 1 second)
    Timer(const Duration(seconds: 16), () => _controller.hangUp());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          FilledButton(
            onPressed: () => _play('Dial'),
            child: const Text('Dial (State 1 -> 3 -> 4 -> 5 -> 4 -> 6)'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => _invited(),
            child: const Text('Incoming call (State 2, answer -> 3 -> 4)'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => _controller.connectionLost(),
            child: const Text('Simulate network lost (in call: 4 -> 5 -> 4)'),
          ),
        ]),
      ),
    );
  }

  // State 2 -> (accept) -> 3 -> 4
  void _invited() {
    setState(() => _title = 'Incoming #${++_tapCount}');
    _controller.invited(ID.parse('moky@anywhere')!);
    Timer(const Duration(seconds: 8), () => _controller.connected());
  }

}
