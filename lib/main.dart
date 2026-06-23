import 'package:flutter/material.dart';
import 'app_shell.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const OpenMontageStudioApp());
}

class OpenMontageStudioApp extends StatelessWidget {
  const OpenMontageStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OpenMontage Studio',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const AppShell(),
    );
  }
}
