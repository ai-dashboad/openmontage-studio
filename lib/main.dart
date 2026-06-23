import 'package:flutter/material.dart';
import 'app_shell.dart';
import 'services/agent_service.dart';
import 'services/render_client.dart';
import 'services/tts_client.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const OpenMontageStudioApp());
}

class OpenMontageStudioApp extends StatelessWidget {
  const OpenMontageStudioApp({
    super.key,
    this.agentService,
    this.ttsClient,
    this.renderClient,
  });

  /// Injected in tests; default to live local providers.
  final AgentService? agentService;
  final TtsClient? ttsClient;
  final RenderClient? renderClient;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OpenMontage Studio',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: AppShell(
        agentService: agentService,
        ttsClient: ttsClient,
        renderClient: renderClient,
      ),
    );
  }
}
