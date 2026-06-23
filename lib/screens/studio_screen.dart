import 'package:flutter/material.dart';
import '../models/studio_models.dart';
import '../services/agent_service.dart';
import '../services/conversation.dart';
import '../services/project_store.dart';
import '../services/provider_manager.dart';
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

/// The studio-first main editor. Owns the state that links the timeline,
/// preview, and inspector: the (editable) scene plan with undo/redo, the
/// selected scene, the playhead, the active rail surface, the shared agent
/// conversation, and online/offline mode.
class StudioScreen extends StatefulWidget {
  const StudioScreen({
    super.key,
    required this.agent,
    required this.tts,
    required this.render,
    required this.provider,
    required this.projectStore,
    required this.projectId,
    this.projectName = 'Untitled video',
    this.initialStage = 2,
    this.brief,
    this.scenes = MockProject.scenes,
    this.onHome,
    this.onOpenSettings,
  });

  final AgentService agent;
  final TtsClient tts;
  final RenderClient render;
  final ProviderManager provider;
  final ProjectStore projectStore;

  /// Identity of the project being edited, so edits persist under one record.
  final String projectId;
  final String projectName;
  final int initialStage;

  /// The brief the user typed on the home screen, if any — seeds the agent
  /// conversation so the studio continues the same thread.
  final String? brief;

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

  /// Current pipeline stage (index into MockProject.stages). The studio opens on
  /// scene_plan; approving walks it forward to compose.
  late int _stage;

  /// The editable scene plan plus its edit history (for undo/redo).
  late List<Scene> _scenes;
  final List<List<Scene>> _undo = [];
  final List<List<Scene>> _redo = [];

  late final ConversationController _conversation;
  late String _projectName;

  // The most recent render for this project, persisted with it.
  String? _renderPath;
  double? _renderSeconds;
  int? _renderBytes;

  bool _narrating = false;
  bool _revising = false;

  String get _stageName => MockProject.stages[_stage].name;
  bool get _atCompose => _stageName == 'compose';

  /// The chat entry sits after the four asset families in the rail.
  static const int _chatIndex = 4;

  double get _total => _scenes.last.endSeconds;
  Scene get _scene => _scenes[_selectedScene];

  /// Playhead follows scene selection by snapping to that scene's in-point.
  late double _playhead;

  @override
  void initState() {
    super.initState();
    _scenes = [...widget.scenes];
    _stage = widget.initialStage;
    _projectName = widget.projectName;
    _selectedScene = _scenes.length > 1 ? 1 : 0;
    _playhead = _scenes[_selectedScene].startSeconds;
    _conversation = ConversationController(
      agent: widget.agent,
      seed: _seedConversation(),
    );
    // One-shot status probe so the top bar reflects reality on entry.
    widget.provider.probe();
    // Persist an initial record so the project shows up immediately.
    _save();
  }

  @override
  void dispose() {
    _save(); // capture the latest text edits on the way out
    _conversation.dispose();
    super.dispose();
  }

  /// Persists the current project state (fire-and-forget).
  void _save() {
    widget.projectStore.save(
      StudioProject(
        id: widget.projectId,
        name: _projectName,
        scenes: [..._scenes],
        stageIndex: _stage,
        updatedAtIso: DateTime.now().toIso8601String(),
        renderPath: _renderPath,
        renderSeconds: _renderSeconds,
        renderBytes: _renderBytes,
      ),
    );
  }

  /// Seeds the conversation from the home brief when present, so the chat
  /// continues the same thread instead of starting blank.
  List<ChatMessage> _seedConversation() {
    final brief = widget.brief?.trim();
    if (brief == null || brief.isEmpty) return [...MockProject.conversation];
    return [
      ChatMessage(role: ChatRole.user, text: brief),
      ChatMessage(
        role: ChatRole.agent,
        text:
            'Locked the brief. I split it into ${_scenes.length} scenes — '
            'select any in the timeline to edit it, then approve to advance.',
        artifact: 'scene_plan · ${_scenes.length} scenes · '
            '${_total.toStringAsFixed(0)}s',
      ),
    ];
  }

