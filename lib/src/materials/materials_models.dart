import 'package:pilotiq/src/domain/catalog.dart';

/// Study materials of one subject as built by the `build` command of
/// `tool/materials/materials.py` into `assets/materials/<subject>.json`
/// (schema 1). Pure Dart.
///
/// Only checked records reach the asset (`verified` and `disputed`); verbatim
/// quotes of the sources are never part of it.

/// Status of a published record.
enum MaterialStatus {
  verified,
  disputed;

  static MaterialStatus? fromId(Object? id) => switch (id) {
    'verified' => MaterialStatus.verified,
    'disputed' => MaterialStatus.disputed,
    _ => null,
  };
}

/// A pointer into a source: `{"src": "PL-PRAWO-LOTNICZE", "loc": "art. 128"}`.
class MaterialRef {
  const MaterialRef({required this.src, required this.loc});

  final String src;
  final String loc;

  factory MaterialRef.fromJson(Object? json) {
    if (json is! Map || json['src'] is! String || json['loc'] is! String) {
      throw FormatException('Invalid material reference: $json');
    }
    return MaterialRef(src: json['src'] as String, loc: json['loc'] as String);
  }
}

/// A source of the register (a statute, an EU regulation, …).
class MaterialSource {
  const MaterialSource({
    required this.id,
    required this.title,
    this.version,
    this.kind,
  });

  final String id;

  /// Human readable name, e.g. "Prawo lotnicze".
  final String title;
  final String? version;
  final String? kind;
}

/// Explanation of one question (by content key `<NUMER>#<fp8>`).
class Explanation {
  const Explanation({
    required this.key,
    required this.status,
    required this.text,
    required this.refs,
    this.disputeNote,
  });

  final String key;
  final MaterialStatus status;
  final String text;
  final List<MaterialRef> refs;

  /// Why the ULC key is doubtful; set for [MaterialStatus.disputed].
  final String? disputeNote;
}

/// One section of a topic summary.
class SummarySection {
  const SummarySection({
    required this.id,
    required this.heading,
    required this.body,
    required this.refs,
    required this.questionKeys,
  });

  /// `AL03-1`; also the key of an error report.
  final String id;
  final String heading;

  /// Paragraphs; a line starting with `- ` is an item of a list.
  final List<String> body;
  final List<MaterialRef> refs;

  /// Content keys of the questions this section covers.
  final List<String> questionKeys;
}

/// A topic of the subject: its title, the order of its explanations and its
/// summary.
class MaterialsTopic {
  const MaterialsTopic({
    required this.id,
    required this.titlePl,
    required this.titleEn,
    required this.order,
    required this.sections,
  });

  final String id;
  final String titlePl;
  final String? titleEn;

  /// Keys of the explanations of the topic in teaching order.
  final List<String> order;
  final List<SummarySection> sections;

  /// Title in the UI language (`pl` or `en`); Polish when English is missing.
  String title(String languageCode) =>
      languageCode == 'en' && (titleEn?.trim().isNotEmpty ?? false)
      ? titleEn!
      : titlePl;
}

/// The whole materials asset of one subject.
class SubjectMaterials {
  SubjectMaterials({
    required this.subject,
    required this.materialsVersion,
    required this.legalStateAsOf,
    required this.sources,
    required this.topics,
    required this.explanations,
    required this.links,
    this.outdated = const {},
  });

  final SubjectId subject;

  /// sha8 of the content; part of an error report.
  final String materialsVersion;

  /// "Stan prawny na": the legal state the materials describe.
  final DateTime? legalStateAsOf;
  final Map<String, MaterialSource> sources;
  final List<MaterialsTopic> topics;
  final Map<String, Explanation> explanations;

  /// `links[licence][questionId]` is the content key of the question.
  final Map<Licence, Map<String, String>> links;

  /// Questions based on repealed norms: content key → what changed (the
  /// `basisNote`). These keys are in [links] but have no explanation and are
  /// in no topic order, so they never take a place of the free sample.
  final Map<String, String> outdated;

  /// Nothing to show (an empty pilot asset).
  bool get isEmpty =>
      explanations.isEmpty &&
      outdated.isEmpty &&
      topics.every((t) => t.sections.isEmpty);

  /// Content key of question [questionId] of [licence], if it has materials.
  String? keyOf(Licence licence, String questionId) =>
      links[licence]?[questionId];

  /// "Prawo lotnicze, art. 128 ust. 1".
  String refLabel(MaterialRef ref) =>
      '${sources[ref.src]?.title ?? ref.src}, ${ref.loc}';

  final Map<Licence, Map<String, int>> _indexCache = {};
  final Map<Licence, Map<String, List<String>>> _idsCache = {};

  /// 0-based position of [key] in its topic, counted only over the keys that
  /// have a question in the bank of [licence]; `null` when the key is in no
  /// topic or not in the licence.
  int? indexInTopic(Licence licence, String key) {
    final index = _indexCache.putIfAbsent(licence, () {
      final present = (links[licence] ?? const {}).values.toSet();
      final result = <String, int>{};
      for (final t in topics) {
        var i = 0;
        for (final k in t.order) {
          if (present.contains(k)) result[k] = i++;
        }
      }
      return result;
    });
    return index[key];
  }

  /// Question ids of [licence] linked to [key] (sorted).
  List<String> questionIdsOf(Licence licence, String key) {
    final byKey = _idsCache.putIfAbsent(licence, () {
      final result = <String, List<String>>{};
      for (final e in (links[licence] ?? const <String, String>{}).entries) {
        result.putIfAbsent(e.value, () => []).add(e.key);
      }
      for (final ids in result.values) {
        ids.sort();
      }
      return result;
    });
    return byKey[key] ?? const [];
  }

