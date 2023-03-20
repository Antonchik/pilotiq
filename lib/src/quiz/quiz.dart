import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:ulc_exam_simulator/src/topics/topic_model.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

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
  _CountDownTimerState createState() => _CountDownTimerState();
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
          const Icon(Icons.alarm, size: 14),
          const SizedBox(width: 5),
          Text(
            '${_durationInSeconds ~/ 60}:${(_durationInSeconds % 60).toString().padLeft(2, '0')}',
            style: const TextStyle(fontSize: 16.0),
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

class QuizScreen extends ConsumerWidget {
  QuizScreen({super.key, required this.quizId, required this.quiz});

  final String quizId;
  final Quiz quiz;

  final timerController = CountDownTimerController();

  void _stopTimer() {
    if (timerController.pause != null) {
      timerController.pause!();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quizState = ref.watch(quizStateProvider);
    quizState.isExam = quizId == 'exam';
    final questionQty = quiz.questions.length;
    final currentQuestion =
        (quizState.progress * questionQty).toStringAsFixed(0);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            AnimatedProgressbar(value: quizState.progress),
          ],
        ),
        flexibleSpace: quiz.id == 'exam'
            ? CountDownTimer(controller: timerController, durationInMinutes: 20)
            : null,
        leading: IconButton(
          icon: const Icon(FontAwesomeIcons.xmark),
          onPressed: () {
            quizState.reset();
            if (timerController.reset != null) {
              timerController.reset!();
            }
            Navigator.pop(context);
          },
        ),
        actions: [
          Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.only(right: 10),
            child: Text('$currentQuestion/$questionQty'),
          )
        ],
      ),
      body: PageView.builder(
        physics: const NeverScrollableScrollPhysics(),
        scrollDirection: Axis.vertical,
        controller: quizState.controller,
        onPageChanged: (int idx) =>
            quizState.progress = (idx / (quiz.questions.length + 1)),
        itemBuilder: (BuildContext context, int idx) {
          if (idx == 0) {
            return StartPage(quiz: quiz, timerController: timerController);
          } else if (idx == quiz.questions.length + 1) {
            if (quizId != 'exam') {
              quizState.reset();
              return CongratsPage(quiz: quiz, quizState: quizState);
            } else {
              _stopTimer();
              if (quizState.result) {
                return CongratsPage(quiz: quiz, quizState: quizState);
              } else {
                return FailPage(quiz: quiz, quizState: quizState);
              }
            }
          } else {
            return QuestionPage(question: quiz.questions[idx - 1]);
          }
        },
      ),
    );
  }
}

class StartPage extends ConsumerWidget {
  final Quiz quiz;
  final CountDownTimerController? timerController;

  const StartPage({super.key, required this.quiz, this.timerController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var state = ref.watch(quizStateProvider);
    final local = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(quiz.title, style: Theme.of(context).textTheme.headlineMedium),
          const Divider(),
          Expanded(
              child: Text(
            quiz.description,
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.justify,
          )),
          ButtonBar(
            alignment: MainAxisAlignment.center,
            children: <Widget>[
              ElevatedButton.icon(
                onPressed: () {
                  state.nextPage();
                  timerController?.start?.call();
                },
                label: Text(
                  local.startQuizTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                icon: const Icon(Icons.checklist),
              )
            ],
          )
        ],
      ),
    );
  }
}

class CongratsPage extends StatelessWidget {
  final Quiz quiz;
  final QuizState quizState;

  const CongratsPage({super.key, required this.quiz, required this.quizState});

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            local.congratsMessage(quiz.title),
            textAlign: TextAlign.center,
          ),
          const Divider(),
          ElevatedButton.icon(
            style: TextButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            icon: const Icon(FontAwesomeIcons.faceSmile),
            label: Text(local.returnToTopicTitle),
            onPressed: () {
              quizState.reset();

              Navigator.pushNamedAndRemoveUntil(
                context,
                '/',
                (route) => false,
              );
            },
          )
        ],
      ),
    );
  }
}

class FailPage extends StatelessWidget {
  final Quiz quiz;
  final QuizState quizState;

  const FailPage({super.key, required this.quiz, required this.quizState});

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            local.failMessage(quiz.title),
            textAlign: TextAlign.center,
          ),
          const Divider(),
          ElevatedButton.icon(
            style: TextButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            icon: const Icon(FontAwesomeIcons.faceFrown),
            label: Text(local.returnToTopicTitle),
            onPressed: () {
              quizState.reset();
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/',
                (route) => false,
              );
            },
          )
        ],
      ),
    );
  }
}

class QuestionPage extends ConsumerWidget {
  final Question question;

