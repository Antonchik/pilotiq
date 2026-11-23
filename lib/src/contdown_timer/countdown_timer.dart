import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pilotiq/src/localization/generated/app_localizations.dart';

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
      widget.controller!.start = () => _startTimer(context);
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
          Icon(Icons.alarm,
              size: 16, color: Theme.of(context).colorScheme.inversePrimary),
          const SizedBox(width: 3),
          Text(
            '${_durationInSeconds ~/ 60}:${(_durationInSeconds % 60).toString().padLeft(2, '0')}',
            style: TextStyle(
                fontSize: 16.0,
                color: Theme.of(context).colorScheme.inversePrimary),
          ),
        ],
      ),
    );
  }

  void _startTimer(BuildContext context) {
    if (_timer != null) {
      _timer!.cancel();
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final local = AppLocalizations.of(context)!;
      if (!_isPaused) {
        setState(() {
          if (_durationInSeconds > 0) {
            _durationInSeconds--;
          } else {
            _timer!.cancel();
            showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => AlertDialog(
                      icon: const Icon(Icons.alarm),
                      title: Text(local.timeIsUpTitle),
                      content: Text(
                        local.timeIsUpMessage,
                        textAlign: TextAlign.center,
                      ),
                      actions: [
                        TextButton(
                          child: const Text('OK'),
                          onPressed: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).pop();
                          },
                        )
                      ],
                    ));
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
