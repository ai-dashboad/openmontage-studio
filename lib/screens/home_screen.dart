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
  });

  final AgentService agent;
  final ProviderManager provider;
  final ProjectStore projects;
  final void Function(List<Scene>? scenes, String? brief) onOpenProject;
  final ValueChanged<StudioProject> onReopenProject;
  final VoidCallback onOpenSettings;

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

  Future<void> _create() async {
    final brief = _brief.text.trim();
    // No brief, or already working: open the sample project.
    if (brief.isEmpty) {
      widget.onOpenProject(null, null);
      return;
    }
    setState(() => _planning = true);
    try {
      final scenes = await widget.agent.planScenes(brief);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
            children: [
              _Header(onOpenSettings: widget.onOpenSettings),
              if (_update != null) ...[
                const SizedBox(height: 16),
                _UpdateBanner(info: _update!),
              ],
              const SizedBox(height: 28),
              _NewProjectCard(
                controller: _brief,
                planning: _planning,
                onCreate: _create,
              ),
              const SizedBox(height: 20),
              _EngineStatus(
                provider: widget.provider,
                onRetry: () async {
                  await widget.provider.ensureRunning();
                  await widget.provider.probe();
                },
              ),
              const SizedBox(height: 32),
              const _SectionLabel('Capabilities'),
              const SizedBox(height: 12),
              const _CapabilityGrid(),
              const SizedBox(height: 32),
              const _SectionLabel('Your projects'),
              const SizedBox(height: 12),
              _ProjectList(
                items: _projects,
                onReopen: widget.onReopenProject,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onOpenSettings});
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.blur_circular, color: AppColors.accentCyan, size: 30),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'OpenMontage Studio',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'AI-orchestrated video production',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ],
        ),
        const Spacer(),
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

class _NewProjectCard extends StatelessWidget {
  const _NewProjectCard({
    required this.controller,
    required this.planning,
    required this.onCreate,
  });
  final TextEditingController controller;
  final bool planning;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        gradient: const LinearGradient(
          colors: [Color(0xFF15233B), AppColors.surface],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Start a new video',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TextField(
                    controller: controller,
                    enabled: !planning,
                    onSubmitted: (_) => onCreate(),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText:
                          'Describe your video — e.g. "a 30s explainer on black holes"',
                      hintStyle: TextStyle(
                        color: AppColors.textFaint,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: planning ? null : onCreate,
                icon: planning
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.background,
                        ),
                      )
                    : const Icon(Icons.auto_awesome, size: 18),
                label: Text(planning ? 'Planning…' : 'Create'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accentCyan,
                  foregroundColor: AppColors.background,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                ),
              ),
            ],
          ),
        ],
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

class _CapabilityGrid extends StatelessWidget {
  const _CapabilityGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.6,
      children: [
        for (final cap in MockProject.capabilities) _CapabilityCard(cap: cap),
      ],
    );
  }
}

class _CapabilityCard extends StatelessWidget {
  const _CapabilityCard({required this.cap});
  final Capability cap;

  @override
  Widget build(BuildContext context) {
    final ok = cap.isConfigured;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Text(
                cap.label,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (cap.isLocalReady)
                const Icon(
                  Icons.computer,
                  size: 13,
                  color: AppColors.accentCyan,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                ok ? 'Ready' : 'Roadmap',
                style: AppTheme.mono.copyWith(
                  color: ok ? AppColors.accentGreen : AppColors.textFaint,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  cap.detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textFaint,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ],
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
