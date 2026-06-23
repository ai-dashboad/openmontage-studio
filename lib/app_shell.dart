import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/studio_screen.dart';
import 'services/agent_service.dart';

/// Top-level views the app switches between.
enum AppView { home, studio, settings }

/// Owns navigation between the launcher, the editor, and settings. Kept as a
/// simple state switch rather than a Navigator stack so the windowed desktop
/// shell stays flat and predictable.
class AppShell extends StatefulWidget {
  const AppShell({super.key, this.agentService});

  /// Injected in tests; defaults to a live local-agent service.
  final AgentService? agentService;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppView _view = AppView.home;
  late final AgentService _agent = widget.agentService ?? AgentService();

  void _go(AppView view) => setState(() => _view = view);

  @override
  Widget build(BuildContext context) {
    return switch (_view) {
      AppView.home => HomeScreen(
        onOpenProject: () => _go(AppView.studio),
        onOpenSettings: () => _go(AppView.settings),
      ),
      AppView.studio => StudioScreen(
        agent: _agent,
        onHome: () => _go(AppView.home),
        onOpenSettings: () => _go(AppView.settings),
      ),
      AppView.settings => SettingsScreen(onBack: () => _go(AppView.home)),
    };
  }
}
