import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:pilotiq/src/hive_box_provider.dart';
import 'package:pilotiq/src/models.dart';
import 'package:pilotiq/src/subjects/subject_list_screen.dart';

class ExamItem extends ConsumerWidget {
  final Exam exam;

  const ExamItem({super.key, required this.exam});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      key: Key('exam_${exam.type.name}'),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: InkWell(
        onTap: () async {
          final navigator = Navigator.of(context);
          ref.read(curExamNameProvider.notifier).state = exam.type.name;
          await Hive.openBox<dynamic>(exam.type.name);
          navigator.push(
            MaterialPageRoute(
              builder: (BuildContext context) => SubjectListScreen(exam: exam),
            ),
          );
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              // flex: 2,
              child: SizedBox(
                child: Hero(
                  tag: exam.img,
                  child: Image.asset(
                    'assets/covers/${exam.img}',
                    fit: BoxFit.fitHeight,
                  ),
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
