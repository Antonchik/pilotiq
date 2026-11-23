/// Single place with the free / premium boundary. Premium itself is read from
/// `isPremiumProvider`; this class only decides what each tier may do.
class AccessPolicy {
  const AccessPolicy._();

  static const int freeDailyAnswers = 20;
  static const int freeExamsPerSubject = 1;

  /// [answeredToday] is the number of answers already given today.
  static bool canAnswer(bool isPremium, int answeredToday) =>
      isPremium || answeredToday < freeDailyAnswers;

  static int remainingAnswers(bool isPremium, int answeredToday) {
    if (isPremium) return -1;
    final left = freeDailyAnswers - answeredToday;
    return left < 0 ? 0 : left;
  }

  /// [examsTakenInSubject] counts finished simulations of the subject.
  static bool canStartExam(bool isPremium, int examsTakenInSubject) =>
      isPremium || examsTakenInSubject < freeExamsPerSubject;

  static bool canUseMistakes(bool isPremium) => isPremium;
  static bool canUseReview(bool isPremium) => isPremium;
  static bool canUseReadinessDetail(bool isPremium) => isPremium;
  static bool canUseExamBreakdown(bool isPremium) => isPremium;
}
