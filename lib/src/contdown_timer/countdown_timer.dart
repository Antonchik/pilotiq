import 'dart:async';

import 'package:flutter/material.dart';

class CountDownTimerController {
  VoidCallback? start;
  VoidCallback? reset;
  VoidCallback? pause;

  CountDownTimerController({this.start, this.reset, this.pause});
}

class CountDownTimer extends StatefulWidget {
  final int durationInMinutes;
  final CountDownTimerController? controller;

  const CountDownTimer(
      {super.key, required this.durationInMinutes, this.controller});

  @override
  State<CountDownTimer> createState() => _CountDownTimerState();
}

class _CountDownTimerState extends State<CountDownTimer> {
  Timer? _timer;
  int _durationInSeconds = 0;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    _durationInSeconds = widget.durationInMinutes * 60;
    if (widget.controller != null) {
      widget.controller!.start = _startTimer;
      widget.controller!.reset = _resetTimer;
      widget.controller!.pause = _pauseTimer;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.bottomCenter,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.alarm, size: 16, color: Theme.of(context).canvasColor),
          const SizedBox(width: 3),
          Text(
            '${_durationInSeconds ~/ 60}:${(_durationInSeconds % 60).toString().padLeft(2, '0')}',
            style:
                TextStyle(fontSize: 18.0, color: Theme.of(context).canvasColor),
          ),
        ],
      ),
    );
  }

  void _startTimer() {
    if (_timer != null) {
      _timer!.cancel();
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused) {
        setState(() {
          if (_durationInSeconds > 0) {
            _durationInSeconds--;
          } else {
            _timer!.cancel();
          }
        });
      }
    });
  }

  void _pauseTimer() {
    if (_timer != null) {
      _timer!.cancel();
      _isPaused = true;
    }
  }

  void _resetTimer() {
    if (_timer != null) {
      _timer!.cancel();
    }
    setState(() {
      _durationInSeconds = widget.durationInMinutes * 60;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