  void _onRailSelect(int index) {
    setState(() {
      if (index == _railIndex) {
        _panelOpen = !_panelOpen;
      } else {
        _railIndex = index;
        _panelOpen = true;
      }
    });
  }

  void _selectScene(int index) {
    setState(() {
      _selectedScene = index;
      _playhead = _scenes[index].startSeconds;
    });
  }

  void _scrub(double seconds) {
    setState(() {
      _playhead = seconds;
      for (var i = 0; i < _scenes.length; i++) {
        final s = _scenes[i];
        if (seconds >= s.startSeconds && seconds < s.endSeconds) {
          _selectedScene = i;
          break;
        }
      }
    });
  }

  // --- Editing with undo/redo -------------------------------------------------

  void _pushHistory() {
    _undo.add([..._scenes]);
    _redo.clear();
  }

  /// Recomputes every scene's start/end from its duration so the timeline stays
  /// contiguous after an insert, delete, reorder, or duration change.
  void _reflowInPlace() {
    var cursor = 0.0;
    for (var i = 0; i < _scenes.length; i++) {
      final d = _scenes[i].durationSeconds;
      _scenes[i] = _scenes[i].copyWith(
        startSeconds: cursor,
        endSeconds: cursor + d,
      );
      cursor += d;
    }
  }

  /// Replaces the selected scene (headline/subtitle/accent edits).
  void _updateScene(Scene updated) {
    setState(() {
      _pushHistory();
      _scenes[_selectedScene] = updated;
    });
    _save();
  }

  /// Sets the selected scene's duration and re-flows the timeline.
  void _setDuration(double seconds) {
    setState(() {
      _pushHistory();
      _scenes[_selectedScene] = _scenes[_selectedScene].copyWith(
        endSeconds: _scenes[_selectedScene].startSeconds + seconds,
      );
      _reflowInPlace();
      _playhead = _scenes[_selectedScene].startSeconds;
    });
    _save();
  }

  /// Inserts a fresh scene after the selection and selects it.
  void _addScene() {
    setState(() {
      _pushHistory();
      final at = _selectedScene + 1;
      _scenes.insert(
        at,
        Scene(
          id: 'scene_${DateTime.now().microsecondsSinceEpoch}',
          type: 'text_card',
          title: 'New scene',
          startSeconds: 0,
          endSeconds: 4,
          accent: AppColors.accentCyan,
          headline: 'New headline',
          subtitle: '',
        ),
      );
      _reflowInPlace();
      _selectedScene = at;
      _playhead = _scenes[at].startSeconds;
    });
    _save();
  }

  /// Removes the selected scene (keeps at least one).
  void _deleteScene() {
    if (_scenes.length <= 1) return;
    setState(() {
      _pushHistory();
      _scenes.removeAt(_selectedScene);
      _reflowInPlace();
      _selectedScene = _selectedScene.clamp(0, _scenes.length - 1);
      _playhead = _scenes[_selectedScene].startSeconds;
    });
    _save();
  }

  /// Moves the selected scene one slot left (-1) or right (+1).
  void _moveScene(int delta) {
    final to = _selectedScene + delta;
    if (to < 0 || to >= _scenes.length) return;
    setState(() {
      _pushHistory();
      final s = _scenes.removeAt(_selectedScene);
      _scenes.insert(to, s);
      _reflowInPlace();
      _selectedScene = to;
      _playhead = _scenes[to].startSeconds;
    });
    _save();
  }

  void _undoEdit() {
    if (_undo.isEmpty) return;
    setState(() {
      _redo.add([..._scenes]);
      _scenes = _undo.removeLast();
      _selectedScene = _selectedScene.clamp(0, _scenes.length - 1);
      _playhead = _scenes[_selectedScene].startSeconds;
    });
    _save();
  }

  void _redoEdit() {
    if (_redo.isEmpty) return;
    setState(() {
      _undo.add([..._scenes]);
      _scenes = _redo.removeLast();
      _selectedScene = _selectedScene.clamp(0, _scenes.length - 1);
      _playhead = _scenes[_selectedScene].startSeconds;
    });
    _save();
  }

