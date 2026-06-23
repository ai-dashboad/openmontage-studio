import 'package:flutter/material.dart';
import 'app_shell.dart';
import 'auth/auth_gate.dart';
import 'services/agent_service.dart';
import 'services/auth_client.dart';
import 'services/render_client.dart';
import 'services/session_store.dart';
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
    this.authClient,
    this.sessionStore,
    this.initialAccount,
  });

  /// Injected in tests; default to live providers. [initialAccount] starts the
  /// app already signed in (tests use this to bypass the auth gate).
  final AgentService? agentService;
  final TtsClient? ttsClient;
  final RenderClient? renderClient;
  final AuthClient? authClient;
  final SessionStore? sessionStore;
  final Account? initialAccount;

  @override
  Widget build(BuildContext context) {
    final auth = authClient ?? AuthClient();
    return MaterialApp(
      title: 'OpenMontage Studio',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: AuthGate(
        authClient: auth,
        sessionStore: sessionStore ?? SessionStore(),
        initialAccount: initialAccount,
        appBuilder: (session) => AppShell(
          agentService: agentService,
          ttsClient: ttsClient,
          renderClient: renderClient,
          session: session,
        ),
      ),
    );
  }
}
