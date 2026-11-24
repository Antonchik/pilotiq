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
  String get appTitle => 'Pilotiq';

  @override
  String get copyright => '© 2023 Anton Antonchik.\nAll rights reserved.';

  @override
  String get no => 'No';

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
  String get returnToSubjectTitle => 'Return to subject';

  @override
  String get nextQuestion => 'Next question';

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
  String get goPremiumLabel => 'Go Premium!';

  @override
  String get privacyPolicyLabel => 'Privacy Policy';

  @override
  String get premiumTitle => 'Premium';

  @override
  String get termsOfServiceLabel => 'Terms of Service';

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
  String get dashboardDataError => 'Could not open your progress data.';

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
  String get recoveryNoticeTitle => 'Saved data was damaged';

  @override
  String get recoveryNoticeRestored =>
      'Part of your saved data was damaged. The readable part was restored.';

  @override
  String get recoveryNoticeReset =>
      'Part of your saved data was damaged and had to be reset.';

  @override
  String get recoveryNoticeBackup =>
      'A backup copy of the damaged file was saved on this device.';

  @override
  String get recoveryNoticeOk => 'OK';

  @override
  String get examScreenTitle => 'Exam simulation';

  @override
  String get examRulesHeading => 'Before you start';

  @override
  String examRulesQuestions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count questions',
      one: '$count question',
    );
    return '$_temp0';
  }

  @override
  String examRulesTime(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
      one: '$minutes minute',
    );
    return 'Time limit: $_temp0';
  }

  @override
  String examRulesPass(int percent) {
    return 'Pass mark: $percent% of all questions. An unanswered question counts as wrong.';
  }

  @override
  String get examRulesNavigate =>
      'You can move between questions freely and change your answers until you finish the exam.';

  @override
  String get examRulesNoFeedback =>
      'The correct answer is not shown during the exam. Mark a question to come back to it later.';

  @override
  String get examRulesTimer =>
      'The timer keeps running when you leave the app. When time runs out the exam ends and the result is saved.';

  @override
  String get examRulesFresh =>
      'Every attempt draws a new random set of questions of this subject, spread across its topics.';

  @override
  String get examStartButton => 'Start exam';

  @override
  String get examStartFailed =>
      'The exam could not be started because the attempt could not be saved on this device.';

  @override
  String get examSaveRetry => 'Retry';

  @override
  String get examLimitTitle => 'Free simulation used';

  @override
  String get examLimitBody =>
      'You have used the free simulation of this subject. Premium gives unlimited simulations with history and topic breakdown.';

  @override
  String get examLimitHistory => 'Open history';

  @override
  String get examResumeTitle => 'Unfinished exam';

  @override
  String examResumeBody(int answered, int total, int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
      one: '$minutes minute',
    );
    return 'You have an exam in progress: $answered of $total answered, $_temp0 left.';
  }

  @override
  String get examResumeContinue => 'Continue exam';

  @override
  String get examResumeFinish => 'Finish exam now';

  @override
  String examQuestionOf(int current, int total) {
    return 'Question $current of $total';
  }

  @override
  String examAnsweredCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count answered',
      one: '$count answered',
    );
    return '$_temp0';
  }

  @override
  String examTimeLeftSemantics(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes left',
      one: '$minutes minute left',
    );
    return '$_temp0';
  }

  @override
  String get examTimeLow => 'Low time';

  @override
  String get examPrevious => 'Previous';

  @override
  String get examNext => 'Next';

  @override
  String get examFlagAdd => 'Mark to come back later';

  @override
  String get examFlagRemove => 'Marked: tap to unmark';

  @override
  String get examGridTooltip => 'Question grid';

  @override
  String get examFinishTooltip => 'Finish exam';

  @override
  String get examFinishButton => 'Finish exam';

  @override
  String examAnswerSemantics(int position, int total, String text) {
    return 'Answer $position of $total: $text';
  }

  @override
  String get examPersistError =>
      'Your progress could not be saved on this device. Your answers are kept for now.';

  @override
  String get examGridTitle => 'Questions';

  @override
  String get examGridLegendAnswered => 'Answered';

  @override
  String get examGridLegendUnanswered => 'Not answered';

  @override
  String get examGridLegendFlagged => 'Marked';

  @override
  String get examGridClose => 'Close';

  @override
  String examGridCell(int number) {
    return 'Question $number';
  }

  @override
  String get examGridStateAnswered => 'answered';

  @override
  String get examGridStateUnanswered => 'not answered';

  @override
  String get examGridStateFlagged => 'marked to come back';

  @override
  String get examGridStateCurrent => 'current question';

  @override
  String get examFinishDialogTitle => 'Finish the exam?';

  @override
  String examFinishUnanswered(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count questions are not answered.',
      one: '$count question is not answered.',
      zero: 'All questions are answered.',
    );
    return '$_temp0';
  }

  @override
  String get examFinishUnansweredNote =>
      'Questions without an answer count as wrong.';

  @override
  String examFinishFlagged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count questions are marked to come back to.',
      one: '$count question is marked to come back to.',
      zero: 'No questions are marked.',
    );
    return '$_temp0';
  }

  @override
  String get examFinishKeepWorking => 'Keep working';

  @override
  String get examFinishConfirm => 'Finish exam';

  @override
  String get examLeaveTitle => 'Leave the exam?';

  @override
  String get examLeaveBody =>
      'The timer keeps running. You can continue from the subject screen until time runs out.';

  @override
  String get examLeaveStay => 'Stay';

  @override
  String get examLeaveConfirm => 'Leave';

  @override
  String get examSavingResult => 'Saving your result…';

  @override
  String get examFinishSaveError =>
      'Your result could not be saved yet. It is not shown as saved until it is.';

  @override
  String get examTimeUpNotice =>
      'Time is up. The exam was finished automatically and your result was saved.';

  @override
  String get examExpiredOnOpenNotice =>
      'Time ran out while the exam was not open. It was finished and saved automatically.';

  @override
  String get examResultTitle => 'Exam result';

  @override
  String get examPassed => 'PASSED';

  @override
  String get examFailed => 'NOT PASSED';

  @override
  String examResultCorrect(int correct, int total) {
    return '$correct of $total correct';
  }

  @override
  String examResultPassMark(int percent) {
    return 'Pass mark: $percent%';
  }

  @override
  String examResultTime(String time) {
    return 'Time used: $time';
  }

  @override
  String examResultUnanswered(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count questions without an answer (counted as wrong).',
      one: '$count question without an answer (counted as wrong).',
      zero: 'Every question was answered.',
    );
    return '$_temp0';
  }

  @override
  String get examBreakdownTitle => 'Results by topic';

  @override
  String examBreakdownRow(String topic, int correct, int total, int percent) {
    return '$topic: $correct of $total ($percent%)';
  }

  @override
  String get examTeaserTitle => 'Topic breakdown and answer review';

  @override
  String get examTeaserBody =>
      'With Premium you see where you lose points, review every answer and train the questions you missed.';

  @override
  String get examReviewButton => 'Review answers';

  @override
  String get examTrainMistakes => 'Train mistakes of this attempt';

  @override
  String get examRepeat => 'Repeat exam';

  @override
  String get examHistoryButton => 'History';

  @override
  String get examReviewTitle => 'Answer review';

  @override
  String get examReviewFilterAll => 'All';

  @override
  String get examReviewFilterWrong => 'Wrong or unanswered';

  @override
  String examReviewQuestionNumber(int index, int total) {
    return 'Question $index of $total';
  }

  @override
  String get examReviewYourAnswer => 'Your answer';

  @override
  String get examReviewCorrectAnswer => 'Correct answer';

  @override
  String get examReviewNoAnswer => 'No answer given';

  @override
  String get examReviewMissing =>
      'This question is no longer in the question bank.';

  @override
  String get examReviewMarkCorrect => 'Correct';

  @override
  String get examReviewMarkWrong => 'Wrong';

  @override
  String get examReviewMarkUnanswered => 'Not answered';

  @override
  String get examReviewEmptyWrong => 'No wrong answers in this attempt.';

  @override
  String get examReviewFlagged => 'Marked to come back';

  @override
  String get examHistoryTitle => 'Exam history';

  @override
  String get examHistoryEmpty =>
      'No simulations yet. Your results will appear here.';

  @override
  String get examHistoryLegacy => 'Before version 2.0';

  @override
  String get examHistoryLoadError => 'The history could not be loaded.';

  @override
  String get examHistoryChartTitle => 'Last results';

  @override
  String examHistoryChartSemantics(String results) {
    return 'Last results, oldest first: $results';
  }

  @override
  String get examHistoryTimedOut => 'Time ran out';

  @override
  String examHistoryPassLine(int percent) {
    return 'Pass mark $percent%';
  }

  @override
  String examTileInProgress(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
      one: '$minutes minute',
    );
    return 'Unfinished attempt, $_temp0 left';
  }

  @override
  String examTileLastPassed(int percent) {
    return 'Last result: $percent%, passed';
  }

  @override
  String examTileLastFailed(int percent) {
    return 'Last result: $percent%, not passed';
  }

  @override
  String get examLeaveUnsavedBody =>
      'Your latest answers could not be saved on this device and will be lost if you leave. The timer keeps running.';

  @override
  String get examLeaveUnsavedResultBody =>
      'Your result is not saved yet. If you leave now, the exam stays unfinished and its result is saved when you open it again. It cannot be continued.';

  @override
  String get examLeaveResultSavedBody =>
      'Your result is saved. Some answers are not yet added to your progress; they will be added automatically.';

  @override
  String get examLeaveNotMarkedBody =>
      'The end of the exam could not be saved, but your answers are. If you leave, the exam can be continued and the time keeps running.';

  @override
  String get examLeaveContinueLostBody =>
      'The end of the exam and your latest answers could not be saved. The latest answers will be lost. If you leave, the exam can be continued from the last saved state and the time keeps running.';

  @override
  String get examLeaveTimeoutSavedBody =>
      'Time is up, but the result could not be saved yet. If you leave, it will be calculated from the saved answers when you open the exam again.';

  @override
  String get examLeaveTimeoutLostBody =>
      'Time is up, but the result could not be saved yet. If you leave, it will be calculated from the saved answers when you open the exam again. Your latest answers were not saved and will not count.';

  @override
  String get examClockPersistError =>
      'The time of your exam could not be saved on this device. Your answers are saved.';

  @override
  String get reminderChannelName => 'Study reminders';

  @override
  String get reminderChannelDescription =>
      'A daily reminder to study for the exam';

  @override
  String get reminderStudyTitle => 'Time to study';

  @override
  String reminderDaysToExam(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days to the exam',
      one: '1 day to the exam',
    );
    return '$_temp0';
  }

  @override
  String reminderGoalLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count answers to today\'s goal',
      one: '1 answer to today\'s goal',
    );
    return '$_temp0';
  }

  @override
  String reminderDueQuestions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count questions to review',
      one: '1 question to review',
    );
    return '$_temp0';
  }

  @override
  String get reminderExamWeekTitle => 'One week to the exam';

  @override
  String get reminderExamEveTitle => 'Your exam is tomorrow';

  @override
  String get reminderExamEveBody =>
      'Go over your mistakes once more and get a good night\'s sleep.';

  @override
  String get reminderAfterExamTitle => 'How did the exam go?';

  @override
  String get reminderAfterExamBody =>
      'Good luck with the result! If you need another go, set a new exam date in Profile.';

  @override
  String get remindersSectionTitle => 'Reminders';

  @override
  String get remindersToggleTitle => 'Daily study reminder';

  @override
  String get remindersToggleOff => 'Off';

  @override
  String remindersToggleOn(String time) {
    return 'Every day at $time';
  }

  @override
  String get remindersTimeTitle => 'Reminder time';

  @override
  String get remindersBlocked =>
      'Notifications are blocked for the app, so no reminders will be shown.';

  @override
  String get remindersOpenSettings => 'Open system settings';

  @override
  String get remindersOpenSettingsFailed =>
      'Could not open the settings. Open your phone\'s Settings, then Apps, Pilotiq, Notifications.';

  @override
  String get remindersScheduleFailed => 'The reminders could not be scheduled.';

  @override
  String get remindersRetry => 'Try again';

  @override
  String get onboardingRemindersTitle => 'When should we remind you?';

  @override
  String get onboardingRemindersBody =>
      'One reminder a day at the time you choose. The app asks the system for permission to show notifications only after you tap the button below.';

  @override
  String get onboardingRemindersEnable => 'Turn on reminders';

  @override
  String onboardingRemindersEnabled(String time) {
    return 'Reminders are on, every day at $time.';
  }

  @override
  String get onboardingRemindersDenied =>
      'Notifications are not allowed. You can turn the reminders on later in Profile.';

  @override
  String get paywallClose => 'Close';

  @override
  String get paywallTitleDailyLimit => 'Today\'s free limit is used up';

  @override
  String paywallSubtitleDailyLimit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Free access includes $count answers per day. Premium has no daily limit.',
      one:
          'Free access includes $count answer per day. Premium has no daily limit.',
    );
    return '$_temp0';
  }

  @override
  String get paywallTitleExamLimit => 'The free simulation is used';

  @override
  String paywallSubtitleExamLimit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Free access includes $count simulations per subject. Premium gives unlimited simulations and topic breakdown.',
      one:
          'Free access includes $count simulation per subject. Premium gives unlimited simulations and topic breakdown.',
    );
    return '$_temp0';
  }

  @override
  String get paywallTitleLocked => 'This feature is part of Premium';

  @override
  String get paywallSubtitleLocked =>
      'My mistakes and spaced repetition help you return to the questions you still get wrong.';

  @override
  String get paywallTitleResults => 'Topic breakdown is part of Premium';

  @override
  String get paywallSubtitleResults =>
      'See where you lose points, review every answer and train the questions you missed.';

  @override
  String get paywallTitleProfile => 'Pilotiq Premium';

  @override
  String get paywallSubtitleProfile =>
      'Study without limits and see where you stand in each subject.';

  @override
  String get paywallBenefitsTitle => 'With Premium';

  @override
  String paywallBenefitUnlimited(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Practice without a daily limit (free: $count answers a day)',
      one: 'Practice without a daily limit (free: $count answer a day)',
    );
    return '$_temp0';
  }

  @override
  String paywallBenefitSimulations(int count) {
    return 'Unlimited exam simulations with topic breakdown of the results (free: $count per subject)';
  }

  @override
  String get paywallBenefitMistakes =>
      'My mistakes: train the questions you got wrong';

  @override
  String get paywallBenefitReview =>
      'Spaced repetition of the questions due for review';

  @override
  String get paywallBenefitReadiness =>
      'Detailed readiness by subject (approximate)';

  @override
  String get paywallChoosePlan => 'Choose a plan';

  @override
  String get paywallBestChoice => 'Best choice';

  @override
  String get paywallPlanLifetime => 'Lifetime';

  @override
  String paywallLifetimePrice(String price) {
    return '$price · one-time payment';
  }

  @override
  String paywallDurationDay(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '$count day',
    );
    return '$_temp0';
  }

  @override
  String paywallDurationWeek(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weeks',
      one: '$count week',
    );
    return '$_temp0';
  }

  @override
  String paywallDurationMonth(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count months',
      one: '$count month',
    );
    return '$_temp0';
  }

  @override
  String paywallDurationYear(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count years',
      one: '$count year',
    );
    return '$_temp0';
  }

  @override
  String get paywallPerDay => 'day';

  @override
  String get paywallPerWeek => 'week';

  @override
  String get paywallPerMonth => 'month';

  @override
  String get paywallPerYear => 'year';

  @override
  String paywallPricePer(String price, String period) {
    return '$price / $period';
  }

  @override
  String paywallIntroFree(String trial, String price) {
    return '$trial free, then $price';
  }

  @override
  String paywallIntroPaid(String period, String introPrice, String price) {
    return '$period: $introPrice, then $price';
  }

  @override
  String get paywallContinue => 'Continue';

  @override
  String get paywallRestore => 'Restore purchases';

  @override
  String get paywallRenewalNotice =>
      'Subscriptions renew automatically for the same period at the price shown until you cancel. Payment is charged to your store account. To avoid the next charge, cancel in your account settings in the store at least 24 hours before the current period ends.';

  @override
  String get paywallRenewalNoticeIos =>
      'Subscriptions renew automatically for the same period at the price shown until you cancel. Payment is charged to your Apple ID account. To avoid the next charge, cancel in your Apple ID account settings (App Store) at least 24 hours before the current period ends.';

  @override
  String get paywallRenewalNoticeAndroid =>
      'Subscriptions renew automatically for the same period at the price shown until you cancel. Payment is charged to your Google Play account. To avoid the next charge, cancel in your Google Play account settings at least 24 hours before the current period ends.';

  @override
  String get paywallTrialNotice =>
      'A free trial becomes a paid subscription at the price shown unless you cancel before it ends.';

  @override
  String get paywallOneTimeNotice =>
      'Lifetime is a one-time payment: it does not renew and is not a subscription.';

  @override
  String get paywallLoading => 'Loading plans…';

  @override
  String get paywallErrorNetwork =>
      'No connection. Check your internet and try again.';

  @override
  String get paywallErrorStore =>
      'The store could not complete the request. Please try again later.';

  @override
  String get paywallErrorUnknown => 'Something went wrong. Please try again.';

  @override
  String get paywallEmpty =>
      'No plans are available right now. Please try again later.';

  @override
  String get paywallUnavailable =>
      'Purchases are not available in this build of the app.';

  @override
  String get paywallRetry => 'Try again';

  @override
  String get paywallPurchasing => 'Processing the purchase…';

  @override
  String get paywallPending =>
      'Your purchase is waiting for approval (for example Ask to Buy or a delayed payment). Premium unlocks as soon as it is approved.';

  @override
  String get paywallNotActivated =>
      'The payment went through, but Premium is not active yet. Try \"Restore purchases\" in a moment.';

  @override
  String get paywallRestoreNone =>
      'No active purchases were found for this store account.';

  @override
  String get paywallThanksTitle => 'Thank you!';

  @override
  String get paywallThanksBody =>
      'Premium is unlocked. You can go back to what you were doing.';

  @override
  String get paywallAlreadyTitle => 'Premium is active';

  @override
  String get paywallAlreadyBody => 'All features are unlocked.';

  @override
  String get paywallSemSelected => 'selected';

  @override
  String get paywallSemNotSelected => 'not selected';

  @override
  String get paywallSettingsSection => 'Purchases';

  @override
  String get paywallSettingsRestoreTitle => 'Restore purchases';

  @override
  String get paywallSettingsRestoreSubtitle =>
      'Get Premium back after reinstalling the app or on a new phone.';

  @override
  String get paywallSettingsUnavailable =>
      'Not available in this build of the app.';

  @override
  String get paywallSettingsManage =>
      'To cancel or change a subscription, open your account settings in the store.';

  @override
  String get paywallSettingsManageIos =>
      'To cancel or change a subscription, open the subscription settings of your Apple ID (App Store).';

  @override
  String get paywallSettingsManageAndroid =>
      'To cancel or change a subscription, open the subscriptions of your Google Play account.';

  @override
  String get paywallSettingsRestored => 'Premium restored';

  @override
  String paywallPlanPrepaid(String duration) {
    return '$duration of access';
  }

  @override
  String paywallPrepaidPrice(String price) {
    return '$price · one-time payment, no renewal';
  }

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

  @override
  String get practiceSaveError =>
      'Could not save your answer. It does not count yet.';

  @override
  String get practiceSaveRetry => 'Retry';

  @override
  String get practiceLimitRecheck => 'Check again';

  @override
  String get practiceBookmarkError => 'Could not save the bookmark.';
}
