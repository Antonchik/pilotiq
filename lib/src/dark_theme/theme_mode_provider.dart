import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

final themeModeProvider = StateProvider<ThemeMode>(
  (ref) => Hive.box<dynamic>('config')
          .get(ThemeMode.dark.name, defaultValue: false) as bool
      ? ThemeMode.dark
      : ThemeMode.light,
);
