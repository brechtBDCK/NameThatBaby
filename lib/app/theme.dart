import 'package:flutter/material.dart';

/// Central palette shared by the app shell and feature screens.
class Palette {
  static const cream = Color(0xfff8f1ec);
  static const surface = Color(0xfffff9f5);
  static const blush = Color(0xffeed7d1);
  static const rose = Color(0xffa66f72);
  static const wine = Color(0xff7d5155);
  static const sage = Color(0xff78806d);
  static const taupe = Color(0xff9a877c);
  static const ink = Color(0xff2c2423);
  // Kept as semantic aliases while screens migrate to the editorial palette.
  static const forest = sage;
  static const terra = rose;
  static const gold = taupe;
  static const sky = blush;
}

ThemeData nameThatBabyTheme() => ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: Palette.cream,
  colorScheme: ColorScheme.fromSeed(
    seedColor: Palette.rose,
    surface: Palette.surface,
    primary: Palette.rose,
    onPrimary: Palette.surface,
    onSurface: Palette.ink,
  ),
  textTheme: ThemeData.light().textTheme
      .apply(bodyColor: Palette.ink, displayColor: Palette.ink)
      .copyWith(
        displayLarge: const TextStyle(fontFamily: 'serif', fontSize: 52),
        displaySmall: const TextStyle(fontFamily: 'serif', fontSize: 36),
        headlineMedium: const TextStyle(fontFamily: 'serif', fontSize: 30),
        headlineSmall: const TextStyle(fontFamily: 'serif', fontSize: 24),
      ),
  appBarTheme: const AppBarTheme(foregroundColor: Palette.ink),
  cardTheme: CardThemeData(
    color: Palette.surface,
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(18)),
      side: BorderSide(color: Palette.blush),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: Palette.rose,
      foregroundColor: Palette.surface,
      minimumSize: const Size.fromHeight(50),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: Palette.wine,
      minimumSize: const Size.fromHeight(50),
      side: const BorderSide(color: Palette.rose),
    ),
  ),
);
