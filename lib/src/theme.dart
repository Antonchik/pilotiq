import 'package:flutter/material.dart';

const primary = Color.fromRGBO(220, 20, 60, 1);

/// Open Sans is bundled in assets/fonts (SIL OFL), no network access needed.
const fontFamily = 'OpenSans';

final lightAppTheme = ThemeData(
  useMaterial3: true,
  colorSchemeSeed: primary,
  fontFamily: fontFamily,
  scaffoldBackgroundColor: Colors.white,
  appBarTheme: const AppBarTheme(
    backgroundColor: primary,
    elevation: 5,
    centerTitle: true,
    iconTheme: IconThemeData(color: Colors.white),
    titleTextStyle: TextStyle(
      fontFamily: fontFamily,
      color: Colors.white,
      fontSize: 22,
    ),
  ),
  dialogTheme: const DialogThemeData(surfaceTintColor: Colors.white),
  cardTheme: const CardThemeData(
    surfaceTintColor: Colors.white,
    color: Colors.white,
    elevation: 5,
  ),
);

final darkAppTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  fontFamily: fontFamily,
  appBarTheme: const AppBarTheme(
    elevation: 5,
    centerTitle: true,
    titleTextStyle: TextStyle(fontFamily: fontFamily, fontSize: 22),
  ),
  cardTheme: const CardThemeData(elevation: 5),
);
