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

  /// Badge of a mode that is not available yet
  ///
  /// In en, this message translates to:
  /// **'Soon'**
  String get subjectModeSoonBadge;

  /// Exam time limit in minutes, short form
  ///
  /// In en, this message translates to:
  /// **'{count} min'**
  String examMinutesShort(int count);

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

  /// The label for Yes option
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

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

  /// The title of the start quiz button
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get startQuizTitle;

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

  /// The title of the review results button
  ///
  /// In en, this message translates to:
  /// **'Review answers'**
  String get reviewAnswersTitle;

  /// Message for the test restart options
  ///
  /// In en, this message translates to:
  /// **'Would you like to continue the test you started before or start over?'**
  String get restartMessage;

  /// Message for the test completion
  ///
  /// In en, this message translates to:
  /// **'Congrats!\nYou have completed the test'**
  String get congratsMessage;

  /// Message for the test fail
  ///
  /// In en, this message translates to:
  /// **'Oh no!\nYou have failed completion of the test'**
  String get failMessage;

  /// The message for the right answer
  ///
  /// In en, this message translates to:
  /// **'Good Job!'**
  String get rightAnswer;

  /// The message for the wrong answer
  ///
  /// In en, this message translates to:
  /// **'Wrong answer!'**
  String get wrongAnswer;

  /// The label for the next question button
  ///
  /// In en, this message translates to:
  /// **'Next question'**
  String get nextQuestion;

  /// The label for the Try again button
  ///
  /// In en, this message translates to:
  /// **'Try again!'**
  String get tryAgain;

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

  /// Label for the 'Exit test' button
  ///
  /// In en, this message translates to:
  /// **'Exit the test?'**
  String get exitQuizTitle;

  /// Title for the 'Time is up' dialog
  ///
  /// In en, this message translates to:
  /// **'Time is up!'**
  String get timeIsUpTitle;

  /// Message for the 'Time is up' dialog
  ///
  /// In en, this message translates to:
  /// **'You have run out of time.\nYour test is over.'**
  String get timeIsUpMessage;

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

  /// The label of the OK button
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get okLabel;

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
