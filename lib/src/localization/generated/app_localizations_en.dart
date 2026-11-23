// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get licencePplaTitle => 'PPL(A)';

  @override
  String get licencePplhTitle => 'PPL(H)';

  @override
  String get licenceSplTitle => 'SPL';

  @override
  String get licenceBplTitle => 'BPL';

  @override
  String get licencePplaSubtitle => 'Aeroplane pilot licence';

  @override
  String get licencePplhSubtitle => 'Helicopter pilot licence';

  @override
  String get licenceSplSubtitle => 'Sailplane pilot licence';

  @override
  String get licenceBplSubtitle => 'Balloon pilot licence';

  @override
  String get questionLanguageLabel => 'Question language';

  @override
  String get questionLanguagePolish => 'Polish';

  @override
  String get questionLanguageEnglish => 'English';

  @override
  String get questionLanguageEnglishHint =>
      'English questions are available for PPL(A) and PPL(H).';

  @override
  String get questionShownAsPublishedNote =>
      'Question shown as published by ULC.';

  @override
  String get bankLoadError => 'Could not load the question bank.';

  @override
  String get bankRetryLabel => 'Retry';

  @override
  String bankSourceNote(String source, String date) {
    return 'Source: $source; database date $date';
  }

  @override
  String subjectQuestionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count questions',
      one: '$count question',
    );
    return '$_temp0';
  }

  @override
  String get subjectModeMistakesTitle => 'MY MISTAKES';

  @override
  String get subjectModeMistakesDescription =>
      'Questions you answered wrongly and have not mastered yet.';

  @override
  String get subjectModeReviewTitle => 'REVIEW';

  @override
  String get subjectModeReviewDescription =>
      'Questions that are due for repetition.';

  @override
  String get subjectModeBookmarksTitle => 'BOOKMARKS';

  @override
  String get subjectModeBookmarksDescription =>
      'Questions you saved for later.';

  @override
  String get subjectModeHistoryTitle => 'HISTORY';

  @override
  String get subjectModeHistoryDescription =>
      'Results of your exam simulations.';

  @override
  String get subjectModeSoonBadge => 'Soon';

  @override
  String examMinutesShort(int count) {
    return '$count min';
  }

  @override
  String get appTitle => 'Pilotiq';

  @override
  String get copyright => '© 2023 Anton Antonchik.\nAll rights reserved.';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get examsTitle => 'Exams';

  @override
  String get subjectsTitle => 'Subjects';

  @override
  String get aboutTitle => 'About';

  @override
  String get airLawSubjectTitle => 'Air law';

  @override
  String get communicationsSubjectTitle => 'Communications';

  @override
  String get meteorologySubjectTitle => 'Meteorology';

  @override
  String get navigationSubjectTitle => 'Navigation';

  @override
  String get performanceSubjectTitle => 'Performance and flight planning';

  @override
  String get generalKnowledgeSubjectTitle => 'Aircraft general knowledge';

  @override
  String get humanPerformanceSubjectTitle =>
      'Human performance and limitations';

  @override
  String get operationalProcedureSubjectTitle => 'Operational procedures';

  @override
  String get principlesOfFlightSubjectTitle => 'Principles of flight';

  @override
  String get airLawSubjectTooltip => 'Air law';

  @override
  String get communicationsSubjectTooltip => 'Communications';

  @override
  String get meteorologySubjectTooltip => 'Meteorology';

  @override
  String get navigationSubjectTooltip => 'Navigation';

  @override
  String get performanceSubjectTooltip => 'Performance and flight planning';

  @override
  String get generalKnowledgeSubjectTooltip => 'Aircraft general knowledge';

  @override
  String get humanPerformanceSubjectTooltip =>
      'Human performance and limitations';

  @override
  String get operationalProcedureSubjectTooltip => 'Operational procedures';

  @override
  String get principlesOfFlightSubjectTooltip => 'Principles of flight';

  @override
  String get startQuizTitle => 'Start';

  @override
  String get continueQuizTitle => 'Continue';

  @override
  String get startNewQuizTitle => 'Restart';

  @override
  String get returnToSubjectTitle => 'Return to subject';

  @override
  String get reviewAnswersTitle => 'Review answers';

  @override
  String get restartMessage =>
      'Would you like to continue the test you started before or start over?';

  @override
  String get congratsMessage => 'Congrats!\nYou have completed the test';

  @override
  String get failMessage => 'Oh no!\nYou have failed completion of the test';

  @override
  String get rightAnswer => 'Good Job!';

  @override
  String get wrongAnswer => 'Wrong answer!';

  @override
  String get nextQuestion => 'Next question';

  @override
  String get tryAgain => 'Try again!';

  @override
  String get fullQuizTitle => 'ALL QUESTIONS';

  @override
  String get examQuizTitle => 'EXAM SIMULATOR';

  @override
  String get fullModeDescription =>
      'This mode allows test takers to practice and review a large number of questions, and to learn from their mistakes.';

  @override
  String get examModeDescription =>
      'The exam simulator mode simulates the actual exam experience.';

  @override
  String get languageButtonTooltip => 'Language';

  @override
  String get exitQuizTitle => 'Exit the test?';

  @override
  String get timeIsUpTitle => 'Time is up!';

  @override
  String get timeIsUpMessage => 'You have run out of time.\nYour test is over.';

  @override
  String get goPremiumLabel => 'Go Premium!';

  @override
  String get featuresDescriptionTitle => 'All features at a glance';

  @override
  String get allExamsAccessLabel => 'Access to all exams';

  @override
  String get darkModeAccessLabel => 'Dark mode unlocked';

  @override
  String get allSubjectsAccessLabel => 'Access to all questions';

  @override
  String get specialPriceLabel => 'Get it now!';

  @override
  String get privacyPolicyLabel => 'Privacy Policy';

  @override
  String get premiumUserGreeting => 'You\'re a Premium User!';

  @override
  String get thankYouMessage => 'Thanks for your Support!';

  @override
  String get letsGoMessage => 'Let\'s go!';

  @override
  String get premiumLabel => 'Go Premium!';

  @override
  String get premiumTitle => 'Premium';

  @override
  String get termsOfServiceLabel => 'Terms of Service';

  @override
  String get okLabel => 'OK';

  @override
  String get aboutScreenBody => 'About this app...';

  @override
  String get paywallStubMessage =>
      'Premium purchases will be available here soon.';

  @override
  String get navToday => 'Today';

  @override
  String get navSubjects => 'Subjects';

  @override
  String get navProfile => 'Profile';

  @override
  String get dashboardTitle => 'Today';

  @override
  String dashboardExamCountdown(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days to the exam',
      one: '1 day to the exam',
      zero: 'The exam is today',
    );
    return '$_temp0';
  }

  @override
  String get dashboardExamPassed => 'The exam date has passed';

  @override
  String get dashboardExamNotSet => 'Set your exam date to see the countdown';

  @override
  String get dashboardExamSetDate => 'Set date';

  @override
  String get dashboardGoalTitle => 'Daily goal';

  @override
  String dashboardGoalValue(int answered, int goal) {
    return '$answered/$goal';
  }

  @override
  String get dashboardGoalReached => 'Goal reached, well done!';

  @override
  String dashboardGoalRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count more answers to reach the goal',
      one: '1 more answer to reach the goal',
    );
    return '$_temp0';
  }

  @override
  String get dashboardStreakTitle => 'Streak';

  @override
  String dashboardStreak(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days in a row',
      one: '1 day in a row',
      zero: 'No streak yet',
    );
    return '$_temp0';
  }

  @override
  String get dashboardStreakHint => 'Answer at least one question every day.';

  @override
  String get dashboardDueTitle => 'To review today';

  @override
  String dashboardDue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count questions to review today',
      one: '1 question to review today',
      zero: 'Nothing to review today',
    );
    return '$_temp0';
  }

  @override
  String get dashboardDueHint => 'Open a subject and choose Review.';

  @override
  String get dashboardDueLocked => 'Spaced repetition is part of Premium.';

  @override
  String get dashboardOverviewTitle => 'Your progress';

  @override
  String dashboardCoverage(int percent) {
    return 'Coverage $percent%';
  }

  @override
  String dashboardAccuracy(int percent) {
    return 'Accuracy $percent%';
  }

  @override
  String get dashboardReadinessTitle => 'Exam readiness';

  @override
  String get dashboardReadinessApprox => 'approximate';

  @override
  String get dashboardReadinessLocked =>
      'Readiness by subject is part of Premium.';

  @override
  String dashboardPercentValue(int percent) {
    return '$percent%';
  }

  @override
  String get dashboardWeakTitle => 'Weak subjects';

  @override
  String get dashboardWeakNone =>
      'Answer at least 10 questions in a subject to see it here.';

  @override
  String get dashboardLastExamTitle => 'Last simulation';

  @override
  String get dashboardLastExamNone => 'No exam simulations yet.';

  @override
  String get dashboardPassed => 'Passed';

  @override
  String get dashboardFailed => 'Failed';

  @override
  String dashboardAttemptResult(int percent, String date) {
    return '$percent% · $date';
  }

  @override
  String dashboardLegacyAttempts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count attempts before version 2.0',
      one: '1 attempt before version 2.0',
    );
    return '$_temp0';
  }

  @override
  String get dashboardBeforeV2 => 'Before version 2.0';

  @override
  String get settingsTitle => 'Profile and settings';

  @override
  String get settingsPremiumActive => 'Premium is active';

  @override
  String get settingsPremiumGet => 'Unlock all features';

  @override
  String get settingsSectionLearning => 'Learning';

  @override
  String get settingsSectionAppearance => 'Appearance';

  @override
  String get settingsLicenceTitle => 'Licence';

  @override
  String get settingsExamDateTitle => 'Exam date';

  @override
  String get settingsExamDateNotSet => 'Not set';

  @override
  String get settingsExamDateClear => 'Remove date';

  @override
  String get settingsExamDateHelp => 'Exam date';

  @override
  String settingsDailyGoalValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count questions per day',
      one: '1 question per day',
    );
    return '$_temp0';
  }

  @override
  String get settingsDailyGoalTitle => 'Daily goal';

  @override
  String get settingsThemeTitle => 'Theme';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsSaveError => 'Could not save the setting.';

  @override
  String get settingsRetry => 'Retry';

  @override
  String get settingsAboutSubtitle => 'Version, sources and legal information';

  @override
  String get settingsStartupError => 'The app could not read its data.';

  @override
  String get startupErrorTitle => 'Pilotiq could not start';

  @override
  String get onboardingWelcomeTitle => 'Welcome to Pilotiq';

  @override
  String get onboardingWelcomeBody =>
      'Choose the licence you are preparing for and the language of the questions.';

  @override
  String get onboardingLegacyBanner =>
      'We found your results from the previous version and kept them. Check that the licence is right.';

  @override
  String get onboardingExamDateTitle => 'When is your exam?';

  @override
  String get onboardingExamDateBody =>
      'We count the days and adapt the repetitions to it. You can skip this.';

  @override
  String get onboardingGoalTitle => 'How many questions a day?';

  @override
  String get onboardingGoalBody =>
      'A small daily goal builds a streak. You can change it any time.';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingBack => 'Back';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingFinish => 'Start learning';

  @override
  String onboardingStepOf(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String aboutVersion(String version, String build) {
    return 'Version $version ($build)';
  }

  @override
  String get aboutDisclaimer =>
      'Pilotiq is not affiliated with ULC or EASA and is not their product.';

  @override
  String get aboutBankTitle => 'Question database';

  @override
  String aboutBankSourceLine(String licence, String source, String date) {
    return '$licence: $source, $date';
  }

  @override
  String get aboutQuestionsNote =>
      'Question texts are given as published by ULC.';

  @override
  String practiceProgress(int current, int total) {
    return '$current / $total';
  }

  @override
  String get practiceFinishSession => 'Finish session';

  @override
  String get practiceLastQuestionButton => 'Finish';

  @override
  String get practiceBookmarkAdd => 'Bookmark question';

  @override
  String get practiceBookmarkRemove => 'Remove bookmark';

  @override
  String get practiceFeedbackCorrect => 'Correct!';

  @override
  String get practiceFeedbackWrong =>
      'Wrong. The correct answer is highlighted.';

  @override
  String get practiceAnswerCorrectSemantics => 'correct answer';

  @override
  String get practiceAnswerWrongSemantics => 'your answer, wrong';

  @override
  String get practiceRetryTitle => 'REPEAT MISTAKES';

  @override
  String get practiceSummaryTitle => 'Session summary';

  @override
  String practiceSummaryCorrect(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count correct answers',
      one: '$count correct answer',
    );
    return '$_temp0';
  }

  @override
  String practiceSummaryWrong(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count wrong answers',
      one: '$count wrong answer',
    );
    return '$_temp0';
  }

  @override
  String practiceSummaryAccuracy(int percent) {
    return 'Accuracy: $percent%';
  }

  @override
  String get practiceSummaryNothing =>
      'You have not answered any question in this session.';

  @override
  String get practiceRepeatMistakes => 'Repeat mistakes of this session';

  @override
  String get practiceEmptyLearn => 'There are no questions to practise here.';

  @override
  String get practiceEmptyMistakes => 'No mistakes to fix. Well done!';

  @override
  String get practiceEmptyReview => 'Nothing is due for review today.';

  @override
  String get practiceEmptyBookmarks =>
      'You have not bookmarked any question in this subject yet.';

  @override
  String get practiceLimitTitle => 'Daily limit reached';

  @override
  String practiceLimitBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Free access includes $count answers per day.',
      one: 'Free access includes $count answer per day.',
    );
    return '$_temp0 Come back tomorrow or go Premium for unlimited practice.';
  }

  @override
  String get practiceLockedTitle => 'Premium feature';

  @override
  String get practiceLockedBody =>
      'My mistakes and spaced review are available in Premium.';

  @override
  String get practiceLockedBadge => 'Premium';

  @override
  String practiceModeLearnStatus(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count questions not seen yet',
      one: '$count question not seen yet',
      zero: 'All questions covered',
    );
    return '$_temp0';
  }

  @override
  String practiceModeMistakesStatus(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count questions to fix',
      one: '$count question to fix',
      zero: 'No mistakes',
    );
    return '$_temp0';
  }

  @override
  String practiceModeReviewStatus(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count questions due',
      one: '$count question due',
      zero: 'Nothing due',
    );
    return '$_temp0';
  }

  @override
  String practiceModeBookmarksStatus(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bookmarked questions',
      one: '$count bookmarked question',
      zero: 'No bookmarks',
    );
    return '$_temp0';
  }

  @override
  String practiceSubjectCoverage(int percent) {
    return '$percent% covered';
  }

  @override
  String practiceSubjectAccuracy(int percent) {
    return '$percent% accuracy';
  }

  @override
  String get practiceSubjectNotStarted => 'Not started';

  @override
  String get practiceLoadError => 'Could not load the questions.';
}
