import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pilotiq/src/domain/access_policy.dart';
import 'package:pilotiq/src/domain/catalog.dart';
import 'package:pilotiq/src/materials/materials_models.dart';
import 'package:pilotiq/src/materials/materials_repository.dart';
import 'package:pilotiq/src/purchases/purchase_service.dart';

final materialsRepositoryProvider = Provider<MaterialsRepository>(
  (ref) => MaterialsRepository(),
);

/// The materials of a subject (`null`: the subject has none, or the asset is
/// missing or broken). Read lazily: nothing watches it at start-up.
final materialsProvider = FutureProvider.family<SubjectMaterials?, SubjectId>(
  (ref, subject) => ref.watch(materialsRepositoryProvider).load(subject),
);

/// Subject of a question id (`PL010-0001~ab12cd` → air law).
SubjectId? subjectOfQuestionId(String questionId) =>
    topicPrefixToSubject[questionId.split('-').first];

/// What the explanation panel shows for one question of one licence.
class ExplanationView {
  const ExplanationView({
    required this.key,
    required this.status,
    required this.text,
    required this.refs,
    required this.disputeNote,
    required this.locked,
    required this.licence,
    required this.questionId,
    required this.materialsVersion,
    required this.legalStateAsOf,
    this.outdated = false,
    this.outdatedNote,
  });

  final String key;

  /// Status of the explanation; `null` when the question has none (only the
  /// [outdated] mark).
  final MaterialStatus? status;
  final String text;

  /// Human readable references ("Prawo lotnicze, art. 128 ust. 1").
  final List<String> refs;
  final String? disputeNote;

  /// Premium only for the current user: the panel shows a teaser (and, for
  /// a disputed question, the dispute mark); [text], [refs] and
  /// [disputeNote] are then empty.
  final bool locked;
  final Licence licence;
  final String questionId;
  final String materialsVersion;
  final DateTime? legalStateAsOf;

  /// The question is based on repealed norms. Shown to every user.
  final bool outdated;

  /// What changed in the regulations; Premium only (null when [locked]).
  final String? outdatedNote;

  bool get disputed => status == MaterialStatus.disputed;

  /// There is an explanation text (not only the outdated mark).
  bool get hasExplanation => status != null;
}

/// The explanation of question `questionId` of `licence`, or `null` when it
/// has none (no panel then). Whether it is locked follows
/// [AccessPolicy.canSeeExplanation] with the position of the question in its
/// topic among the questions of the licence.
final explanationForQuestionProvider =
    FutureProvider.family<ExplanationView?, (Licence, String)>((
      ref,
      arg,
    ) async {
      final (licence, questionId) = arg;
      final subject = subjectOfQuestionId(questionId);
      if (subject == null || !materialsSubjects.contains(subject)) return null;
      final materials = await ref.watch(materialsProvider(subject).future);
      if (materials == null) return null;
      final key = materials.keyOf(licence, questionId);
      final explanation = key == null ? null : materials.explanations[key];
      final outdatedNote = key == null ? null : materials.outdated[key];
      if (key == null || (explanation == null && outdatedNote == null)) {
        return null;
      }
      final isPremium = ref.watch(isPremiumProvider);
      // An outdated question without an explanation is in no topic order:
      // its note is Premium only and it takes no place of the free sample.
      final locked = explanation == null
          ? !isPremium
          : !AccessPolicy.canSeeExplanation(
              isPremium,
              materials.indexInTopic(licence, key),
            );
      // A locked view carries no Premium content: only the status and the
      // outdated mark, which every user sees.
      return ExplanationView(
        key: key,
        status: explanation?.status,
        text: locked || explanation == null ? '' : explanation.text,
        refs: locked || explanation == null
            ? const []
            : [for (final r in explanation.refs) materials.refLabel(r)],
        disputeNote: locked ? null : explanation?.disputeNote,
        outdated: outdatedNote != null,
        outdatedNote: locked || outdatedNote == null || outdatedNote.isEmpty
            ? null
            : outdatedNote,
        locked: locked,
        licence: licence,
        questionId: questionId,
        materialsVersion: materials.materialsVersion,
        legalStateAsOf: materials.legalStateAsOf,
      );
    });

/// One section of a summary as the user may see it.
class SectionView {
  const SectionView({
    required this.section,
    required this.refs,
    required this.locked,
    required this.questionIds,
  });

  final SummarySection section;
  final List<String> refs;
  final bool locked;

  /// Questions of the licence covered by the section ("questions of this
  /// topic"), in the order of its keys.
  final List<String> questionIds;
}

class TopicSummaryView {
  const TopicSummaryView({required this.topic, required this.sections});

  final MaterialsTopic topic;
  final List<SectionView> sections;
}

/// The study notes of a subject for one licence.
class SummariesView {
  const SummariesView({
    required this.subject,
    required this.licence,
    required this.topics,
    required this.materialsVersion,
    required this.legalStateAsOf,
  });

  final SubjectId subject;
  final Licence licence;

  /// Topics that have at least one section.
  final List<TopicSummaryView> topics;
  final String materialsVersion;
  final DateTime? legalStateAsOf;

  TopicSummaryView? topic(String id) {
    for (final t in topics) {
      if (t.topic.id == id) return t;
    }
    return null;
  }
}

/// The summaries of a subject for a licence; `null` when there are no
/// materials (no asset, broken asset or nothing published yet).
final summariesProvider =
    FutureProvider.family<SummariesView?, (Licence, SubjectId)>((
      ref,
      arg,
    ) async {
      final (licence, subject) = arg;
      final materials = await ref.watch(materialsProvider(subject).future);
      if (materials == null) return null;
      final isPremium = ref.watch(isPremiumProvider);
      final topics = <TopicSummaryView>[
        for (final t in materials.topics)
          if (t.sections.isNotEmpty)
            TopicSummaryView(
              topic: t,
              sections: [
                for (var i = 0; i < t.sections.length; i++)
                  SectionView(
                    section: t.sections[i],
                    refs: [
                      for (final r in t.sections[i].refs) materials.refLabel(r),
                    ],
                    locked: !AccessPolicy.canSeeSummarySection(isPremium, i),
                    questionIds: {
                      for (final k in t.sections[i].questionKeys)
                        ...materials.questionIdsOf(licence, k),
                    }.toList(),
                  ),
              ],
            ),
      ];
      if (topics.isEmpty) return null;
      return SummariesView(
        subject: subject,
        licence: licence,
        topics: topics,
        materialsVersion: materials.materialsVersion,
        legalStateAsOf: materials.legalStateAsOf,
      );
    });
