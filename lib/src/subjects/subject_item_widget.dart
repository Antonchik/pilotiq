import 'package:flutter/material.dart';
import 'package:pilotiq/src/models.dart';
import 'package:pilotiq/src/subjects/subject_screen.dart';

class SubjectItem extends StatelessWidget {
  final Subject subject;

  const SubjectItem({super.key, required this.subject});

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: subject.id,
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
                builder: (BuildContext context) =>
                    SubjectScreen(subject: subject),
              ),
            );
          },
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                child: SizedBox(
                  child: Image.asset(
                    'assets/covers/${subject.img}',
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
                      subject.title,
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
