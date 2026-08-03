import 'package:flutter/material.dart';

/// Central palette shared by the app shell and feature screens.
class Palette {
  static const cream = Color(0xfff6f0e4);
  static const surface = Color(0xfffff9ef);
  static const forest = Color(0xff244b38);
  static const terra = Color(0xffc65d3b);
  static const sky = Color(0xffafcedb);
  static const gold = Color(0xffd79a29);
}

ThemeData nameThatBabyTheme() => ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: Palette.cream,
  colorScheme: ColorScheme.fromSeed(
    seedColor: Palette.forest,
    surface: Palette.surface,
  ),
  textTheme: ThemeData.light().textTheme.apply(
    bodyColor: Palette.forest,
    displayColor: Palette.forest,
  ),
);
