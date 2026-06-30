import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/aurora_background.dart';

/// The animated "Generating" pipeline from the Open Montage Flow design — shown
/// while the agent really plans the ad. Seven stages light up in sequence with
/// orbs/connectors/engine badges, a spinning conic hero, and a progress bar.
/// Drives purely off an animation; the parent navigates away when the real plan
/// is ready.
class GeneratingScreen extends StatefulWidget {
  const GeneratingScreen({
    super.key,
    required this.promptEcho,
    required this.onCancel,
  });

  final String promptEcho;
  final VoidCallback onCancel;

  @override
  State<GeneratingScreen> createState() => _GeneratingScreenState();
}

class _GeneratingScreenState extends State<GeneratingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _c;
  late final AnimationController _spin;

  // (title, sub, engine) — the 7-stage pipeline from the spec.
  static const _stages = <(String, String, String)>[
    ('Understanding your brief', 'Parsing intent, audience & goal', 'GPT-4o'),
    ('Writing the script', 'Hook · problem · solution · CTA', 'Claude 3.5'),
    ('Storyboarding scenes', 'Framing 5 beats into shots', 'Director AI'),
    ('Sourcing footage', 'Stock, b-roll & generated clips', 'Stock + Runway'),
    ('Recording voiceover', 'Nova · upbeat read', 'ElevenLabs'),
    ('Syncing captions', 'Word-level timing to the track', 'Whisper sync'),
    ('Rendering master', 'Compositing the final 1080p cut', 'Render farm'),
  ];

  @override
  void initState() {
    super.initState();
    // ~7s sweep; holds at the end (master stays "rendering") until the parent
    // leaves once the real plan resolves.
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 7))
      ..forward();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.app,
      body: AuroraBackground(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final v = _c.value;
            // Keep the last stage "active" (spinning) while we wait.
            final active = (v * 7).floor().clamp(0, _stages.length - 1);
            final pct = (v * 100).round().clamp(0, 99);
            return Column(
              children: [
                _statusBar(v),
                Expanded(
                  child: Row(
                    children: [
                      _pipeline(active),
                      Expanded(child: _hero(active, pct)),
                    ],
                  ),
                ),
                _progressBar(v, active),
              ],
            );
          },
        ),
      ),
    );
  }

  // --- Top status bar --------------------------------------------------------

  Widget _statusBar(double v) {
    final elapsed = (v * 6.4);
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 26),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.borderSoft)),
      ),
      child: Row(
        children: [
          _BlinkDot(),
          const SizedBox(width: 10),
          Text(
            'GENERATING',
            style: AppTheme.mono.copyWith(
              color: AppColors.accent2,
              fontSize: 12,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: 14),
          Flexible(
            child: Text(
              '“${widget.promptEcho}”',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textFaint, fontSize: 13),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            _fmt(elapsed),
            style: AppTheme.mono.copyWith(
              color: AppColors.textMuted,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 12),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: widget.onCancel,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppColors.panel2,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderStrong),
              ),
              child: const Icon(Icons.close, size: 15, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  // --- Left pipeline ---------------------------------------------------------

  Widget _pipeline(int active) {
    return Container(
      width: 388,
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: AppColors.borderSoft)),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(26, 28, 26, 28),
        children: [
          Text(
            'PIPELINE',
            style: AppTheme.mono.copyWith(
              color: AppColors.textFaint,
              fontSize: 11,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          for (var i = 0; i < _stages.length; i++)
            _stageRow(i, active, last: i == _stages.length - 1),
        ],
      ),
    );
  }

  Widget _stageRow(int i, int active, {required bool last}) {
    final done = i < active;
    final isActive = i == active;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              _orb(i, done, isActive),
              if (!last)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: done ? AppColors.accent : AppColors.borderSoft,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _stages[i].$1,
                    style: AppTheme.heading.copyWith(
                      color: (done || isActive)
                          ? AppColors.textPrimary
                          : AppColors.textFaint,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _stages[i].$2,
                    style: const TextStyle(
                      color: AppColors.textFaint,
                      fontSize: 12.5,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: AppColors.accent2.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      _stages[i].$3,
                      style: AppTheme.mono.copyWith(
                        color: AppColors.accent2,
                        fontSize: 9.5,
                      ),
                    ),
                  ),
                  if (isActive) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: const _ShimmerBar(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _orb(int i, bool done, bool isActive) {
    if (done) {
      return Container(
        width: 30,
        height: 30,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: [AppColors.accent2, AppColors.accent]),
        ),
        child: const Icon(Icons.check, size: 16, color: Colors.white),
      );
    }
    if (isActive) {
      return Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [AppColors.accent2, AppColors.accentViolet],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.5),
              blurRadius: 16,
            ),
          ],
        ),
        child: Center(
          child: RotationTransition(
            turns: _spin,
            child: const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            ),
          ),
        ),
      );
    }
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.panel2,
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Center(
        child: Text(
          '${i + 1}',
          style: AppTheme.mono.copyWith(
            color: AppColors.textFaint,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  // --- Right hero ------------------------------------------------------------

  Widget _hero(int active, int pct) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: AspectRatio(
          aspectRatio: 9 / 16,
          child: LayoutBuilder(
            builder: (context, c) {
              final ring = math.min(c.maxWidth, c.maxHeight) * 0.62;
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Conic ring.
                  RotationTransition(
                    turns: _c,
                    child: Container(
                      width: ring,
                      height: ring,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: SweepGradient(
                          colors: [
                            AppColors.accent,
                            AppColors.accentViolet,
                            AppColors.accentSky,
                            AppColors.accent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Inner mask.
                  Container(
                    width: ring - 16,
                    height: ring - 16,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF0A0A11),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$pct%',
                        style: AppTheme.heading.copyWith(
                          color: Colors.white,
                          fontSize: 34,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _stages[active].$1,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  // ASSEMBLING tag.
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Text(
                      'ASSEMBLING',
                      style: AppTheme.mono.copyWith(
                        color: AppColors.textFaint,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // --- Bottom progress -------------------------------------------------------

  Widget _progressBar(double v, int active) {
    final filled = (v * 5).round().clamp(0, 5);
    return Container(
      padding: const EdgeInsets.fromLTRB(26, 16, 26, 20),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.borderSoft)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 6,
              child: Row(
                children: [
                  Expanded(
                    flex: (v * 1000).round().clamp(1, 1000),
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.accent,
                            AppColors.accentViolet,
                            AppColors.accentSky,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: ((1 - v) * 1000).round().clamp(1, 1000),
                    child: const ColoredBox(color: AppColors.bg2),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${_stages[active].$1}…',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5),
              ),
              const Spacer(),
              Text(
                '$filled/5 scenes',
                style: AppTheme.mono.copyWith(
                  color: AppColors.textFaint,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmt(double sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toStringAsFixed(1).padLeft(4, '0');
    return '$m:$s';
  }
}

/// A blinking live dot.
class _BlinkDot extends StatefulWidget {
  @override
  State<_BlinkDot> createState() => _BlinkDotState();
}

class _BlinkDotState extends State<_BlinkDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 1.0, end: 0.2).animate(_c),
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: AppColors.accentSky,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: AppColors.accentSky, blurRadius: 8)],
        ),
      ),
    );
  }
}

/// A looping shimmer bar for the active pipeline stage.
class _ShimmerBar extends StatefulWidget {
  const _ShimmerBar();
  @override
  State<_ShimmerBar> createState() => _ShimmerBarState();
}

class _ShimmerBarState extends State<_ShimmerBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 4,
      width: 120,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          return ShaderMask(
            shaderCallback: (rect) => LinearGradient(
              colors: const [
                AppColors.accent,
                AppColors.accentSky,
                AppColors.accent,
              ],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment(-1 + _c.value * 2, 0),
              end: Alignment(1 + _c.value * 2, 0),
            ).createShader(rect),
            child: const ColoredBox(color: Colors.white),
          );
        },
      ),
    );
  }
}
