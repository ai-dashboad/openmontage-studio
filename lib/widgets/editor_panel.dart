import 'package:flutter/material.dart';
import '../models/studio_models.dart';
import '../services/agent_service.dart';
import '../services/conversation.dart';
import '../theme/app_theme.dart';
import 'storyboard_rail.dart' show DottedBorderBox;

/// The right-side control panel from the Open Montage editor design: a single
/// 344px column with five tabs — AI (the director chat), Scenes (the selected
/// scene's properties), Media, Brand, and Audio — over a persistent action
/// footer that holds the pipeline gate (approve/render/export), revise, and
/// undo/redo.
///
/// It consolidates what used to be three separate surfaces (the agent side
/// panel, the asset gallery, and the inspector) into one tabbed panel, matching
/// the design's information architecture.
class EditorPanel extends StatefulWidget {
  const EditorPanel({
    super.key,
    required this.conversation,
    required this.scene,
    required this.stageName,
    required this.onApprove,
    required this.onSceneChanged,
    required this.onDurationChanged,
    this.sceneIndex = 0,
    this.sceneCount = 1,
    this.onAddScene,
    this.onDeleteScene,
    this.onMoveLeft,
    this.onMoveRight,
    this.approveLabel = 'Approve & continue',
    this.onGenerateNarration,
    this.narrating = false,
    this.voice = 'Samantha',
    this.voices = const [],
    this.onVoiceChanged,
    this.runtime = 'ffmpeg',
    this.runtimes = const ['ffmpeg'],
    this.onRuntimeChanged,
    this.onRevise,
    this.revising = false,
    this.onUploadFootage,
    this.onGeneratePresenter,
    this.generatingPresenter = false,
    this.onGenerateVideo,
    this.generatingVideo = false,
    this.onPickPresenterPhoto,
    this.presenterPhotoSet = false,
    this.onUndo,
    this.onRedo,
    this.canUndo = false,
    this.canRedo = false,
  });

  final ConversationController conversation;
  final Scene scene;
  final String stageName;
  final VoidCallback onApprove;
  final ValueChanged<Scene> onSceneChanged;
  final ValueChanged<double> onDurationChanged;
  final int sceneIndex;
  final int sceneCount;
  final VoidCallback? onAddScene;
  final VoidCallback? onDeleteScene;
  final VoidCallback? onMoveLeft;
  final VoidCallback? onMoveRight;
  final String approveLabel;
  final VoidCallback? onGenerateNarration;
  final bool narrating;
  final String voice;
  final List<String> voices;
  final ValueChanged<String>? onVoiceChanged;
  final String runtime;
  final List<String> runtimes;
  final ValueChanged<String>? onRuntimeChanged;
  final VoidCallback? onRevise;
  final bool revising;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final VoidCallback? onUploadFootage;
  final VoidCallback? onGeneratePresenter;
  final bool generatingPresenter;
  final VoidCallback? onGenerateVideo;
  final bool generatingVideo;
  final VoidCallback? onPickPresenterPhoto;
  final bool presenterPhotoSet;
  final bool canUndo;
  final bool canRedo;

  @override
  State<EditorPanel> createState() => _EditorPanelState();
}

class _EditorPanelState extends State<EditorPanel> {
  /// Opens on Scenes — the storyboard editing surface — so a freshly entered
  /// project lands on the scene the timeline selected.
  int _tab = 1;

  static const _tabs = <({String label, IconData icon})>[
    (label: 'AI', icon: Icons.graphic_eq),
    (label: 'Scenes', icon: Icons.layers_outlined),
    (label: 'Media', icon: Icons.image_outlined),
    (label: 'Brand', icon: Icons.grid_view_rounded),
    (label: 'Audio', icon: Icons.equalizer),
  ];

  ({String title, String hint}) get _heading => switch (_tab) {
    0 => (title: 'Director', hint: 'AI'),
    1 => (
      title: 'Scenes',
      hint: '${widget.sceneIndex + 1}/${widget.sceneCount}',
    ),
    2 => (title: 'Media', hint: 'stock + uploads'),
    3 => (title: 'Brand kit', hint: 'Lumen'),
    _ => (title: 'Audio', hint: 'voice + music'),
  };

