import 'package:flutter/material.dart';
import '../models/studio_models.dart';
import '../theme/app_theme.dart';

/// Region E — the timeline. The top row is the 7-stage pipeline progress; below
/// it are two aligned tracks sharing one playhead: a **video track** (the scene
/// strip) and an **audio track** (per-scene narration). Selecting a scene drives
/// the preview and inspector.
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

  /// Left gutter where the V/A track labels sit.
  static const double _gutter = 26;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 168,
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final fullWidth = constraints.maxWidth;
                final trackWidth = fullWidth - _gutter;
                final frac = totalSeconds == 0
                    ? 0.0
                    : (playheadSeconds / totalSeconds).clamp(0.0, 1.0);
                final playheadX = _gutter + frac * trackWidth;
                return Stack(
                  children: [
                    Column(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              _trackLabel('V', Icons.movie_outlined),
                              Expanded(
                                child: _VideoTrack(
                                  scenes: scenes,
                                  selectedIndex: selectedSceneIndex,
                                  onSelect: onSelectScene,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: Row(
                            children: [
                              _trackLabel('A', Icons.graphic_eq),
                              Expanded(
                                child: _AudioTrack(
                                  scenes: scenes,
                                  selectedIndex: selectedSceneIndex,
                                  onSelect: onSelectScene,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    // Shared playhead across both tracks.
                    Positioned(
                      left: playheadX.clamp(_gutter, fullWidth - 1),
                      top: 0,
                      bottom: 0,
                      child: Container(width: 2, color: AppColors.accentCyan),
                    ),
                    Positioned(
                      left: (playheadX - 5).clamp(_gutter - 5, fullWidth - 10),
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _trackLabel(String label, IconData icon) {
    return SizedBox(
      width: _gutter,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 13, color: AppColors.textFaint),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTheme.mono.copyWith(
              color: AppColors.textFaint,
              fontSize: 10,
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

/// The video track: one block per scene, sized by its duration.
class _VideoTrack extends StatelessWidget {
  const _VideoTrack({
    required this.scenes,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<Scene> scenes;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < scenes.length; i++)
          Expanded(
            flex: (scenes[i].durationSeconds * 10).round().clamp(1, 1 << 30),
            child: _SceneBlock(
              scene: scenes[i],
              selected: i == selectedIndex,
              onTap: () => onSelect(i),
            ),
          ),
      ],
    );
  }
}

/// The audio track: a narration block per scene, aligned to the video track.
class _AudioTrack extends StatelessWidget {
  const _AudioTrack({
    required this.scenes,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<Scene> scenes;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < scenes.length; i++)
          Expanded(
            flex: (scenes[i].durationSeconds * 10).round().clamp(1, 1 << 30),
            child: _NarrationBlock(
              scene: scenes[i],
              selected: i == selectedIndex,
              onTap: () => onSelect(i),
            ),
          ),
      ],
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

/// A scene's narration, drawn as a small deterministic waveform so the audio
/// track reads as a real layer. Empty when the scene has no spoken text.
class _NarrationBlock extends StatelessWidget {
  const _NarrationBlock({
    required this.scene,
    required this.selected,
    required this.onTap,
  });

  final Scene scene;
  final bool selected;
  final VoidCallback onTap;

  String get _narration =>
      [scene.headline, scene.subtitle].where((s) => s.isNotEmpty).join('. ');

  @override
  Widget build(BuildContext context) {
    final has = _narration.isNotEmpty;
    const audioColor = AppColors.accentGreen;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: has
                ? audioColor.withValues(alpha: selected ? 0.22 : 0.10)
                : AppColors.background,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: selected && has ? audioColor : AppColors.border,
              width: selected && has ? 1.5 : 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: has
              ? _Waveform(seed: _narration, color: audioColor)
              : const Center(
                  child: Text(
                    'silent',
                    style: TextStyle(
                      color: AppColors.textFaint,
                      fontSize: 10,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _Waveform extends StatelessWidget {
  const _Waveform({required this.seed, required this.color});
  final String seed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // Deterministic bar heights derived from the narration text.
    final codes = seed.codeUnits;
    return LayoutBuilder(
      builder: (context, c) {
        final barCount = (c.maxWidth / 5).clamp(6, 48).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (var i = 0; i < barCount; i++)
              Container(
                width: 2,
                height: 4 + (codes[i % codes.length] % 16).toDouble(),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
          ],
        );
      },
    );
  }
}
