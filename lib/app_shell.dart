import 'package:flutter/material.dart';
import 'models/studio_models.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/studio_screen.dart';
import 'auth/account_session.dart';
import 'services/agent_service.dart';
import 'services/media_settings.dart';
import 'services/project_store.dart';
import 'services/provider_manager.dart';
import 'services/render_client.dart';
import 'services/tts_client.dart';
import 'services/update_checker.dart';
import 'services/voice_settings.dart';

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
    this.updateChecker,
    this.providerManager,
    this.projectStore,
    this.mediaSettings,
    this.voiceSettings,
    this.session,
  });

  /// Injected in tests; default to live local providers.
  final AgentService? agentService;
  final TtsClient? ttsClient;
  final RenderClient? renderClient;
  final UpdateChecker? updateChecker;
  final ProviderManager? providerManager;
  final ProjectStore? projectStore;
  final MediaSettings? mediaSettings;
  final VoiceSettings? voiceSettings;
  final AccountSession? session;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppView _view = AppView.home;
  late final AgentService _agent = widget.agentService ?? AgentService();
  late final VoiceSettings _voiceSettings =
      widget.voiceSettings ?? VoiceSettings();
  late final TtsClient _tts =
      widget.ttsClient ?? TtsClient(voiceSettings: _voiceSettings);
  late final RenderClient _render =
      widget.renderClient ?? RenderClient(voiceSettings: _voiceSettings);
  late final ProviderManager _provider =
      widget.providerManager ?? ProviderManager(agent: _agent, media: _tts);
  late final ProjectStore _projects = widget.projectStore ?? ProjectStore();
  late final MediaSettings _media = widget.mediaSettings ?? MediaSettings();

  /// Whether the branded end card is appended to renders. Disabled once the
  /// user unlocks the "remove branding" referral reward (checked at startup).
  bool _branding = true;

  /// The plan driving the studio — the agent's output, or the sample default.
  List<Scene> _scenes = MockProject.scenes;

  /// Identity/state of the project currently open in the studio.
  String _projectId = 'sample';
  String _projectName = 'Untitled video';
  int _projectStage = 2;
  String _projectVoice = 'Samantha';
  String _projectRuntime = 'ffmpeg';
  String? _brief;

  @override
  void initState() {
    super.initState();
    // Apply the "remove branding" referral reward if the user has unlocked it.
    final session = widget.session;
    if (session != null) {
      session.referral().then((status) {
        if (mounted && status.hasUnlock('no_branding')) {
          setState(() => _branding = false);
        }
      }).catchError((_) {/* referral is best-effort; keep branding on */});
    }
  }

  void _go(AppView view) => setState(() => _view = view);

  /// Starts a NEW project from a brief (or the sample when empty).
  void _startProject(List<Scene>? scenes, String? brief) {
    setState(() {
      _scenes = scenes ?? MockProject.scenes;
      _brief = brief;
      _projectId = 'proj_${DateTime.now().microsecondsSinceEpoch}';
      _projectName = _deriveName(brief);
      _projectStage = 2;
      _projectVoice = 'Samantha';
      _projectRuntime = 'ffmpeg';
      _view = AppView.studio;
    });
  }

  /// Reopens a saved project for further editing.
  void _reopenProject(StudioProject project) {
    setState(() {
      _scenes = project.scenes.isNotEmpty ? project.scenes : MockProject.scenes;
      _brief = null;
      _projectId = project.id;
      _projectName = project.name;
      _projectStage = project.stageIndex;
      _projectVoice = project.voice;
      _projectRuntime = project.runtime;
      _view = AppView.studio;
    });
  }

  String _deriveName(String? brief) {
    final b = brief?.trim();
    if (b == null || b.isEmpty) return 'Untitled video';
    final words = b.split(RegExp(r'\s+')).take(6).join(' ');
    return words.length > 48 ? '${words.substring(0, 48)}…' : words;
  }

  @override
  Widget build(BuildContext context) {
    return switch (_view) {
      AppView.home => HomeScreen(
        agent: _agent,
        provider: _provider,
        projects: _projects,
        onOpenProject: _startProject,
        onReopenProject: _reopenProject,
        onOpenSettings: () => _go(AppView.settings),
        updateChecker: widget.updateChecker,
      ),
      AppView.studio => StudioScreen(
        agent: _agent,
        tts: _tts,
        render: _render,
        provider: _provider,
        projectStore: _projects,
        mediaSettings: _media,
        projectId: _projectId,
        projectName: _projectName,
        initialStage: _projectStage,
        voice: _projectVoice,
        runtime: _projectRuntime,
        branding: _branding,
        session: widget.session,
        brief: _brief,
        scenes: _scenes,
        onHome: () => _go(AppView.home),
        onOpenSettings: () => _go(AppView.settings),
      ),
      AppView.settings => SettingsScreen(
        onBack: () => _go(AppView.home),
        session: widget.session,
        mediaSettings: _media,
        voiceSettings: _voiceSettings,
      ),
    };
  }
}
