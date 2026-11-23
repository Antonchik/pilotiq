import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/l10n/merge_arb.dart';

Map<String, dynamic> _readArb(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

Map<String, String> _messages(Map<String, dynamic> arb) => {
  for (final e in arb.entries)
    if (!e.key.startsWith('@')) e.key: e.value as String,
};

/// Names of the placeholders of a message: `{name}` and the argument of an ICU
/// form such as `{count, plural, one{{count} item} other{{count} items}}`. A
/// brace right after a word or `=` opens an ICU branch, not a placeholder.
Set<String> _placeholders(String message) =>
    RegExp(r'(?<![\w=])\{(\w+)\s*[,}]')
        .allMatches(message)
        .map((m) => m.group(1)!)
        .toSet();

void main() {
  const dir = 'lib/src/localization';

  test('placeholder extraction understands plain and ICU forms', () {
    expect(_placeholders('Hello {name}, {date}'), {'name', 'date'});
    expect(
      _placeholders(
        '{count, plural, one{{count} item} other{{count} items}} for {user}',
      ),
      {'count', 'user'},
    );
    expect(_placeholders('{n, plural, =0{none} one{{n} item} other{many}}'), {
      'n',
    });
    expect(_placeholders('no placeholders'), isEmpty);
  });

  test('EN and PL contain the same message keys', () {
    final en = _messages(_readArb('$dir/app_en.arb'));
    final pl = _messages(_readArb('$dir/app_pl.arb'));
    expect(
      pl.keys.toSet().difference(en.keys.toSet()),
      isEmpty,
      reason: 'keys only in PL',
    );
    expect(
      en.keys.toSet().difference(pl.keys.toSet()),
      isEmpty,
      reason: 'keys only in EN',
    );
  });

  test('EN and PL use the same placeholders', () {
    final en = _messages(_readArb('$dir/app_en.arb'));
    final pl = _messages(_readArb('$dir/app_pl.arb'));
    for (final key in en.keys) {
      expect(
        _placeholders(pl[key]!),
        _placeholders(en[key]!),
        reason: 'placeholders of "$key"',
      );
    }
  });

  test('every fragment has an EN and a PL counterpart with equal keys', () {
    final fragments = Directory('$dir/fragments')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.arb'))
        .map((f) => f.uri.pathSegments.last)
        .toList();
    final features = {
      for (final name in fragments)
        name.replaceFirst(RegExp(r'_(en|pl)\.arb$'), ''),
    };
    expect(features, isNotEmpty);
    for (final feature in features) {
      final en = File('$dir/fragments/${feature}_en.arb');
      final pl = File('$dir/fragments/${feature}_pl.arb');
      expect(
        en.existsSync() && pl.existsSync(),
        isTrue,
        reason: 'fragment pair for "$feature"',
      );
      expect(
        _messages(_readArb(pl.path)).keys.toSet(),
        _messages(_readArb(en.path)).keys.toSet(),
        reason: 'keys of fragment "$feature"',
      );
    }
  });

  test('merge_arb --check reports generated files as up to date', () {
    final result = mergeArb(Directory.current, check: true);
    expect(result.messages, isEmpty);
    expect(result.exitCode, 0);
  });

  test('merge_arb --check fails when a generated file is stale', () {
    final tmp = Directory.systemTemp.createTempSync('arb_test_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    Directory('${tmp.path}/lib/src/localization/fragments')
        .createSync(recursive: true);
    File('${tmp.path}/lib/src/localization/fragments/a_en.arb')
        .writeAsStringSync('{"hello": "Hello"}');
    File('${tmp.path}/lib/src/localization/fragments/a_pl.arb')
        .writeAsStringSync('{"hello": "Cześć"}');
    expect(mergeArb(tmp, check: true).exitCode, 1);
    expect(mergeArb(tmp).exitCode, 0);
    expect(mergeArb(tmp, check: true).exitCode, 0);
  });

  test('merge_arb rejects a key defined in two fragments', () {
    final tmp = Directory.systemTemp.createTempSync('arb_test_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    Directory('${tmp.path}/lib/src/localization/fragments')
        .createSync(recursive: true);
    for (final lang in ['en', 'pl']) {
      File('${tmp.path}/lib/src/localization/fragments/a_$lang.arb')
          .writeAsStringSync('{"dup": "x"}');
      File('${tmp.path}/lib/src/localization/fragments/b_$lang.arb')
          .writeAsStringSync('{"dup": "y"}');
    }
    final result = mergeArb(tmp);
    expect(result.exitCode, 1);
    expect(result.messages.join('\n'), contains('Duplicate key "dup"'));
  });

  test('merge_arb writes nothing when one language has an error', () {
    final tmp = Directory.systemTemp.createTempSync('arb_test_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    Directory('${tmp.path}/lib/src/localization/fragments')
        .createSync(recursive: true);
    File('${tmp.path}/lib/src/localization/fragments/a_en.arb')
        .writeAsStringSync('{"hello": "Hello"}');
    // The Polish side is invalid; the English side alone would be fine.
    File('${tmp.path}/lib/src/localization/fragments/a_pl.arb')
        .writeAsStringSync('{"hello": ');
    final result = mergeArb(tmp);
    expect(result.exitCode, 1);
    expect(
      File('${tmp.path}/lib/src/localization/app_en.arb').existsSync(),
      isFalse,
    );
    expect(
      File('${tmp.path}/lib/src/localization/app_pl.arb').existsSync(),
      isFalse,
    );
  });
}
