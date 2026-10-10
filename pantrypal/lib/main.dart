import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'screens/login_screen.dart';

void main() => runApp(const PantryPalApp());

class PantryPalApp extends StatelessWidget {
  const PantryPalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PantryPal',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const LoginScreen(),
    );
  }
}