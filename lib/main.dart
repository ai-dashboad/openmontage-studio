import 'package:flutter/material.dart';
import 'app_shell.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const ReelforgeApp());
}

class ReelforgeApp extends StatelessWidget {
  const ReelforgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reelforge',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const AppShell(),
    );
  }
}
