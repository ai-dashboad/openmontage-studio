import 'package:flutter/material.dart';
import '../models/studio_models.dart';
import '../theme/app_theme.dart';

/// Region D — the inspector. Shows the selected scene's structured properties
/// (the editable slice of the `scene_plan` artifact) and the approval gate that
/// advances the pipeline. Editing a field flows back through [onSceneChanged]
/// so the preview and timeline update live.
class Inspector extends StatefulWidget {
  const Inspector({
    super.key,
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
    this.onRevise,
    this.revising = false,
    this.onUndo,
    this.onRedo,
    this.canUndo = false,
    this.canRedo = false,
  });

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
  final VoidCallback? onRevise;
  final bool revising;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final bool canUndo;
  final bool canRedo;

  @override
  State<Inspector> createState() => _InspectorState();
}

class _InspectorState extends State<Inspector> {
  late final TextEditingController _headline;
  late final TextEditingController _subtitle;

  static const List<Color> _accentChoices = [
    AppColors.accentCyan,
    AppColors.accentPurple,
    AppColors.accentAmber,
    AppColors.accentGreen,
  ];

  @override
  void initState() {
    super.initState();
    _headline = TextEditingController(text: widget.scene.headline);
    _subtitle = TextEditingController(text: widget.scene.subtitle);
  }

  @override
  void didUpdateWidget(Inspector old) {
    super.didUpdateWidget(old);
    // Reseed only when the value changed from outside (scene switch or an agent
    // revision); typing keeps controller and scene in sync, so this won't fire
    // mid-keystroke and won't move the cursor.
    if (widget.scene.headline != _headline.text) {
      _headline.text = widget.scene.headline;
    }
    if (widget.scene.subtitle != _subtitle.text) {
      _subtitle.text = widget.scene.subtitle;
    }
  }

  @override
  void dispose() {
    _headline.dispose();
    _subtitle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 268,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(left: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _sceneOps(),
                _field('Scene', widget.scene.title),
                _field('Type', widget.scene.type, mono: true),
                _duration(),
                const SizedBox(height: 4),
                _textField('Headline', _headline, (v) {
                  widget.onSceneChanged(widget.scene.copyWith(headline: v));
                }),
                _textField('Subtitle', _subtitle, (v) {
                  widget.onSceneChanged(widget.scene.copyWith(subtitle: v));
                }, maxLines: 2),
                _accentRow(),
              ],
            ),
          ),
          _approvalGate(),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'INSPECTOR',
            style: TextStyle(
              color: AppColors.textFaint,
              fontSize: 11,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.stageName,
            style: AppTheme.mono.copyWith(
              color: AppColors.accentCyan,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(String label, String value, {bool mono = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label),
          const SizedBox(height: 4),
          Text(
            value,
            style: (mono ? AppTheme.mono : const TextStyle()).copyWith(
              color: AppColors.textPrimary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  /// Scene index + structural ops: move, add, delete.
  Widget _sceneOps() {
    final canDelete = widget.sceneCount > 1;
    final canLeft = widget.sceneIndex > 0;
    final canRight = widget.sceneIndex < widget.sceneCount - 1;
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Row(
        children: [
          Text(
            'SCENE ${widget.sceneIndex + 1} / ${widget.sceneCount}',
            style: const TextStyle(
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
      ),
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

  Widget _label(String text) => Text(
    text.toUpperCase(),
    style: const TextStyle(
      color: AppColors.textFaint,
      fontSize: 10,
      letterSpacing: 0.8,
    ),
  );

  /// A stepper for the scene duration; nudging it re-flows the whole timeline.
  Widget _duration() {
    final seconds = widget.scene.durationSeconds;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Duration'),
          const SizedBox(height: 4),
          Row(
            children: [
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
          ),
        ],
      ),
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
          color: AppColors.background,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.border),
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
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label),
          const SizedBox(height: 4),
          TextField(
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
              fillColor: AppColors.background,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppColors.accentCyan),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _accentRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
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

  Widget _approvalGate() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: widget.narrating ? null : widget.onGenerateNarration,
              icon: widget.narrating
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accentCyan,
                      ),
                    )
                  : const Icon(Icons.graphic_eq, size: 16),
              label: Text(
                widget.narrating ? 'Synthesizing…' : 'Generate narration',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accentCyan,
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: widget.onApprove,
              icon: const Icon(Icons.check, size: 18),
              label: Text(widget.approveLabel),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accentGreen,
                foregroundColor: AppColors.background,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: widget.revising ? null : widget.onRevise,
              icon: widget.revising
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accentPurple,
                      ),
                    )
                  : const Icon(Icons.auto_fix_high, size: 16),
              label: Text(widget.revising ? 'Revising…' : 'Revise with agent'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accentPurple,
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.canUndo ? widget.onUndo : null,
                  icon: const Icon(Icons.undo, size: 16),
                  label: const Text('Undo'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textMuted,
                    side: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.canRedo ? widget.onRedo : null,
                  icon: const Icon(Icons.redo, size: 16),
                  label: const Text('Redo'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textMuted,
                    side: const BorderSide(color: AppColors.border),
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
