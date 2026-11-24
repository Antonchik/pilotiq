/// Single place with the free / premium boundary. Premium itself is read from
/// `isPremiumProvider`; this class only decides what each tier may do.
class AccessPolicy {
  const AccessPolicy._();

  static const int freeDailyAnswers = 20;
  static const int freeExamsPerSubject = 1;

  /// Explanations open for free in every topic of the study materials: the
  /// first ones of the topic's order among the questions of the licence.
  static const int freeExplanationsPerTopic = 3;

  /// Sections of every topic summary open for free (from the first one).
  static const int freeSummarySectionsPerTopic = 1;

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

  /// [indexInTopic] is the 0-based position of the explanation in its topic,
  /// counted only over the questions of the user's licence; `null` when the
  /// explanation belongs to no topic (then it is Premium only).
  static bool canSeeExplanation(bool isPremium, int? indexInTopic) =>
      isPremium ||
      (indexInTopic != null && indexInTopic < freeExplanationsPerTopic);

  /// [sectionIndex] is the 0-based position of the section in its summary.
  static bool canSeeSummarySection(bool isPremium, int sectionIndex) =>
      isPremium || sectionIndex < freeSummarySectionsPerTopic;
}
