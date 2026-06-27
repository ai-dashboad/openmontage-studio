import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/studio_models.dart';
import '../services/agent_service.dart';
import '../services/project_store.dart';
import '../services/provider_manager.dart';
import '../services/update_checker.dart';
import '../theme/app_theme.dart';

/// The launcher: a brief composer to start a video, a live engine status, and
/// recent renders. This is the "what can you do" entry point.
///
/// Submitting a brief asks the agent to draft a scene plan; [onOpenProject] is
/// called with that plan (or null to open the sample) plus the brief text, and
/// opens the studio.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.agent,
    required this.provider,
    required this.projects,
    required this.onOpenProject,
    required this.onReopenProject,
    required this.onOpenSettings,
    this.updateChecker,
    this.onSignIn,
  });

  final AgentService agent;
  final ProviderManager provider;
  final ProjectStore projects;
  final void Function(List<Scene>? scenes, String? brief) onOpenProject;
  final ValueChanged<StudioProject> onReopenProject;
  final VoidCallback onOpenSettings;

  /// When set (guest mode), the header shows a "Sign in" affordance.
  final VoidCallback? onSignIn;

  /// When provided, the home checks for a newer release and shows a banner.
  final UpdateChecker? updateChecker;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _brief = TextEditingController();
  bool _planning = false;
  UpdateInfo? _update;
  List<StudioProject> _projects = const [];

  @override
  void initState() {
    super.initState();
    _checkForUpdate();
    widget.provider.probe();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    final items = await widget.projects.load();
    if (mounted) setState(() => _projects = items);
  }

  Future<void> _checkForUpdate() async {
    final checker = widget.updateChecker;
    if (checker == null) return;
    final info = await checker.check();
    if (mounted && info != null && info.available) {
      setState(() => _update = info);
    }
  }

  @override
  void dispose() {
    _brief.dispose();
    super.dispose();
  }

  Future<void> _create() => _createWith('');

  /// Plans a scene plan from the brief plus an optional spec [suffix] carrying
  /// the chosen format / length / tone, then opens the studio.
  Future<void> _createWith(String suffix) async {
    final brief = _brief.text.trim();
    // No brief, or already working: open the sample project.
    if (brief.isEmpty) {
      widget.onOpenProject(null, null);
      return;
    }
    setState(() => _planning = true);
    try {
      final scenes = await widget.agent.planScenes('$brief$suffix');
      if (!mounted) return;
      widget.onOpenProject(scenes, brief);
    } catch (_) {
      // Agent unreachable or unparseable — fall back to the sample plan.
      if (!mounted) return;
      widget.onOpenProject(null, brief);
    } finally {
      if (mounted) setState(() => _planning = false);
    }
  }

  /// One-click start from an example prompt.
  void _useExample(String prompt) {
    if (_planning) return;
    _brief.text = prompt;
    _create();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
            children: [
              _Header(
                onOpenSettings: widget.onOpenSettings,
                onSignIn: widget.onSignIn,
              ),
              if (_update != null) ...[
                const SizedBox(height: 16),
                _UpdateBanner(info: _update!),
              ],
              const SizedBox(height: 44),
              _BriefHero(
                controller: _brief,
                planning: _planning,
                onGenerate: _createWith,
                onExample: _useExample,
              ),
              const SizedBox(height: 40),
              if (_projects.isNotEmpty) ...[
                const _SectionLabel('Your projects'),
                const SizedBox(height: 12),
                _ProjectList(
                  items: _projects,
                  onReopen: widget.onReopenProject,
                ),
                const SizedBox(height: 24),
              ],
              _EngineStatus(
                provider: widget.provider,
                onRetry: () async {
                  await widget.provider.ensureRunning();
                  await widget.provider.probe();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onOpenSettings, this.onSignIn});
  final VoidCallback onOpenSettings;
  final VoidCallback? onSignIn;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.accent2, AppColors.accent],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.4),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 11),
        Text(
          'Open Montage',
          style: AppTheme.heading.copyWith(
            color: AppColors.textPrimary,
            fontSize: 18,
          ),
        ),
        const SizedBox(width: 11),
        Container(
          padding: const EdgeInsets.only(left: 11),
          decoration: const BoxDecoration(
            border: Border(left: BorderSide(color: AppColors.borderSoft)),
          ),
          child: Text(
            'AI AD STUDIO',
            style: AppTheme.mono.copyWith(
              color: AppColors.textFaint,
              fontSize: 11,
              letterSpacing: 1.0,
            ),
          ),
        ),
        const Spacer(),
        if (onSignIn != null) ...[
          TextButton(
            onPressed: onSignIn,
            child: const Text(
              'Sign in',
              style: TextStyle(color: AppColors.accentCyan),
            ),
          ),
          const SizedBox(width: 4),
        ],
        OutlinedButton.icon(
          onPressed: onOpenSettings,
          icon: const Icon(Icons.settings_outlined, size: 16),
          label: const Text('Settings'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textMuted,
            side: const BorderSide(color: AppColors.border),
          ),
        ),
      ],
    );
  }
}

