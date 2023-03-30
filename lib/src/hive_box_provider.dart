import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pilotiq/src/home/home.dart';

final examBoxProvider = StateProvider((ref) => Hive.box(ExamType.ppla.name));
