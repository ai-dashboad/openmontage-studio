import 'package:flutter/material.dart';
import '../models/studio_models.dart';
import '../theme/app_theme.dart';

/// Region E — the multi-track timeline from the Open Montage editor design. A
/// labelled track stack (Clips / Captions / Voice / Music) shares one ruler and
/// playhead; selecting a clip drives the preview and the Scenes panel. The
/// current pipeline stage rides in the header so the approve→render→export flow
/// stays legible.
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

  /// Width of the left track-label gutter.
  static const double _labels = 116;
  static const double _ruler = 20;
  static const double _trackH = 28;
  static const double _gap = 4;

  static const _tracks = <({String name, Color dot})>[
    (name: 'Clips', dot: AppColors.accent),
    (name: 'Captions', dot: AppColors.accentSky),
    (name: 'Voice', dot: AppColors.accentGreen),
    (name: 'Music', dot: AppColors.accentAmber),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34 + _ruler + _tracks.length * (_trackH + _gap) + 20,
      decoration: const BoxDecoration(
        color: AppColors.panel1,
        border: Border(top: BorderSide(color: AppColors.borderSoft)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _trackLabels(),
                Expanded(child: _trackArea()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    final stage = MockProject.stages[currentStageIndex.clamp(
      0,
      MockProject.stages.length - 1,
    )];
    return SizedBox(
      height: 34,
      child: Row(
        children: [
          Text(
            'TIMELINE',
            style: AppTheme.mono.copyWith(
              color: AppColors.accent2,
              fontSize: 11,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(width: 12),
          _StageChip(stage: stage),
          const Spacer(),
          Text(
            '${totalSeconds.toStringAsFixed(1)}s',
            style: AppTheme.mono.copyWith(
              color: AppColors.textFaint,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 14),
          Text(
            '30 FPS · 1080p',
            style: AppTheme.mono.copyWith(
              color: AppColors.textFaint,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _trackLabels() {
    return SizedBox(
      width: _labels,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: _ruler),
          for (final t in _tracks) ...[
            SizedBox(
              height: _trackH,
              child: Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: t.dot,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t.name,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.visibility_outlined,
                    size: 13,
                    color: AppColors.textFaint,
                  ),
                ],
              ),
            ),
            const SizedBox(height: _gap),
          ],
        ],
      ),
    );
  }

  Widget _trackArea() {
    return LayoutBuilder(
      builder: (context, c) {
        final width = c.maxWidth;
        final frac = totalSeconds == 0
            ? 0.0
            : (playheadSeconds / totalSeconds).clamp(0.0, 1.0);
        final playheadX = (frac * width).clamp(0.0, width - 1);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Ruler(totalSeconds: totalSeconds),
                _row(
                  _ClipTrack(
                    scenes: scenes,
                    selectedIndex: selectedSceneIndex,
                    onSelect: onSelectScene,
                  ),
                ),
                _row(
                  _CaptionTrack(
                    scenes: scenes,
                    selectedIndex: selectedSceneIndex,
                    onSelect: onSelectScene,
                  ),
                ),
                _row(
                  _ClipWaveTrack(
                    scenes: scenes,
                    selectedIndex: selectedSceneIndex,
                    onSelect: onSelectScene,
                  ),
                ),
                _row(_MusicTrack(seed: '${scenes.length}-$totalSeconds')),
              ],
            ),
            // Shared playhead across all tracks (below the ruler).
            Positioned(
              left: playheadX,
              top: _ruler - 4,
              bottom: 0,
              child: Column(
                children: [
                  Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: Container(width: 2, color: AppColors.accent)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _row(Widget child) => Padding(
    padding: const EdgeInsets.only(bottom: _gap),
    child: SizedBox(height: _trackH, child: child),
  );
}

class _StageChip extends StatelessWidget {
  const _StageChip({required this.stage});
  final PipelineStage stage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.accentAmber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.accentAmber.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.radio_button_checked,
            size: 11,
            color: AppColors.accentAmber,
          ),
          const SizedBox(width: 5),
          Text(
            stage.name,
            style: AppTheme.mono.copyWith(
              color: AppColors.textMuted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// Second markers spanning the track width. Visual only — selection drives the
/// playhead today.
class _Ruler extends StatelessWidget {
  const _Ruler({required this.totalSeconds});
  final double totalSeconds;

  @override
  Widget build(BuildContext context) {
    final total = totalSeconds <= 0 ? 1 : totalSeconds.ceil();
    // Keep the labels readable: step so there are at most ~12 marks.
    final step = (total / 12).ceil().clamp(1, total);
    return SizedBox(
      height: Timeline._ruler,
      child: LayoutBuilder(
        builder: (context, c) {
          final marks = <Widget>[];
          for (var s = 0; s <= total; s += step) {
            final x = (s / total) * c.maxWidth;
            marks.add(Positioned(
              left: x.clamp(0, c.maxWidth - 18),
              bottom: 2,
              child: Text(
                '${s}s',
                style: AppTheme.mono.copyWith(
                  color: AppColors.textFaint,
                  fontSize: 9.5,
                ),
              ),
            ));
          }
          return Stack(children: marks);
        },
      ),
    );
  }
}

/// A row of per-scene blocks sized by duration — the shared geometry for the
/// clip, caption, and voice tracks so they stay aligned.
class _ScaledRow extends StatelessWidget {
  const _ScaledRow({required this.scenes, required this.builder});
  final List<Scene> scenes;
  final Widget Function(int index, Scene scene) builder;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < scenes.length; i++)
          Expanded(
            flex: (scenes[i].durationSeconds * 10).round().clamp(1, 1 << 30),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: builder(i, scenes[i]),
            ),
          ),
      ],
    );
  }
}

class _ClipTrack extends StatelessWidget {
  const _ClipTrack({
    required this.scenes,
    required this.selectedIndex,
    required this.onSelect,
  });
  final List<Scene> scenes;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return _ScaledRow(
      scenes: scenes,
      builder: (i, scene) {
        final selected = i == selectedIndex;
        return InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => onSelect(i),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  scene.accent.withValues(alpha: selected ? 0.42 : 0.22),
                  scene.accent.withValues(alpha: selected ? 0.24 : 0.12),
                ],
              ),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: selected ? scene.accent : Colors.transparent,
                width: 1.5,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    scene.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected
                          ? AppColors.textPrimary
                          : AppColors.textMuted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${scene.durationSeconds.toStringAsFixed(1)}s',
                  style: AppTheme.mono.copyWith(
                    color: AppColors.textFaint,
                    fontSize: 9.5,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CaptionTrack extends StatelessWidget {
  const _CaptionTrack({
    required this.scenes,
    required this.selectedIndex,
    required this.onSelect,
  });
  final List<Scene> scenes;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return _ScaledRow(
      scenes: scenes,
      builder: (i, scene) {
        final caption = scene.subtitle.isNotEmpty
            ? scene.subtitle
            : scene.headline;
        final selected = i == selectedIndex;
        return InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => onSelect(i),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.accentSky.withValues(
                alpha: selected ? 0.20 : 0.10,
              ),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: selected
                    ? AppColors.accentSky.withValues(alpha: 0.7)
                    : Colors.transparent,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.centerLeft,
            child: Text(
              caption.isEmpty ? '—' : caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Per-scene narration waveform (the Voice track).
class _ClipWaveTrack extends StatelessWidget {
  const _ClipWaveTrack({
    required this.scenes,
    required this.selectedIndex,
    required this.onSelect,
  });
  final List<Scene> scenes;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return _ScaledRow(
      scenes: scenes,
      builder: (i, scene) {
        final narration = [scene.headline, scene.subtitle]
            .where((s) => s.isNotEmpty)
            .join('. ');
        final has = narration.isNotEmpty;
        final selected = i == selectedIndex;
        return InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => onSelect(i),
          child: Container(
            decoration: BoxDecoration(
              color: has
                  ? AppColors.accentGreen.withValues(
                      alpha: selected ? 0.20 : 0.10,
                    )
                  : Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: selected && has
                    ? AppColors.accentGreen.withValues(alpha: 0.7)
                    : Colors.transparent,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: has
                ? _Waveform(seed: narration, color: AppColors.accentGreen)
                : const Center(
                    child: Text(
                      'silent',
                      style: TextStyle(
                        color: AppColors.textFaint,
                        fontSize: 9.5,
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }
}

/// The Music track: one continuous bed across the whole timeline.
class _MusicTrack extends StatelessWidget {
  const _MusicTrack({required this.seed});
  final String seed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.accentAmber.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.accentAmber.withValues(alpha: 0.25)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: _Waveform(seed: 'music-$seed', color: AppColors.accentAmber),
    );
  }
}

class _Waveform extends StatelessWidget {
  const _Waveform({required this.seed, required this.color});
  final String seed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final codes = seed.codeUnits;
    return LayoutBuilder(
      builder: (context, c) {
        final barCount = (c.maxWidth / 4).clamp(4, 120).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (var i = 0; i < barCount; i++)
              Container(
                width: 2,
                height: 3 + (codes[(i * 7) % codes.length] % 14).toDouble(),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
          ],
        );
      },
    );
  }
}
