import 'package:flutter/material.dart';
import '../models/studio_models.dart';
import '../theme/app_theme.dart';

/// Region E — the dual-layer timeline. Top row is the 7-stage pipeline progress;
/// bottom row is the scene strip for the current stage, with a draggable-looking
/// playhead. Selecting a scene drives the preview and inspector.
class Timeline extends StatelessWidget {
  const Timeline({
    super.key,
    required this.scenes,
    required this.totalSeconds,
    required this.currentStageIndex,
    required this.selectedSceneIndex,
    required this.playheadSeconds,
    required this.onSelectScene,
  });

  final List<Scene> scenes;
  final double totalSeconds;
  final int currentStageIndex;
  final int selectedSceneIndex;
  final double playheadSeconds;
  final ValueChanged<int> onSelectScene;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 116,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StageTrack(currentStageIndex: currentStageIndex),
          const SizedBox(height: 10),
          Expanded(
            child: _SceneTrack(
              scenes: scenes,
              totalSeconds: totalSeconds,
              selectedIndex: selectedSceneIndex,
              playheadSeconds: playheadSeconds,
              onSelect: onSelectScene,
            ),
          ),
        ],
      ),
    );
  }
}

class _StageTrack extends StatelessWidget {
  const _StageTrack({required this.currentStageIndex});
  final int currentStageIndex;

  WorkStatus _statusFor(int i) {
    if (i < currentStageIndex) return WorkStatus.done;
    if (i == currentStageIndex) return WorkStatus.awaiting;
    return WorkStatus.pending;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < MockProject.stages.length; i++) ...[
          Icon(_statusFor(i).glyph, size: 13, color: _statusFor(i).color),
          const SizedBox(width: 5),
          Text(
            MockProject.stages[i].name,
            style: AppTheme.mono.copyWith(
              fontSize: 11.5,
              color: _statusFor(i) == WorkStatus.awaiting
                  ? AppColors.accentAmber
                  : _statusFor(i) == WorkStatus.done
                  ? AppColors.textMuted
                  : AppColors.textFaint,
              fontWeight: _statusFor(i) == WorkStatus.awaiting
                  ? FontWeight.w700
                  : FontWeight.w400,
            ),
          ),
          if (i < MockProject.stages.length - 1)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '—',
                style: TextStyle(color: AppColors.statusPending, fontSize: 11),
              ),
            ),
        ],
      ],
    );
  }
}

class _SceneTrack extends StatelessWidget {
  const _SceneTrack({
    required this.scenes,
    required this.totalSeconds,
    required this.selectedIndex,
    required this.playheadSeconds,
    required this.onSelect,
  });

  final List<Scene> scenes;
  final double totalSeconds;
  final int selectedIndex;
  final double playheadSeconds;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final playheadX = (playheadSeconds / totalSeconds) * width;
        return Stack(
          children: [
            Row(
              children: [
                for (var i = 0; i < scenes.length; i++)
                  Expanded(
                    flex: (scenes[i].durationSeconds * 10).round(),
                    child: _SceneBlock(
                      scene: scenes[i],
                      selected: i == selectedIndex,
                      onTap: () => onSelect(i),
                    ),
                  ),
              ],
            ),
            // Playhead.
            Positioned(
              left: playheadX.clamp(0, width - 1),
              top: 0,
              bottom: 0,
              child: Container(width: 2, color: AppColors.accentCyan),
            ),
            Positioned(
              left: (playheadX - 5).clamp(0, width - 10),
              top: -2,
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppColors.accentCyan,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SceneBlock extends StatelessWidget {
  const _SceneBlock({
    required this.scene,
    required this.selected,
    required this.onTap,
  });

  final Scene scene;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: scene.accent.withValues(alpha: selected ? 0.30 : 0.14),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: selected ? scene.accent : Colors.transparent,
              width: 1.5,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                scene.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? AppColors.textPrimary : AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${scene.durationSeconds.toStringAsFixed(1)}s',
                style: AppTheme.mono.copyWith(
                  color: AppColors.textFaint,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
