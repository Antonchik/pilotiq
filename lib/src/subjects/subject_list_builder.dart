import 'package:flutter/material.dart';
import 'package:pilotiq/src/localization/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pilotiq/src/models.dart';
import 'package:pilotiq/src/repo/repo.dart';
import 'package:pilotiq/src/subjects/subject_item_widget.dart';

class SubjectListBuilder extends ConsumerWidget {
  const SubjectListBuilder({
    Key? key,
    this.isHelicopter = false,
    this.isEnglish = false,
    this.isGlider = false,
    this.isBalloon = false,
  }) : super(key: key);

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
            Subject(
                id: 'air_law',
                title: local.airLawSubjectTitle,
                description: local.airLawSubjectTooltip,
                img: 'air_law.png',
                quizLength: 28,
                examTime: 45,
                questions: questions['airLaw']!),
            Subject(
              id: 'communications',
              title: local.communicationsSubjectTitle,
              description: local.communicationsSubjectTooltip,
              img: 'communications.png',
              quizLength: 12,
              examTime: 30,
              questions: questions['communications']!,
            ),
            Subject(
              id: 'meteorology',
              title: local.meteorologySubjectTitle,
              description: local.meteorologySubjectTooltip,
              img: 'meteorology.png',
              quizLength: 12,
              examTime: 30,
              questions: questions['meteorology']!,
            ),
            Subject(
              id: 'navigation',
              title: local.navigationSubjectTitle,
              description: local.navigationSubjectTooltip,
              img: 'navigation.png',
              quizLength: 24,
              examTime: 60,
              questions: questions['navigation']!,
            ),
            Subject(
              id: 'performance_and_planning',
              title: local.performanceSubjectTitle,
              description: local.performanceSubjectTooltip,
              img: 'performance_and_planning.png',
              quizLength: 20,
              examTime: 60,
              questions: questions['flightPerformance']!,
            ),
            Subject(
              id: 'aircraft_general_knowledge',
              title: local.generalKnowledgeSubjectTitle,
              description: local.generalKnowledgeSubjectTooltip,
              img: 'aircraft_general_knowledge.png',
              quizLength: 16,
              examTime: 30,
              questions: questions['generalKnowledge']!,
            ),
            Subject(
              id: 'human_performance',
              title: local.humanPerformanceSubjectTitle,
              description: local.humanPerformanceSubjectTooltip,
              img: 'human_performance.png',
              quizLength: 12,
              examTime: 30,
              questions: questions['humanPerformance']!,
            ),
            Subject(
              id: 'principles_of_flight',
              title: local.principlesOfFlightSubjectTitle,
              description: local.principlesOfFlightSubjectTooltip,
              img: 'principles_of_flight.png',
              quizLength: 16,
              examTime: 45,
              questions: questions['principlesOfFlight']!,
            ),
            Subject(
              id: 'operational_procedures',
              title: local.operationalProcedureSubjectTitle,
              description: local.operationalProcedureSubjectTooltip,
              img: 'operational_procedures.png',
              quizLength: 12,
              examTime: 30,
              questions: questions['operationalProcedures']!,
            ),
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
