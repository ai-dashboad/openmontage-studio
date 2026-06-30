import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../auth/account_session.dart';
import '../models/studio_models.dart';
import '../services/agent_service.dart';
import '../services/auth_client.dart';
import '../services/conversation.dart';
import '../services/digital_human_settings.dart';
import '../services/media_settings.dart';
import '../services/video_settings.dart';
import '../services/project_store.dart';
import '../services/provider_manager.dart';
import '../services/render_client.dart';
import '../services/tts_client.dart';
import '../theme/app_theme.dart';
import '../widgets/editor_panel.dart';
import '../widgets/paywall_sheet.dart';
import '../widgets/preview_stage.dart';
import '../widgets/render_dialog.dart';
import '../widgets/storyboard_rail.dart';
import '../widgets/timeline.dart';
import '../widgets/export_modal.dart';
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
    required this.mediaSettings,
    required this.projectId,
    this.projectName = 'Untitled video',
    this.initialStage = 2,
    this.voice = 'Samantha',
    this.runtime = 'ffmpeg',
    this.branding = true,
    this.session,
    this.onRequestSignIn,
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
  final MediaSettings mediaSettings;

  /// Identity of the project being edited, so edits persist under one record.
  final String projectId;
  final String projectName;
  final int initialStage;
  final String voice;
  final String runtime;

  /// Whether the branded end card is appended to renders. Turned off once the
  /// user unlocks the "remove branding" referral reward.
  final bool branding;

  /// The signed-in session, used to meter renders against the free credit
  /// allowance and show the paywall. Null for guests / tests, where rendering
  /// isn't metered until the user signs in.
  final AccountSession? session;

  /// Presents sign-in on demand. Guests are prompted to sign in the first time
  /// they render (rendering is the metered action).
  final Future<AccountSession?> Function()? onRequestSignIn;

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

