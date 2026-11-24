import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pilotiq/src/domain/catalog.dart';
import 'package:pilotiq/src/materials/materials_models.dart';

/// Subjects that ship a materials asset. Known statically, so that the UI can
/// offer the study notes without loading anything.
const Set<SubjectId> materialsSubjects = {SubjectId.airLaw};

/// Path of the materials asset of [subject].
String materialsAssetPath(SubjectId subject) =>
    'assets/materials/${subject.id}.json';

/// Parses the JSON text of a materials asset. Top-level so that it can run in
/// a background isolate.
SubjectMaterials parseMaterials(String jsonText, {SubjectId? subject}) =>
    SubjectMaterials.fromJson(jsonDecode(jsonText), expected: subject);

class _ParseRequest {
  const _ParseRequest(this.json, this.subject);

  final String json;
  final SubjectId subject;
}

SubjectMaterials _parseRequest(_ParseRequest r) =>
    parseMaterials(r.json, subject: r.subject);

/// Below this size the asset is parsed on the calling isolate: starting an
/// isolate costs more than parsing a small file.
const int materialsBackgroundParseBytes = 64 * 1024;

/// Parses an asset off the UI thread (small assets in place).
Future<SubjectMaterials> parseMaterialsInBackground(
  String json,
  SubjectId subject,
) async => json.length < materialsBackgroundParseBytes
    ? parseMaterials(json, subject: subject)
    : compute(_parseRequest, _ParseRequest(json, subject));

typedef MaterialsParser = Future<SubjectMaterials> Function(
  String json,
  SubjectId subject,
);

/// Loads the materials of a subject lazily (on the first explanation shown or
/// when the study notes open, never at start-up) and keeps them in memory.
///
/// A missing or broken asset gives `null` ("no materials"): it is logged and
/// never breaks the screen that asked.
class MaterialsRepository {
  MaterialsRepository({
    AssetBundle? bundle,
    MaterialsParser? parser,
    void Function(String message)? log,
  }) : _bundle = bundle ?? rootBundle,
       _parser = parser ?? parseMaterialsInBackground,
       _log = log ?? ((m) => debugPrint(m));

  final AssetBundle _bundle;
  final MaterialsParser _parser;
  final void Function(String message) _log;
  final Map<SubjectId, Future<SubjectMaterials?>> _cache = {};

  /// The materials of [subject]; the first call reads the asset, later calls
  /// (also while it is being read) share the result.
  Future<SubjectMaterials?> load(SubjectId subject) {
    if (!materialsSubjects.contains(subject)) return Future.value();
    return _cache.putIfAbsent(subject, () => _read(subject));
  }

  Future<SubjectMaterials?> _read(SubjectId subject) async {
    final path = materialsAssetPath(subject);
    try {
      final json = await _bundle.loadString(path, cache: false);
      final materials = await _parser(json, subject);
      for (final w in materials.warnings) {
        _log('materials: $path: $w');
      }
      return materials;
    } on Object catch (e) {
      _log('materials: $path not available ($e)');
      return null;
    }
  }
}