  /// Asks the agent to revise the selected scene from a one-line instruction.
  Future<void> _revise() async {
    final instruction = await _askRevision();
    if (instruction == null || instruction.trim().isEmpty) return;
    setState(() => _revising = true);
    final target = _scene;
    try {
      final revised = await widget.agent.reviseScene(target, instruction);
      if (!mounted) return;
      _updateScene(revised);
      _conversation.addAgentLine(
        'Revised "${target.title}": ${revised.headline}',
      );
    } catch (_) {
      if (!mounted) return;
      _toast('Could not revise — is the agent (Ollama) running?');
    } finally {
      if (mounted) setState(() => _revising = false);
    }
  }

  Future<String?> _askRevision() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Revise with agent',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
          decoration: const InputDecoration(
            hintText: 'e.g. make it punchier, mention the year',
            hintStyle: TextStyle(color: AppColors.textFaint),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accentPurple,
              foregroundColor: AppColors.background,
            ),
            child: const Text('Revise'),
          ),
        ],
      ),
    );
  }

  // --- Pipeline ---------------------------------------------------------------

  /// Approve the current stage. At compose this renders; otherwise it advances
  /// and the agent posts what it produced for the new stage (a visible artifact
  /// in the chat), not just a toast.
  void _approveStage() {
    if (_atCompose) {
      _openRender();
      return;
    }
    final current = _stageName;
    if (_stage + 1 >= MockProject.stages.length) {
      _toast('Published');
      return;
    }
    setState(() => _stage += 1);
    _save();
    final next = _stageName;
    _toast('$current approved → entering $next…');
    _conversation.addAgentLine('$current approved. Working on $next…');
    widget.agent
        .summarizeStage(next)
        .then((line) {
          if (mounted) {
            _conversation.addAgentLine(
              line.trim(),
              artifact: '$next · ready for review',
            );
          }
        })
        .catchError((_) {
          if (mounted) {
            _conversation.addAgentLine(
              'Drafted the $next stage.',
              artifact: '$next · ready for review',
            );
          }
        });
  }

  void _openRender() {
    showRenderDialog(
      context,
      client: widget.render,
      provider: widget.provider,
      scenes: _renderPayload(),
      projectName: _projectName,
      onComplete: (result) {
        _renderPath = result.path;
        _renderSeconds = result.seconds;
        _renderBytes = result.bytes;
        _save();
      },
    );
  }

  /// Serializes the scene plan for the render provider.
  List<Map<String, dynamic>> _renderPayload() {
    return [
      for (final s in _scenes)
        {
          'title': s.title,
          'type': s.type,
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
      _toast('Voice provider offline — starting it…');
      await widget.provider.ensureRunning();
    } finally {
      if (mounted) setState(() => _narrating = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
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
            projectName: _projectName,
            onToggleOnline: () => setState(() => _isOnline = !_isOnline),
            provider: widget.provider,
            onRetryServices: () async {
              await widget.provider.ensureRunning();
              await widget.provider.probe();
            },
            onHome: widget.onHome,
            onOpenSettings: widget.onOpenSettings,
            onRender: _openRender,
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
                    conversation: _conversation,
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
                  stageName: _stageName,
                  sceneIndex: _selectedScene,
                  sceneCount: _scenes.length,
                  approveLabel: _atCompose ? 'Render' : 'Approve & continue',
                  onApprove: _approveStage,
                  onSceneChanged: _updateScene,
                  onDurationChanged: _setDuration,
                  onAddScene: _addScene,
                  onDeleteScene: _deleteScene,
                  onMoveLeft: () => _moveScene(-1),
                  onMoveRight: () => _moveScene(1),
                  onGenerateNarration: _generateNarration,
                  narrating: _narrating,
                  onRevise: _revise,
                  revising: _revising,
                  onUndo: _undoEdit,
                  onRedo: _redoEdit,
                  canUndo: _undo.isNotEmpty,
                  canRedo: _redo.isNotEmpty,
                ),
              ],
            ),
          ),
          Timeline(
            scenes: _scenes,
            totalSeconds: _total,
            currentStageIndex: _stage,
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
