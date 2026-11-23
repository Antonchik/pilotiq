// Builds lib/src/localization/app_{en,pl}.arb from the fragments in
// lib/src/localization/fragments/<feature>_{en,pl}.arb.
//
// Usage (from the repository root or anywhere):
//   dart run tool/l10n/merge_arb.dart          write app_en.arb / app_pl.arb
//   dart run tool/l10n/merge_arb.dart --check  exit 1 if the files are stale
//
// Fragments are merged in file-name order, keys keep their order inside a
// fragment. A key (or "@key" metadata entry) defined twice is an error.
import 'dart:convert';
import 'dart:io';

const _languages = ['en', 'pl'];

/// Result of a merge run; [exitCode] 0 means success.
class MergeResult {
  MergeResult(this.exitCode, this.messages);

  final int exitCode;
  final List<String> messages;
}

/// Merges fragments below [root] (the repository root). With [check] set
/// nothing is written and stale outputs are reported as failure.
MergeResult mergeArb(Directory root, {bool check = false}) {
  final messages = <String>[];
  final l10nDir = Directory('${root.path}/lib/src/localization');
  final fragmentsDir = Directory('${l10nDir.path}/fragments');
  if (!fragmentsDir.existsSync()) {
    return MergeResult(1, ['Missing directory: ${fragmentsDir.path}']);
  }
  var failed = false;
  for (final lang in _languages) {
    final files = fragmentsDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('_$lang.arb'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    final merged = <String, Object?>{};
    final origin = <String, String>{};
    for (final file in files) {
      final name = file.uri.pathSegments.last;
      final Object? decoded;
      try {
        decoded = jsonDecode(file.readAsStringSync());
      } on FormatException catch (e) {
        messages.add('$name: invalid JSON (${e.message})');
        failed = true;
        continue;
      }
      if (decoded is! Map<String, dynamic>) {
        messages.add('$name: top level must be a JSON object');
        failed = true;
        continue;
      }
      for (final entry in decoded.entries) {
        if (merged.containsKey(entry.key)) {
          messages.add(
              'Duplicate key "${entry.key}" in $name (already in ${origin[entry.key]})');
          failed = true;
          continue;
        }
        merged[entry.key] = entry.value;
        origin[entry.key] = name;
      }
    }
    final content =
        '${const JsonEncoder.withIndent('  ').convert(merged)}\n';
    final target = File('${l10nDir.path}/app_$lang.arb');
    if (check) {
      final current = target.existsSync() ? target.readAsStringSync() : null;
      if (current != content) {
        messages.add('${target.path} is out of date; '
            'run: dart run tool/l10n/merge_arb.dart');
        failed = true;
      }
    } else if (!failed) {
      target.writeAsStringSync(content);
      messages.add('Wrote ${target.path} (${merged.length} entries)');
    }
  }
  return MergeResult(failed ? 1 : 0, messages);
}

void main(List<String> args) {
  final check = args.contains('--check');
  final unknown = args.where((a) => a != '--check').toList();
  if (unknown.isNotEmpty) {
    stderr.writeln('Unknown arguments: ${unknown.join(' ')}');
    exitCode = 64;
    return;
  }
  final root = File.fromUri(Platform.script).parent.parent.parent;
  final result = mergeArb(root, check: check);
  for (final message in result.messages) {
    (result.exitCode == 0 ? stdout : stderr).writeln(message);
  }
  if (check && result.exitCode == 0) stdout.writeln('ARB files are up to date.');
  exitCode = result.exitCode;
}