  @override
  Widget build(BuildContext context) {
    final h = _heading;
    return Container(
      width: 344,
      decoration: const BoxDecoration(
        color: AppColors.panel1,
        border: Border(left: BorderSide(color: AppColors.borderSoft)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _tabBar(),
          _panelHeader(h.title, h.hint),
          Expanded(child: _body()),
          _ActionFooter(
            approveLabel: widget.approveLabel,
            onApprove: widget.onApprove,
            onRevise: widget.onRevise,
            revising: widget.revising,
            onUndo: widget.canUndo ? widget.onUndo : null,
            onRedo: widget.canRedo ? widget.onRedo : null,
            runtime: widget.runtime,
            runtimes: widget.runtimes,
            onRuntimeChanged: widget.onRuntimeChanged,
          ),
        ],
      ),
    );
  }

  Widget _tabBar() {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.borderSoft)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < _tabs.length; i++)
            Expanded(
              child: _TabButton(
                icon: _tabs[i].icon,
                label: _tabs[i].label,
                active: _tab == i,
                onTap: () => setState(() => _tab = i),
              ),
            ),
        ],
      ),
    );
  }

  Widget _panelHeader(String title, String hint) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.borderSoft)),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: AppTheme.heading.copyWith(
              color: AppColors.textPrimary,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          Text(
            hint,
            style: AppTheme.mono.copyWith(
              color: AppColors.textFaint,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    return switch (_tab) {
      0 => _AiTab(conversation: widget.conversation),
      1 => _ScenesTab(
        scene: widget.scene,
        stageName: widget.stageName,
        sceneIndex: widget.sceneIndex,
        sceneCount: widget.sceneCount,
        onSceneChanged: widget.onSceneChanged,
        onDurationChanged: widget.onDurationChanged,
        onAddScene: widget.onAddScene,
        onDeleteScene: widget.onDeleteScene,
        onMoveLeft: widget.onMoveLeft,
        onMoveRight: widget.onMoveRight,
      ),
      2 => _MediaTab(
        onUpload: widget.onUploadFootage,
        onGeneratePresenter: widget.onGeneratePresenter,
        generatingPresenter: widget.generatingPresenter,
        onGenerateVideo: widget.onGenerateVideo,
        generatingVideo: widget.generatingVideo,
        onPickPresenterPhoto: widget.onPickPresenterPhoto,
        presenterPhotoSet: widget.presenterPhotoSet,
      ),
      3 => const _BrandTab(),
      _ => _AudioTab(
        voice: widget.voice,
        voices: widget.voices,
        onVoiceChanged: widget.onVoiceChanged,
        onGenerateNarration: widget.onGenerateNarration,
        narrating: widget.narrating,
      ),
    };
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.accent2 : AppColors.textMuted;
    return Tooltip(
      message: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
          decoration: BoxDecoration(
            color: active
                ? AppColors.accent.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 9.5,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Shared bits ------------------------------------------------------------

Widget _sectionLabel(String text) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Text(
    text,
    style: AppTheme.mono.copyWith(
      color: AppColors.textFaint,
      fontSize: 11,
      letterSpacing: 1.2,
    ),
  ),
);

// --- AI tab -----------------------------------------------------------------

class _AiTab extends StatefulWidget {
  const _AiTab({required this.conversation});
  final ConversationController conversation;

  @override
  State<_AiTab> createState() => _AiTabState();
}

class _AiTabState extends State<_AiTab> {
  final ScrollController _scroll = ScrollController();
  AgentStatus? _status;

  static const _suggestions = [
    'Punch up the hook',
    'Tighten to 15s',
    'More energetic',
    'Add a CTA',
  ];

  @override
  void initState() {
    super.initState();
    widget.conversation.addListener(_onChanged);
    _refreshStatus();
  }

  @override
  void dispose() {
    widget.conversation.removeListener(_onChanged);
    _scroll.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(_scrollToEnd);
  }

  Future<void> _refreshStatus() async {
    final s = await widget.conversation.agent.status();
    if (mounted) setState(() => _status = s);
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = widget.conversation.messages;
    final sending = widget.conversation.sending;
    return Column(
      children: [
        _StatusBar(status: _status),
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.all(12),
            children: [
              for (final m in messages) _Bubble(message: m),
              if (sending) const _Thinking(),
            ],
          ),
        ),
        _SuggestionChips(
          suggestions: _suggestions,
          onTap: sending ? null : (t) => widget.conversation.send(t),
        ),
        _Composer(
          enabled: !sending,
          onSend: (t) => widget.conversation.send(t),
        ),
      ],
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.status});
  final AgentStatus? status;

  @override
  Widget build(BuildContext context) {
    final connected = status?.connected ?? false;
    final color = connected ? AppColors.accentGreen : AppColors.accentAmber;
    final label = status == null
        ? 'connecting…'
        : connected
        ? status!.model
        : 'agent offline';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.borderSoft)),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.mono.copyWith(color: color, fontSize: 11),
            ),
          ),
          const Text(
            'local',
            style: TextStyle(color: AppColors.textFaint, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _SuggestionChips extends StatelessWidget {
  const _SuggestionChips({required this.suggestions, required this.onTap});
  final List<String> suggestions;
  final ValueChanged<String>? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        children: [
          for (final s in suggestions)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: onTap == null ? null : () => onTap!(s),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.panel2,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.borderStrong),
                  ),
                  child: Text(
                    s,
                    style: const TextStyle(
                      color: AppColors.accent2,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Thinking extends StatelessWidget {
  const _Thinking();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Row(
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.accent2,
            ),
          ),
          SizedBox(width: 8),
          Text(
            'Director is thinking…',
            style: TextStyle(color: AppColors.textFaint, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;
    final align = isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bg = isUser ? AppColors.panel3 : AppColors.panel2;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Text(
            isUser ? 'You' : 'Director',
            style: const TextStyle(color: AppColors.textFaint, fontSize: 10),
          ),
          const SizedBox(height: 3),
          Container(
            constraints: const BoxConstraints(maxWidth: 268),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderSoft),
            ),
            child: Text(
              message.text,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
          if (message.artifact != null) _ArtifactCard(label: message.artifact!),
        ],
      ),
    );
  }
}

class _ArtifactCard extends StatelessWidget {
  const _ArtifactCard({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.description_outlined,
            size: 16,
            color: AppColors.accent2,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: AppTheme.mono.copyWith(
                color: AppColors.textPrimary,
                fontSize: 12,
              ),
            ),
          ),
          const Icon(Icons.open_in_new, size: 14, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

class _Composer extends StatefulWidget {
  const _Composer({required this.enabled, required this.onSend});
  final bool enabled;
  final ValueChanged<String> onSend;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text;
    if (text.trim().isEmpty || !widget.enabled) return;
    _controller.clear();
    widget.onSend(text);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 4, 6, 4),
        decoration: BoxDecoration(
          color: AppColors.panel2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderStrong),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('agentComposer'),
                controller: _controller,
                enabled: widget.enabled,
                onSubmitted: (_) => _submit(),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13.5,
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Tell the director what to change…',
                  hintStyle: TextStyle(
                    color: AppColors.textFaint,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: widget.enabled ? _submit : null,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.accent2, AppColors.accent],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.arrow_upward,
                  size: 17,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Scenes tab -------------------------------------------------------------

class _ScenesTab extends StatefulWidget {
  const _ScenesTab({
    required this.scene,
    required this.stageName,
    required this.sceneIndex,
    required this.sceneCount,
    required this.onSceneChanged,
    required this.onDurationChanged,
    this.onAddScene,
    this.onDeleteScene,
    this.onMoveLeft,
    this.onMoveRight,
  });

  final Scene scene;
  final String stageName;
  final int sceneIndex;
  final int sceneCount;
  final ValueChanged<Scene> onSceneChanged;
  final ValueChanged<double> onDurationChanged;
  final VoidCallback? onAddScene;
  final VoidCallback? onDeleteScene;
  final VoidCallback? onMoveLeft;
  final VoidCallback? onMoveRight;

  @override
  State<_ScenesTab> createState() => _ScenesTabState();
}

class _ScenesTabState extends State<_ScenesTab> {
  late final TextEditingController _headline;
  late final TextEditingController _subtitle;
  late final TextEditingController _title;

  /// Selectable render types + friendly labels.
  static const List<(String, String)> _types = [
    ('hero_title', 'Hero title'),
    ('stat_card', 'Stat'),
    ('bar_chart', 'Bar chart'),
    ('pie_chart', 'Pie chart'),
    ('text_card', 'Text'),
    ('footage_clip', 'Footage'),
    ('ai_video', 'AI video'),
    ('presenter', 'Presenter'),
  ];

  static const List<Color> _accentChoices = [
    AppColors.accent,
    AppColors.accent2,
    AppColors.accentViolet,
    AppColors.accentSky,
    AppColors.accentAmber,
    AppColors.accentGreen,
  ];

  @override
  void initState() {
    super.initState();
    _headline = TextEditingController(text: widget.scene.headline);
    _subtitle = TextEditingController(text: widget.scene.subtitle);
    _title = TextEditingController(text: widget.scene.title);
  }

  @override
  void didUpdateWidget(_ScenesTab old) {
    super.didUpdateWidget(old);
    if (widget.scene.headline != _headline.text) {
      _headline.text = widget.scene.headline;
    }
    if (widget.scene.subtitle != _subtitle.text) {
      _subtitle.text = widget.scene.subtitle;
    }
    if (widget.scene.title != _title.text) {
      _title.text = widget.scene.title;
    }
  }

  @override
  void dispose() {
    _headline.dispose();
    _subtitle.dispose();
    _title.dispose();
    super.dispose();
  }

  /// A dropdown to change the scene's render type.
  Widget _typePicker() {
    final current = widget.scene.type;
    final ids = _types.map((t) => t.$1).toList();
    final value = ids.contains(current) ? current : _types.first.$1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          isDense: true,
          dropdownColor: AppColors.panel3,
          icon: const Icon(Icons.expand_more, size: 16, color: AppColors.textMuted),
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
          items: [
            for (final t in _types)
              DropdownMenuItem(value: t.$1, child: Text('${t.$2} · editing')),
          ],
          onChanged: (v) {
            if (v != null) widget.onSceneChanged(widget.scene.copyWith(type: v));
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      children: [
        _sceneOps(),
        const SizedBox(height: 10),
        _currentSceneCard(),
        const SizedBox(height: 8),
        _accentRow(),
        if (widget.scene.isChart)
          _ChartDataEditor(
            sceneId: widget.scene.id,
            data: widget.scene.chartData,
            accent: widget.scene.accent,
            onChanged: (d) =>
                widget.onSceneChanged(widget.scene.copyWith(chartData: d)),
          ),
      ],
    );
  }

  Widget _sceneOps() {
    final canDelete = widget.sceneCount > 1;
    final canLeft = widget.sceneIndex > 0;
    final canRight = widget.sceneIndex < widget.sceneCount - 1;
    return Row(
      children: [
        Text(
          'SCENE ${widget.sceneIndex + 1} / ${widget.sceneCount}',
          style: AppTheme.mono.copyWith(
            color: AppColors.textFaint,
            fontSize: 10,
            letterSpacing: 0.8,
          ),
        ),
        const Spacer(),
        _opButton(Icons.chevron_left, 'Move left', canLeft ? widget.onMoveLeft : null),
        _opButton(Icons.chevron_right, 'Move right', canRight ? widget.onMoveRight : null),
        _opButton(Icons.add, 'Add scene', widget.onAddScene),
        _opButton(
          Icons.delete_outline,
          'Delete scene',
          canDelete ? widget.onDeleteScene : null,
          danger: true,
        ),
      ],
    );
  }

  Widget _opButton(
    IconData icon,
    String tip,
    VoidCallback? onTap, {
    bool danger = false,
  }) {
    final enabled = onTap != null;
    return Tooltip(
      message: tip,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(
            icon,
            size: 17,
            color: !enabled
                ? AppColors.textFaint.withValues(alpha: 0.4)
                : danger
                ? AppColors.accentAmber
                : AppColors.textMuted,
          ),
        ),
      ),
    );
  }

  /// The highlighted "current scene" editor card from the design — carries the
  /// scene kind, the structured fields, and the duration stepper.
  Widget _currentSceneCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'S${widget.sceneIndex + 1}',
                style: AppTheme.mono.copyWith(
                  color: widget.scene.accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: _typePicker()),
            ],
          ),
          const SizedBox(height: 10),
          _textField('Title (kind)', _title, (v) {
            widget.onSceneChanged(widget.scene.copyWith(title: v));
          }, fieldKey: const Key('inspectorTitle')),
          const SizedBox(height: 10),
          _textField('Headline', _headline, (v) {
            widget.onSceneChanged(widget.scene.copyWith(headline: v));
          }, fieldKey: const Key('inspectorHeadline')),
          const SizedBox(height: 10),
          _textField('Caption', _subtitle, (v) {
            widget.onSceneChanged(widget.scene.copyWith(subtitle: v));
          }, maxLines: 2, fieldKey: const Key('inspectorSubtitle')),
          const SizedBox(height: 12),
          _duration(),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(
    text.toUpperCase(),
    style: AppTheme.mono.copyWith(
      color: AppColors.textFaint,
      fontSize: 10,
      letterSpacing: 0.8,
    ),
  );

  Widget _duration() {
    final seconds = widget.scene.durationSeconds;
    return Row(
      children: [
        _label('Duration'),
        const SizedBox(width: 10),
        Text(
          '${seconds.toStringAsFixed(1)}s',
          style: AppTheme.mono.copyWith(
            color: AppColors.textPrimary,
            fontSize: 13,
          ),
        ),
        const Spacer(),
        _stepButton(Icons.remove, () {
          widget.onDurationChanged((seconds - 0.5).clamp(1.0, 15.0));
        }),
        const SizedBox(width: 6),
        _stepButton(Icons.add, () {
          widget.onDurationChanged((seconds + 0.5).clamp(1.0, 15.0));
        }),
      ],
    );
  }

  Widget _stepButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.borderStrong),
        ),
        child: Icon(icon, size: 15, color: AppColors.textMuted),
      ),
    );
  }

  Widget _textField(
    String label,
    TextEditingController controller,
    ValueChanged<String> onChanged, {
    int maxLines = 1,
    Key? fieldKey,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        const SizedBox(height: 4),
        TextField(
          key: fieldKey,
          controller: controller,
          onChanged: onChanged,
          maxLines: maxLines,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            filled: true,
            fillColor: Colors.black.withValues(alpha: 0.25),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: const BorderSide(color: AppColors.borderStrong),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: const BorderSide(color: AppColors.accent),
            ),
          ),
        ),
      ],
    );
  }

  Widget _accentRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          _label('Accent'),
          const Spacer(),
          for (final c in _accentChoices) ...[
            _swatch(c),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _swatch(Color color) {
    final selected = widget.scene.accent.toARGB32() == color.toARGB32();
    return InkWell(
      borderRadius: BorderRadius.circular(5),
      onTap: () => widget.onSceneChanged(widget.scene.copyWith(accent: color)),
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: selected ? AppColors.textPrimary : Colors.transparent,
            width: 2,
          ),
        ),
      ),
    );
  }
}

