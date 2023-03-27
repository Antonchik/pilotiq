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

var appTheme = ThemeData(
  useMaterial3: true,
  colorSchemeSeed: primary,
  fontFamily: GoogleFonts.openSans().fontFamily,
  appBarTheme: const AppBarTheme(
    color: primary,
    elevation: 5,
    centerTitle: true,
    iconTheme: IconThemeData(color: Colors.white),
    titleTextStyle: TextStyle(color: Colors.white, fontSize: 20),
  ),
  dialogTheme: const DialogTheme(
    // backgroundColor: Colors.white,
    surfaceTintColor: Colors.white,
  ),
  cardTheme: const CardTheme(
    // shape: RoundedRectangleBorder(
    //   borderRadius: BorderRadius.all(Radius.circular(10)),
    // ),
    surfaceTintColor: Colors.white,
    elevation: 5,
  ),
);
