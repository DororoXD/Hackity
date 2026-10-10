import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const brown = Color(0xFF2E1A12);
  static const peach = Color(0xFFF5BF9A);
  static const cream = Color(0xFFFCE8DA);
  static const red = Color(0xFFE8605C);
  static const orange = Color(0xFFEE8A57);
}

ThemeData buildTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.peach,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.brown),
    textTheme: GoogleFonts.oswaldTextTheme(),
  );
}