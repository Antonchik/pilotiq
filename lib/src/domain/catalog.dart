/// Shared vocabulary of the app: licences, subjects, exam parameters and the
/// mapping from legacy (pre-2.0) Hive boxes. Pure Dart, no Flutter imports.
library;

/// Licence the user prepares for. One question bank per licence.
enum Licence {
  ppla('ppla', 'bank_ppla.json', hasEnglish: true),
  pplh('pplh', 'bank_pplh.json', hasEnglish: true),
  spl('spl', 'bank_spl.json', hasEnglish: false),
  bpl('bpl', 'bank_bpl.json', hasEnglish: false);

  const Licence(this.id, this.bankFileName, {required this.hasEnglish});

  /// Stable identifier used in storage (box names, settings).
  final String id;

  /// File name of the bank inside `assets/data/`.
  final String bankFileName;

  /// Whether the bank contains English translations of the questions.
  final bool hasEnglish;

  static Licence? fromId(String? id) {
    for (final licence in values) {
      if (licence.id == id) return licence;
    }
    return null;
  }
}

/// The nine theory subjects. [id] matches the keys used in legacy Hive boxes.
enum SubjectId {
  airLaw('air_law'),
  communications('communications'),
  meteorology('meteorology'),
  navigation('navigation'),
  performanceAndPlanning('performance_and_planning'),
  aircraftGeneralKnowledge('aircraft_general_knowledge'),
  humanPerformance('human_performance'),
  principlesOfFlight('principles_of_flight'),
  operationalProcedures('operational_procedures');

  const SubjectId(this.id);

  final String id;

  static SubjectId? fromId(String? id) {
    for (final subject in values) {
      if (subject.id == id) return subject;
    }
    return null;
  }
}

/// Question-number prefix (the part of `PLxxx-yyyy` before the dash) to subject.
const Map<String, SubjectId> topicPrefixToSubject = {
  'PL010': SubjectId.airLaw,
  'PL099': SubjectId.airLaw,
  // PL100 (in-flight procedures) belongs to operational procedures (owner decision).
  'PL100': SubjectId.operationalProcedures,
  'PL102': SubjectId.airLaw,
  'PL020': SubjectId.aircraftGeneralKnowledge,
  'PL021': SubjectId.aircraftGeneralKnowledge,
  'PL024': SubjectId.aircraftGeneralKnowledge,
  'PL025': SubjectId.aircraftGeneralKnowledge,
  'PL030': SubjectId.performanceAndPlanning,
  'PL040': SubjectId.humanPerformance,
  'PL050': SubjectId.meteorology,
  'PL060': SubjectId.navigation,
  'PL070': SubjectId.operationalProcedures,
  'PL080': SubjectId.principlesOfFlight,
  'PL090': SubjectId.communications,
};

/// Exam parameters of one subject: number of questions, time limit and the
/// pass threshold (share of **all** questions of the attempt).
class ExamSpec {
  const ExamSpec({
    required this.quizLength,
    required this.minutes,
    this.passRatio = defaultPassRatio,
  });

  static const double defaultPassRatio = 0.75;

  final int quizLength;
  final int minutes;
  final double passRatio;

  /// Default parameters (the same for every licence).
  static const Map<SubjectId, ExamSpec> defaults = {
    SubjectId.airLaw: ExamSpec(quizLength: 28, minutes: 45),
    SubjectId.communications: ExamSpec(quizLength: 12, minutes: 30),
    SubjectId.meteorology: ExamSpec(quizLength: 12, minutes: 30),
    SubjectId.navigation: ExamSpec(quizLength: 24, minutes: 60),
    SubjectId.performanceAndPlanning: ExamSpec(quizLength: 20, minutes: 60),
    SubjectId.aircraftGeneralKnowledge: ExamSpec(quizLength: 16, minutes: 30),
    SubjectId.humanPerformance: ExamSpec(quizLength: 12, minutes: 30),
    SubjectId.principlesOfFlight: ExamSpec(quizLength: 16, minutes: 45),
    SubjectId.operationalProcedures: ExamSpec(quizLength: 12, minutes: 30),
  };

  /// Per-licence overrides; empty means "same as [defaults]".
  static const Map<Licence, Map<SubjectId, ExamSpec>> overrides = {};

  static ExamSpec forSubject(SubjectId subject, {Licence? licence}) {
    final override = licence == null ? null : overrides[licence]?[subject];
    return override ?? defaults[subject]!;
  }
}

/// Legacy (pre-2.0) Hive box name to the licence it belonged to.
const Map<String, Licence> legacyBoxToLicence = {
  'ppla': Licence.ppla,
  'pplaEng': Licence.ppla,
  'pplh': Licence.pplh,
  'pplhEng': Licence.pplh,
  'plg': Licence.spl,
  'plfb': Licence.bpl,
};
