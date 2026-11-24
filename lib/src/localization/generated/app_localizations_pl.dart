// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Polish (`pl`).
class AppLocalizationsPl extends AppLocalizations {
  AppLocalizationsPl([String locale = 'pl']) : super(locale);

  @override
  String get licencePplaTitle => 'PPL(A)';

  @override
  String get licencePplhTitle => 'PPL(H)';

  @override
  String get licenceSplTitle => 'SPL';

  @override
  String get licenceBplTitle => 'BPL';

  @override
  String get licencePplaSubtitle => 'Licencja pilota samolotowego';

  @override
  String get licencePplhSubtitle => 'Licencja pilota śmigłowcowego';

  @override
  String get licenceSplSubtitle => 'Licencja pilota szybowcowego';

  @override
  String get licenceBplSubtitle => 'Licencja pilota balonowego';

  @override
  String get questionLanguageLabel => 'Język pytań';

  @override
  String get questionLanguagePolish => 'Polski';

  @override
  String get questionLanguageEnglish => 'English';

  @override
  String get questionLanguageEnglishHint =>
      'Pytania po angielsku są dostępne dla PPL(A) i PPL(H).';

  @override
  String get questionShownAsPublishedNote =>
      'Pytanie pokazane w oryginalnej postaci ULC.';

  @override
  String get bankLoadError => 'Nie udało się wczytać bazy pytań.';

  @override
  String get bankRetryLabel => 'Ponów';

  @override
  String bankSourceNote(String source, String date) {
    return 'Źródło: $source; data bazy $date';
  }