  const QuestionPage({super.key, required this.question});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var state = ref.watch(quizStateProvider);
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            alignment: Alignment.center,
            child: Text(question.question,
                style: Theme.of(context).textTheme.bodyLarge),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: question.answers.map((answer) {
              return Container(
                height: 90,
                margin: const EdgeInsets.only(bottom: 10),
                color: Colors.black26,
                child: InkWell(
                  onTap: () {
                    state.selected = answer;
                    if (state.isExam) {
                      state.answer = answer.isCorrect;
                      state.nextPage();
                    } else {
                      _bottomSheet(context, answer, state);
                    }
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                            state.selected == answer
                                ? FontAwesomeIcons.circleCheck
                                : FontAwesomeIcons.circle,
                            size: 20),
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.only(left: 12),
                            child: Text(
                              answer.value,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        )
      ],
    );
  }

  /// Bottom sheet shown when Question is answered
  _bottomSheet(BuildContext context, Answer opt, QuizState state) {
    bool correct = opt.isCorrect;

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        final local = AppLocalizations.of(context)!;
        return Container(
          height: 250,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Text(correct ? local.rightAnswer : local.wrongAnswer),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: correct ? Colors.green : Colors.red),
                child: Text(
                  correct ? local.nextQuestion : local.tryAgain,
                  style: const TextStyle(
                    color: Colors.white,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () {
                  if (correct) {
                    state.nextPage();
                  }
                  state.answer = correct;
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

final quizStateProvider = ChangeNotifierProvider((ref) => QuizState());

class QuizState with ChangeNotifier {
  double _progress = 0;
  Answer? _selected;
  final List<bool> _answers = [];
  bool isExam = false;

  final PageController controller = PageController();

  double get progress => _progress;

  Answer? get selected => _selected;

  bool get result {
    var right = 0;
    var wrong = 0;
    for (final answer in _answers) {
      if (answer) {
        right += 1;
      } else {
        wrong += 1;
      }
    }
    return !(right / (right + wrong) < 0.75);
  }

  set progress(double newValue) {
    _progress = newValue;
    notifyListeners();
  }

  set selected(Answer? newValue) {
    _selected = newValue;
    notifyListeners();
  }

  set answer(bool newValue) {
    _answers.add(newValue);
    notifyListeners();
  }

  void reset() {
    _progress = 0;
    _selected = null;
    _answers.clear();
    isExam = false;
    notifyListeners();
  }

  void nextPage() async {
    await controller.nextPage(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
    );
  }
}

class AnimatedProgressbar extends StatelessWidget {
  final double value;
  final double height;

  const AnimatedProgressbar({super.key, required this.value, this.height = 12});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        return Container(
          padding: const EdgeInsets.all(10),
          width: box.maxWidth,
          child: Stack(
            children: [
              Container(
                height: height,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.background,
                  borderRadius: BorderRadius.all(
                    Radius.circular(height),
                  ),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                height: height,
                width: box.maxWidth * _floor(value),
                decoration: BoxDecoration(
                  color: _colorGen(value),
                  borderRadius: BorderRadius.all(
                    Radius.circular(height),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Always round negative or NaNs to min value
  _floor(double value, [min = 0.0]) {
    return value.sign <= min ? min : value;
  }

  _colorGen(double value) {
    int rbg = (value * 255).toInt();
    return Colors.deepOrange.withGreen(rbg).withRed(255 - rbg);
  }
}

List<Quiz> composeQuizes(List<Question> questions,
    {required AppLocalizations local, int qty = 12}) {
  return [
    generateDemoQuiz(questions, local: local),
    generateFullQuiz(questions, local: local),
    generateExamQuiz(questions, local: local),
  ];
}

Quiz generateDemoQuiz(List<Question> questions,
    {required AppLocalizations local}) {
  final demoQuestions = questions.sublist(0, 12);
  return Quiz(
    id: 'demo',
    title: local.demoQuizTitle,
    questions: demoQuestions,
    description: local.demoModeDescription,
  );
}

Quiz generateFullQuiz(List<Question> questions,
    {required AppLocalizations local}) {
  final allQuestions = questions.toList()..shuffle();
  return Quiz(
    id: 'test',
    title: local.fullQuizTitle,
    questions: allQuestions,
    description: local.fullModeDescription,
  );
}

Quiz generateExamQuiz(List<Question> questions,
    {required AppLocalizations local}) {
  final examQuestions = (questions.toList()..shuffle()).sublist(0, 12);
  return Quiz(
    id: 'exam',
    title: local.examQuizTitle,
    questions: examQuestions,
    description: local.examModeDescription,
  );
}
