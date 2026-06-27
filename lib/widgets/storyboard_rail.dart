import 'package:flutter/material.dart';
import '../models/studio_models.dart';
import '../theme/app_theme.dart';

/// The left storyboard rail from the Open Montage editor design: a vertical
/// stack of numbered scene cards that doubles as the scene navigator. Selecting
/// a card drives the preview, timeline, and the Scenes tab of the editor panel.
class StoryboardRail extends StatelessWidget {
  const StoryboardRail({
    super.key,
    required this.scenes,
    required this.selectedIndex,
    required this.onSelect,
    this.onAddScene,
  });

  final List<Scene> scenes;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback? onAddScene;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      decoration: const BoxDecoration(
        color: AppColors.panel1,
        border: Border(right: BorderSide(color: AppColors.borderSoft)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
              children: [
                for (var i = 0; i < scenes.length; i++)
                  _SceneCard(
                    number: i + 1,
                    scene: scenes[i],
                    selected: i == selectedIndex,
                    onTap: () => onSelect(i),
                  ),
                const SizedBox(height: 4),
                _AddSceneButton(onTap: onAddScene),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.borderSoft)),
      ),
      child: Row(
        children: [
          Text(
            'STORYBOARD',
            style: AppTheme.mono.copyWith(
              color: AppColors.textMuted,
              fontSize: 11,
              letterSpacing: 0.6,
            ),
          ),
          const Spacer(),
          Text(
            '${scenes.length} scenes',
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

class _SceneCard extends StatelessWidget {
  const _SceneCard({
    required this.number,
    required this.scene,
    required this.selected,
    required this.onTap,
  });

  final int number;
  final Scene scene;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final caption = scene.subtitle.isNotEmpty ? scene.subtitle : scene.headline;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.accent.withValues(alpha: 0.12)
                : AppColors.panel2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.accent2 : AppColors.borderSoft,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Thumbnail(number: number, accent: scene.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            scene.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${scene.durationSeconds.toStringAsFixed(1)}s',
                          style: AppTheme.mono.copyWith(
                            color: AppColors.textFaint,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A 46×46 gradient tile carrying the scene's ordinal — stands in for the scene
/// thumbnail until a rendered frame is available.
class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.number, required this.accent});
  final int number;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.85),
            accent.withValues(alpha: 0.35),
          ],
        ),
      ),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Container(
          margin: const EdgeInsets.all(3),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '$number',
            style: AppTheme.mono.copyWith(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _AddSceneButton extends StatelessWidget {
  const _AddSceneButton({this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: DottedBorderBox(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add, size: 16, color: AppColors.textMuted),
            const SizedBox(width: 6),
            Text(
              'Add scene',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A reusable dashed-border container matching the design's "Add …" affordances
/// (add scene, upload footage). Implemented with a CustomPainter so the dashes
/// follow the rounded rectangle.
class DottedBorderBox extends StatelessWidget {
  const DottedBorderBox({super.key, required this.child, this.padding});
  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRectPainter(),
      child: Padding(
        padding: padding ?? const EdgeInsets.symmetric(vertical: 12),
        child: child,
      ),
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.borderStrong
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(12),
    );
    final path = Path()..addRRect(rrect);
    const dash = 5.0, gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + dash),
          paint,
        );
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