// --- Media tab --------------------------------------------------------------

class _MediaTab extends StatelessWidget {
  const _MediaTab({
    this.onUpload,
    this.onGeneratePresenter,
    this.generatingPresenter = false,
    this.onGenerateVideo,
    this.generatingVideo = false,
    this.onPickPresenterPhoto,
    this.presenterPhotoSet = false,
  });
  final VoidCallback? onUpload;
  final VoidCallback? onGeneratePresenter;
  final bool generatingPresenter;
  final VoidCallback? onGenerateVideo;
  final bool generatingVideo;
  final VoidCallback? onPickPresenterPhoto;
  final bool presenterPhotoSet;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // Primary AI/footage actions first so they're never below the fold.
        _sectionLabel('AI VIDEO'),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: generatingVideo ? null : onGenerateVideo,
            icon: generatingVideo
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.movie_filter_outlined, size: 16),
            label: Text(generatingVideo ? 'Generating video…' : 'Generate AI video'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 11),
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Real generative video (text→motion) for the selected scene. Set a '
          'source in Settings — Veo/Runway with your key, or local (GPU).',
          style: TextStyle(color: AppColors.textFaint, fontSize: 11.5, height: 1.4),
        ),
        const SizedBox(height: 16),
        _sectionLabel('AI PRESENTER'),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: generatingPresenter ? null : onGeneratePresenter,
            icon: generatingPresenter
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.accent2,
                    ),
                  )
                : const Icon(Icons.face_retouching_natural, size: 16),
            label: Text(
              generatingPresenter ? 'Generating presenter…' : 'Generate digital human',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accent2,
              side: const BorderSide(color: AppColors.borderStrong),
              padding: const EdgeInsets.symmetric(vertical: 11),
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'AI-generated presenter speaking the selected scene’s copy. Set a '
          'source in Settings — local (free), or HeyGen/D-ID with your key.',
          style: TextStyle(color: AppColors.textFaint, fontSize: 11.5, height: 1.4),
        ),
        if (onPickPresenterPhoto != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onPickPresenterPhoto,
              icon: Icon(
                presenterPhotoSet
                    ? Icons.check_circle
                    : Icons.add_a_photo_outlined,
                size: 15,
              ),
              label: Text(presenterPhotoSet ? 'Your photo set' : 'Use my photo'),
              style: TextButton.styleFrom(
                foregroundColor: presenterPhotoSet
                    ? AppColors.accentGreen
                    : AppColors.accent2,
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
          ),
        const SizedBox(height: 16),
        _sectionLabel('YOUR FOOTAGE'),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onUpload,
          child: const DottedBorderBox(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.upload_outlined, size: 16, color: AppColors.textMuted),
                SizedBox(width: 6),
                Text(
                  'Upload your footage',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Your own clip renders behind the selected scene with the headline as '
          'a caption — the basis of real-person / UGC ads.',
          style: TextStyle(color: AppColors.textFaint, fontSize: 11.5, height: 1.4),
        ),
        const SizedBox(height: 16),
        _sectionLabel('STOCK'),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.panel2,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: AppColors.borderStrong),
          ),
          child: const Row(
            children: [
              Icon(Icons.search, size: 16, color: AppColors.textFaint),
              SizedBox(width: 8),
              Text(
                'Search stock library…',
                style: TextStyle(color: AppColors.textFaint, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 9,
          crossAxisSpacing: 9,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final m in MockProject.imageAssets)
              _MediaTile(label: m.label, accent: m.accent),
            _MediaTile(label: 'Skyline', accent: AppColors.accentSky),
          ],
        ),
      ],
    );
  }
}