/// The Brief screen ("Open Montage" design): a director-style prompt with
/// FORMAT / LENGTH / TONE controls and one-click examples. The selections are
/// folded into the brief so the agent directs to spec.
class _BriefHero extends StatefulWidget {
  const _BriefHero({
    required this.controller,
    required this.planning,
    required this.onGenerate,
    required this.onExample,
  });
  final TextEditingController controller;
  final bool planning;
  final ValueChanged<String> onGenerate;
  final ValueChanged<String> onExample;

  @override
  State<_BriefHero> createState() => _BriefHeroState();
}

class _BriefHeroState extends State<_BriefHero> {
  static const _formats = [
    ('9:16', 'Reels'),
    ('1:1', 'Square'),
    ('16:9', 'Wide'),
  ];
  static const _lengths = ['10s', '15s', '30s'];
  static const _tones = ['Bold', 'Playful', 'Premium', 'Calm'];
  static const _examples = [
    'A 15-second Reels ad for our AI productivity app launch',
    'A punchy product drop for a new sneaker',
    'A founder-led teaser for our seed round',
  ];

  int _fmt = 0, _len = 1, _tone = 0; // default 15s to match the sample copy

  void _generate() {
    final f = _formats[_fmt];
    final suffix =
        ' — Make it a ${_lengths[_len]} ${f.$2} (${f.$1}) ad, '
        '${_tones[_tone].toLowerCase()} tone.';
    widget.onGenerate(suffix);
  }

  @override
  Widget build(BuildContext context) {
    final planning = widget.planning;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'DESCRIBE IT · WE DIRECT IT',
          style: AppTheme.mono.copyWith(
            color: AppColors.accent2,
            fontSize: 12,
            letterSpacing: 2.4,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'What ad are we making today?',
          textAlign: TextAlign.center,
          style: AppTheme.heading.copyWith(
            color: AppColors.textPrimary,
            fontSize: 40,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Write a brief in plain language. Open Montage scripts it, '
          'storyboards the scenes, picks the footage, and lays it on a '
          'timeline you can edit.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 15,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 28),
        // Input card with a control bar — the heart of the Brief screen.
        Container(
          decoration: BoxDecoration(
            color: AppColors.panel1,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.borderSoft),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 60,
                offset: Offset(0, 26),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: TextField(
                  controller: widget.controller,
                  enabled: !planning,
                  autofocus: true,
                  maxLines: 3,
                  minLines: 2,
                  onSubmitted: (_) => _generate(),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    height: 1.5,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText:
                        'e.g. A 15-second Reels ad for our app launch — fast, '
                        'bold, ending on a free-trial CTA.',
                    hintStyle: TextStyle(color: AppColors.textFaint, fontSize: 16),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.borderSoft)),
                ),
                child: Wrap(
                  spacing: 22,
                  runSpacing: 16,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                    _ControlGroup(
                      label: 'FORMAT',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < _formats.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: _Chip(
                                active: _fmt == i,
                                onTap: planning
                                    ? null
                                    : () => setState(() => _fmt = i),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(_formats[i].$1,
                                        style: AppTheme.mono.copyWith(
                                            color: AppColors.textPrimary,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600)),
                                    Text(_formats[i].$2,
                                        style: const TextStyle(
                                            color: AppColors.textMuted,
                                            fontSize: 10)),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    _ControlGroup(
                      label: 'LENGTH',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < _lengths.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: _Chip(
                                active: _len == i,
                                onTap: planning
                                    ? null
                                    : () => setState(() => _len = i),
                                child: Text(_lengths[i],
                                    style: AppTheme.mono.copyWith(
                                        color: AppColors.textPrimary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ),
                        ],
                      ),
                    ),
                    _ControlGroup(
                      label: 'TONE',
                      child: _Chip(
                        active: false,
                        onTap: planning
                            ? null
                            : () => setState(
                                () => _tone = (_tone + 1) % _tones.length),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_tones[_tone],
                                style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500)),
                            const SizedBox(width: 6),
                            const Text('▾',
                                style: TextStyle(
                                    color: AppColors.textFaint, fontSize: 10)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 220, height: 0), // spacer pushes CTA
                    FilledButton.icon(
                      onPressed: planning ? null : _generate,
                      icon: planning
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.auto_awesome, size: 17),
                      label: Text(planning ? 'Directing…' : 'Generate ad'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 22, vertical: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 9,
          runSpacing: 9,
          alignment: WrapAlignment.center,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 7, right: 2),
              child: Text('Try:',
                  style: TextStyle(color: AppColors.textFaint, fontSize: 12.5)),
            ),
            for (final ex in _examples)
              _ExampleChip(
                  label: ex,
                  onTap: planning ? null : () => widget.onExample(ex)),
          ],
        ),
      ],
    );
  }
}

