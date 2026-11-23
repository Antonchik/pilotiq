import 'package:pilotiq/src/bank/models.dart';
import 'package:pilotiq/src/domain/catalog.dart';
import 'package:pilotiq/src/localization/generated/app_localizations.dart';

/// A subject of one licence as shown in the UI: texts, exam parameters and
/// the questions of the bank.
class SubjectInfo {
  const SubjectInfo({
    required this.licence,
    required this.id,
    required this.title,
    required this.description,
    required this.spec,
    required this.questions,
  });

  final Licence licence;
  final SubjectId id;
  final String title;
  final String description;
  final ExamSpec spec;
  final List<Question> questions;

  /// File name inside `assets/covers/`.
  String get image => '${id.id}.png';
}

String subjectTitle(AppLocalizations local, SubjectId id) => switch (id) {
  SubjectId.airLaw => local.airLawSubjectTitle,
  SubjectId.communications => local.communicationsSubjectTitle,
  SubjectId.meteorology => local.meteorologySubjectTitle,
  SubjectId.navigation => local.navigationSubjectTitle,
  SubjectId.performanceAndPlanning => local.performanceSubjectTitle,
  SubjectId.aircraftGeneralKnowledge => local.generalKnowledgeSubjectTitle,
  SubjectId.humanPerformance => local.humanPerformanceSubjectTitle,
  SubjectId.principlesOfFlight => local.principlesOfFlightSubjectTitle,
  SubjectId.operationalProcedures => local.operationalProcedureSubjectTitle,
};

String subjectDescription(AppLocalizations local, SubjectId id) => switch (id) {
  SubjectId.airLaw => local.airLawSubjectTooltip,
  SubjectId.communications => local.communicationsSubjectTooltip,
  SubjectId.meteorology => local.meteorologySubjectTooltip,
  SubjectId.navigation => local.navigationSubjectTooltip,
  SubjectId.performanceAndPlanning => local.performanceSubjectTooltip,
  SubjectId.aircraftGeneralKnowledge => local.generalKnowledgeSubjectTooltip,
  SubjectId.humanPerformance => local.humanPerformanceSubjectTooltip,
  SubjectId.principlesOfFlight => local.principlesOfFlightSubjectTooltip,
  SubjectId.operationalProcedures => local.operationalProcedureSubjectTooltip,
};