  /// Parses the decoded JSON of the asset; throws [FormatException] when it
  /// does not follow schema 1 or is for another subject.
  factory SubjectMaterials.fromJson(Object? json, {SubjectId? expected}) {
    if (json is! Map || json['schema'] != 1) {
      throw const FormatException('Unsupported materials schema');
    }
    final subject = SubjectId.fromId(json['subject'] as String?);
    if (subject == null || (expected != null && subject != expected)) {
      throw FormatException('Materials of subject ${json['subject']}');
    }
    final rawSources = json['sources'] ?? const {};
    final rawTopics = json['topics'] ?? const [];
    final rawExplanations = json['explanations'] ?? const {};
    final rawLinks = json['links'] ?? const {};
    if (rawSources is! Map ||
        rawTopics is! List ||
        rawExplanations is! Map ||
        rawLinks is! Map) {
      throw const FormatException('Malformed materials');
    }
    final sources = <String, MaterialSource>{};
    for (final e in rawSources.entries) {
      final v = e.value;
      if (e.key is! String || v is! Map || v['title'] is! String) {
        throw FormatException('Invalid source ${e.key}');
      }
      sources[e.key as String] = MaterialSource(
        id: e.key as String,
        title: v['title'] as String,
        version: v['version'] is String ? v['version'] as String : null,
        kind: v['kind'] is String ? v['kind'] as String : null,
      );
    }
    final explanations = <String, Explanation>{};
    for (final e in rawExplanations.entries) {
      final v = e.value;
      if (e.key is! String || v is! Map || v['text'] is! String) {
        throw FormatException('Invalid explanation ${e.key}');
      }
      final status = MaterialStatus.fromId(v['status']);
      // Only checked records are shown, whatever else the file contains.
      if (status == null) continue;
      final note = v['disputeNote'];
      explanations[e.key as String] = Explanation(
        key: e.key as String,
        status: status,
        text: v['text'] as String,
        refs: _refs(v['refs']),
        disputeNote: note is String && note.trim().isNotEmpty ? note : null,
      );
    }
    final topics = [for (final t in rawTopics) _topic(t)];
    final links = <Licence, Map<String, String>>{};
    for (final e in rawLinks.entries) {
      final licence = Licence.fromId(e.key as String?);
      final v = e.value;
      if (licence == null) continue;
      if (v is! Map) throw FormatException('Invalid links of ${e.key}');
      links[licence] = {
        for (final l in v.entries)
          if (l.key is String && l.value is String)
            l.key as String: l.value as String,
      };
    }
    // Optional (added to schema 1 later): older assets have no `outdated`.
    final rawOutdated = json['outdated'] ?? const {};
    if (rawOutdated is! Map) throw const FormatException('Invalid outdated');
    final outdated = <String, String>{};
    for (final e in rawOutdated.entries) {
      final v = e.value;
      if (e.key is! String) throw FormatException('Invalid outdated ${e.key}');
      final note = v is Map ? v['note'] : null;
      outdated[e.key as String] = note is String ? note : '';
    }
    final legal = json['legalStateAsOf'];
    return SubjectMaterials(
      subject: subject,
      materialsVersion: '${json['materialsVersion'] ?? ''}',
      legalStateAsOf: legal is String ? DateTime.tryParse(legal) : null,
      sources: Map.unmodifiable(sources),
      topics: List.unmodifiable(topics),
      explanations: Map.unmodifiable(explanations),
      links: Map.unmodifiable(links),
      outdated: Map.unmodifiable(outdated),
    );
  }

  static List<MaterialRef> _refs(Object? json) {
    if (json == null) return const [];
    if (json is! List) throw FormatException('Invalid refs: $json');
    return List.unmodifiable([for (final r in json) MaterialRef.fromJson(r)]);
  }

  static List<String> _strings(Object? json) {
    if (json == null) return const [];
    if (json is! List || json.any((e) => e is! String)) {
      throw FormatException('Expected a list of strings: $json');
    }
    return List.unmodifiable(json.cast<String>());
  }

  static MaterialsTopic _topic(Object? json) {
    if (json is! Map || json['id'] is! String) {
      throw FormatException('Invalid topic: $json');
    }
    final title = json['title'];
    final String titlePl;
    String? titleEn;
    if (title is Map && title['pl'] is String) {
      titlePl = title['pl'] as String;
      titleEn = title['en'] is String ? title['en'] as String : null;
    } else if (title is String) {
      titlePl = title;
    } else {
      titlePl = json['id'] as String;
    }
    final summary = json['summary'];
    final rawSections = summary is Map ? summary['sections'] : null;
    if (rawSections != null && rawSections is! List) {
      throw FormatException('Invalid sections of ${json['id']}');
    }
    final sections = <SummarySection>[
      for (final s in (rawSections as List?) ?? const [])
        if (s is Map && s['id'] is String && s['heading'] is String)
          SummarySection(
            id: s['id'] as String,
            heading: s['heading'] as String,
            body: _strings(s['body']),
            refs: _refs(s['refs']),
            questionKeys: _strings(s['questionKeys']),
          )
        else
          throw FormatException('Invalid section: $s'),
    ];
    return MaterialsTopic(
      id: json['id'] as String,
      titlePl: titlePl,
      titleEn: titleEn,
      order: _strings(json['order']),
      sections: List.unmodifiable(sections),
    );
  }
}
