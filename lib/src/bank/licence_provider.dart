import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pilotiq/src/domain/catalog.dart';
import 'package:pilotiq/src/progress/providers.dart';
import 'package:pilotiq/src/progress/user_settings.dart';

/// Licence the user prepares for (stored in `config`; PPL(A) by default).
final selectedLicenceProvider = Provider<Licence>(
  (ref) => ref.watch(userSettingsProvider).value?.licence ?? Licence.ppla,
);

/// Language of the questions the user asked for (Polish by default). It is
/// shared by all licences; see [effectiveQuestionLanguage] for the language
/// that is really available.
final questionLanguageProvider = Provider<QuestionLanguage>(
  (ref) =>
      ref.watch(userSettingsProvider).value?.questionLanguage ??
      QuestionLanguage.pl,
);

/// The requested language, or Polish when [licence] has no English bank.
QuestionLanguage effectiveQuestionLanguage(
  Licence licence,
  QuestionLanguage requested,
) => licence.hasEnglish ? requested : QuestionLanguage.pl;

/// Language in which the questions of [licence] are shown.
final effectiveQuestionLanguageProvider =
    Provider.family<QuestionLanguage, Licence>(
      (ref, licence) => effectiveQuestionLanguage(
        licence,
        ref.watch(questionLanguageProvider),
      ),
    );

/// Remembers [licence] as the selected one.
Future<void> selectLicence(WidgetRef ref, Licence licence) => ref
    .read(userSettingsProvider.notifier)
    .change((s) => s.copyWith(licence: licence));

/// Remembers the question language.
Future<void> selectQuestionLanguage(WidgetRef ref, QuestionLanguage language) =>
    ref
        .read(userSettingsProvider.notifier)
        .change((s) => s.copyWith(questionLanguage: language));
