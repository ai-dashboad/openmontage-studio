import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/studio_screen.dart';

/// Top-level views the app switches between.
enum AppView { home, studio, settings }

/// Owns navigation between the launcher, the editor, and settings. Kept as a
/// simple state switch rather than a Navigator stack so the windowed desktop
/// shell stays flat and predictable.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppView _view = AppView.home;

  void _go(AppView view) => setState(() => _view = view);

  @override
  Widget build(BuildContext context) {
    return switch (_view) {
      AppView.home => HomeScreen(
          onOpenProject: () => _go(AppView.studio),
          onOpenSettings: () => _go(AppView.settings),
        ),
      AppView.studio => StudioScreen(
          onHome: () => _go(AppView.home),
          onOpenSettings: () => _go(AppView.settings),
        ),
      AppView.settings => SettingsScreen(
          onBack: () => _go(AppView.home),
        ),
    };
  }
}
