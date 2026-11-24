import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_pl.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('pl'),
  ];

  /// Name of the PPL(A) licence
  ///
  /// In en, this message translates to:
  /// **'PPL(A)'**
  String get licencePplaTitle;

  /// Name of the PPL(H) licence
  ///
  /// In en, this message translates to:
  /// **'PPL(H)'**
  String get licencePplhTitle;

  /// Name of the SPL licence
  ///
  /// In en, this message translates to:
  /// **'SPL'**
  String get licenceSplTitle;

  /// Name of the BPL licence
  ///
  /// In en, this message translates to:
  /// **'BPL'**
  String get licenceBplTitle;

  /// Subtitle of the PPL(A) card
  ///
  /// In en, this message translates to:
  /// **'Aeroplane pilot licence'**
  String get licencePplaSubtitle;

  /// Subtitle of the PPL(H) card
  ///
  /// In en, this message translates to:
  /// **'Helicopter pilot licence'**
  String get licencePplhSubtitle;

  /// Subtitle of the SPL card
  ///
  /// In en, this message translates to:
  /// **'Sailplane pilot licence'**
  String get licenceSplSubtitle;

  /// Subtitle of the BPL card
  ///
  /// In en, this message translates to:
  /// **'Balloon pilot licence'**
  String get licenceBplSubtitle;

  /// Label of the question language selector
  ///
  /// In en, this message translates to:
  /// **'Question language'**
  String get questionLanguageLabel;

  /// Polish option of the question language selector
  ///
  /// In en, this message translates to:
  /// **'Polish'**
  String get questionLanguagePolish;

  /// English option of the question language selector
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get questionLanguageEnglish;

  /// Hint under the language selector
  ///
  /// In en, this message translates to:
  /// **'English questions are available for PPL(A) and PPL(H).'**
  String get questionLanguageEnglishHint;

  /// Note when a question falls back to Polish
  ///
  /// In en, this message translates to:
  /// **'Question shown as published by ULC.'**
  String get questionShownAsPublishedNote;

  /// Shown when the question bank cannot be loaded
  ///
  /// In en, this message translates to:
  /// **'Could not load the question bank.'**
  String get bankLoadError;

  /// Retry button after a loading error
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get bankRetryLabel;

  /// Source and date of the question database
  ///
  /// In en, this message translates to:
  /// **'Source: {source}; database date {date}'**
  String bankSourceNote(String source, String date);

  /// Number of questions of a subject
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} question} other{{count} questions}}'**
  String subjectQuestionCount(int count);

  /// Title of the mistakes mode tile
  ///
  /// In en, this message translates to:
  /// **'MY MISTAKES'**
  String get subjectModeMistakesTitle;

  /// Description of the mistakes mode
  ///
  /// In en, this message translates to:
  /// **'Questions you answered wrongly and have not mastered yet.'**
  String get subjectModeMistakesDescription;

  /// Title of the spaced review mode tile
  ///
  /// In en, this message translates to:
  /// **'REVIEW'**
  String get subjectModeReviewTitle;

  /// Description of the review mode
  ///
  /// In en, this message translates to:
  /// **'Questions that are due for repetition.'**
  String get subjectModeReviewDescription;

  /// Title of the bookmarks mode tile
  ///
  /// In en, this message translates to:
  /// **'BOOKMARKS'**
  String get subjectModeBookmarksTitle;

  /// Description of the bookmarks mode
  ///
  /// In en, this message translates to:
  /// **'Questions you saved for later.'**
  String get subjectModeBookmarksDescription;

  /// Title of the exam history tile
  ///
  /// In en, this message translates to:
  /// **'HISTORY'**
  String get subjectModeHistoryTitle;

  /// Description of the history tile
  ///
  /// In en, this message translates to:
  /// **'Results of your exam simulations.'**
  String get subjectModeHistoryDescription;

  /// The title of the application
  ///
  /// In en, this message translates to:
  /// **'Pilotiq'**
  String get appTitle;

  /// Copyright message
  ///
  /// In en, this message translates to:
  /// **'© 2023 Anton Antonchik.\nAll rights reserved.'**
  String get copyright;

  /// The label for No option
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// The title of the exams screen
  ///
  /// In en, this message translates to:
  /// **'Exams'**
  String get examsTitle;

  /// The title of the subjects screen
  ///
  /// In en, this message translates to:
  /// **'Subjects'**
  String get subjectsTitle;

  /// The title of the about screen
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutTitle;

  /// The title of the Air law subject
  ///
  /// In en, this message translates to:
  /// **'Air law'**
  String get airLawSubjectTitle;

  /// The title of the Communications subject
  ///
  /// In en, this message translates to:
  /// **'Communications'**
  String get communicationsSubjectTitle;

  /// The title of the Meteorology subject
  ///
  /// In en, this message translates to:
  /// **'Meteorology'**
  String get meteorologySubjectTitle;

  /// The title of the Navigation subject
  ///
  /// In en, this message translates to:
  /// **'Navigation'**
  String get navigationSubjectTitle;

  /// The title of the Performance subject
  ///
  /// In en, this message translates to:
  /// **'Performance and flight planning'**
  String get performanceSubjectTitle;

  /// The title of the Aircraft general knowledge subject
  ///
  /// In en, this message translates to:
  /// **'Aircraft general knowledge'**
  String get generalKnowledgeSubjectTitle;

  /// The title of the Human performance and limitations subject
  ///
  /// In en, this message translates to:
  /// **'Human performance and limitations'**
  String get humanPerformanceSubjectTitle;

  /// The title of the Operational procedures subject
  ///
  /// In en, this message translates to:
  /// **'Operational procedures'**
  String get operationalProcedureSubjectTitle;

  /// The title of the Principles of flight subject
  ///
  /// In en, this message translates to:
  /// **'Principles of flight'**
  String get principlesOfFlightSubjectTitle;

  /// The title of the Air law subject
  ///
  /// In en, this message translates to:
  /// **'Air law'**
  String get airLawSubjectTooltip;

  /// The title of the Communications subject
  ///
  /// In en, this message translates to:
  /// **'Communications'**
  String get communicationsSubjectTooltip;

  /// The title of the Meteorology subject
  ///
  /// In en, this message translates to:
  /// **'Meteorology'**
  String get meteorologySubjectTooltip;

  /// The title of the Navigation subject
  ///
  /// In en, this message translates to:
  /// **'Navigation'**
  String get navigationSubjectTooltip;

  /// The title of the Performance subject
  ///
  /// In en, this message translates to:
  /// **'Performance and flight planning'**
  String get performanceSubjectTooltip;

  /// The title of the Aircraft general knowledge subject
  ///
  /// In en, this message translates to:
  /// **'Aircraft general knowledge'**
  String get generalKnowledgeSubjectTooltip;

  /// The title of the Human performance and limitations subject
  ///
  /// In en, this message translates to:
  /// **'Human performance and limitations'**
  String get humanPerformanceSubjectTooltip;

  /// The title of the Operational procedures subject
  ///
  /// In en, this message translates to:
  /// **'Operational procedures'**
  String get operationalProcedureSubjectTooltip;

  /// The title of the Principles of flight subject
  ///
  /// In en, this message translates to:
  /// **'Principles of flight'**
  String get principlesOfFlightSubjectTooltip;

  /// The title of the continue quiz button
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueQuizTitle;

  /// The title of the restart quiz button
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get startNewQuizTitle;

  /// The title of the return to subjects button
  ///
  /// In en, this message translates to:
  /// **'Return to subject'**
  String get returnToSubjectTitle;

  /// Message for the test restart options
  ///
  /// In en, this message translates to:
  /// **'Would you like to continue the test you started before or start over?'**
  String get restartMessage;

  /// The message for the right answer
  ///
  /// In en, this message translates to:
  /// **'Good Job!'**
  String get rightAnswer;

  /// The label for the next question button
  ///
  /// In en, this message translates to:
  /// **'Next question'**
  String get nextQuestion;

  /// The label for the Full Quiz
  ///
  /// In en, this message translates to:
  /// **'ALL QUESTIONS'**
  String get fullQuizTitle;

  /// The label for the Exam Quiz
  ///
  /// In en, this message translates to:
  /// **'EXAM SIMULATOR'**
  String get examQuizTitle;

  /// Description for the All questions mode Quiz
  ///
  /// In en, this message translates to:
  /// **'This mode allows test takers to practice and review a large number of questions, and to learn from their mistakes.'**
  String get fullModeDescription;

  /// Description for the Exam mode Quiz
  ///
  /// In en, this message translates to:
  /// **'The exam simulator mode simulates the actual exam experience.'**
  String get examModeDescription;

  /// Label for the 'Language' button
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageButtonTooltip;

  /// Label for Go Premium
  ///
  /// In en, this message translates to:
  /// **'Go Premium!'**
  String get goPremiumLabel;

  /// Features description title
  ///
  /// In en, this message translates to:
  /// **'All features at a glance'**
  String get featuresDescriptionTitle;

  /// All exams access label
  ///
  /// In en, this message translates to:
  /// **'Access to all exams'**
  String get allExamsAccessLabel;

  /// Dark mode unlocked label
  ///
  /// In en, this message translates to:
  /// **'Dark mode unlocked'**
  String get darkModeAccessLabel;

  /// All subjects access label
  ///
  /// In en, this message translates to:
  /// **'Access to all questions'**
  String get allSubjectsAccessLabel;

  /// Special price label
  ///
  /// In en, this message translates to:
  /// **'Get it now!'**
  String get specialPriceLabel;

  /// Privacy policy label
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicyLabel;

  /// Premium user greeting
  ///
  /// In en, this message translates to:
  /// **'You\'re a Premium User!'**
  String get premiumUserGreeting;

  /// Thanks for supporting
  ///
  /// In en, this message translates to:
  /// **'Thanks for your Support!'**
  String get thankYouMessage;

  /// Let's go!
  ///
  /// In en, this message translates to:
  /// **'Let\'s go!'**
  String get letsGoMessage;

  /// Premium paywall
  ///
  /// In en, this message translates to:
  /// **'Go Premium!'**
  String get premiumLabel;

  /// The title of the premium (paywall) screen
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get premiumTitle;

  /// The label of the Terms of Service link
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfServiceLabel;

  /// Placeholder body of the about screen
  ///
  /// In en, this message translates to:
  /// **'About this app...'**
  String get aboutScreenBody;

  /// Message of the temporary paywall screen
  ///
  /// In en, this message translates to:
  /// **'Premium purchases will be available here soon.'**
  String get paywallStubMessage;

  /// Bottom navigation: dashboard tab
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get navToday;

  /// Bottom navigation: subjects tab
  ///
  /// In en, this message translates to:
  /// **'Subjects'**
  String get navSubjects;

  /// Bottom navigation: profile and settings tab
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// Dashboard title
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get dashboardTitle;

  /// Days left until the exam
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =0{The exam is today} one{1 day to the exam} other{{days} days to the exam}}'**
  String dashboardExamCountdown(int days);

  /// Exam date is in the past
  ///
  /// In en, this message translates to:
  /// **'The exam date has passed'**
  String get dashboardExamPassed;

  /// Hint when no exam date is set
  ///
  /// In en, this message translates to:
  /// **'Set your exam date to see the countdown'**
  String get dashboardExamNotSet;

  /// Button that opens the exam date picker
  ///
  /// In en, this message translates to:
  /// **'Set date'**
  String get dashboardExamSetDate;

  /// Daily goal card title
  ///
  /// In en, this message translates to:
  /// **'Daily goal'**
  String get dashboardGoalTitle;

  /// Answers given today out of the daily goal
  ///
  /// In en, this message translates to:
  /// **'{answered}/{goal}'**
  String dashboardGoalValue(int answered, int goal);

  /// Shown when the daily goal is met
  ///
  /// In en, this message translates to:
  /// **'Goal reached, well done!'**
  String get dashboardGoalReached;

  /// Answers left to reach the daily goal
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 more answer to reach the goal} other{{count} more answers to reach the goal}}'**
  String dashboardGoalRemaining(int count);

  /// Streak card title
  ///
  /// In en, this message translates to:
  /// **'Streak'**
  String get dashboardStreakTitle;

  /// Current streak in days
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No streak yet} one{1 day in a row} other{{count} days in a row}}'**
  String dashboardStreak(int count);

  /// Streak rule
  ///
  /// In en, this message translates to:
  /// **'Answer at least one question every day.'**
  String get dashboardStreakHint;

  /// Spaced repetition card title
  ///
  /// In en, this message translates to:
  /// **'To review today'**
  String get dashboardDueTitle;

  /// Questions due for repetition today
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nothing to review today} one{1 question to review today} other{{count} questions to review today}}'**
  String dashboardDue(int count);

  /// Where to start the review
  ///
  /// In en, this message translates to:
  /// **'Open a subject and choose Review.'**
  String get dashboardDueHint;

  /// Teaser for free users
  ///
  /// In en, this message translates to:
  /// **'Spaced repetition is part of Premium.'**
  String get dashboardDueLocked;

  /// Shown when the progress storage fails to open
  ///
  /// In en, this message translates to:
  /// **'Could not open your progress data.'**
  String get dashboardDataError;

  /// Basic statistics card title
  ///
  /// In en, this message translates to:
  /// **'Your progress'**
  String get dashboardOverviewTitle;

  /// Share of the bank answered at least once
  ///
  /// In en, this message translates to:
  /// **'Coverage {percent}%'**
  String dashboardCoverage(int percent);

  /// Share of correct answers
  ///
  /// In en, this message translates to:
  /// **'Accuracy {percent}%'**
  String dashboardAccuracy(int percent);

  /// Readiness card title
  ///
  /// In en, this message translates to:
  /// **'Exam readiness'**
  String get dashboardReadinessTitle;

  /// Label next to the readiness values
  ///
  /// In en, this message translates to:
  /// **'approximate'**
  String get dashboardReadinessApprox;

  /// Teaser for free users
  ///
  /// In en, this message translates to:
  /// **'Readiness by subject is part of Premium.'**
  String get dashboardReadinessLocked;

  /// A percentage
  ///
  /// In en, this message translates to:
  /// **'{percent}%'**
  String dashboardPercentValue(int percent);

  /// Weak subjects card title
  ///
  /// In en, this message translates to:
  /// **'Weak subjects'**
  String get dashboardWeakTitle;

  /// Hint when no subject has enough answers
  ///
  /// In en, this message translates to:
  /// **'Answer at least 10 questions in a subject to see it here.'**
  String get dashboardWeakNone;

  /// Last exam simulation card title
  ///
  /// In en, this message translates to:
  /// **'Last simulation'**
  String get dashboardLastExamTitle;

  /// Hint when there is no simulation
  ///
  /// In en, this message translates to:
  /// **'No exam simulations yet.'**
  String get dashboardLastExamNone;

  /// Exam passed badge
  ///
  /// In en, this message translates to:
  /// **'Passed'**
  String get dashboardPassed;

  /// Exam failed badge
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get dashboardFailed;

  /// Result and date of an attempt
  ///
  /// In en, this message translates to:
  /// **'{percent}% · {date}'**
  String dashboardAttemptResult(int percent, String date);

  /// Attempts migrated from version 1.x
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 attempt before version 2.0} other{{count} attempts before version 2.0}}'**
  String dashboardLegacyAttempts(int count);

  /// Settings screen title
  ///
  /// In en, this message translates to:
  /// **'Profile and settings'**
  String get settingsTitle;

  /// Shown to premium users
  ///
  /// In en, this message translates to:
  /// **'Premium is active'**
  String get settingsPremiumActive;

  /// Subtitle of the premium card for free users
  ///
  /// In en, this message translates to:
  /// **'Unlock all features'**
  String get settingsPremiumGet;

  /// Settings section
  ///
  /// In en, this message translates to:
  /// **'Learning'**
  String get settingsSectionLearning;

  /// Settings section
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsSectionAppearance;

  /// Licence setting
  ///
  /// In en, this message translates to:
  /// **'Licence'**
  String get settingsLicenceTitle;

  /// Exam date setting
  ///
  /// In en, this message translates to:
  /// **'Exam date'**
  String get settingsExamDateTitle;

  /// Exam date is empty
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get settingsExamDateNotSet;

  /// Button that clears the exam date
  ///
  /// In en, this message translates to:
  /// **'Remove date'**
  String get settingsExamDateClear;

  /// Help text of the date picker
  ///
  /// In en, this message translates to:
  /// **'Exam date'**
  String get settingsExamDateHelp;

  /// Daily goal value
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 question per day} other{{count} questions per day}}'**
  String settingsDailyGoalValue(int count);

  /// Daily goal setting
  ///
  /// In en, this message translates to:
  /// **'Daily goal'**
  String get settingsDailyGoalTitle;

  /// Theme setting
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsThemeTitle;

  /// Follow the system theme
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsThemeSystem;

  /// Light theme
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// Dark theme
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// Shown when saving fails
  ///
  /// In en, this message translates to:
  /// **'Could not save the setting.'**
  String get settingsSaveError;

  /// Retry action of a failed save
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get settingsRetry;

  /// Subtitle of the About tile
  ///
  /// In en, this message translates to:
  /// **'Version, sources and legal information'**
  String get settingsAboutSubtitle;

  /// Shown when the settings cannot be opened
  ///
  /// In en, this message translates to:
  /// **'The app could not read its data.'**
  String get settingsStartupError;

  /// Title of the start-up error screen
  ///
  /// In en, this message translates to:
  /// **'Pilotiq could not start'**
  String get startupErrorTitle;

  /// Onboarding first step title
  ///
  /// In en, this message translates to:
  /// **'Welcome to Pilotiq'**
  String get onboardingWelcomeTitle;

  /// Onboarding first step text
  ///
  /// In en, this message translates to:
  /// **'Choose the licence you are preparing for and the language of the questions.'**
  String get onboardingWelcomeBody;

  /// Shown to users who upgrade from version 1.x
  ///
  /// In en, this message translates to:
  /// **'We found your results from the previous version and kept them. Check that the licence is right.'**
  String get onboardingLegacyBanner;

  /// Onboarding exam date step title
  ///
  /// In en, this message translates to:
  /// **'When is your exam?'**
  String get onboardingExamDateTitle;

  /// Onboarding exam date step text
  ///
  /// In en, this message translates to:
  /// **'We count the days and adapt the repetitions to it. You can skip this.'**
  String get onboardingExamDateBody;

  /// Onboarding goal step title
  ///
  /// In en, this message translates to:
  /// **'How many questions a day?'**
  String get onboardingGoalTitle;

  /// Onboarding goal step text
  ///
  /// In en, this message translates to:
  /// **'A small daily goal builds a streak. You can change it any time.'**
  String get onboardingGoalBody;

  /// Onboarding: next step
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingNext;

  /// Onboarding: previous step
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get onboardingBack;

  /// Onboarding: skip a step
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkip;

  /// Onboarding: finish
  ///
  /// In en, this message translates to:
  /// **'Start learning'**
  String get onboardingFinish;

  /// Onboarding progress
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total}'**
  String onboardingStepOf(int current, int total);

  /// App version
  ///
  /// In en, this message translates to:
  /// **'Version {version} ({build})'**
  String aboutVersion(String version, String build);

  /// Legal disclaimer
  ///
  /// In en, this message translates to:
  /// **'Pilotiq is not affiliated with ULC or EASA and is not their product.'**
  String get aboutDisclaimer;

  /// About: section title
  ///
  /// In en, this message translates to:
  /// **'Question database'**
  String get aboutBankTitle;

  /// Source and date of the question database of one licence
  ///
  /// In en, this message translates to:
  /// **'{licence}: {source}, {date}'**
  String aboutBankSourceLine(String licence, String source, String date);

  /// Questions are not reworded
  ///
  /// In en, this message translates to:
  /// **'Question texts are given as published by ULC.'**
  String get aboutQuestionsNote;

  /// Title of the exam simulation screen
  ///
  /// In en, this message translates to:
  /// **'Exam simulation'**
  String get examScreenTitle;

  /// Heading of the rules page
  ///
  /// In en, this message translates to:
  /// **'Before you start'**
  String get examRulesHeading;

  /// Number of questions of the exam
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} question} other{{count} questions}}'**
  String examRulesQuestions(int count);

  /// Time limit of the exam
  ///
  /// In en, this message translates to:
  /// **'Time limit: {minutes, plural, one{{minutes} minute} other{{minutes} minutes}}'**
  String examRulesTime(int minutes);

  /// Pass mark rule
  ///
  /// In en, this message translates to:
  /// **'Pass mark: {percent}% of all questions. An unanswered question counts as wrong.'**
  String examRulesPass(int percent);

  /// Navigation rule
  ///
  /// In en, this message translates to:
  /// **'You can move between questions freely and change your answers until you finish the exam.'**
  String get examRulesNavigate;

  /// No feedback and flag rule
  ///
  /// In en, this message translates to:
  /// **'The correct answer is not shown during the exam. Mark a question to come back to it later.'**
  String get examRulesNoFeedback;

  /// Timer rule
  ///
  /// In en, this message translates to:
  /// **'The timer keeps running when you leave the app. When time runs out the exam ends and the result is saved.'**
  String get examRulesTimer;

  /// Fresh sample rule
  ///
  /// In en, this message translates to:
  /// **'Every attempt draws a new random set of questions of this subject, spread across its topics.'**
  String get examRulesFresh;

  /// Start button
  ///
  /// In en, this message translates to:
  /// **'Start exam'**
  String get examStartButton;

  /// Error when the attempt cannot be stored at start
  ///
  /// In en, this message translates to:
  /// **'The exam could not be started because the attempt could not be saved on this device.'**
  String get examStartFailed;

  /// Retry button of the save errors
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get examSaveRetry;

  /// Title when the free exam is used
  ///
  /// In en, this message translates to:
  /// **'Free simulation used'**
  String get examLimitTitle;

  /// Body when the free exam is used
  ///
  /// In en, this message translates to:
  /// **'You have used the free simulation of this subject. Premium gives unlimited simulations with history and topic breakdown.'**
  String get examLimitBody;

  /// Button that opens the exam history
  ///
  /// In en, this message translates to:
  /// **'Open history'**
  String get examLimitHistory;

  /// Title of the resume page
  ///
  /// In en, this message translates to:
  /// **'Unfinished exam'**
  String get examResumeTitle;

  /// Body of the resume page
  ///
  /// In en, this message translates to:
  /// **'You have an exam in progress: {answered} of {total} answered, {minutes, plural, one{{minutes} minute} other{{minutes} minutes}} left.'**
  String examResumeBody(int answered, int total, int minutes);

  /// Resume button
  ///
  /// In en, this message translates to:
  /// **'Continue exam'**
  String get examResumeContinue;

  /// Finish the unfinished exam button
  ///
  /// In en, this message translates to:
  /// **'Finish exam now'**
  String get examResumeFinish;

  /// Position in the exam
  ///
  /// In en, this message translates to:
  /// **'Question {current} of {total}'**
  String examQuestionOf(int current, int total);

  /// Number of answered questions
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} answered} other{{count} answered}}'**
  String examAnsweredCount(int count);

  /// Accessibility label of the timer
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, one{{minutes} minute left} other{{minutes} minutes left}}'**
  String examTimeLeftSemantics(int minutes);

  /// Shown when little time is left
  ///
  /// In en, this message translates to:
  /// **'Low time'**
  String get examTimeLow;

  /// Previous question button
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get examPrevious;

  /// Next question button
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get examNext;

  /// Flag button
  ///
  /// In en, this message translates to:
  /// **'Mark to come back later'**
  String get examFlagAdd;

  /// Unflag button
  ///
  /// In en, this message translates to:
  /// **'Marked: tap to unmark'**
  String get examFlagRemove;

  /// Tooltip of the grid button
  ///
  /// In en, this message translates to:
  /// **'Question grid'**
  String get examGridTooltip;

  /// Tooltip of the finish button
  ///
  /// In en, this message translates to:
  /// **'Finish exam'**
  String get examFinishTooltip;

  /// Finish button
  ///
  /// In en, this message translates to:
  /// **'Finish exam'**
  String get examFinishButton;

  /// Accessibility label of an answer
  ///
  /// In en, this message translates to:
  /// **'Answer {position} of {total}: {text}'**
  String examAnswerSemantics(int position, int total, String text);

  /// Error when the running attempt cannot be stored
  ///
  /// In en, this message translates to:
  /// **'Your progress could not be saved on this device. Your answers are kept for now.'**
  String get examPersistError;

  /// Title of the grid
  ///
  /// In en, this message translates to:
  /// **'Questions'**
  String get examGridTitle;

  /// Legend of the grid
  ///
  /// In en, this message translates to:
  /// **'Answered'**
  String get examGridLegendAnswered;

  /// Legend of the grid
  ///
  /// In en, this message translates to:
  /// **'Not answered'**
  String get examGridLegendUnanswered;

  /// Legend of the grid
  ///
  /// In en, this message translates to:
  /// **'Marked'**
  String get examGridLegendFlagged;

  /// Close button of the grid
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get examGridClose;

  /// Accessibility label of a grid cell
  ///
  /// In en, this message translates to:
  /// **'Question {number}'**
  String examGridCell(int number);

  /// State in the label of a grid cell
  ///
  /// In en, this message translates to:
  /// **'answered'**
  String get examGridStateAnswered;

  /// State in the label of a grid cell
  ///
  /// In en, this message translates to:
  /// **'not answered'**
  String get examGridStateUnanswered;

  /// State in the label of a grid cell
  ///
  /// In en, this message translates to:
  /// **'marked to come back'**
  String get examGridStateFlagged;

  /// State in the label of a grid cell
  ///
  /// In en, this message translates to:
  /// **'current question'**
  String get examGridStateCurrent;

  /// Title of the confirmation
  ///
  /// In en, this message translates to:
  /// **'Finish the exam?'**
  String get examFinishDialogTitle;

  /// Unanswered questions in the confirmation
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{All questions are answered.} one{{count} question is not answered.} other{{count} questions are not answered.}}'**
  String examFinishUnanswered(int count);

  /// Note in the confirmation
  ///
  /// In en, this message translates to:
  /// **'Questions without an answer count as wrong.'**
  String get examFinishUnansweredNote;

  /// Marked questions in the confirmation
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No questions are marked.} one{{count} question is marked to come back to.} other{{count} questions are marked to come back to.}}'**
  String examFinishFlagged(int count);

  /// Cancel of the confirmation
  ///
  /// In en, this message translates to:
  /// **'Keep working'**
  String get examFinishKeepWorking;

  /// Confirm of the confirmation
  ///
  /// In en, this message translates to:
  /// **'Finish exam'**
  String get examFinishConfirm;

  /// Title of the leave dialog
  ///
  /// In en, this message translates to:
  /// **'Leave the exam?'**
  String get examLeaveTitle;

  /// Body of the leave dialog
  ///
  /// In en, this message translates to:
  /// **'The timer keeps running. You can continue from the subject screen until time runs out.'**
  String get examLeaveBody;

  /// Stay button
  ///
  /// In en, this message translates to:
  /// **'Stay'**
  String get examLeaveStay;

  /// Leave button
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get examLeaveConfirm;

  /// Shown while the result is saved
  ///
  /// In en, this message translates to:
  /// **'Saving your result…'**
  String get examSavingResult;

  /// Error when the attempt cannot be stored at the end
  ///
  /// In en, this message translates to:
  /// **'Your result could not be saved yet. It is not shown as saved until it is.'**
  String get examFinishSaveError;

  /// Notice after a timeout
  ///
  /// In en, this message translates to:
  /// **'Time is up. The exam was finished automatically and your result was saved.'**
  String get examTimeUpNotice;

  /// Notice after an expired attempt was restored
  ///
  /// In en, this message translates to:
  /// **'Time ran out while the exam was not open. It was finished and saved automatically.'**
  String get examExpiredOnOpenNotice;

  /// Title of the result screen
  ///
  /// In en, this message translates to:
  /// **'Exam result'**
  String get examResultTitle;

  /// Passed badge
  ///
  /// In en, this message translates to:
  /// **'PASSED'**
  String get examPassed;

  /// Failed badge
  ///
  /// In en, this message translates to:
  /// **'NOT PASSED'**
  String get examFailed;

  /// Score line
  ///
  /// In en, this message translates to:
  /// **'{correct} of {total} correct'**
  String examResultCorrect(int correct, int total);

  /// Pass mark line
  ///
  /// In en, this message translates to:
  /// **'Pass mark: {percent}%'**
  String examResultPassMark(int percent);

  /// Time used line
  ///
  /// In en, this message translates to:
  /// **'Time used: {time}'**
  String examResultTime(String time);

  /// Unanswered questions line
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Every question was answered.} one{{count} question without an answer (counted as wrong).} other{{count} questions without an answer (counted as wrong).}}'**
  String examResultUnanswered(int count);

  /// Title of the topic breakdown
  ///
  /// In en, this message translates to:
  /// **'Results by topic'**
  String get examBreakdownTitle;

  /// Row of the topic breakdown
  ///
  /// In en, this message translates to:
  /// **'{topic}: {correct} of {total} ({percent}%)'**
  String examBreakdownRow(String topic, int correct, int total, int percent);

  /// Title of the premium teaser
  ///
  /// In en, this message translates to:
  /// **'Topic breakdown and answer review'**
  String get examTeaserTitle;

  /// Body of the premium teaser
  ///
  /// In en, this message translates to:
  /// **'With Premium you see where you lose points, review every answer and train the questions you missed.'**
  String get examTeaserBody;

  /// Review button
  ///
  /// In en, this message translates to:
  /// **'Review answers'**
  String get examReviewButton;

  /// Train mistakes button
  ///
  /// In en, this message translates to:
  /// **'Train mistakes of this attempt'**
  String get examTrainMistakes;

  /// Repeat button
  ///
  /// In en, this message translates to:
  /// **'Repeat exam'**
  String get examRepeat;

  /// History button
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get examHistoryButton;

  /// Title of the review
  ///
  /// In en, this message translates to:
  /// **'Answer review'**
  String get examReviewTitle;

  /// Filter of the review
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get examReviewFilterAll;

  /// Filter of the review
  ///
  /// In en, this message translates to:
  /// **'Wrong or unanswered'**
  String get examReviewFilterWrong;

  /// Heading of a reviewed question
  ///
  /// In en, this message translates to:
  /// **'Question {index} of {total}'**
  String examReviewQuestionNumber(int index, int total);

  /// Label in the review
  ///
  /// In en, this message translates to:
  /// **'Your answer'**
  String get examReviewYourAnswer;

  /// Label in the review
  ///
  /// In en, this message translates to:
  /// **'Correct answer'**
  String get examReviewCorrectAnswer;

  /// Label in the review
  ///
  /// In en, this message translates to:
  /// **'No answer given'**
  String get examReviewNoAnswer;

  /// Shown when the bank no longer has the question
  ///
  /// In en, this message translates to:
  /// **'This question is no longer in the question bank.'**
  String get examReviewMissing;

  /// Result mark in the review
  ///
  /// In en, this message translates to:
  /// **'Correct'**
  String get examReviewMarkCorrect;

  /// Result mark in the review
  ///
  /// In en, this message translates to:
  /// **'Wrong'**
  String get examReviewMarkWrong;

  /// Result mark in the review
  ///
  /// In en, this message translates to:
  /// **'Not answered'**
  String get examReviewMarkUnanswered;

  /// Empty filtered review
  ///
  /// In en, this message translates to:
  /// **'No wrong answers in this attempt.'**
  String get examReviewEmptyWrong;

  /// Mark in the review
  ///
  /// In en, this message translates to:
  /// **'Marked to come back'**
  String get examReviewFlagged;

  /// Title of the history
  ///
  /// In en, this message translates to:
  /// **'Exam history'**
  String get examHistoryTitle;

  /// Empty history
  ///
  /// In en, this message translates to:
  /// **'No simulations yet. Your results will appear here.'**
  String get examHistoryEmpty;

  /// Label of a legacy attempt
  ///
  /// In en, this message translates to:
  /// **'Before version 2.0'**
  String get examHistoryLegacy;

  /// Error of the history
  ///
  /// In en, this message translates to:
  /// **'The history could not be loaded.'**
  String get examHistoryLoadError;

  /// Title of the chart
  ///
  /// In en, this message translates to:
  /// **'Last results'**
  String get examHistoryChartTitle;

  /// Accessibility label of the chart
  ///
  /// In en, this message translates to:
  /// **'Last results, oldest first: {results}'**
  String examHistoryChartSemantics(String results);

  /// Mark of an attempt that ended by timeout
  ///
  /// In en, this message translates to:
  /// **'Time ran out'**
  String get examHistoryTimedOut;

  /// Label of the pass line
  ///
  /// In en, this message translates to:
  /// **'Pass mark {percent}%'**
  String examHistoryPassLine(int percent);

  /// Status of the exam tile with an unfinished attempt
  ///
  /// In en, this message translates to:
  /// **'Unfinished attempt, {minutes, plural, one{{minutes} minute} other{{minutes} minutes}} left'**
  String examTileInProgress(int minutes);

  /// Status of the exam tile
  ///
  /// In en, this message translates to:
  /// **'Last result: {percent}%, passed'**
  String examTileLastPassed(int percent);

  /// Status of the exam tile
  ///
  /// In en, this message translates to:
  /// **'Last result: {percent}%, not passed'**
  String examTileLastFailed(int percent);

  /// Leave dialog when answers are not stored
  ///
  /// In en, this message translates to:
  /// **'Your latest answers could not be saved on this device and will be lost if you leave. The timer keeps running.'**
  String get examLeaveUnsavedBody;

  /// Leave dialog while the result is not stored
  ///
  /// In en, this message translates to:
  /// **'Your result is not saved yet. If you leave now, the exam stays unfinished and its result is saved when you open it again. It cannot be continued.'**
  String get examLeaveUnsavedResultBody;

  /// Android notification channel name
  ///
  /// In en, this message translates to:
  /// **'Study reminders'**
  String get reminderChannelName;

  /// Android notification channel description
  ///
  /// In en, this message translates to:
  /// **'A daily reminder to study for the exam'**
  String get reminderChannelDescription;

  /// Title of the daily study reminder
  ///
  /// In en, this message translates to:
  /// **'Time to study'**
  String get reminderStudyTitle;

  /// Days left until the exam, part of a reminder
  ///
  /// In en, this message translates to:
  /// **'{days, plural, one{1 day to the exam} other{{days} days to the exam}}'**
  String reminderDaysToExam(int days);

  /// Answers left to the daily goal, part of a reminder
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 answer to today\'s goal} other{{count} answers to today\'s goal}}'**
  String reminderGoalLeft(int count);

  /// Questions due for review, part of a reminder
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 question to review} other{{count} questions to review}}'**
  String reminderDueQuestions(int count);

  /// Title of the reminder seven days before the exam
  ///
  /// In en, this message translates to:
  /// **'One week to the exam'**
  String get reminderExamWeekTitle;

  /// Title of the reminder the day before the exam
  ///
  /// In en, this message translates to:
  /// **'Your exam is tomorrow'**
  String get reminderExamEveTitle;

  /// Body of the reminder the day before the exam
  ///
  /// In en, this message translates to:
  /// **'Go over your mistakes once more and get a good night\'s sleep.'**
  String get reminderExamEveBody;

  /// Title of the reminder the day after the exam
  ///
  /// In en, this message translates to:
  /// **'How did the exam go?'**
  String get reminderAfterExamTitle;

  /// Body of the reminder the day after the exam
  ///
  /// In en, this message translates to:
  /// **'Good luck with the result! If you need another go, set a new exam date in Profile.'**
  String get reminderAfterExamBody;

  /// Settings section title
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get remindersSectionTitle;

  /// Switch title
  ///
  /// In en, this message translates to:
  /// **'Daily study reminder'**
  String get remindersToggleTitle;

  /// Subtitle of the reminder switch when off
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get remindersToggleOff;

  /// Subtitle of the reminder switch when on
  ///
  /// In en, this message translates to:
  /// **'Every day at {time}'**
  String remindersToggleOn(String time);

  /// Time tile title and time picker help text
  ///
  /// In en, this message translates to:
  /// **'Reminder time'**
  String get remindersTimeTitle;

  /// Shown when the system permission is missing
  ///
  /// In en, this message translates to:
  /// **'Notifications are blocked for the app, so no reminders will be shown.'**
  String get remindersBlocked;

  /// Button that opens the system notification settings
  ///
  /// In en, this message translates to:
  /// **'Open system settings'**
  String get remindersOpenSettings;

  /// Snack bar when the system settings cannot be opened
  ///
  /// In en, this message translates to:
  /// **'Could not open the settings. Open your phone\'s Settings, then Apps, Pilotiq, Notifications.'**
  String get remindersOpenSettingsFailed;

  /// Shown when scheduling failed
  ///
  /// In en, this message translates to:
  /// **'The reminders could not be scheduled.'**
  String get remindersScheduleFailed;

  /// Button that repeats scheduling
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get remindersRetry;

  /// Onboarding reminders page title
  ///
  /// In en, this message translates to:
  /// **'When should we remind you?'**
  String get onboardingRemindersTitle;

  /// Onboarding reminders page text
  ///
  /// In en, this message translates to:
  /// **'One reminder a day at the time you choose. The app asks the system for permission to show notifications only after you tap the button below.'**
  String get onboardingRemindersBody;

  /// Onboarding button that turns reminders on and asks for permission
  ///
  /// In en, this message translates to:
  /// **'Turn on reminders'**
  String get onboardingRemindersEnable;

  /// Onboarding: reminders are on
  ///
  /// In en, this message translates to:
  /// **'Reminders are on, every day at {time}.'**
  String onboardingRemindersEnabled(String time);

  /// Onboarding: permission was refused
  ///
  /// In en, this message translates to:
  /// **'Notifications are not allowed. You can turn the reminders on later in Profile.'**
  String get onboardingRemindersDenied;

  /// Tooltip of the close button of the paywall
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get paywallClose;

  /// Paywall title when the daily free limit is used up
  ///
  /// In en, this message translates to:
  /// **'Today\'s free limit is used up'**
  String get paywallTitleDailyLimit;

  /// Paywall subtitle for the daily limit; count is the free daily limit
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Free access includes {count} answer per day. Premium has no daily limit.} other{Free access includes {count} answers per day. Premium has no daily limit.}}'**
  String paywallSubtitleDailyLimit(int count);

  /// Paywall title when the free simulation of a subject is used
  ///
  /// In en, this message translates to:
  /// **'The free simulation is used'**
  String get paywallTitleExamLimit;

  /// Paywall subtitle for the simulation limit; count is the free simulations per subject
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Free access includes {count} simulation per subject. Premium gives unlimited simulations with history and topic breakdown.} other{Free access includes {count} simulations per subject. Premium gives unlimited simulations with history and topic breakdown.}}'**
  String paywallSubtitleExamLimit(int count);

  /// Paywall title for a locked feature
  ///
  /// In en, this message translates to:
  /// **'This feature is part of Premium'**
  String get paywallTitleLocked;

  /// Paywall subtitle for a locked feature
  ///
  /// In en, this message translates to:
  /// **'My mistakes and spaced repetition help you return to the questions you still get wrong.'**
  String get paywallSubtitleLocked;

  /// Paywall title opened from the exam result
  ///
  /// In en, this message translates to:
  /// **'Topic breakdown is part of Premium'**
  String get paywallTitleResults;

  /// Paywall subtitle opened from the exam result
  ///
  /// In en, this message translates to:
  /// **'See where you lose points, review every answer and train the questions you missed.'**
  String get paywallSubtitleResults;

  /// Paywall title opened from the profile
  ///
  /// In en, this message translates to:
  /// **'Pilotiq Premium'**
  String get paywallTitleProfile;

  /// Paywall subtitle opened from the profile
  ///
  /// In en, this message translates to:
  /// **'Study without limits and see where you stand in each subject.'**
  String get paywallSubtitleProfile;

  /// Heading of the list of Premium benefits
  ///
  /// In en, this message translates to:
  /// **'With Premium'**
  String get paywallBenefitsTitle;

  /// Benefit: no daily limit; count is the free daily limit
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Practice without a daily limit (free: {count} answer a day)} other{Practice without a daily limit (free: {count} answers a day)}}'**
  String paywallBenefitUnlimited(int count);

  /// Benefit: unlimited simulations; count is the free simulations per subject
  ///
  /// In en, this message translates to:
  /// **'Unlimited exam simulations with history and topic breakdown (free: {count} per subject)'**
  String paywallBenefitSimulations(int count);

  /// Benefit: my mistakes
  ///
  /// In en, this message translates to:
  /// **'My mistakes: train the questions you got wrong'**
  String get paywallBenefitMistakes;

  /// Benefit: spaced repetition
  ///
  /// In en, this message translates to:
  /// **'Spaced repetition of the questions due for review'**
  String get paywallBenefitReview;

  /// Benefit: readiness by subject
  ///
  /// In en, this message translates to:
  /// **'Detailed readiness by subject (approximate)'**
  String get paywallBenefitReadiness;

  /// Heading above the plans
  ///
  /// In en, this message translates to:
  /// **'Choose a plan'**
  String get paywallChoosePlan;

  /// Label of the lifetime plan
  ///
  /// In en, this message translates to:
  /// **'Best choice'**
  String get paywallBestChoice;

  /// Name of the one-time lifetime plan
  ///
  /// In en, this message translates to:
  /// **'Lifetime'**
  String get paywallPlanLifetime;

  /// Price line of the lifetime plan; price comes from the store
  ///
  /// In en, this message translates to:
  /// **'{price} · one-time payment'**
  String paywallLifetimePrice(String price);

  /// Length of a period, for example "3 months"
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} day} other{{count} days}}'**
  String paywallDurationDay(int count);

  /// Length of a period, for example "3 months"
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} week} other{{count} weeks}}'**
  String paywallDurationWeek(int count);

  /// Length of a period, for example "3 months"
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} month} other{{count} months}}'**
  String paywallDurationMonth(int count);

  /// Length of a period, for example "3 months"
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} year} other{{count} years}}'**
  String paywallDurationYear(int count);

  /// Single unit after the slash in a price, for example "/ month"
  ///
  /// In en, this message translates to:
  /// **'day'**
  String get paywallPerDay;

  /// Single unit after the slash in a price, for example "/ month"
  ///
  /// In en, this message translates to:
  /// **'week'**
  String get paywallPerWeek;

  /// Single unit after the slash in a price, for example "/ month"
  ///
  /// In en, this message translates to:
  /// **'month'**
  String get paywallPerMonth;

  /// Single unit after the slash in a price, for example "/ month"
  ///
  /// In en, this message translates to:
  /// **'year'**
  String get paywallPerYear;

  /// Price per period, for example "PLN 24,99 / month"; both parts come from the store data
  ///
  /// In en, this message translates to:
  /// **'{price} / {period}'**
  String paywallPricePer(String price, String period);

  /// Free trial line; trial is a length such as "3 days"; price is the price after the trial
  ///
  /// In en, this message translates to:
  /// **'{trial} free, then {price}'**
  String paywallIntroFree(String trial, String price);

  /// Reduced-price introductory period line
  ///
  /// In en, this message translates to:
  /// **'{period}: {introPrice}, then {price}'**
  String paywallIntroPaid(String period, String introPrice, String price);

  /// Button that buys the selected plan
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get paywallContinue;

  /// Button that restores purchases
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get paywallRestore;

  /// Auto-renewal and cancellation terms of subscriptions
  ///
  /// In en, this message translates to:
  /// **'Subscriptions renew automatically for the same period at the price shown until you cancel. Payment is charged to your App Store or Google Play account. To avoid the next charge, cancel in your account settings in the store at least 24 hours before the current period ends.'**
  String get paywallRenewalNotice;

  /// Terms of a free trial
  ///
  /// In en, this message translates to:
  /// **'A free trial becomes a paid subscription at the price shown unless you cancel before it ends.'**
  String get paywallTrialNotice;

  /// Terms of the lifetime plan
  ///
  /// In en, this message translates to:
  /// **'Lifetime is a one-time payment: it does not renew and is not a subscription.'**
  String get paywallOneTimeNotice;

  /// Shown while the plans load
  ///
  /// In en, this message translates to:
  /// **'Loading plans…'**
  String get paywallLoading;

  /// Error: no connection
  ///
  /// In en, this message translates to:
  /// **'No connection. Check your internet and try again.'**
  String get paywallErrorNetwork;

  /// Error: the store reported a problem
  ///
  /// In en, this message translates to:
  /// **'The store could not complete the request. Please try again later.'**
  String get paywallErrorStore;

  /// Error: anything else
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get paywallErrorUnknown;

  /// The store has no plans to offer
  ///
  /// In en, this message translates to:
  /// **'No plans are available right now. Please try again later.'**
  String get paywallEmpty;

  /// Build without store keys
  ///
  /// In en, this message translates to:
  /// **'Purchases are not available in this build of the app.'**
  String get paywallUnavailable;

  /// Retry button
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get paywallRetry;

  /// Shown while a purchase is processed
  ///
  /// In en, this message translates to:
  /// **'Processing the purchase…'**
  String get paywallPurchasing;

  /// Purchase waits for approval
  ///
  /// In en, this message translates to:
  /// **'Your purchase is waiting for approval (for example Ask to Buy or a delayed payment). Premium unlocks as soon as it is approved.'**
  String get paywallPending;

  /// Payment went through but Premium is not active
  ///
  /// In en, this message translates to:
  /// **'The payment went through, but Premium is not active yet. Try \"Restore purchases\" in a moment.'**
  String get paywallNotActivated;

  /// Restore found nothing
  ///
  /// In en, this message translates to:
  /// **'No active purchases were found for this store account.'**
  String get paywallRestoreNone;

  /// Shown after a successful purchase
  ///
  /// In en, this message translates to:
  /// **'Thank you!'**
  String get paywallThanksTitle;

  /// Shown after a successful purchase
  ///
  /// In en, this message translates to:
  /// **'Premium is unlocked. You can go back to what you were doing.'**
  String get paywallThanksBody;

  /// Shown when the paywall opens and Premium is already active
  ///
  /// In en, this message translates to:
  /// **'Premium is active'**
  String get paywallAlreadyTitle;

  /// Shown when Premium is already active
  ///
  /// In en, this message translates to:
  /// **'All features are unlocked.'**
  String get paywallAlreadyBody;

  /// Accessibility: the plan is selected
  ///
  /// In en, this message translates to:
  /// **'selected'**
  String get paywallSemSelected;

  /// Accessibility: the plan is not selected
  ///
  /// In en, this message translates to:
  /// **'not selected'**
  String get paywallSemNotSelected;

  /// Settings section title
  ///
  /// In en, this message translates to:
  /// **'Purchases'**
  String get paywallSettingsSection;

  /// Settings: restore purchases
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get paywallSettingsRestoreTitle;

  /// Settings: restore purchases, explanation
  ///
  /// In en, this message translates to:
  /// **'Get Premium back after reinstalling the app or on a new phone.'**
  String get paywallSettingsRestoreSubtitle;

  /// Settings: restore is not possible in this build
  ///
  /// In en, this message translates to:
  /// **'Not available in this build of the app.'**
  String get paywallSettingsUnavailable;

  /// Settings: how to cancel a subscription
  ///
  /// In en, this message translates to:
  /// **'To cancel or change a subscription, open your App Store or Google Play account settings.'**
  String get paywallSettingsManage;

  /// Snack bar after a successful restore
  ///
  /// In en, this message translates to:
  /// **'Premium restored'**
  String get paywallSettingsRestored;

  /// Position in the session
  ///
  /// In en, this message translates to:
  /// **'{current} / {total}'**
  String practiceProgress(int current, int total);

  /// Tooltip of the finish button
  ///
  /// In en, this message translates to:
  /// **'Finish session'**
  String get practiceFinishSession;

  /// Next button on the last question
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get practiceLastQuestionButton;

  /// Tooltip: add a bookmark
  ///
  /// In en, this message translates to:
  /// **'Bookmark question'**
  String get practiceBookmarkAdd;

  /// Tooltip: remove a bookmark
  ///
  /// In en, this message translates to:
  /// **'Remove bookmark'**
  String get practiceBookmarkRemove;

  /// Feedback after a correct answer
  ///
  /// In en, this message translates to:
  /// **'Correct!'**
  String get practiceFeedbackCorrect;

  /// Feedback after a wrong answer
  ///
  /// In en, this message translates to:
  /// **'Wrong. The correct answer is highlighted.'**
  String get practiceFeedbackWrong;

  /// Accessibility label of the correct answer
  ///
  /// In en, this message translates to:
  /// **'correct answer'**
  String get practiceAnswerCorrectSemantics;

  /// Accessibility label of a wrong chosen answer
  ///
  /// In en, this message translates to:
  /// **'your answer, wrong'**
  String get practiceAnswerWrongSemantics;

  /// Title of the session that repeats session mistakes
  ///
  /// In en, this message translates to:
  /// **'REPEAT MISTAKES'**
  String get practiceRetryTitle;

  /// Title of the summary
  ///
  /// In en, this message translates to:
  /// **'Session summary'**
  String get practiceSummaryTitle;

  /// Number of correct answers in the session
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} correct answer} other{{count} correct answers}}'**
  String practiceSummaryCorrect(int count);

  /// Number of wrong answers in the session
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} wrong answer} other{{count} wrong answers}}'**
  String practiceSummaryWrong(int count);

  /// Accuracy of the session
  ///
  /// In en, this message translates to:
  /// **'Accuracy: {percent}%'**
  String practiceSummaryAccuracy(int percent);

  /// Summary of an empty session
  ///
  /// In en, this message translates to:
  /// **'You have not answered any question in this session.'**
  String get practiceSummaryNothing;

  /// Button that starts a session with the wrong answers
  ///
  /// In en, this message translates to:
  /// **'Repeat mistakes of this session'**
  String get practiceRepeatMistakes;

  /// Empty learn session
  ///
  /// In en, this message translates to:
  /// **'There are no questions to practise here.'**
  String get practiceEmptyLearn;

  /// Empty mistakes session
  ///
  /// In en, this message translates to:
  /// **'No mistakes to fix. Well done!'**
  String get practiceEmptyMistakes;

  /// Empty review session
  ///
  /// In en, this message translates to:
  /// **'Nothing is due for review today.'**
  String get practiceEmptyReview;

  /// Empty bookmarks session
  ///
  /// In en, this message translates to:
  /// **'You have not bookmarked any question in this subject yet.'**
  String get practiceEmptyBookmarks;

  /// Title when the free daily limit is reached
  ///
  /// In en, this message translates to:
  /// **'Daily limit reached'**
  String get practiceLimitTitle;

  /// Explanation of the free daily limit
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Free access includes {count} answer per day.} other{Free access includes {count} answers per day.}} Come back tomorrow or go Premium for unlimited practice.'**
  String practiceLimitBody(int count);

  /// Title of the locked-mode screen
  ///
  /// In en, this message translates to:
  /// **'Premium feature'**
  String get practiceLockedTitle;

  /// Body of the locked-mode screen
  ///
  /// In en, this message translates to:
  /// **'My mistakes and spaced review are available in Premium.'**
  String get practiceLockedBody;

  /// Badge of a locked mode tile
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get practiceLockedBadge;

  /// Counter of the learn tile
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{All questions covered} one{{count} question not seen yet} other{{count} questions not seen yet}}'**
  String practiceModeLearnStatus(int count);

  /// Counter of the mistakes tile
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No mistakes} one{{count} question to fix} other{{count} questions to fix}}'**
  String practiceModeMistakesStatus(int count);

  /// Counter of the review tile
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nothing due} one{{count} question due} other{{count} questions due}}'**
  String practiceModeReviewStatus(int count);

  /// Counter of the bookmarks tile
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No bookmarks} one{{count} bookmarked question} other{{count} bookmarked questions}}'**
  String practiceModeBookmarksStatus(int count);

  /// Coverage of a subject
  ///
  /// In en, this message translates to:
  /// **'{percent}% covered'**
  String practiceSubjectCoverage(int percent);

  /// Accuracy of a subject
  ///
  /// In en, this message translates to:
  /// **'{percent}% accuracy'**
  String practiceSubjectAccuracy(int percent);

  /// Subject without any answer
  ///
  /// In en, this message translates to:
  /// **'Not started'**
  String get practiceSubjectNotStarted;

  /// Error while preparing a practice session
  ///
  /// In en, this message translates to:
  /// **'Could not load the questions.'**
  String get practiceLoadError;

  /// Shown when an answer could not be stored
  ///
  /// In en, this message translates to:
  /// **'Could not save your answer. It does not count yet.'**
  String get practiceSaveError;

  /// Retry storing the answer
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get practiceSaveRetry;

  /// Re-check the daily limit
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get practiceLimitRecheck;

  /// Shown when a bookmark could not be stored
  ///
  /// In en, this message translates to:
  /// **'Could not save the bookmark.'**
  String get practiceBookmarkError;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'pl'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'pl':
      return AppLocalizationsPl();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