  @override
  String subjectQuestionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pytania',
      many: '$count pytań',
      few: '$count pytania',
      one: '$count pytanie',
    );
    return '$_temp0';
  }

  @override
  String get subjectModeMistakesTitle => 'MOJE BŁĘDY';

  @override
  String get subjectModeMistakesDescription =>
      'Pytania, na które odpowiedziałeś błędnie i których jeszcze nie opanowałeś.';

  @override
  String get subjectModeReviewTitle => 'POWTÓRKI';

  @override
  String get subjectModeReviewDescription => 'Pytania do powtórzenia.';

  @override
  String get subjectModeBookmarksTitle => 'ZAKŁADKI';

  @override
  String get subjectModeBookmarksDescription => 'Pytania zapisane na później.';

  @override
  String get subjectModeHistoryTitle => 'HISTORIA';

  @override
  String get subjectModeHistoryDescription =>
      'Wyniki Twoich symulacji egzaminu.';

  @override
  String get appTitle => 'Pilotiq';

  @override
  String get copyright =>
      '© 2023 Anton Antonchik.\nWszelkie prawa zastrzeżone.';

  @override
  String get no => 'Nie';

  @override
  String get examsTitle => 'Egzaminy';

  @override
  String get subjectsTitle => 'Przedmioty';

  @override
  String get aboutTitle => 'O aplikacji';

  @override
  String get airLawSubjectTitle => 'Prawo lotnicze';

  @override
  String get communicationsSubjectTitle => 'Łączność';

  @override
  String get meteorologySubjectTitle => 'Meteorologia';

  @override
  String get navigationSubjectTitle => 'Nawigacja';

  @override
  String get performanceSubjectTitle => 'Osiągi i planowanie lotu';

  @override
  String get generalKnowledgeSubjectTitle =>
      'Ogólna wiedza o statku powietrznym';

  @override
  String get humanPerformanceSubjectTitle =>
      'Człowiek możliwości i ograniczenia';

  @override
  String get operationalProcedureSubjectTitle => 'Procedury operacyjne';

  @override
  String get principlesOfFlightSubjectTitle => 'Zasady lotu';

  @override
  String get airLawSubjectTooltip => 'Prawo lotnicze';

  @override
  String get communicationsSubjectTooltip => 'Łączność';

  @override
  String get meteorologySubjectTooltip => 'Meteorologia';

  @override
  String get navigationSubjectTooltip => 'Nawigacja';

  @override
  String get performanceSubjectTooltip => 'Osiągi i planowanie lotu';

  @override
  String get generalKnowledgeSubjectTooltip =>
      'Ogólna wiedza o statku powietrznym';

  @override
  String get humanPerformanceSubjectTooltip =>
      'Człowiek możliwości i ograniczenia';

  @override
  String get operationalProcedureSubjectTooltip => 'Procedury operacyjne';

  @override
  String get principlesOfFlightSubjectTooltip => 'Zasady lotu';

  @override
  String get continueQuizTitle => 'Kontynuuj';

  @override
  String get startNewQuizTitle => 'Zacznij od nowa';

  @override
  String get returnToSubjectTitle => 'Powrót do przedmiotu';

  @override
  String get restartMessage =>
      'Czy chcesz kontynuować rozpoczęty wcześniej test, czy zacząć od nowa?';

  @override
  String get rightAnswer => 'Poprawna odpowiedź!';

  @override
  String get nextQuestion => 'Następne pytanie';

  @override
  String get fullQuizTitle => 'WSZYSTKIE PYTANIA';

  @override
  String get examQuizTitle => 'SYMULATOR EGZAMINU';

  @override
  String get fullModeDescription =>
      'Tryb ten umożliwia uczestnikom testu przećwiczenie i przejrzenie dużej liczby pytań oraz uczenie się na własnych błędach.';

  @override
  String get examModeDescription =>
      'Tryb symulatora egzaminacyjnego symuluje rzeczywiste doświadczenie egzaminacyjne.';

  @override
  String get languageButtonTooltip => 'Zmień język';

  @override
  String get goPremiumLabel => 'Przejdź na Premium!';

  @override
  String get featuresDescriptionTitle => 'Wszystkie cechy w skrócie';

  @override
  String get privacyPolicyLabel => 'Polityka Prywatności';

  @override
  String get premiumTitle => 'Premium';

  @override
  String get termsOfServiceLabel => 'Regulamin';

  @override
  String get aboutScreenBody => 'O tej aplikacji...';

  @override
  String get navToday => 'Dziś';

  @override
  String get navSubjects => 'Przedmioty';

  @override
  String get navProfile => 'Profil';

  @override
  String get dashboardTitle => 'Dziś';

  @override
  String dashboardExamCountdown(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days dnia do egzaminu',
      many: '$days dni do egzaminu',
      few: '$days dni do egzaminu',
      one: '1 dzień do egzaminu',
      zero: 'Egzamin jest dziś',
    );
    return '$_temp0';
  }

  @override
  String get dashboardExamPassed => 'Termin egzaminu już minął';

  @override
  String get dashboardExamNotSet =>
      'Ustaw datę egzaminu, aby zobaczyć odliczanie';

  @override
  String get dashboardExamSetDate => 'Ustaw datę';

  @override
  String get dashboardGoalTitle => 'Cel dnia';

  @override
  String dashboardGoalValue(int answered, int goal) {
    return '$answered/$goal';
  }

  @override
  String get dashboardGoalReached => 'Cel osiągnięty, brawo!';

  @override
  String dashboardGoalRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Jeszcze $count odpowiedzi do celu',
      many: 'Jeszcze $count odpowiedzi do celu',
      few: 'Jeszcze $count odpowiedzi do celu',
      one: 'Jeszcze 1 odpowiedź do celu',
    );
    return '$_temp0';
  }

  @override
  String get dashboardStreakTitle => 'Seria';

  @override
  String dashboardStreak(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dnia z rzędu',
      many: '$count dni z rzędu',
      few: '$count dni z rzędu',
      one: '1 dzień z rzędu',
      zero: 'Brak serii',
    );
    return '$_temp0';
  }

  @override
  String get dashboardStreakHint =>
      'Odpowiedz na co najmniej jedno pytanie każdego dnia.';

  @override
  String get dashboardDueTitle => 'Do powtórzenia dziś';

  @override
  String dashboardDue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pytania do powtórzenia dziś',
      many: '$count pytań do powtórzenia dziś',
      few: '$count pytania do powtórzenia dziś',
      one: '1 pytanie do powtórzenia dziś',
      zero: 'Dziś nic do powtórzenia',
    );
    return '$_temp0';
  }

  @override
  String get dashboardDueHint => 'Otwórz przedmiot i wybierz Powtórki.';

  @override
  String get dashboardDueLocked => 'Powtórki w odstępach są częścią Premium.';

  @override
  String get dashboardDataError => 'Nie udało się otworzyć danych o postępach.';

  @override
  String get dashboardOverviewTitle => 'Twój postęp';

  @override
  String dashboardCoverage(int percent) {
    return 'Pokrycie $percent%';
  }

  @override
  String dashboardAccuracy(int percent) {
    return 'Skuteczność $percent%';
  }

  @override
  String get dashboardReadinessTitle => 'Gotowość do egzaminu';

  @override
  String get dashboardReadinessApprox => 'orientacyjnie';

  @override
  String get dashboardReadinessLocked =>
      'Gotowość według przedmiotów jest częścią Premium.';

  @override
  String dashboardPercentValue(int percent) {
    return '$percent%';
  }

  @override
  String get dashboardWeakTitle => 'Najsłabsze przedmioty';

  @override
  String get dashboardWeakNone =>
      'Odpowiedz na co najmniej 10 pytań z przedmiotu, aby pojawił się tutaj.';

  @override
  String get dashboardLastExamTitle => 'Ostatnia symulacja';

  @override
  String get dashboardLastExamNone => 'Brak symulacji egzaminu.';

  @override
  String get dashboardPassed => 'Zdany';

  @override
  String get dashboardFailed => 'Niezdany';

  @override
  String dashboardAttemptResult(int percent, String date) {
    return '$percent% · $date';
  }

  @override
  String dashboardLegacyAttempts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count podejścia sprzed wersji 2.0',
      many: '$count podejść sprzed wersji 2.0',
      few: '$count podejścia sprzed wersji 2.0',
      one: '1 podejście sprzed wersji 2.0',
    );
    return '$_temp0';
  }

  @override
  String get settingsTitle => 'Profil i ustawienia';

  @override
  String get settingsPremiumActive => 'Premium jest aktywne';

  @override
  String get settingsPremiumGet => 'Odblokuj wszystkie funkcje';

  @override
  String get settingsSectionLearning => 'Nauka';

  @override
  String get settingsSectionAppearance => 'Wygląd';

  @override
  String get settingsLicenceTitle => 'Licencja';

  @override
  String get settingsExamDateTitle => 'Data egzaminu';

  @override
  String get settingsExamDateNotSet => 'Nie ustawiono';

  @override
  String get settingsExamDateClear => 'Usuń datę';

  @override
  String get settingsExamDateHelp => 'Data egzaminu';

  @override
  String settingsDailyGoalValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pytania dziennie',
      many: '$count pytań dziennie',
      few: '$count pytania dziennie',
      one: '1 pytanie dziennie',
    );
    return '$_temp0';
  }

  @override
  String get settingsDailyGoalTitle => 'Cel dzienny';

  @override
  String get settingsThemeTitle => 'Motyw';

  @override
  String get settingsThemeSystem => 'Systemowy';

  @override
  String get settingsThemeLight => 'Jasny';

  @override
  String get settingsThemeDark => 'Ciemny';

  @override
  String get settingsSaveError => 'Nie udało się zapisać ustawienia.';

  @override
  String get settingsRetry => 'Ponów';

  @override
  String get settingsAboutSubtitle => 'Wersja, źródła i informacje prawne';

  @override
  String get settingsStartupError =>
      'Aplikacja nie mogła odczytać swoich danych.';

  @override
  String get startupErrorTitle => 'Nie udało się uruchomić Pilotiq';

  @override
  String get onboardingWelcomeTitle => 'Witaj w Pilotiq';

  @override
  String get onboardingWelcomeBody =>
      'Wybierz licencję, do której się przygotowujesz, oraz język pytań.';

  @override
  String get onboardingLegacyBanner =>
      'Znaleźliśmy Twoje wyniki z poprzedniej wersji i je zachowaliśmy. Sprawdź, czy licencja jest właściwa.';

  @override
  String get onboardingExamDateTitle => 'Kiedy masz egzamin?';

  @override
  String get onboardingExamDateBody =>
      'Odliczamy dni i dostosowujemy do nich powtórki. Możesz to pominąć.';

  @override
  String get onboardingGoalTitle => 'Ile pytań dziennie?';

  @override
  String get onboardingGoalBody =>
      'Mały cel dzienny buduje serię. Możesz go zmienić w każdej chwili.';

  @override
  String get onboardingNext => 'Dalej';

  @override
  String get onboardingBack => 'Wstecz';

  @override
  String get onboardingSkip => 'Pomiń';

  @override
  String get onboardingFinish => 'Zaczynamy naukę';

  @override
  String onboardingStepOf(int current, int total) {
    return 'Krok $current z $total';
  }

  @override
  String aboutVersion(String version, String build) {
    return 'Wersja $version ($build)';
  }

  @override
  String get aboutDisclaimer =>
      'Pilotiq nie jest powiązane z ULC ani EASA i nie jest ich produktem.';

  @override
  String get aboutBankTitle => 'Baza pytań';

  @override
  String aboutBankSourceLine(String licence, String source, String date) {
    return '$licence: $source, $date';
  }

  @override
  String get aboutQuestionsNote =>
      'Treści pytań podano w takiej postaci, w jakiej opublikował je ULC.';

  @override
  String get recoveryNoticeTitle => 'Zapisane dane były uszkodzone';

  @override
  String get recoveryNoticeRestored =>
      'Część zapisanych danych została uszkodzona. Odczytywalną część przywrócono.';

  @override
  String get recoveryNoticeReset =>
      'Część zapisanych danych została uszkodzona i musiała zostać wyzerowana.';

  @override
  String get recoveryNoticeBackup =>
      'Kopia zapasowa uszkodzonego pliku została zapisana na tym urządzeniu.';

  @override
  String get recoveryNoticeOk => 'OK';

  @override
  String get examScreenTitle => 'Symulacja egzaminu';

  @override
  String get examRulesHeading => 'Zanim zaczniesz';

  @override
  String examRulesQuestions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pytania',
      many: '$count pytań',
      few: '$count pytania',
      one: '$count pytanie',
    );
    return '$_temp0';
  }

  @override
  String examRulesTime(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minuty',
      many: '$minutes minut',
      few: '$minutes minuty',
      one: '$minutes minuta',
    );
    return 'Limit czasu: $_temp0';
  }

  @override
  String examRulesPass(int percent) {
    return 'Próg zaliczenia: $percent% wszystkich pytań. Pytanie bez odpowiedzi liczy się jako błędne.';
  }

  @override
  String get examRulesNavigate =>
      'Możesz swobodnie przechodzić między pytaniami i zmieniać odpowiedzi aż do zakończenia egzaminu.';

  @override
  String get examRulesNoFeedback =>
      'Podczas egzaminu poprawna odpowiedź nie jest pokazywana. Oznacz pytanie, aby wrócić do niego później.';

  @override
  String get examRulesTimer =>
      'Czas płynie także po wyjściu z aplikacji. Gdy czas minie, egzamin kończy się, a wynik zostaje zapisany.';

  @override
  String get examRulesFresh =>
      'Każde podejście losuje nowy zestaw pytań z tego przedmiotu, rozłożony na tematy.';

  @override
  String get examStartButton => 'Rozpocznij egzamin';

  @override
  String get examStartFailed =>
      'Nie udało się rozpocząć egzaminu, bo nie można zapisać podejścia na tym urządzeniu.';

  @override
  String get examSaveRetry => 'Spróbuj ponownie';

  @override
  String get examLimitTitle => 'Darmowa symulacja wykorzystana';

  @override
  String get examLimitBody =>
      'Wykorzystano darmową symulację tego przedmiotu. Premium daje nieograniczone symulacje z historią i analizą tematów.';

  @override
  String get examLimitHistory => 'Otwórz historię';

  @override
  String get examResumeTitle => 'Niedokończony egzamin';

  @override
  String examResumeBody(int answered, int total, int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minuty',
      many: '$minutes minut',
      few: '$minutes minuty',
      one: '$minutes minuta',
    );
    return 'Masz egzamin w toku: odpowiedzi $answered z $total, pozostało $_temp0.';
  }

  @override
  String get examResumeContinue => 'Kontynuuj egzamin';

  @override
  String get examResumeFinish => 'Zakończ egzamin teraz';

  @override
  String examQuestionOf(int current, int total) {
    return 'Pytanie $current z $total';
  }

  @override
  String examAnsweredCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count odpowiedzi',
      many: '$count odpowiedzi',
      few: '$count odpowiedzi',
      one: '$count odpowiedź',
    );
    return '$_temp0';
  }

  @override
  String examTimeLeftSemantics(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minuty',
      many: '$minutes minut',
      few: '$minutes minuty',
      one: '$minutes minuta',
    );
    return 'Pozostało $_temp0';
  }

  @override
  String get examTimeLow => 'Mało czasu';

  @override
  String get examPrevious => 'Wstecz';

  @override
  String get examNext => 'Dalej';

  @override
  String get examFlagAdd => 'Oznacz, aby wrócić później';

  @override
  String get examFlagRemove => 'Oznaczone: dotknij, aby usunąć oznaczenie';

  @override
  String get examGridTooltip => 'Siatka pytań';

  @override
  String get examFinishTooltip => 'Zakończ egzamin';

  @override
  String get examFinishButton => 'Zakończ egzamin';

  @override
  String examAnswerSemantics(int position, int total, String text) {
    return 'Odpowiedź $position z $total: $text';
  }

  @override
  String get examPersistError =>
      'Nie udało się zapisać postępu na tym urządzeniu. Odpowiedzi są na razie zachowane.';

  @override
  String get examGridTitle => 'Pytania';

  @override
  String get examGridLegendAnswered => 'Z odpowiedzią';

  @override
  String get examGridLegendUnanswered => 'Bez odpowiedzi';

  @override
  String get examGridLegendFlagged => 'Oznaczone';

  @override
  String get examGridClose => 'Zamknij';

  @override
  String examGridCell(int number) {
    return 'Pytanie $number';
  }

  @override
  String get examGridStateAnswered => 'z odpowiedzią';

  @override
  String get examGridStateUnanswered => 'bez odpowiedzi';

  @override
  String get examGridStateFlagged => 'oznaczone do powrotu';

  @override
  String get examGridStateCurrent => 'bieżące pytanie';

  @override
  String get examFinishDialogTitle => 'Zakończyć egzamin?';

  @override
  String examFinishUnanswered(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pytania bez odpowiedzi.',
      many: '$count pytań bez odpowiedzi.',
      few: '$count pytania bez odpowiedzi.',
      one: '$count pytanie bez odpowiedzi.',
      zero: 'Na wszystkie pytania udzielono odpowiedzi.',
    );
    return '$_temp0';
  }

  @override
  String get examFinishUnansweredNote =>
      'Pytania bez odpowiedzi liczą się jako błędne.';

  @override
  String examFinishFlagged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pytania oznaczonego do powrotu.',
      many: '$count pytań oznaczonych do powrotu.',
      few: '$count pytania oznaczone do powrotu.',
      one: '$count pytanie oznaczone do powrotu.',
      zero: 'Brak oznaczonych pytań.',
    );
    return '$_temp0';
  }

  @override
  String get examFinishKeepWorking => 'Wróć do egzaminu';

  @override
  String get examFinishConfirm => 'Zakończ egzamin';

  @override
  String get examLeaveTitle => 'Opuścić egzamin?';

  @override
  String get examLeaveBody =>
      'Czas nadal płynie. Możesz kontynuować z ekranu przedmiotu, dopóki czas nie minie.';

  @override
  String get examLeaveStay => 'Zostań';

  @override
  String get examLeaveConfirm => 'Wyjdź';

  @override
  String get examSavingResult => 'Zapisywanie wyniku…';

  @override
  String get examFinishSaveError =>
      'Nie udało się jeszcze zapisać wyniku. Nie jest pokazywany jako zapisany, dopóki się nie zapisze.';

  @override
  String get examTimeUpNotice =>
      'Czas minął. Egzamin został zakończony automatycznie, a wynik zapisany.';

  @override
  String get examExpiredOnOpenNotice =>
      'Czas minął, gdy egzamin nie był otwarty. Został zakończony i zapisany automatycznie.';

  @override
  String get examResultTitle => 'Wynik egzaminu';

  @override
  String get examPassed => 'ZALICZONY';

  @override
  String get examFailed => 'NIEZALICZONY';

  @override
  String examResultCorrect(int correct, int total) {
    return '$correct z $total poprawnych';
  }

  @override
  String examResultPassMark(int percent) {
    return 'Próg zaliczenia: $percent%';
  }

  @override
  String examResultTime(String time) {
    return 'Wykorzystany czas: $time';
  }

  @override
  String examResultUnanswered(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pytania bez odpowiedzi (liczone jako błędne).',
      many: '$count pytań bez odpowiedzi (liczone jako błędne).',
      few: '$count pytania bez odpowiedzi (liczone jako błędne).',
      one: '$count pytanie bez odpowiedzi (liczone jako błędne).',
      zero: 'Na każde pytanie udzielono odpowiedzi.',
    );
    return '$_temp0';
  }

  @override
  String get examBreakdownTitle => 'Wyniki według tematów';

  @override
  String examBreakdownRow(String topic, int correct, int total, int percent) {
    return '$topic: $correct z $total ($percent%)';
  }

  @override
  String get examTeaserTitle => 'Wyniki według tematów i przegląd odpowiedzi';

  @override
  String get examTeaserBody =>
      'W Premium zobaczysz, gdzie tracisz punkty, przejrzysz każdą odpowiedź i potrenujesz pytania z błędami.';

  @override
  String get examReviewButton => 'Przejrzyj odpowiedzi';

  @override
  String get examTrainMistakes => 'Trenuj błędy z tego podejścia';

  @override
  String get examRepeat => 'Powtórz egzamin';

  @override
  String get examHistoryButton => 'Historia';

  @override
  String get examReviewTitle => 'Przegląd odpowiedzi';

  @override
  String get examReviewFilterAll => 'Wszystkie';

  @override
  String get examReviewFilterWrong => 'Błędne lub bez odpowiedzi';

  @override
  String examReviewQuestionNumber(int index, int total) {
    return 'Pytanie $index z $total';
  }

  @override
  String get examReviewYourAnswer => 'Twoja odpowiedź';

  @override
  String get examReviewCorrectAnswer => 'Poprawna odpowiedź';

  @override
  String get examReviewNoAnswer => 'Brak odpowiedzi';

  @override
  String get examReviewMissing => 'Tego pytania nie ma już w bazie pytań.';

  @override
  String get examReviewMarkCorrect => 'Poprawnie';

  @override
  String get examReviewMarkWrong => 'Błędnie';

  @override
  String get examReviewMarkUnanswered => 'Bez odpowiedzi';

  @override
  String get examReviewEmptyWrong =>
      'Brak błędnych odpowiedzi w tym podejściu.';

  @override
  String get examReviewFlagged => 'Oznaczone do powrotu';

  @override
  String get examHistoryTitle => 'Historia egzaminów';

  @override
  String get examHistoryEmpty =>
      'Brak symulacji. Tutaj pojawią się Twoje wyniki.';

  @override
  String get examHistoryLegacy => 'Przed wersją 2.0';

  @override
  String get examHistoryLoadError => 'Nie udało się wczytać historii.';

  @override
  String get examHistoryChartTitle => 'Ostatnie wyniki';

  @override
  String examHistoryChartSemantics(String results) {
    return 'Ostatnie wyniki, od najstarszego: $results';
  }

  @override
  String get examHistoryTimedOut => 'Czas minął';

  @override
  String examHistoryPassLine(int percent) {
    return 'Próg $percent%';
  }

  @override
  String examTileInProgress(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minuty',
      many: '$minutes minut',
      few: '$minutes minuty',
      one: '$minutes minuta',
    );
    return 'Niedokończone podejście, pozostało $_temp0';
  }

  @override
  String examTileLastPassed(int percent) {
    return 'Ostatni wynik: $percent%, zaliczony';
  }

  @override
  String examTileLastFailed(int percent) {
    return 'Ostatni wynik: $percent%, niezaliczony';
  }

  @override
  String get examLeaveUnsavedBody =>
      'Ostatnie odpowiedzi nie zostały zapisane na tym urządzeniu i zostaną utracone, jeśli wyjdziesz. Czas nadal płynie.';

  @override
  String get examLeaveUnsavedResultBody =>
      'Wynik nie został jeszcze zapisany. Jeśli wyjdziesz teraz, egzamin pozostanie niezakończony, a jego wynik zostanie zapisany po ponownym otwarciu. Nie można go kontynuować.';

  @override
  String get examLeaveResultSavedBody =>
      'Wynik jest zapisany. Część odpowiedzi nie została jeszcze dodana do postępu; zostanie dodana automatycznie.';

  @override
  String get examLeaveNotMarkedBody =>
      'Nie udało się zapisać zakończenia egzaminu, ale odpowiedzi są zapisane. Jeśli wyjdziesz, egzamin będzie można kontynuować, a czas będzie nadal płynął.';

  @override
  String get examLeaveContinueLostBody =>
      'Nie udało się zapisać zakończenia egzaminu ani ostatnich odpowiedzi. Ostatnie odpowiedzi zostaną utracone. Jeśli wyjdziesz, egzamin będzie można kontynuować od ostatniego zapisanego stanu, a czas nadal płynie.';

  @override
  String get examLeaveTimeoutSavedBody =>
      'Czas minął, ale nie udało się jeszcze zapisać wyniku. Jeśli wyjdziesz, zostanie obliczony z zapisanych odpowiedzi przy następnym otwarciu egzaminu.';

  @override
  String get examLeaveTimeoutLostBody =>
      'Czas minął, ale nie udało się jeszcze zapisać wyniku. Jeśli wyjdziesz, zostanie obliczony z zapisanych odpowiedzi przy następnym otwarciu egzaminu. Ostatnie odpowiedzi nie zostały zapisane i nie zostaną uwzględnione.';

  @override
  String get examClockPersistError =>
      'Nie udało się zapisać czasu egzaminu na tym urządzeniu. Odpowiedzi są zapisane.';

  @override
  String get reminderChannelName => 'Przypomnienia o nauce';

  @override
  String get reminderChannelDescription =>
      'Codzienne przypomnienie o nauce do egzaminu';

  @override
  String get reminderStudyTitle => 'Czas na naukę';

  @override
  String reminderDaysToExam(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Do egzaminu: $days dnia',
      many: 'Do egzaminu: $days dni',
      few: 'Do egzaminu: $days dni',
      one: 'Do egzaminu: 1 dzień',
    );
    return '$_temp0';
  }

  @override
  String reminderGoalLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Do dzisiejszego celu: $count odpowiedzi',
      many: 'Do dzisiejszego celu: $count odpowiedzi',
      few: 'Do dzisiejszego celu: $count odpowiedzi',
      one: 'Do dzisiejszego celu: 1 odpowiedź',
    );
    return '$_temp0';
  }

  @override
  String reminderDueQuestions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pytania do powtórki',
      many: '$count pytań do powtórki',
      few: '$count pytania do powtórki',
      one: '1 pytanie do powtórki',
    );
    return '$_temp0';
  }

  @override
  String get reminderExamWeekTitle => 'Tydzień do egzaminu';

  @override
  String get reminderExamEveTitle => 'Egzamin już jutro';

  @override
  String get reminderExamEveBody =>
      'Powtórz jeszcze raz swoje błędy i dobrze się wyśpij.';

  @override
  String get reminderAfterExamTitle => 'Jak poszedł egzamin?';

  @override
  String get reminderAfterExamBody =>
      'Powodzenia z wynikiem! Jeśli potrzebujesz kolejnego podejścia, ustaw nową datę egzaminu w Profilu.';

  @override
  String get remindersSectionTitle => 'Przypomnienia';

  @override
  String get remindersToggleTitle => 'Codzienne przypomnienie o nauce';

  @override
  String get remindersToggleOff => 'Wyłączone';

  @override
  String remindersToggleOn(String time) {
    return 'Codziennie o $time';
  }

  @override
  String get remindersTimeTitle => 'Godzina przypomnienia';

  @override
  String get remindersBlocked =>
      'Powiadomienia są zablokowane dla aplikacji, więc przypomnienia nie będą wyświetlane.';

  @override
  String get remindersOpenSettings => 'Otwórz ustawienia systemu';

  @override
  String get remindersOpenSettingsFailed =>
      'Nie udało się otworzyć ustawień. Otwórz Ustawienia telefonu, potem Aplikacje, Pilotiq, Powiadomienia.';

  @override
  String get remindersScheduleFailed => 'Nie udało się zaplanować przypomnień.';

  @override
  String get remindersRetry => 'Spróbuj ponownie';

  @override
  String get onboardingRemindersTitle => 'Kiedy przypominać?';

  @override
  String get onboardingRemindersBody =>
      'Jedno przypomnienie dziennie o wybranej godzinie. Aplikacja poprosi system o zgodę na powiadomienia dopiero po dotknięciu przycisku poniżej.';

  @override
  String get onboardingRemindersEnable => 'Włącz przypomnienia';

  @override
  String onboardingRemindersEnabled(String time) {
    return 'Przypomnienia włączone, codziennie o $time.';
  }

  @override
  String get onboardingRemindersDenied =>
      'Powiadomienia nie są dozwolone. Przypomnienia możesz włączyć później w Profilu.';

  @override
  String get paywallClose => 'Zamknij';

  @override
  String get paywallTitleDailyLimit =>
      'Dzisiejszy limit bezpłatnych odpowiedzi wykorzystany';

  @override
  String paywallSubtitleDailyLimit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Wersja bezpłatna to $count odpowiedzi dziennie. Premium nie ma dziennego limitu.',
      many:
          'Wersja bezpłatna to $count odpowiedzi dziennie. Premium nie ma dziennego limitu.',
      few:
          'Wersja bezpłatna to $count odpowiedzi dziennie. Premium nie ma dziennego limitu.',
      one:
          'Wersja bezpłatna to $count odpowiedź dziennie. Premium nie ma dziennego limitu.',
    );
    return '$_temp0';
  }

  @override
  String get paywallTitleExamLimit => 'Bezpłatna symulacja wykorzystana';

  @override
  String paywallSubtitleExamLimit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Wersja bezpłatna to $count symulacji na przedmiot. Premium daje nielimitowane symulacje i analizę tematów.',
      many:
          'Wersja bezpłatna to $count symulacji na przedmiot. Premium daje nielimitowane symulacje i analizę tematów.',
      few:
          'Wersja bezpłatna to $count symulacje na przedmiot. Premium daje nielimitowane symulacje i analizę tematów.',
      one:
          'Wersja bezpłatna to $count symulacja na przedmiot. Premium daje nielimitowane symulacje i analizę tematów.',
    );
    return '$_temp0';
  }

  @override
  String get paywallTitleLocked => 'Ta funkcja jest częścią Premium';

  @override
  String get paywallSubtitleLocked =>
      'Moje błędy i powtórki w odstępach pomagają wracać do pytań, z którymi nadal masz problem.';

  @override
  String get paywallTitleResults => 'Analiza tematów jest częścią Premium';

  @override
  String get paywallSubtitleResults =>
      'Zobacz, gdzie tracisz punkty, przejrzyj każdą odpowiedź i ćwicz pytania, które sprawiły kłopot.';

  @override
  String get paywallTitleProfile => 'Pilotiq Premium';

  @override
  String get paywallSubtitleProfile =>
      'Ucz się bez limitów i sprawdzaj, jak stoisz z każdym przedmiotem.';

  @override
  String get paywallBenefitsTitle => 'W Premium';

  @override
  String paywallBenefitUnlimited(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Nauka bez dziennego limitu (bezpłatnie: $count odpowiedzi dziennie)',
      many:
          'Nauka bez dziennego limitu (bezpłatnie: $count odpowiedzi dziennie)',
      few:
          'Nauka bez dziennego limitu (bezpłatnie: $count odpowiedzi dziennie)',
      one: 'Nauka bez dziennego limitu (bezpłatnie: $count odpowiedź dziennie)',
    );
    return '$_temp0';
  }

  @override
  String paywallBenefitSimulations(int count) {
    return 'Nielimitowane symulacje egzaminu z analizą tematów wyników (bezpłatnie: $count na przedmiot)';
  }

  @override
  String get paywallBenefitMistakes =>
      'Moje błędy: ćwicz pytania, w których popełniono błąd';

  @override
  String get paywallBenefitReview =>
      'Powtórki w odstępach dla pytań do powtórzenia';

  @override
  String get paywallBenefitReadiness =>
      'Szczegółowa gotowość z każdego przedmiotu (orientacyjnie)';

  @override
  String get paywallChoosePlan => 'Wybierz plan';

  @override
  String get paywallBestChoice => 'Najlepszy wybór';

  @override
  String get paywallPlanLifetime => 'Na zawsze';

  @override
  String paywallLifetimePrice(String price) {
    return '$price · płatność jednorazowa';
  }

  @override
  String paywallDurationDay(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dnia',
      many: '$count dni',
      few: '$count dni',
      one: '$count dzień',
    );
    return '$_temp0';
  }

  @override
  String paywallDurationWeek(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tygodnia',
      many: '$count tygodni',
      few: '$count tygodnie',
      one: '$count tydzień',
    );
    return '$_temp0';
  }

  @override
  String paywallDurationMonth(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count miesiąca',
      many: '$count miesięcy',
      few: '$count miesiące',
      one: '$count miesiąc',
    );
    return '$_temp0';
  }

  @override
  String paywallDurationYear(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count roku',
      many: '$count lat',
      few: '$count lata',
      one: '$count rok',
    );
    return '$_temp0';
  }

  @override
  String get paywallPerDay => 'dzień';

  @override
  String get paywallPerWeek => 'tydzień';

  @override
  String get paywallPerMonth => 'miesiąc';

  @override
  String get paywallPerYear => 'rok';

  @override
  String paywallPricePer(String price, String period) {
    return '$price / $period';
  }

  @override
  String paywallIntroFree(String trial, String price) {
    return '$trial za darmo, potem $price';
  }

  @override
  String paywallIntroPaid(String period, String introPrice, String price) {
    return '$period: $introPrice, potem $price';
  }

  @override
  String get paywallContinue => 'Kontynuuj';

  @override
  String get paywallRestore => 'Przywróć zakupy';

  @override
  String get paywallRenewalNotice =>
      'Subskrypcje odnawiają się automatycznie na ten sam okres w pokazanej cenie, dopóki ich nie anulujesz. Płatność jest pobierana z Twojego konta w sklepie. Aby uniknąć kolejnej opłaty, anuluj subskrypcję w ustawieniach konta w sklepie co najmniej 24 godziny przed końcem bieżącego okresu.';

  @override
  String get paywallRenewalNoticeIos =>
      'Subskrypcje odnawiają się automatycznie na ten sam okres w pokazanej cenie, dopóki ich nie anulujesz. Płatność jest pobierana z Twojego konta Apple ID. Aby uniknąć kolejnej opłaty, anuluj subskrypcję w ustawieniach konta Apple ID (App Store) co najmniej 24 godziny przed końcem bieżącego okresu.';

  @override
  String get paywallRenewalNoticeAndroid =>
      'Subskrypcje odnawiają się automatycznie na ten sam okres w pokazanej cenie, dopóki ich nie anulujesz. Płatność jest pobierana z Twojego konta Google Play. Aby uniknąć kolejnej opłaty, anuluj subskrypcję w ustawieniach konta Google Play co najmniej 24 godziny przed końcem bieżącego okresu.';

  @override
  String get paywallTrialNotice =>
      'Bezpłatny okres próbny zamienia się w płatną subskrypcję w pokazanej cenie, jeśli nie anulujesz jej przed jego końcem.';

  @override
  String get paywallOneTimeNotice =>
      'Dostęp na zawsze to płatność jednorazowa: nie odnawia się i nie jest subskrypcją.';

  @override
  String get paywallLoading => 'Wczytywanie planów…';

  @override
  String get paywallErrorNetwork =>
      'Brak połączenia. Sprawdź internet i spróbuj ponownie.';

  @override
  String get paywallErrorStore =>
      'Sklep nie mógł zrealizować żądania. Spróbuj ponownie później.';

  @override
  String get paywallErrorUnknown => 'Coś poszło nie tak. Spróbuj ponownie.';

  @override
  String get paywallEmpty =>
      'Obecnie brak dostępnych planów. Spróbuj ponownie później.';

  @override
  String get paywallUnavailable =>
      'Zakupy nie są dostępne w tej wersji aplikacji.';

  @override
  String get paywallRetry => 'Spróbuj ponownie';

  @override
  String get paywallPurchasing => 'Przetwarzanie zakupu…';

  @override
  String get paywallPending =>
      'Zakup czeka na zatwierdzenie (np. Poproś o zakup lub opóźniona płatność). Premium odblokuje się po zatwierdzeniu.';

  @override
  String get paywallNotActivated =>
      'Płatność przeszła, ale Premium nie jest jeszcze aktywne. Za chwilę użyj opcji „Przywróć zakupy”.';

  @override
  String get paywallRestoreNone =>
      'Nie znaleziono aktywnych zakupów na tym koncie sklepu.';

  @override
  String get paywallThanksTitle => 'Dziękujemy!';

  @override
  String get paywallThanksBody =>
      'Premium jest odblokowane. Możesz wrócić do tego, co robisz.';

  @override
  String get paywallAlreadyTitle => 'Premium jest aktywne';

  @override
  String get paywallAlreadyBody => 'Wszystkie funkcje są odblokowane.';

  @override
  String get paywallSemSelected => 'wybrany';

  @override
  String get paywallSemNotSelected => 'niewybrany';

  @override
  String get paywallSettingsSection => 'Zakupy';

  @override
  String get paywallSettingsRestoreTitle => 'Przywróć zakupy';

  @override
  String get paywallSettingsRestoreSubtitle =>
      'Odzyskaj Premium po ponownej instalacji lub na nowym telefonie.';

  @override
  String get paywallSettingsUnavailable =>
      'Niedostępne w tej wersji aplikacji.';

  @override
  String get paywallSettingsManage =>
      'Aby anulować lub zmienić subskrypcję, otwórz ustawienia konta w sklepie.';

  @override
  String get paywallSettingsManageIos =>
      'Aby anulować lub zmienić subskrypcję, otwórz ustawienia subskrypcji swojego konta Apple ID (App Store).';

  @override
  String get paywallSettingsManageAndroid =>
      'Aby anulować lub zmienić subskrypcję, otwórz subskrypcje swojego konta Google Play.';

  @override
  String get paywallSettingsRestored => 'Premium przywrócone';

  @override
  String paywallPlanPrepaid(String duration) {
    return 'Dostęp na $duration';
  }

  @override
  String paywallPrepaidPrice(String price) {
    return '$price · płatność jednorazowa, bez odnowienia';
  }

  @override
  String practiceProgress(int current, int total) {
    return '$current / $total';
  }

  @override
  String get practiceFinishSession => 'Zakończ sesję';

  @override
  String get practiceLastQuestionButton => 'Zakończ';

  @override
  String get practiceBookmarkAdd => 'Dodaj zakładkę';

  @override
  String get practiceBookmarkRemove => 'Usuń zakładkę';

  @override
  String get practiceFeedbackCorrect => 'Dobrze!';

  @override
  String get practiceFeedbackWrong =>
      'Źle. Poprawna odpowiedź jest wyróżniona.';

  @override
  String get practiceAnswerCorrectSemantics => 'poprawna odpowiedź';

  @override
  String get practiceAnswerWrongSemantics => 'twoja odpowiedź, błędna';

  @override
  String get practiceRetryTitle => 'POWTÓRZ BŁĘDY';

  @override
  String get practiceSummaryTitle => 'Podsumowanie sesji';

  @override
  String practiceSummaryCorrect(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count poprawnej odpowiedzi',
      many: '$count poprawnych odpowiedzi',
      few: '$count poprawne odpowiedzi',
      one: '$count poprawna odpowiedź',
    );
    return '$_temp0';
  }

  @override
  String practiceSummaryWrong(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count błędnej odpowiedzi',
      many: '$count błędnych odpowiedzi',
      few: '$count błędne odpowiedzi',
      one: '$count błędna odpowiedź',
    );
    return '$_temp0';
  }

  @override
  String practiceSummaryAccuracy(int percent) {
    return 'Skuteczność: $percent%';
  }

  @override
  String get practiceSummaryNothing =>
      'W tej sesji nie odpowiedziano na żadne pytanie.';

  @override
  String get practiceRepeatMistakes => 'Powtórz błędy z tej sesji';

  @override
  String get practiceEmptyLearn => 'Brak pytań do przećwiczenia.';

  @override
  String get practiceEmptyMistakes => 'Brak błędów do poprawienia. Świetnie!';

  @override
  String get practiceEmptyReview => 'Na dziś nie ma powtórek.';

  @override
  String get practiceEmptyBookmarks =>
      'Nie dodano jeszcze zakładek w tym przedmiocie.';

  @override
  String get practiceLimitTitle => 'Dzienny limit wykorzystany';

  @override
  String practiceLimitBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Bezpłatny dostęp obejmuje $count odpowiedzi dziennie.',
      many: 'Bezpłatny dostęp obejmuje $count odpowiedzi dziennie.',
      few: 'Bezpłatny dostęp obejmuje $count odpowiedzi dziennie.',
      one: 'Bezpłatny dostęp obejmuje $count odpowiedź dziennie.',
    );
    return '$_temp0 Wróć jutro albo przejdź na Premium, aby ćwiczyć bez limitu.';
  }

  @override
  String get practiceLockedTitle => 'Funkcja Premium';

  @override
  String get practiceLockedBody =>
      'Moje błędy i powtórki są dostępne w wersji Premium.';

  @override
  String get practiceLockedBadge => 'Premium';

  @override
  String practiceModeLearnStatus(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pytania jeszcze nieoglądanego',
      many: '$count pytań jeszcze nieoglądanych',
      few: '$count pytania jeszcze nieoglądane',
      one: '$count pytanie jeszcze nieoglądane',
      zero: 'Wszystkie pytania poznane',
    );
    return '$_temp0';
  }

  @override
  String practiceModeMistakesStatus(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pytania do poprawy',
      many: '$count pytań do poprawy',
      few: '$count pytania do poprawy',
      one: '$count pytanie do poprawy',
      zero: 'Brak błędów',
    );
    return '$_temp0';
  }

  @override
  String practiceModeReviewStatus(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pytania do powtórki',
      many: '$count pytań do powtórki',
      few: '$count pytania do powtórki',
      one: '$count pytanie do powtórki',
      zero: 'Brak powtórek',
    );
    return '$_temp0';
  }

  @override
  String practiceModeBookmarksStatus(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pytania w zakładkach',
      many: '$count pytań w zakładkach',
      few: '$count pytania w zakładkach',
      one: '$count pytanie w zakładkach',
      zero: 'Brak zakładek',
    );
    return '$_temp0';
  }

  @override
  String practiceSubjectCoverage(int percent) {
    return '$percent% poznane';
  }

  @override
  String practiceSubjectAccuracy(int percent) {
    return '$percent% skuteczności';
  }

  @override
  String get practiceSubjectNotStarted => 'Jeszcze nie rozpoczęto';

  @override
  String get practiceLoadError => 'Nie udało się wczytać pytań.';

  @override
  String get practiceSaveError =>
      'Nie udało się zapisać odpowiedzi. Na razie nie jest liczona.';

  @override
  String get practiceSaveRetry => 'Ponów';

  @override
  String get practiceLimitRecheck => 'Sprawdź ponownie';

  @override
  String get practiceBookmarkError => 'Nie udało się zapisać zakładki.';
}
