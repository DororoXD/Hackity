import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'screens/home_shell.dart';

void main() => runApp(const PantryPal());

class PantryPal extends StatelessWidget {
  const PantryPal({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PantryPal',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const HomeShell(),
    );
  }
}