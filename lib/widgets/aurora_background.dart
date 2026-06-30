import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// The shared aurora-gradient backdrop from the Open Montage Flow design: three
/// soft indigo/violet/cyan radial blooms over the near-black base, a vignette,
/// and a faint grid. Every screen sits on this, with content layered above.
class AuroraBackground extends StatelessWidget {
  const AuroraBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.app),
      child: Stack(
        children: [
          // The aurora blooms + vignette + grid, behind everything.
          const Positioned.fill(child: IgnorePointer(child: _AuroraLayer())),
          child,
        ],
      ),
    );
  }
}

class _AuroraLayer extends StatelessWidget {
  const _AuroraLayer();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Blob A — indigo, top-left.
        _blob(
          alignment: const Alignment(-0.9, -1.1),
          size: 0.9,
          color: const Color(0xFF6366F1),
          opacity: 0.5,
        ),
        // Blob B — violet, bottom-right.
        _blob(
          alignment: const Alignment(1.1, 1.15),
          size: 0.85,
          color: const Color(0xFFA855F7),
          opacity: 0.42,
        ),
        // Blob C — cyan, upper-right.
        _blob(
          alignment: const Alignment(0.7, -0.5),
          size: 0.6,
          color: const Color(0xFF38BDF8),
          opacity: 0.3,
        ),
        // Vignette.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.2),
              radius: 1.1,
              colors: [Colors.transparent, Color(0xA6000000)],
              stops: [0.55, 1.0],
            ),
          ),
        ),
      ],
    );
  }

  Widget _blob({
    required Alignment alignment,
    required double size,
    required Color color,
    required double opacity,
  }) {
    return Align(
      alignment: alignment,
      child: FractionallySizedBox(
        widthFactor: size,
        heightFactor: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color.withValues(alpha: opacity), Colors.transparent],
              stops: const [0.0, 0.7],
            ),
          ),
        ),
      ),
    );
  }
}