class _MediaTile extends StatelessWidget {
  const _MediaTile({required this.label, required this.accent});
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.7),
            accent.withValues(alpha: 0.25),
          ],
        ),
      ),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            label,
            style: AppTheme.mono.copyWith(color: Colors.white, fontSize: 10),
          ),
        ),
      ),
    );
  }
}

// --- Brand tab --------------------------------------------------------------

class _BrandTab extends StatelessWidget {
  const _BrandTab();

  static const _colors = <({String name, Color hex})>[
    (name: 'Indigo', hex: AppColors.accent),
    (name: 'Periwinkle', hex: AppColors.accent2),
    (name: 'Violet', hex: AppColors.accentViolet),
    (name: 'Sky', hex: AppColors.accentSky),
    (name: 'Ink', hex: AppColors.app),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                gradient: const LinearGradient(
                  colors: [AppColors.accent2, AppColors.accentViolet],
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                'L',
                style: AppTheme.heading.copyWith(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lumen',
                  style: AppTheme.heading.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Active brand kit',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 18),
        _sectionLabel('COLORS'),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final c in _colors)
              Column(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: c.hex,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.borderStrong),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    c.name,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 18),
        _sectionLabel('TYPEFACES'),
        _typeCard('Space Grotesk', 'Headlines · captions', AppTheme.heading),
        const SizedBox(height: 8),
        _typeCard(
          'Geist',
          'Body · supporting copy',
          const TextStyle(fontFamily: 'Geist', fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _typeCard(String name, String role, TextStyle style) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.panel2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: style.copyWith(color: AppColors.textPrimary, fontSize: 19),
          ),
          const SizedBox(height: 3),
          Text(
            role,
            style: const TextStyle(color: AppColors.textFaint, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// --- Audio tab --------------------------------------------------------------

class _AudioTab extends StatelessWidget {
  const _AudioTab({
    required this.voice,
    required this.voices,
    required this.onVoiceChanged,
    required this.onGenerateNarration,
    required this.narrating,
  });

  final String voice;
  final List<String> voices;
  final ValueChanged<String>? onVoiceChanged;
  final VoidCallback? onGenerateNarration;
  final bool narrating;

  @override
  Widget build(BuildContext context) {
    final shown = voices.isEmpty ? [voice] : voices.take(4).toList();
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _sectionLabel('VOICEOVER'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final v in shown)
              _VoiceChip(
                label: v,
                selected: v == voice,
                onTap: () => onVoiceChanged?.call(v),
              ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: narrating ? null : onGenerateNarration,
            icon: narrating
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.accent,
                    ),
                  )
                : const Icon(Icons.graphic_eq, size: 16),
            label: Text(narrating ? 'Synthesizing…' : 'Generate narration'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accent2,
              side: const BorderSide(color: AppColors.borderStrong),
              padding: const EdgeInsets.symmetric(vertical: 11),
            ),
          ),
        ),
        const SizedBox(height: 18),
        _sectionLabel('MUSIC'),
        Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: AppColors.panel2,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderSoft),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.music_note,
                  size: 18,
                  color: AppColors.accent2,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Momentum — Pulse',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Upbeat · 124 BPM · licensed',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.textFaint, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          decoration: BoxDecoration(
            color: AppColors.panel2,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderSoft),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Auto-captions',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                'On · synced',
                style: TextStyle(
                  color: AppColors.accent2,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VoiceChip extends StatelessWidget {
  const _VoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.16)
              : AppColors.panel2,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.accent2 : AppColors.borderStrong,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.record_voice_over,
              size: 13,
              color: selected ? AppColors.accent2 : AppColors.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.textPrimary : AppColors.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Action footer ----------------------------------------------------------

/// The persistent action area below the tabs: the optional render-engine
/// toggle, the pipeline stage action (approve/render/export), revise, and
/// undo/redo. Always visible regardless of the active tab so the primary CTA is
/// never hidden behind one.
class _ActionFooter extends StatelessWidget {
  const _ActionFooter({
    required this.approveLabel,
    required this.onApprove,
    required this.onRevise,
    required this.revising,
    required this.onUndo,
    required this.onRedo,
    required this.runtime,
    required this.runtimes,
    required this.onRuntimeChanged,
  });

  final String approveLabel;
  final VoidCallback onApprove;
  final VoidCallback? onRevise;
  final bool revising;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final String runtime;
  final List<String> runtimes;
  final ValueChanged<String>? onRuntimeChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.borderSoft)),
      ),
      child: Column(
        children: [
          if (runtimes.length > 1) ...[
            _runtimePicker(),
            const SizedBox(height: 8),
          ],
          SizedBox(
            width: double.infinity,
            child: _GradientButton(
              label: approveLabel,
              icon: Icons.check,
              onPressed: onApprove,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: revising ? null : onRevise,
              icon: revising
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accent2,
                      ),
                    )
                  : const Icon(Icons.auto_fix_high, size: 16),
              label: Text(revising ? 'Revising…' : 'Revise with agent'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accent2,
                side: const BorderSide(color: AppColors.borderStrong),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onUndo,
                  icon: const Icon(Icons.undo, size: 16),
                  label: const Text('Undo'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textMuted,
                    side: const BorderSide(color: AppColors.borderStrong),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onRedo,
                  icon: const Icon(Icons.redo, size: 16),
                  label: const Text('Redo'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textMuted,
                    side: const BorderSide(color: AppColors.borderStrong),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _runtimePicker() {
    Widget seg(String value, String label, IconData icon) {
      final selected = runtime == value;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(7),
          onTap: selected ? null : () => onRuntimeChanged?.call(value),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.accent.withValues(alpha: 0.16)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: selected ? AppColors.accent2 : AppColors.textMuted,
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? AppColors.accent2 : AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.panel2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Row(
        children: [
          seg('ffmpeg', 'Fast', Icons.bolt),
          seg('remotion', 'Cinematic', Icons.auto_awesome),
        ],
      ),
    );
  }
}

/// The design's primary gradient CTA (indigo → violet) used for the stage
/// action, mirroring the top-bar Export button.
class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.accent2, AppColors.accent, AppColors.accentViolet],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.45),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

// --- Chart data editor (chart scenes) --------------------------------------

class _ChartDataEditor extends StatefulWidget {
  const _ChartDataEditor({
    required this.sceneId,
    required this.data,
    required this.accent,
    required this.onChanged,
  });

  final String sceneId;
  final List<ChartDatum> data;
  final Color accent;
  final ValueChanged<List<ChartDatum>> onChanged;

  @override
  State<_ChartDataEditor> createState() => _ChartDataEditorState();
}

class _ChartDataEditorState extends State<_ChartDataEditor> {
  late List<TextEditingController> _labels;
  late List<TextEditingController> _values;

  @override
  void initState() {
    super.initState();
    _seed();
  }

  @override
  void didUpdateWidget(_ChartDataEditor old) {
    super.didUpdateWidget(old);
    if (old.sceneId != widget.sceneId ||
        old.data.length != widget.data.length) {
      _disposeControllers();
      _seed();
    }
  }

  void _seed() {
    _labels = [
      for (final d in widget.data) TextEditingController(text: d.label),
    ];
    _values = [
      for (final d in widget.data) TextEditingController(text: _fmt(d.value)),
    ];
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  void _disposeControllers() {
    for (final c in _labels) {
      c.dispose();
    }
    for (final c in _values) {
      c.dispose();
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _emit() {
    widget.onChanged([
      for (var i = 0; i < _labels.length; i++)
        ChartDatum(
          label: _labels[i].text,
          value: double.tryParse(_values[i].text.trim()) ?? 0,
        ),
    ]);
  }

  void _add() {
    widget.onChanged([
      ...widget.data,
      const ChartDatum(label: 'Item', value: 10),
    ]);
  }

  void _removeAt(int i) {
    widget.onChanged([...widget.data]..removeAt(i));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'CHART DATA',
                style: AppTheme.mono.copyWith(
                  color: AppColors.textFaint,
                  fontSize: 10,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              InkWell(
                key: const Key('chartAddRow'),
                borderRadius: BorderRadius.circular(6),
                onTap: _add,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.add, size: 16, color: AppColors.accent2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (var i = 0; i < _labels.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: widget.accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: _miniField(_labels[i], (_) => _emit()),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 2,
                    child: _miniField(_values[i], (_) => _emit(), numeric: true),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => _removeAt(i),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.close,
                        size: 14,
                        color: AppColors.textFaint,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _miniField(
    TextEditingController controller,
    ValueChanged<String> onChanged, {
    bool numeric = false,
  }) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: numeric ? TextInputType.number : null,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.25),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.borderStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.accent),
        ),
      ),
    );
  }
}
