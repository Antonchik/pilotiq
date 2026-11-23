import 'dart:io';

import 'package:hive_ce/hive.dart';

/// Creates a temp dir and points Hive at it.
Future<Directory> initTempHive() async {
  final dir = await Directory.systemTemp.createTemp('pilotiq_progress_');
  Hive.init(dir.path);
  return dir;
}

Future<void> disposeTempHive(Directory dir) async {
  await Hive.close();
  if (dir.existsSync()) await dir.delete(recursive: true);
}
