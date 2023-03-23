import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pilotiq/src/models.dart';

final questionRepositoryProvider = Provider<QuestionRepository>((ref) {
  return QuestionRepository();
});

class QuestionRepository {
  final Map<String, List<Question>> _questions = {};

  Future<Map<String, List<Question>>> getPPLQuestions({
    bool isHelicopter = false,
    bool isEnglish = false,
    bool isGlider = false,
    bool isBalloon = false,
  }) async {
    _questions.clear();
    if (isGlider) {
      await parseQuestions('plg-pl.json');
    } else if (isBalloon) {
      await parseQuestions('plfb-pl.json');
    } else {
      final aircraftType = isHelicopter ? 'h' : 'a';
      final language = isEnglish ? 'en' : 'pl';
      await parseQuestions('ppl$aircraftType-$language.json');
    }
    return _questions;
  }

  Future<void> parseQuestions(String jsonFile) async {
    final String jsonString =
        await rootBundle.loadString('assets/data/$jsonFile');
    final data = jsonDecode(jsonString);
    for (final entry in data) {
      final question = Question.fromJson(entry);
      final topic = question.number.split('-').first;
      switch (topic) {
        case 'PL010':
          _questions['airLaw'] ??= [];
          _questions['airLaw']!.add(question);
          break;
        case 'PL020':
          _questions['generalKnowledge'] ??= [];
          _questions['generalKnowledge']!.add(question);
          break;
        case 'PL024':
          _questions['generalKnowledge'] ??= [];
          _questions['generalKnowledge']!.add(question);
          break;
        case 'PL025':
          _questions['generalKnowledge'] ??= [];
          _questions['generalKnowledge']!.add(question);
          break;
        case 'PL030':
          _questions['flightPerformance'] ??= [];
          _questions['flightPerformance']!.add(question);
          break;
        case 'PL040':
          _questions['humanPerformance'] ??= [];
          _questions['humanPerformance']!.add(question);
          break;
        case 'PL050':
          _questions['meteorology'] ??= [];
          _questions['meteorology']!.add(question);
          break;
        case 'PL060':
          _questions['navigation'] ??= [];
          _questions['navigation']!.add(question);
          break;
        case 'PL070':
          _questions['operationalProcedures'] ??= [];
          _questions['operationalProcedures']!.add(question);
          break;
        case 'PL080':
          _questions['principlesOfFlight'] ??= [];
          _questions['principlesOfFlight']!.add(question);
          break;
        case 'PL090':
          _questions['communications'] ??= [];
          _questions['communications']!.add(question);
          break;
        case 'PL099':
          _questions['airLaw'] ??= [];
          _questions['airLaw']!.add(question);
          break;
        case 'PL100':
          _questions['airLaw'] ??= [];
          _questions['airLaw']!.add(question);
          break;
        case 'PL102':
          _questions['airLaw'] ??= [];
          _questions['airLaw']!.add(question);
          break;
      }
    }
  }
}
