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

const primary = Color.fromARGB(255, 220, 20, 60);

MaterialColor colorCustom = MaterialColor(primary.value, color);

var appTheme = ThemeData(
  primarySwatch: colorCustom,
  fontFamily: GoogleFonts.inconsolata().fontFamily,
  bottomAppBarTheme: const BottomAppBarTheme(
    color: Colors.black87,
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    elevation: 2.0,
    backgroundColor: Colors.black87,
    selectedItemColor: Colors.white,
    unselectedItemColor: Colors.white70,
  ),
  brightness: Brightness.light,
  textTheme: const TextTheme(
    bodyLarge: TextStyle(fontSize: 18),
    bodyMedium: TextStyle(fontSize: 16),
    labelLarge: TextStyle(
      letterSpacing: 1.5,
      fontWeight: FontWeight.bold,
    ),
    displayLarge: TextStyle(
      fontWeight: FontWeight.bold,
    ),
    titleMedium: TextStyle(
      color: Colors.grey,
    ),
  ),
  buttonTheme: const ButtonThemeData(),
);
