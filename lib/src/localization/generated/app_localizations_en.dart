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
  String get questionShownInPolishNote =>
      'No English translation for this question: shown in Polish.';

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
}
