import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pilotiq/src/shared/bottom_nav.dart';
import 'package:pilotiq/src/topics/topic_model.dart';
import 'package:pilotiq/src/repo/repo.dart';
import 'package:pilotiq/src/topics/topic_item_widget.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final local = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(local.topicsTitle),
      ),
      body: FutureBuilder(
        future: ref.read(questionRepositoryProvider).getQuestions(),
        builder: (BuildContext context,
            AsyncSnapshot<Map<String, List<Question>>> snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            final questions = snapshot.data!;
            final airLawQuestions = questions['airLaw']!;
            final communicationsQuestions = questions['communications']!;
            final meteorologyQuestions = questions['meteorology']!;
            final navigationQuestions = questions['navigation']!;
            final performanceQuestions = questions['flightPerformance']!;
            final generalKnowledgeQuestions = questions['generalKnowledge']!;
            final humanQuestions = questions['humanPerformance']!;
            final opsProceduresQuestions = questions['operationalProcedures']!;
            final flightPrinciplesQuestions = questions['principlesOfFlight']!;
            final topics = [
              Topic(
                  id: '1',
                  title: local.airLawTopicTitle,
                  description: local.airLawTopicTooltip,
                  img: 'air_law.png',
                  questions: airLawQuestions),
              Topic(
                id: '2',
                title: local.communicationsTopicTitle,
                description: local.communicationsTopicTooltip,
                img: 'communications.png',
                questions: communicationsQuestions,
              ),
              Topic(
                id: '3',
                title: local.meteorologyTopicTitle,
                description: local.meteorologyTopicTooltip,
                img: 'meteorology.png',
                questions: meteorologyQuestions,
              ),
              Topic(
                id: '4',
                title: local.navigationTopicTitle,
                description: local.navigationTopicTooltip,
                img: 'navigation.png',
                questions: navigationQuestions,
              ),
              Topic(
                id: '5',
                title: local.performanceTopicTitle,
                description: local.performanceTopicTooltip,
                img: 'flight_planning.png',
                questions: performanceQuestions,
              ),
              Topic(
                id: '6',
                title: local.generalKnowledgeTopicTitle,
                description: local.generalKnowledgeTopicTooltip,
                img: 'aircraft_knowledge.png',
                questions: generalKnowledgeQuestions,
              ),
              Topic(
                id: '7',
                title: local.humanPerformanceTopicTitle,
                description: local.humanPerformanceTopicTooltip,
                img: 'human_performance.png',
                questions: humanQuestions,
              ),
              Topic(
                id: '8',
                title: local.principlesOfFlightTopicTitle,
                description: local.principlesOfFlightTopicTooltip,
                img: 'flight_principles.png',
                questions: flightPrinciplesQuestions,
              ),
              Topic(
                id: '9',
                title: local.operationalProcedureTopicTitle,
                description: local.operationalProcedureTopicTooltip,
                img: 'operational_procedures.png',
                questions: opsProceduresQuestions,
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
      ),
      bottomNavigationBar: const BottomNavBar(),
    );
  }
}
