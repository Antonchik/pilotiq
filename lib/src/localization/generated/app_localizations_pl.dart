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
}
