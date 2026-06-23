import 'package:flutter/material.dart';
import '../models/studio_models.dart';
import '../services/agent_service.dart';
import '../services/render_client.dart';
import '../services/tts_client.dart';
import '../theme/app_theme.dart';
import '../widgets/inspector.dart';
import '../widgets/left_rail.dart';
import '../widgets/preview_stage.dart';
import '../widgets/render_dialog.dart';
import '../widgets/side_panel.dart';
import '../widgets/timeline.dart';
import '../widgets/top_bar.dart';

/// The studio-first main editor. Owns the small amount of UI state that links
/// the timeline, preview, and inspector together: selected scene, playhead, the
/// active rail surface, and online/offline mode.
class StudioScreen extends StatefulWidget {
  const StudioScreen({
    super.key,
    required this.agent,
    required this.tts,
    required this.render,
    this.scenes = MockProject.scenes,
    this.onHome,
    this.onOpenSettings,
  });

  final AgentService agent;
  final TtsClient tts;
  final RenderClient render;

  /// The scene plan driving the editor — defaults to the sample, or an
  /// agent-generated plan passed in from the home brief.
  final List<Scene> scenes;
  final VoidCallback? onHome;
  final VoidCallback? onOpenSettings;

  @override
  State<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends State<StudioScreen> {
  int _selectedScene = 0;
  int _railIndex = 4; // Start on the agent chat.
  bool _isOnline = true;
  bool _panelOpen = true;

  /// The chat entry sits after the four asset families in the rail.
  static const int _chatIndex = 4;

  List<Scene> get _scenes => widget.scenes;
  double get _total => _scenes.last.endSeconds;

  @override
  void initState() {
    super.initState();
    // Prefer the second scene as the initial selection when available.
    _selectedScene = _scenes.length > 1 ? 1 : 0;
    _playhead = _scenes[_selectedScene].startSeconds;
  }

  void _onRailSelect(int index) {
    setState(() {
      // Tapping the active rail item toggles the panel; otherwise switch to it.
      if (index == _railIndex) {
        _panelOpen = !_panelOpen;
      } else {
        _railIndex = index;
        _panelOpen = true;
      }
    });
  }

  Scene get _scene => _scenes[_selectedScene];

  /// Playhead follows scene selection by snapping to that scene's in-point.
  late double _playhead;

  void _selectScene(int index) {
    setState(() {
      _selectedScene = index;
      _playhead = _scenes[index].startSeconds;
    });
  }

  void _scrub(double seconds) {
    setState(() {
      _playhead = seconds;
      // Keep the selected scene in sync with where the playhead lands.
      for (var i = 0; i < _scenes.length; i++) {
        final s = _scenes[i];
        if (seconds >= s.startSeconds && seconds < s.endSeconds) {
          _selectedScene = i;
          break;
        }
      }
    });
  }

  void _approve() {
    _toast('scene_plan approved — advancing to assets');
  }

  /// Serializes the scene plan for the render provider.
  List<Map<String, dynamic>> _renderPayload() {
    return [
      for (final s in _scenes)
        {
          'headline': s.headline,
          'subtitle': s.subtitle,
          'seconds': s.durationSeconds,
          'accent': s.accent
              .toARGB32()
              .toRadixString(16)
              .padLeft(8, '0')
              .substring(2),
        },
    ];
  }

  bool _narrating = false;

  Future<void> _generateNarration() async {
    if (_narrating) return;
    setState(() => _narrating = true);
    final scene = _scene;
    final text = [
      scene.headline,
      scene.subtitle,
    ].where((s) => s.isNotEmpty).join('. ');
    try {
      final clip = await widget.tts.synthesize(
        text.isEmpty ? scene.title : text,
      );
      await widget.tts.play(clip.path);
      if (!mounted) return;
      _toast(
        'Narration ready · ${clip.voice} · ${clip.seconds}s '
        '(${(clip.bytes / 1024).round()} KB)',
      );
    } catch (_) {
      if (!mounted) return;
      _toast('TTS provider offline — run: python3 backend/provider_server.py');
    } finally {
      if (mounted) setState(() => _narrating = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        width: 420,
        backgroundColor: AppColors.surfaceHigh,
        content: Text(
          message,
          style: const TextStyle(color: AppColors.textPrimary),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          TopBar(
            isOnline: _isOnline,
            onToggleOnline: () => setState(() => _isOnline = !_isOnline),
            onHome: widget.onHome,
            onOpenSettings: widget.onOpenSettings,
            onRender: () => showRenderDialog(
              context,
              client: widget.render,
              scenes: _renderPayload(),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                LeftRail(selected: _railIndex, onSelect: _onRailSelect),
                if (_panelOpen)
                  SidePanel(
                    railIndex: _railIndex,
                    chatIndex: _chatIndex,
                    onCollapse: () => setState(() => _panelOpen = false),
                    agent: widget.agent,
                  ),
                Expanded(
                  child: PreviewStage(
                    scene: _scene,
                    playheadSeconds: _playhead,
                    totalSeconds: _total,
                    onScrub: _scrub,
                  ),
                ),
                Inspector(
                  scene: _scene,
                  stageName: 'scene_plan',
                  onApprove: _approve,
                  onGenerateNarration: _generateNarration,
                  narrating: _narrating,
                ),
              ],
            ),
          ),
          Timeline(
            scenes: _scenes,
            totalSeconds: _total,
            selectedSceneIndex: _selectedScene,
            playheadSeconds: _playhead,
            onSelectScene: _selectScene,
          ),
          const _CapabilityBar(),
        ],
      ),
    );
  }
}

/// The footer capability rollup — the "X of Y configured" provider menu in
/// compact form, with an offline-ready marker per family.
class _CapabilityBar extends StatelessWidget {
  const _CapabilityBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Icon(
            Icons.dashboard_customize_outlined,
            size: 14,
            color: AppColors.textFaint,
          ),
          const SizedBox(width: 10),
          // Capability chips scroll horizontally so a narrow window degrades
          // gracefully instead of overflowing.
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final cap in MockProject.capabilities) ...[
                    _CapabilityChip(cap: cap),
                    const SizedBox(width: 14),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'runtime: ${MockProject.renderRuntime}',
            style: AppTheme.mono.copyWith(
              color: AppColors.textFaint,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _CapabilityChip extends StatelessWidget {
  const _CapabilityChip({required this.cap});
  final Capability cap;

  @override
  Widget build(BuildContext context) {
    final color = cap.isConfigured
        ? AppColors.accentGreen
        : AppColors.textFaint;
    return Tooltip(
      message: cap.detail,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            '${cap.label} ${cap.configured}/${cap.total}',
            style: TextStyle(
              color: cap.isConfigured
                  ? AppColors.textMuted
                  : AppColors.textFaint,
              fontSize: 11.5,
            ),
          ),
          if (cap.isLocalReady) ...[
            const SizedBox(width: 3),
            const Icon(Icons.computer, size: 11, color: AppColors.accentCyan),
          ],
        ],
      ),
    );
  }
}
