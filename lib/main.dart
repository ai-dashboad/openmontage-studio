import 'package:flutter/material.dart';
import 'app_shell.dart';
import 'services/agent_service.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const OpenMontageStudioApp());
}

class OpenMontageStudioApp extends StatelessWidget {
  const OpenMontageStudioApp({super.key, this.agentService});

  /// Injected in tests; defaults to a live local-agent service.
  final AgentService? agentService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OpenMontage Studio',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: AppShell(agentService: agentService),
    );
  }
}
