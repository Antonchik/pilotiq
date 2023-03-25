import 'package:flutter/material.dart';
import 'package:pilotiq/src/models.dart';
import 'package:pilotiq/src/quiz/quiz_list.dart';

class TopicScreen extends StatelessWidget {
  final Topic topic;

  const TopicScreen({super.key, required this.topic});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(topic.title),
        centerTitle: true,
      ),
      body: ListView(children: [
        Hero(
          tag: topic.id,
          child: Image.asset(
            'assets/covers/${topic.img}',
            height: 150,
            width: MediaQuery.of(context).size.width,
          ),
        ),
        // Padding(
        //   padding: const EdgeInsets.only(left: 8),
        //   child: Text(topic.title,
        //       style: const TextStyle(
        //           height: 2,
        //           fontSize: 24,
        //           fontWeight: FontWeight.bold,
        //           overflow: TextOverflow.fade)),
        // ),
        QuizList(topic: topic),
      ]),
    );
  }
}
