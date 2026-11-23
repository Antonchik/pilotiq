import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pilotiq/src/bank/bank_text.dart';
import 'package:pilotiq/src/bank/models.dart';
import 'package:pilotiq/src/localization/generated/app_localizations.dart';
import 'package:pilotiq/src/progress/providers.dart';
import 'package:pilotiq/src/progress/user_settings.dart';
import 'package:pilotiq/src/quiz/state/quiz_state.dart';
import 'package:pilotiq/src/quiz/widgets/answer_card.dart';

class QuestionPage extends ConsumerStatefulWidget {
  const QuestionPage({super.key, required this.question});

  final Question question;

  @override
  ConsumerState<QuestionPage> createState() => _QuestionPageState();
}

class _QuestionPageState extends ConsumerState<QuestionPage> {
  /// Answers are shuffled once per page, when it is shown.
  late final ShuffledAnswers _shuffled = shuffledAnswers(
    widget.question,
    ref.read(randomProvider),
  );

  /// Position (in the shown order) of the tapped answer.
  int? _selected;
  bool _recorded = false;
  bool _done = false;

  void _record(QuizState state, bool correct) {
    if (_recorded) return;
    _recorded = true;
    final repository = ref.read(progressRepositoryProvider);
    unawaited(
      repository
          .recordAnswer(
            state.quiz.licence,
            widget.question.id,
            correct,
            ref.read(clockProvider).now(),
          )
          .then<void>(
            (_) {},
            onError: (Object e) => debugPrint('Could not save progress: $e'),
          ),
    );
  }

  void _onTap(QuizState state, int position) {
    if (_done) return;
    final canonical = _shuffled.canonicalIndexAt(position);
    final answer = QuizAnswer(
      question: widget.question,
      canonicalIndex: canonical,
    );
    setState(() => _selected = position);
    if (state.isExam) {
      _done = true;
      state.answers.add(answer);
      HapticFeedback.lightImpact();
      state.nextPage();
      return;
    }
    _record(state, answer.isCorrect);
    if (answer.isCorrect) {
      _done = true;
      HapticFeedback.heavyImpact();
      Future<void>.delayed(const Duration(milliseconds: 500))
          .then((_) => state.nextPage());
    } else {
      HapticFeedback.vibrate();
      _showWrongSheet();
    }
  }

  void _showWrongSheet() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (BuildContext context) {
        final local = AppLocalizations.of(context)!;
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                local.wrongAnswer,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: Text(
                  local.tryAgain,
                  style: const TextStyle(
                    color: Colors.white,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    final state = ref.watch(quizStateProvider);
    final question = widget.question;
    final language = question.displayLanguage(state.language);
    final fellBack =
        state.language == QuestionLanguage.en &&
        language == QuestionLanguage.pl;
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: BankText(
              question.text.resolve(language),
              textAlign: TextAlign.justify,
              style: Theme.of(context).textTheme.bodyLarge!
                  .copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        if (fellBack)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              local.questionShownInPolishNote,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            child: ListView.builder(
              itemCount: _shuffled.length,
              itemBuilder: (context, position) {
                final canonical = _shuffled.canonicalIndexAt(position);
                final isCorrect = canonical == question.correctIndex;
                final reveal = !state.isExam && _selected == position;
                return AnswerCard(
                  text: question.answers[canonical].resolve(language),
                  selected: _selected == position,
                  feedback: reveal
                      ? (isCorrect ? Colors.green : Colors.red)
                      : null,
                  onTap: () => _onTap(state, position),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
