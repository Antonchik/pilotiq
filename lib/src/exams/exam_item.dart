import 'package:flutter/material.dart';
import 'package:pilotiq/src/models.dart';
import 'package:pilotiq/src/topics/topic_list_screen.dart';

class ExamItem extends StatelessWidget {
  final Exam exam;

  const ExamItem({super.key, required this.exam});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 5.0,
      shadowColor: Theme.of(context).primaryColorLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (BuildContext context) => TopicListScreen(exam: exam),
            ),
          );
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          // mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              // flex: 2,
              child: SizedBox(
                child: Image.asset(
                  'assets/covers/${exam.img}',
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
                    exam.title,
                    style: const TextStyle(
                      height: 1.5,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
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
    );
  }
}
