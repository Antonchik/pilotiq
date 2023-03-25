import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pilotiq/src/models.dart';
import 'package:pilotiq/src/repo/repo.dart';
import 'package:pilotiq/src/topics/topic_item_widget.dart';

class ExamBuilder extends ConsumerWidget {
  const ExamBuilder({
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
          final topics = [
            Topic(
                id: 'air_law',
                title: local.airLawTopicTitle,
                description: local.airLawTopicTooltip,
                img: 'air_law.png',
                quizLength: 28,
                examTime: 45,
                questions: questions['airLaw']!),
            Topic(
              id: 'communications',
              title: local.communicationsTopicTitle,
              description: local.communicationsTopicTooltip,
              img: 'communications.png',
              quizLength: 12,
              examTime: 30,
              questions: questions['communications']!,
            ),
            Topic(
              id: 'meteorology',
              title: local.meteorologyTopicTitle,
              description: local.meteorologyTopicTooltip,
              img: 'meteorology.png',
              quizLength: 12,
              examTime: 30,
              questions: questions['meteorology']!,
            ),
            Topic(
              id: 'navigation',
              title: local.navigationTopicTitle,
              description: local.navigationTopicTooltip,
              img: 'navigation.png',
              quizLength: 24,
              examTime: 60,
              questions: questions['navigation']!,
            ),
            Topic(
              id: 'performance_and_planning',
              title: local.performanceTopicTitle,
              description: local.performanceTopicTooltip,
              img: 'performance_and_planning.png',
              quizLength: 20,
              examTime: 60,
              questions: questions['flightPerformance']!,
            ),
            Topic(
              id: 'aircraft_general_knowledge',
              title: local.generalKnowledgeTopicTitle,
              description: local.generalKnowledgeTopicTooltip,
              img: 'aircraft_general_knowledge.png',
              quizLength: 16,
              examTime: 30,
              questions: questions['generalKnowledge']!,
            ),
            Topic(
              id: 'human_performance',
              title: local.humanPerformanceTopicTitle,
              description: local.humanPerformanceTopicTooltip,
              img: 'human_performance.png',
              quizLength: 12,
              examTime: 30,
              questions: questions['humanPerformance']!,
            ),
            Topic(
              id: 'principles_of_flight',
              title: local.principlesOfFlightTopicTitle,
              description: local.principlesOfFlightTopicTooltip,
              img: 'principles_of_flight.png',
              quizLength: 16,
              examTime: 45,
              questions: questions['principlesOfFlight']!,
            ),
            Topic(
              id: 'operational_procedures',
              title: local.operationalProcedureTopicTitle,
              description: local.operationalProcedureTopicTooltip,
              img: 'operational_procedures.png',
              quizLength: 12,
              examTime: 30,
              questions: questions['operationalProcedures']!,
            ),
          ];
          return ListView.builder(
            itemCount: topics.length,
            itemBuilder: (BuildContext context, int index) {
              return SizedBox(
                height: 90,
                child: TopicItem(topic: topics[index]),
              );
            },
          );
          // return GridView.count(
          //   primary: false,
          //   padding: const EdgeInsets.all(20.0),
          //   crossAxisSpacing: 10.0,
          //   crossAxisCount: 2,
          //   children: topics.map((topic) => TopicItem(topic: topic)).toList(),
          // );
        } else {
          return const Center(child: CircularProgressIndicator());
        }
      },
    );
  }
}
