import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ulc_exam_simulator/src/repo/repo.dart';
import 'package:ulc_exam_simulator/src/shared/bottom_nav.dart';
import 'package:ulc_exam_simulator/src/topics/topic_item_widget.dart';
import 'package:ulc_exam_simulator/src/topics/topic_model.dart';

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
                  img: 'flutter.png',
                  questions: airLawQuestions),
              Topic(
                id: '2',
                title: local.communicationsTopicTitle,
                description: local.communicationsTopicTooltip,
                img: 'flutter.png',
                questions: communicationsQuestions,
              ),
              Topic(
                id: '3',
                title: local.meteorologyTopicTitle,
                description: local.meteorologyTopicTooltip,
                img: 'flutter.png',
                questions: meteorologyQuestions,
              ),
              Topic(
                id: '4',
                title: local.navigationTopicTitle,
                description: local.navigationTopicTooltip,
                img: 'flutter.png',
                questions: navigationQuestions,
              ),
              Topic(
                id: '5',
                title: local.performanceTopicTitle,
                description: local.performanceTopicTooltip,
                img: 'flutter.png',
                questions: performanceQuestions,
              ),
              Topic(
                id: '6',
                title: local.generalKnowledgeTopicTitle,
                description: local.generalKnowledgeTopicTooltip,
                img: 'flutter.png',
                questions: generalKnowledgeQuestions,
              ),
              Topic(
                id: '7',
                title: local.humanPerformanceTopicTitle,
                description: local.humanPerformanceTopicTooltip,
                img: 'flutter.png',
                questions: humanQuestions,
              ),
              Topic(
                id: '8',
                title: local.operationalProcedureTopicTitle,
                description: local.operationalProcedureTopicTooltip,
                img: 'flutter.png',
                questions: opsProceduresQuestions,
              ),
              Topic(
                id: '9',
                title: local.principlesOfFlightTopicTitle,
                description: local.principlesOfFlightTopicTooltip,
                img: 'flutter.png',
                questions: flightPrinciplesQuestions,
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