/// A labeled control group: a small mono caption above its control row.
class _ControlGroup extends StatelessWidget {
  const _ControlGroup({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: AppTheme.mono.copyWith(
                color: AppColors.textFaint, fontSize: 10, letterSpacing: 1.4)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

/// A selectable pill in the control bar; indigo ring + tint when active.
class _Chip extends StatelessWidget {
  const _Chip({required this.active, required this.onTap, required this.child});
  final bool active;
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? AppColors.accent.withValues(alpha: 0.14)
              : AppColors.panel2,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: active ? AppColors.accent : AppColors.borderStrong,
            width: active ? 1.5 : 1,
          ),
        ),
        child: child,
      ),
    );
  }
}

class _ExampleChip extends StatelessWidget {
  const _ExampleChip({required this.label, this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ),
      ),
    );
  }
}

class _UpdateBanner extends StatelessWidget {
  const _UpdateBanner({required this.info});
  final UpdateInfo info;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.accentCyan.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accentCyan.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.system_update_alt,
            size: 18,
            color: AppColors.accentCyan,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Version ${info.latest} is available'
              '${info.notes != null && info.notes!.isNotEmpty ? ' · ${info.notes}' : ''}',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
              ),
            ),
          ),
          FilledButton(
            onPressed: info.url.isEmpty
                ? null
                : () => launchUrl(
                    Uri.parse(info.url),
                    mode: LaunchMode.externalApplication,
                  ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accentCyan,
              foregroundColor: AppColors.background,
            ),
            child: const Text('Download'),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: AppColors.textFaint,
        fontSize: 12,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

/// Live status of the two local engines, reflecting real health checks so the
/// home screen tells the truth about what will work right now.
class _EngineStatus extends StatelessWidget {
  const _EngineStatus({required this.provider, required this.onRetry});
  final ProviderManager provider;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: provider,
      builder: (context, _) {
        final starting = provider.mediaPhase == MediaPhase.starting;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.bolt, size: 16, color: AppColors.accentCyan),
              const SizedBox(width: 8),
              const Text(
                'Local engine',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
              ),
              const SizedBox(width: 16),
              _pill('Agent', provider.agentUp, false),
              const SizedBox(width: 8),
              _pill('Voice + Render', provider.mediaUp, starting),
              const Spacer(),
              if (!provider.mediaUp && !starting)
                TextButton(
                  onPressed: onRetry,
                  child: const Text(
                    'Start',
                    style: TextStyle(color: AppColors.accentCyan),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _pill(String label, bool up, bool starting) {
    final color = starting
        ? AppColors.accentAmber
        : up
        ? AppColors.accentGreen
        : AppColors.textFaint;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            starting ? '$label · starting…' : label,
            style: TextStyle(color: color, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

/// Saved projects; clicking a row reopens it for editing, the play button (when
/// a render exists) opens the finished file.
class _ProjectList extends StatelessWidget {
  const _ProjectList({required this.items, required this.onReopen});
  final List<StudioProject> items;
  final ValueChanged<StudioProject> onReopen;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: const Row(
          children: [
            Icon(Icons.movie_outlined, color: AppColors.textFaint, size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'No projects yet — describe a video above to start your first one.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [for (final p in items) _ProjectRow(project: p, onReopen: onReopen)],
    );
  }
}

class _ProjectRow extends StatelessWidget {
  const _ProjectRow({required this.project, required this.onReopen});
  final StudioProject project;
  final ValueChanged<StudioProject> onReopen;

  static const _stages = [
    'idea',
    'script',
    'scene_plan',
    'assets',
    'edit',
    'compose',
    'publish',
  ];

  String _when() {
    final ts = DateTime.tryParse(project.updatedAtIso);
    if (ts == null) return '';
    final d = DateTime.now().difference(ts);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final stageName = _stages[project.stageIndex.clamp(0, _stages.length - 1)];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => onReopen(project),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.accentCyan.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    project.hasRender ? Icons.movie : Icons.edit_note,
                    color: AppColors.accentCyan,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        project.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${project.scenes.length} scenes · $stageName · ${_when()}',
                        style: const TextStyle(
                          color: AppColors.textFaint,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (project.hasRender)
                  IconButton(
                    tooltip: 'Play render',
                    onPressed: () => launchUrl(Uri.file(project.renderPath!)),
                    icon: const Icon(
                      Icons.play_circle_outline,
                      color: AppColors.accentCyan,
                      size: 20,
                    ),
                  ),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.textFaint,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
