import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'screens/home_shell.dart';

void main() => runApp(const FreshStockApp());

class FreshStockApp extends StatelessWidget {
  const FreshStockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FreshStock AI',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const HomeShell(),
    );
  }
}