class _StudioScreenState extends State<StudioScreen>
    with SingleTickerProviderStateMixin {
  int _selectedScene = 0;

  /// Studio (full editor) vs Focus (distraction-free stage). From the design's
  /// top-bar layout toggle.
  bool _focus = false;

  // Preview playback: a ticker advances the playhead in real time.
  late final Ticker _ticker;
  bool _playing = false;
  Duration _lastTick = Duration.zero;

  /// Current pipeline stage (index into MockProject.stages). The studio opens on
  /// scene_plan; approving walks it forward to compose.
  late int _stage;

  /// The editable scene plan plus its edit history (for undo/redo).
  late List<Scene> _scenes;
  final List<List<Scene>> _undo = [];
  final List<List<Scene>> _redo = [];

  late final ConversationController _conversation;
  late String _projectName;
  late String _voice;
  List<String> _voices = const [];
  late String _runtime;
  List<String> _runtimes = const ['ffmpeg'];

  // The most recent render for this project, persisted with it.
  String? _renderPath;
  double? _renderSeconds;
  int? _renderBytes;

  bool _narrating = false;
  bool _revising = false;
  bool _fetchingImages = false;
  bool _generatingPresenter = false;
  bool _generatingVideo = false;

  /// The signed-in user's credit balance (null until loaded / when unmetered).
  CreditStatus? _credits;

  String get _stageName => MockProject.stages[_stage].name;
  bool get _atCompose => _stageName == 'compose';
  bool get _atPublish => _stageName == 'publish';

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
    _voice = widget.voice;
    _runtime = widget.runtime;
    _selectedScene = _scenes.length > 1 ? 1 : 0;
    _playhead = _scenes[_selectedScene].startSeconds;
    _ticker = createTicker(_onTick);
    // Discover available narration voices (best-effort).
    widget.tts.voices().then((v) {
      if (mounted && v.isNotEmpty) {
        setState(() {
          _voices = v;
          if (!v.contains(_voice)) _voice = v.first;
        });
      }
    });
    // Discover available render runtimes (ffmpeg / remotion).
    widget.render.runtimes().then((r) {
      if (mounted && r.isNotEmpty) {
        setState(() {
          _runtimes = r;
          // Empty = "auto": adopt the preferred (first) runtime, which is
          // Remotion when available.
          if (_runtime.isEmpty || !r.contains(_runtime)) _runtime = r.first;
        });
      }
    });
    _conversation = ConversationController(
      agent: widget.agent,
      seed: _seedConversation(),
    );
    // One-shot status probe so the top bar reflects reality on entry.
    widget.provider.probe();
    // Load the media-source choice so the Images action reflects it.
    widget.mediaSettings.load().then((_) {
      if (mounted) setState(() {});
    });
    // Load the credit balance so the top bar shows renders remaining.
    _refreshCredits();
    // Persist an initial record so the project shows up immediately.
    _save();
  }

  @override
  void didUpdateWidget(StudioScreen old) {
    super.didUpdateWidget(old);
    // A guest signed in (session appeared) — load their balance for the chip.
    if (old.session == null && widget.session != null) _refreshCredits();
  }

  Future<void> _refreshCredits() => _refreshCreditsWith(widget.session);

  Future<void> _refreshCreditsWith(AccountSession? session) async {
    if (session == null) return;
    try {
      final c = await session.credits();
      if (mounted) setState(() => _credits = c);
    } catch (_) {
      // Best-effort; the top bar simply omits the credit chip.
    }
  }

  /// A short label for the top-bar credit chip, or null when unmetered/Pro.
  String? get _creditsLabel {
    final c = _credits;
    if (c == null || c.isPro) return c?.isPro == true ? 'Pro' : null;
    return '${c.credits} free ${c.credits == 1 ? "render" : "renders"} left';
  }

  @override
  void dispose() {
    _ticker.dispose();
    _save(); // capture the latest text edits on the way out
    _conversation.dispose();
    super.dispose();
  }

  // --- Preview playback -------------------------------------------------------

  void _togglePlay() {
    if (_playing) {
      _stopPlayback();
      return;
    }
    if (_playhead >= _total) _playhead = 0; // restart from the top
    _lastTick = Duration.zero;
    _ticker.start();
    setState(() => _playing = true);
  }

  void _stopPlayback() {
    if (_ticker.isActive) _ticker.stop();
    _lastTick = Duration.zero;
    if (mounted) setState(() => _playing = false);
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    setState(() {
      _playhead += dt;
      if (_playhead >= _total) {
        _playhead = _total;
        _stopPlayback();
      }
      _syncSelectionToPlayhead();
    });
  }

  /// Keeps the selected scene aligned with where the playhead lands.
  void _syncSelectionToPlayhead() {
    for (var i = 0; i < _scenes.length; i++) {
      final s = _scenes[i];
      if (_playhead >= s.startSeconds && _playhead < s.endSeconds) {
        _selectedScene = i;
        return;
      }
    }
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
        voice: _voice,
        runtime: _runtime,
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

  void _selectScene(int index) {
    _stopPlayback();
    setState(() {
      _selectedScene = index;
      _playhead = _scenes[index].startSeconds;
    });
  }

  void _scrub(double seconds) {
    _stopPlayback();
    setState(() {
      _playhead = seconds;
      _syncSelectionToPlayhead();
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
          key: const Key('reviseInput'),
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
    if (_atPublish) {
      _exportFinal();
      return;
    }
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

  /// Opens the design's Export paywall modal; either tier proceeds to render.
  Future<void> _showExport() async {
    final tier = await showExportModal(context);
    if (tier == null || !mounted) return;
    await _openRender();
  }

  Future<void> _openRender() async {
    // Guests must sign in to render (rendering is the metered action). Prompt
    // on demand; if they cancel, don't render.
    var session = widget.session;
    if (session == null && widget.onRequestSignIn != null) {
      session = await widget.onRequestSignIn!();
      if (session == null) return; // cancelled sign-in
      if (mounted) await _refreshCreditsWith(session);
    }
    // Meter against the free credit allowance when signed in. A network error
    // fails open (never block a render over a connectivity blip).
    if (session != null) {
      try {
        var result = await session.consumeCredit();
        if (!result.allowed) {
          if (!mounted) return;
          final gained = await showPaywallSheet(
            context,
            session: session,
            status: result.status,
          );
          if (gained != true) {
            await _refreshCredits();
            return; // user didn't unlock more renders
          }
          // They earned credits via sharing — try once more.
          result = await session.consumeCredit();
          if (!result.allowed) {
            await _refreshCredits();
            return;
          }
        }
        if (mounted) setState(() => _credits = result.status);
      } catch (_) {
        // fail open
      }
    }
    if (!mounted) return;
    showRenderDialog(
      context,
      client: widget.render,
      provider: widget.provider,
      scenes: _renderPayload(),
      projectName: _projectName,
      voice: _voice,
      runtime: _runtime,
      branding: widget.branding,
      onComplete: (result) {
        _renderPath = result.path;
        _renderSeconds = result.seconds;
        _renderBytes = result.bytes;
        // A successful render advances the pipeline to its final stage.
        if (_atCompose) {
          final publishIndex = MockProject.stages.indexWhere(
            (s) => s.name == 'publish',
          );
          if (publishIndex >= 0) setState(() => _stage = publishIndex);
        }
        _save();
      },
    );
  }

  /// Publish: export a copy of the finished render to a location the user picks.
  Future<void> _exportFinal() async {
    if (_renderPath == null) {
      _toast('Render the video first (compose stage).');
      return;
    }
    final location = await getSaveLocation(
      suggestedName: '${_safeName(_projectName)}.mp4',
      acceptedTypeGroups: const [
        XTypeGroup(label: 'MP4 video', extensions: ['mp4']),
      ],
    );
    if (location == null) return;
    try {
      await File(_renderPath!).copy(location.path);
      if (!mounted) return;
      _toast('Published — exported to ${location.path}');
      _conversation.addAgentLine(
        'Published the final video.',
        artifact: 'publish · ${_safeName(_projectName)}.mp4',
      );
    } catch (_) {
      if (mounted) _toast('Could not export the file.');
    }
  }

  String _safeName(String name) =>
      name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');

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
          if (s.chartData.isNotEmpty)
            'chartData': [
              for (final d in s.chartData) {'label': d.label, 'value': d.value},
            ],
          if (s.imageUrl.isNotEmpty) 'imageUrl': s.imageUrl,
          if (s.clipPath.isNotEmpty) 'clipPath': s.clipPath,
        },
    ];
  }

  /// Lets the user attach their own video clip to the selected scene — the basis
  /// of people-based / UGC ads. A poster frame is extracted for the preview, and
  /// the clip renders behind the scene with the headline/subtitle as captions.
  Future<void> _uploadFootage() async {
    const group = XTypeGroup(
      label: 'Video',
      extensions: ['mp4', 'mov', 'm4v', 'webm'],
    );
    final file = await openFile(acceptedTypeGroups: const [group]);
    if (file == null) return;
    final thumb = await widget.render.extractThumbnail(file.path);
    if (!mounted) return;
    _updateScene(
      _scene.copyWith(
        clipPath: file.path,
        type: 'footage_clip',
        imageUrl: thumb ?? _scene.imageUrl,
      ),
    );
    _toast('Footage added to "${_scene.title}"');
  }

  /// Generates an AI digital-human presenter speaking the selected scene's copy
  /// and drops it in as the scene's footage (reusing the UGC clip pipeline).
  Future<void> _generatePresenter() async {
    if (_generatingPresenter) return;
    // Read fresh so the latest Settings choice is always reflected.
    final dh = DigitalHumanSettings();
    await dh.load();
    if (!dh.isActive) {
      _toast('Pick a digital-human source in Settings first.');
      return;
    }
    final scene = _scene;
    final script = [scene.headline, scene.subtitle]
        .where((s) => s.isNotEmpty)
        .join('. ');
    if (script.isEmpty) {
      _toast('Add a headline/subtitle for the presenter to say.');
      return;
    }
    setState(() => _generatingPresenter = true);
    _toast('Generating presenter… this can take a minute.');
    try {
      final clip = await dh.generate(script);
      if (!mounted) return;
      if (clip == null) {
        _toast('No presenter returned — check the source/key in Settings.');
        return;
      }
      final thumb = await widget.render.extractThumbnail(clip.path);
      if (!mounted) return;
      _updateScene(
        scene.copyWith(
          clipPath: clip.path,
          type: 'presenter',
          imageUrl: thumb ?? scene.imageUrl,
        ),
      );
      _toast('Digital human added to "${scene.title}"');
    } catch (e) {
      if (mounted) _toast('Presenter failed — check the source/key.');
    } finally {
      if (mounted) setState(() => _generatingPresenter = false);
    }
  }

  /// Generates real AI video (text/image→video) for the selected scene from its
  /// copy and drops it in as the scene's footage (reuses the UGC pipeline).
  Future<void> _generateVideo() async {
    if (_generatingVideo) return;
    final vs = VideoSettings();
    await vs.load();
    if (!vs.isActive) {
      _toast('Pick an AI-video source in Settings first.');
      return;
    }
    final scene = _scene;
    final prompt = [scene.headline, scene.subtitle]
        .where((s) => s.isNotEmpty)
        .join('. ');
    if (prompt.isEmpty) {
      _toast('Add a headline/subtitle to describe the video.');
      return;
    }
    setState(() => _generatingVideo = true);
    _toast('Generating AI video… this can take a few minutes.');
    try {
      final clip = await vs.generate(prompt, initImagePath: scene.imageUrl);
      if (!mounted) return;
      if (clip == null) {
        _toast('No video returned — check the source/key in Settings.');
        return;
      }
      final thumb = await widget.render.extractThumbnail(clip.path);
      if (!mounted) return;
      _updateScene(
        scene.copyWith(
          clipPath: clip.path,
          type: 'ai_video',
          imageUrl: thumb ?? scene.imageUrl,
        ),
      );
      _toast('AI video added to "${scene.title}"');
    } catch (e) {
      if (mounted) _toast('Video generation failed — check the source/key.');
    } finally {
      if (mounted) setState(() => _generatingVideo = false);
    }
  }

  /// Fetches a background image for every scene from the selected media source
  /// (using each scene's image query, falling back to its headline).
  Future<void> _fetchImages() async {
    if (_fetchingImages) return;
    await widget.mediaSettings.load();
    if (!widget.mediaSettings.isActive) {
      _toast('Pick an image source in Settings first.');
      return;
    }
    setState(() => _fetchingImages = true);
    var count = 0;
    try {
      for (var i = 0; i < _scenes.length; i++) {
        final s = _scenes[i];
        final query = s.imageQuery.isNotEmpty
            ? s.imageQuery
            : (s.headline.isNotEmpty ? s.headline : s.title);
        final image = await widget.mediaSettings.resolve(query);
        if (image != null && mounted) {
          setState(() {
            _scenes[i] = s.copyWith(imageUrl: image.url, imageQuery: query);
          });
          count++;
        }
      }
      if (mounted) {
        _save();
        _toast(
          count > 0
              ? 'Added images to $count scene${count == 1 ? '' : 's'}'
              : 'No images found — check the source/key in Settings.',
        );
      }
    } finally {
      if (mounted) setState(() => _fetchingImages = false);
    }
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
        voice: _voice,
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
            projectName: _projectName,
            provider: widget.provider,
            creditsLabel: _creditsLabel,
            focusMode: _focus,
            onToggleFocus: () => setState(() => _focus = !_focus),
            imagesEnabled: widget.mediaSettings.isActive,
            fetchingImages: _fetchingImages,
            onFetchImages: _fetchImages,
            onRetryServices: () async {
              await widget.provider.ensureRunning();
              await widget.provider.probe();
            },
            onHome: widget.onHome,
            onOpenSettings: widget.onOpenSettings,
            onRender: _openRender,
            onExport: _showExport,
          ),
          Expanded(
            child: Row(
              children: [
                if (!_focus)
                  StoryboardRail(
                    scenes: _scenes,
                    selectedIndex: _selectedScene,
                    onSelect: _selectScene,
                    onAddScene: _addScene,
                  ),
                Expanded(
                  child: PreviewStage(
                    scene: _scene,
                    playheadSeconds: _playhead,
                    totalSeconds: _total,
                    onScrub: _scrub,
                    isPlaying: _playing,
                    onTogglePlay: _togglePlay,
                  ),
                ),
                if (!_focus)
                  EditorPanel(
                    conversation: _conversation,
                    scene: _scene,
                    stageName: _stageName,
                    sceneIndex: _selectedScene,
                    sceneCount: _scenes.length,
                    approveLabel: _atPublish
                        ? 'Export video'
                        : _atCompose
                        ? 'Render'
                        : 'Approve & continue',
                    onApprove: _approveStage,
                    onSceneChanged: _updateScene,
                    onDurationChanged: _setDuration,
                    onAddScene: _addScene,
                    onDeleteScene: _deleteScene,
                    onMoveLeft: () => _moveScene(-1),
                    onMoveRight: () => _moveScene(1),
                    onGenerateNarration: _generateNarration,
                    narrating: _narrating,
                    voice: _voice,
                    voices: _voices,
                    onVoiceChanged: (v) {
                      setState(() => _voice = v);
                      _save();
                    },
                    runtime: _runtime,
                    runtimes: _runtimes,
                    onRuntimeChanged: (r) {
                      setState(() => _runtime = r);
                      _save();
                    },
                    onRevise: _revise,
                    revising: _revising,
                    onUploadFootage: _uploadFootage,
                    onGeneratePresenter: _generatePresenter,
                    generatingPresenter: _generatingPresenter,
                    onGenerateVideo: _generateVideo,
                    generatingVideo: _generatingVideo,
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
          if (!_focus) const _CapabilityBar(),
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
            '${cap.label} · ${cap.isConfigured ? "ready" : "roadmap"}',
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
