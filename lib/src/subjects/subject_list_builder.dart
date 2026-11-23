import 'package:flutter/material.dart';
import 'package:pilotiq/src/localization/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pilotiq/src/domain/catalog.dart';
import 'package:pilotiq/src/models.dart';
import 'package:pilotiq/src/repo/repo.dart';
import 'package:pilotiq/src/subjects/subject_item_widget.dart';

class SubjectListBuilder extends ConsumerWidget {
  const SubjectListBuilder({
    super.key,
    this.isHelicopter = false,
    this.isEnglish = false,
    this.isGlider = false,
    this.isBalloon = false,
  });

  final bool isEnglish;
  final bool isHelicopter;
  final bool isGlider;
  final bool isBalloon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final local = AppLocalizations.of(context)!;
    final future = ref.read(questionRepositoryProvider).getPPLQuestions(
          isHelicopter: isHelicopter,
          isEnglish: isEnglish,
          isGlider: isGlider,
          isBalloon: isBalloon,
        );
    return FutureBuilder(
      future: future,
      builder: (BuildContext context,
          AsyncSnapshot<Map<String, List<Question>>> snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          final questions = snapshot.data!;
          final subjects = [
            for (final id in SubjectId.values)
              if (questions[_repoKeys[id]]?.isNotEmpty ?? false)
                _buildSubject(id, local, questions[_repoKeys[id]]!),
          ];
          final isPortrait =
              MediaQuery.of(context).orientation == Orientation.portrait;
          return isPortrait
              ? ListView.builder(
                  shrinkWrap: true,
                  itemCount: subjects.length,
                  itemBuilder: (BuildContext context, int index) {
                    return SizedBox(
                      height: 90,
                      child: SubjectItem(subject: subjects[index]),
                    );
                  },
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: (subjects.length * 0.5).ceil(),
                  itemBuilder: (context, index) => Row(
                    children: [
                      Flexible(
                        child: SizedBox(
                            height: 90,
                            child: SubjectItem(subject: subjects[index * 2])),
                      ),
                      Flexible(
                        child: SizedBox(
                            height: 90,
                            child: index * 2 + 1 < subjects.length
                                ? SubjectItem(subject: subjects[index * 2 + 1])
                                : const SizedBox.expand()),
                      ),
                    ],
                  ),
                );
        } else {
          return const Center(child: CircularProgressIndicator());
        }
      },
    );
  }
}

/// Keys under which [QuestionRepository] groups the questions of a subject.
const _repoKeys = {
  SubjectId.airLaw: 'airLaw',
  SubjectId.communications: 'communications',
  SubjectId.meteorology: 'meteorology',
  SubjectId.navigation: 'navigation',
  SubjectId.performanceAndPlanning: 'flightPerformance',
  SubjectId.aircraftGeneralKnowledge: 'generalKnowledge',
  SubjectId.humanPerformance: 'humanPerformance',
  SubjectId.principlesOfFlight: 'principlesOfFlight',
  SubjectId.operationalProcedures: 'operationalProcedures',
};

Subject _buildSubject(
  SubjectId id,
  AppLocalizations local,
  List<Question> questions,
) {
  final (title, description) = switch (id) {
    SubjectId.airLaw => (local.airLawSubjectTitle, local.airLawSubjectTooltip),
    SubjectId.communications => (
        local.communicationsSubjectTitle,
        local.communicationsSubjectTooltip
      ),
    SubjectId.meteorology => (
        local.meteorologySubjectTitle,
        local.meteorologySubjectTooltip
      ),
    SubjectId.navigation => (
        local.navigationSubjectTitle,
        local.navigationSubjectTooltip
      ),
    SubjectId.performanceAndPlanning => (
        local.performanceSubjectTitle,
        local.performanceSubjectTooltip
      ),
    SubjectId.aircraftGeneralKnowledge => (
        local.generalKnowledgeSubjectTitle,
        local.generalKnowledgeSubjectTooltip
      ),
    SubjectId.humanPerformance => (
        local.humanPerformanceSubjectTitle,
        local.humanPerformanceSubjectTooltip
      ),
    SubjectId.principlesOfFlight => (
        local.principlesOfFlightSubjectTitle,
        local.principlesOfFlightSubjectTooltip
      ),
    SubjectId.operationalProcedures => (
        local.operationalProcedureSubjectTitle,
        local.operationalProcedureSubjectTooltip
      ),
  };
  final spec = ExamSpec.forSubject(id);
  return Subject(
    id: id.id,
    title: title,
    description: description,
    img: '${id.id}.png',
    quizLength: spec.quizLength,
    examTime: spec.minutes,
    questions: questions,
  );
}
