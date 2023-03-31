import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pilotiq/src/home/home.dart';

final curExamNameProvider = StateProvider((ref) => ExamType.ppla.name);
