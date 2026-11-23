import 'dart:typed_data';

import 'package:hive_ce/hive.dart';
import 'package:pilotiq/src/progress/progress_repository.dart';

/// Opens a box that lives in memory only. Widget tests run in a fake-async
/// zone where real file writes of Hive cannot complete, so they keep all
/// boxes in memory.
Future<Box<dynamic>> openMemoryBox(String name) =>
    Hive.openBox<dynamic>(name, bytes: Uint8List(0));

/// A repository whose boxes are all in memory (see [openMemoryBox]).
ProgressRepository memoryProgressRepository() =>
    ProgressRepository(openBox: openMemoryBox);
