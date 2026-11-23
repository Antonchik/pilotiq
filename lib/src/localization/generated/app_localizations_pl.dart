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
  String get subjectModeSoonBadge => 'Wkrótce';

  @override
  String examMinutesShort(int count) {
    return '$count min';
  }

  @override
  String get appTitle => 'Pilotiq';

  @override
  String get copyright =>
      '© 2023 Anton Antonchik.\nWszelkie prawa zastrzeżone.';

  @override
  String get yes => 'Tak';

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
  String get startQuizTitle => 'Start';

  @override
  String get continueQuizTitle => 'Kontynuuj';

  @override
  String get startNewQuizTitle => 'Zacznij od nowa';

  @override
  String get returnToSubjectTitle => 'Powrót do przedmiotu';

  @override
  String get reviewAnswersTitle => 'Przeglądaj odpowiedzi';

  @override
  String get restartMessage =>
      'Czy chcesz kontynuować rozpoczęty wcześniej test, czy zacząć od nowa?';

  @override
  String get congratsMessage =>
      'Gratulacje!\nTest został zakończony pomyślnie!';

  @override
  String get failMessage => 'Niestety, nie udało Ci się ukończyć testu.';

  @override
  String get rightAnswer => 'Poprawna odpowiedź!';

  @override
  String get wrongAnswer => 'Zła odpowiedź!';

  @override
  String get nextQuestion => 'Następne pytanie';

  @override
  String get tryAgain => 'Spróbuj ponownie';

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
  String get exitQuizTitle => 'Wyjść z testu?';

  @override
  String get timeIsUpTitle => 'Czas minął!';

  @override
  String get timeIsUpMessage => 'Nie udało Ci się ukończyć testu.';

  @override
  String get goPremiumLabel => 'Przejdź na Premium!';

  @override
  String get featuresDescriptionTitle => 'Wszystkie cechy w skrócie';

  @override
  String get allExamsAccessLabel => 'Dostęp do wszystkich egzaminów';

  @override
  String get darkModeAccessLabel => 'Tryb ciemny odblokowany';

  @override
  String get allSubjectsAccessLabel => 'Dostęp do wszystkich pytań';

  @override
  String get specialPriceLabel => 'Uzyskaj teraz!';

  @override
  String get privacyPolicyLabel => 'Polityka Prywatności';

  @override
  String get premiumUserGreeting => 'Jesteś użytkownikiem Premium!';

  @override
  String get thankYouMessage => 'Dziękujemy za wsparcie!';

  @override
  String get letsGoMessage => 'Lecimy!';

  @override
  String get premiumLabel => 'Przejdź na Premium!';

  @override
  String get premiumTitle => 'Premium';

  @override
  String get termsOfServiceLabel => 'Regulamin';

  @override
  String get okLabel => 'OK';

  @override
  String get aboutScreenBody => 'O tej aplikacji...';

  @override
  String get paywallStubMessage => 'Zakupy Premium będą tu wkrótce dostępne.';

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
}
