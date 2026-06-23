import 'package:flutter/material.dart';
import 'models/studio_models.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/studio_screen.dart';
import 'services/agent_service.dart';
import 'services/auth_client.dart';
import 'services/render_client.dart';
import 'services/tts_client.dart';

/// Top-level views the app switches between.
enum AppView { home, studio, settings }

/// Owns navigation between the launcher, the editor, and settings. Kept as a
/// simple state switch rather than a Navigator stack so the windowed desktop
/// shell stays flat and predictable.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    this.agentService,
    this.ttsClient,
    this.renderClient,
    this.account,
    this.onLogout,
    this.onSetConsent,
  });

  /// Injected in tests; default to live local providers.
  final AgentService? agentService;
  final TtsClient? ttsClient;
  final RenderClient? renderClient;
  final Account? account;
  final VoidCallback? onLogout;
  final Future<void> Function(bool)? onSetConsent;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppView _view = AppView.home;
  late final AgentService _agent = widget.agentService ?? AgentService();
  late final TtsClient _tts = widget.ttsClient ?? TtsClient();
  late final RenderClient _render = widget.renderClient ?? RenderClient();

  /// The plan driving the studio — the agent's output, or the sample default.
  List<Scene> _scenes = MockProject.scenes;

  void _go(AppView view) => setState(() => _view = view);

  void _openStudio(List<Scene>? scenes) {
    setState(() {
      _scenes = scenes ?? MockProject.scenes;
      _view = AppView.studio;
    });
  }

  @override
  Widget build(BuildContext context) {
    return switch (_view) {
      AppView.home => HomeScreen(
        agent: _agent,
        onOpenProject: _openStudio,
        onOpenSettings: () => _go(AppView.settings),
      ),
      AppView.studio => StudioScreen(
        agent: _agent,
        tts: _tts,
        render: _render,
        scenes: _scenes,
        onHome: () => _go(AppView.home),
        onOpenSettings: () => _go(AppView.settings),
      ),
      AppView.settings => SettingsScreen(
        onBack: () => _go(AppView.home),
        account: widget.account,
        onLogout: widget.onLogout,
        onSetConsent: widget.onSetConsent,
      ),
    };
  }
}
