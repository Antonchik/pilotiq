import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

final themeModeProvider = StateProvider<ThemeMode>(
  (ref) => Hive.box<dynamic>('config')
          .get(ThemeMode.dark.name, defaultValue: false) as bool
      ? ThemeMode.dark
      : ThemeMode.light,
);
