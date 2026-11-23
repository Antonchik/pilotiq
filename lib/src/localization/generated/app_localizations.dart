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

  /// The title of the PPL(A) exam
  ///
  /// In en, this message translates to:
  /// **'PPL(A)'**
  String get pplaExamTitle;

  /// The title of the PPL(A) ENG exam
  ///
  /// In en, this message translates to:
  /// **'PPL(A)'**
  String get pplaEngExamTitle;

  /// The title of the PPL(H) exam
  ///
  /// In en, this message translates to:
  /// **'PPL(H)'**
  String get pplhExamTitle;

  /// The title of the PPL(H) ENG exam
  ///
  /// In en, this message translates to:
  /// **'PPL(H)'**
  String get pplhEngExamTitle;

  /// The title of the PL(G) exam
  ///
  /// In en, this message translates to:
  /// **'PL(G)'**
  String get plgExamTitle;

  /// The title of the PL(FB) exam
  ///
  /// In en, this message translates to:
  /// **'PL(FB)'**
  String get plfbExamTitle;

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

  /// The label for the Demo Quiz
  ///
  /// In en, this message translates to:
  /// **'DEMO'**
  String get demoQuizTitle;

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

  /// Description for the Demo mode Quiz
  ///
  /// In en, this message translates to:
  /// **'The demo mode of the test is a version with a limited set of questions.'**
  String get demoModeDescription;

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

  /// Shown when no exam is selected
  ///
  /// In en, this message translates to:
  /// **'No exam selected'**
  String get noExamSelected;

  /// Message of the temporary paywall screen
  ///
  /// In en, this message translates to:
  /// **'Premium purchases will be available here soon.'**
  String get paywallStubMessage;
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
