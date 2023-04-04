import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

Map<int, Color> color = {
  50: const Color.fromRGBO(220, 20, 60, .1),
  100: const Color.fromRGBO(220, 20, 60, .2),
  200: const Color.fromRGBO(220, 20, 60, .3),
  300: const Color.fromRGBO(220, 20, 60, .4),
  400: const Color.fromRGBO(220, 20, 60, .5),
  500: const Color.fromRGBO(220, 20, 60, .6),
  600: const Color.fromRGBO(220, 20, 60, .7),
  700: const Color.fromRGBO(220, 20, 60, .8),
  800: const Color.fromRGBO(220, 20, 60, .9),
  900: const Color.fromRGBO(220, 20, 60, 1),
};

const primary = Color.fromRGBO(220, 20, 60, 1);

MaterialColor colorCustom = MaterialColor(primary.value, color);

final fontFamily = GoogleFonts.openSans().fontFamily;

var lightAppTheme = ThemeData(
  useMaterial3: true,
  colorSchemeSeed: primary,
  fontFamily: GoogleFonts.openSans().fontFamily,
  scaffoldBackgroundColor: Colors.white,
  appBarTheme: AppBarTheme(
    color: primary,
    elevation: 5,
    centerTitle: true,
    iconTheme: const IconThemeData(color: Colors.white),
    titleTextStyle:
        TextStyle(fontFamily: fontFamily, color: Colors.white, fontSize: 22),
  ),
  dialogTheme: const DialogTheme(
    surfaceTintColor: Colors.white,
  ),
  cardTheme: const CardTheme(
    surfaceTintColor: Colors.white,
    color: Colors.white,
    elevation: 5,
  ),
);

var darkAppTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  fontFamily: GoogleFonts.openSans().fontFamily,
  appBarTheme: AppBarTheme(
    elevation: 5,
    centerTitle: true,
    titleTextStyle: TextStyle(fontFamily: fontFamily, fontSize: 22),
  ),
  cardTheme: const CardTheme(
    elevation: 5,
  ),
);
