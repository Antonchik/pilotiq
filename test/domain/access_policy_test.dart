import 'package:flutter_test/flutter_test.dart';
import 'package:pilotiq/src/domain/access_policy.dart';

void main() {
  test('free user may give the 20th answer but not the 21st', () {
    expect(AccessPolicy.canAnswer(false, 19), isTrue);
    expect(AccessPolicy.canAnswer(false, 20), isFalse);
    expect(AccessPolicy.canAnswer(false, 0), isTrue);
  });

  test('premium is never limited', () {
    expect(AccessPolicy.canAnswer(true, 0), isTrue);
    expect(AccessPolicy.canAnswer(true, 20), isTrue);
    expect(AccessPolicy.canAnswer(true, 5000), isTrue);
  });

  test('remaining answers', () {
    expect(AccessPolicy.remainingAnswers(false, 5), 15);
    expect(AccessPolicy.remainingAnswers(false, 25), 0);
    expect(AccessPolicy.remainingAnswers(true, 25), -1);
  });

  test('free has one simulation per subject', () {
    expect(AccessPolicy.canStartExam(false, 0), isTrue);
    expect(AccessPolicy.canStartExam(false, 1), isFalse);
    expect(AccessPolicy.canStartExam(true, 10), isTrue);
  });

  test('premium-only features', () {
    for (final f in [
      AccessPolicy.canUseMistakes,
      AccessPolicy.canUseReview,
      AccessPolicy.canUseReadinessDetail,
      AccessPolicy.canUseExamBreakdown,
    ]) {
      expect(f(false), isFalse);
      expect(f(true), isTrue);
    }
  });

  test('free sees the first 3 explanations of a topic, premium all', () {
    expect(AccessPolicy.freeExplanationsPerTopic, 3);
    for (final i in [0, 1, 2]) {
      expect(AccessPolicy.canSeeExplanation(false, i), isTrue);
    }
    expect(AccessPolicy.canSeeExplanation(false, 3), isFalse);
    expect(AccessPolicy.canSeeExplanation(false, 40), isFalse);
    expect(AccessPolicy.canSeeExplanation(false, null), isFalse);
    expect(AccessPolicy.canSeeExplanation(true, 3), isTrue);
    expect(AccessPolicy.canSeeExplanation(true, null), isTrue);
  });

  test('free sees the first summary section of a topic, premium all', () {
    expect(AccessPolicy.freeSummarySectionsPerTopic, 1);
    expect(AccessPolicy.canSeeSummarySection(false, 0), isTrue);
    expect(AccessPolicy.canSeeSummarySection(false, 1), isFalse);
    expect(AccessPolicy.canSeeSummarySection(true, 1), isTrue);
    expect(AccessPolicy.canSeeSummarySection(true, 9), isTrue);
  });
}
