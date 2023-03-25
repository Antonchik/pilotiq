import 'package:flutter/material.dart';
import 'package:pilotiq/src/models.dart';
import 'package:pilotiq/src/topics/topic_screen.dart';

class TopicItem extends StatelessWidget {
  final Topic topic;

  const TopicItem({super.key, required this.topic});

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: topic.id,
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 2.0,
        shadowColor: Theme.of(context).primaryColorLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (BuildContext context) => TopicScreen(topic: topic),
              ),
            );
          },
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                child: SizedBox(
                  child: Image.asset(
                    'assets/covers/${topic.img}',
                    fit: BoxFit.fitHeight,
                  ),
                ),
              ),
              Flexible(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.only(left: 10, right: 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      topic.title,
                      style: const TextStyle(
                        height: 1.2,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                      overflow: TextOverflow.fade,
                      softWrap: true,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
