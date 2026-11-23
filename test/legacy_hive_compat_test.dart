// Verifies that boxes written by the legacy app (hive 2.x, app version 1.2.0)
// can be read by hive_ce. The binary fixtures live in test/fixtures/legacy_hive.
//
// How to re-create the fixtures (needs the OLD toolchain, Dart 2.19 with
// `hive: ^2.2.3` in a scratch pubspec):
//
//   Hive.init(dir);
//   (await Hive.openBox('config')).put('dark', true);
//   final ppla = await Hive.openBox('ppla');
//   ppla.put('air_law', 57);
//   ppla.put('air_law_positive', 2);
//   ppla.put('air_law_negative', 1);
//   final pplh = await Hive.openBox('pplh');
//   pplh.put('meteorology', 5);
//   pplh.put('meteorology_negative', 1);
//   (await Hive.openBox('plg')).put('', 3);
//   await Hive.close();
//
// then copy the resulting *.hive files into test/fixtures/legacy_hive/.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('legacy_hive_test_');
    final fixtures = Directory('test/fixtures/legacy_hive');
    for (final file in fixtures.listSync().whereType<File>()) {
      if (file.path.endsWith('.hive')) {
        await file.copy('${tmp.path}/${file.uri.pathSegments.last}');
      }
    }
    Hive.init(tmp.path);
  });

  tearDown(() async {
    await Hive.close();
    await tmp.delete(recursive: true);
  });

  test('config box keeps the dark flag', () async {
    final box = await Hive.openBox<dynamic>('config');
    expect(box.keys.toSet(), {'dark'});
    expect(box.get('dark'), true);
  });

  test('ppla box keeps position and counters', () async {
    final box = await Hive.openBox<dynamic>('ppla');
    expect(box.toMap(), {
      'air_law': 57,
      'air_law_positive': 2,
      'air_law_negative': 1,
    });
  });

  test('pplh box keeps position and negative counter', () async {
    final box = await Hive.openBox<dynamic>('pplh');
    expect(box.toMap(), {'meteorology': 5, 'meteorology_negative': 1});
  });

  test('plg box keeps the legacy empty-string key', () async {
    final box = await Hive.openBox<dynamic>('plg');
    expect(box.toMap(), {'': 3});
  });
}
