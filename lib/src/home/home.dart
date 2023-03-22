import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pilotiq/src/home/bottom_nav.dart';
import 'package:pilotiq/src/models.dart';
import 'package:pilotiq/src/repo/repo.dart';
import 'package:pilotiq/src/settings/language_button.dart';
import 'package:pilotiq/src/topics/topic_item_widget.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(local.topicsTitle),
        actions: const [
          LanguageButton(),
        ],
      ),
      body: const PPLAExamBuilder(),
      bottomNavigationBar: const BottomNavBar(),
    );
  }
}

class PPLAExamBuilder extends ConsumerWidget {
  const PPLAExamBuilder({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final local = AppLocalizations.of(context)!;
    return FutureBuilder(
      future: ref.read(questionRepositoryProvider).getPPLAQuestions(),
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
                questions: questions['airLaw']!),
            Topic(
              id: 'communications',
              title: local.communicationsTopicTitle,
              description: local.communicationsTopicTooltip,
              img: 'communications.png',
              questions: questions['communications']!,
            ),
            Topic(
              id: 'meteorology',
              title: local.meteorologyTopicTitle,
              description: local.meteorologyTopicTooltip,
              img: 'meteorology.png',
              questions: questions['meteorology']!,
            ),
            Topic(
              id: 'navigation',
              title: local.navigationTopicTitle,
              description: local.navigationTopicTooltip,
              img: 'navigation.png',
              questions: questions['navigation']!,
            ),
            Topic(
              id: 'performance_and_planning',
              title: local.performanceTopicTitle,
              description: local.performanceTopicTooltip,
              img: 'performance_and_planning.png',
              questions: questions['flightPerformance']!,
            ),
            Topic(
              id: 'aircraft_general_knowledge',
              title: local.generalKnowledgeTopicTitle,
              description: local.generalKnowledgeTopicTooltip,
              img: 'aircraft_general_knowledge.png',
              questions: questions['generalKnowledge']!,
            ),
            Topic(
              id: 'human_performance',
              title: local.humanPerformanceTopicTitle,
              description: local.humanPerformanceTopicTooltip,
              img: 'human_performance.png',
              quizLength: 28,
              quizTime: 45,
              questions: questions['humanPerformance']!,
            ),
            Topic(
              id: 'principles_of_flight',
              title: local.principlesOfFlightTopicTitle,
              description: local.principlesOfFlightTopicTooltip,
              img: 'principles_of_flight.png',
              questions: questions['principlesOfFlight']!,
            ),
            Topic(
              id: 'operational_procedures',
              title: local.operationalProcedureTopicTitle,
              description: local.operationalProcedureTopicTooltip,
              img: 'operational_procedures.png',
              questions: questions['operationalProcedures']!,
            ),
          ];
          return GridView.count(
            primary: false,
            padding: const EdgeInsets.all(20.0),
            crossAxisSpacing: 10.0,
            crossAxisCount: 2,
            children: topics.map((topic) => TopicItem(topic: topic)).toList(),
          );
        } else {
          return const Center(child: CircularProgressIndicator());
        }
      },
    );
  }
}
