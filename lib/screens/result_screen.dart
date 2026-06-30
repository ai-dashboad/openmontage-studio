import 'dart:async';

import 'package:flutter/material.dart';
import '../models/studio_models.dart';
import '../theme/app_theme.dart';
import '../widgets/aurora_background.dart';

/// The Result screen from the Open Montage Flow design: the finished ad plays in
/// a phone frame with a filmstrip, and an info column offers variations and the
/// CTAs. Editing is optional — "Open in editor" is one button among several, so
/// users who just want the ad never have to touch the editor.
class ResultScreen extends StatefulWidget {
  const ResultScreen({
    super.key,
    required this.scenes,
    required this.onOpenEditor,
    required this.onNewAd,
    required this.onRegenerate,
  });

  final List<Scene> scenes;
  final VoidCallback onOpenEditor;
  final VoidCallback onNewAd;
  final VoidCallback onRegenerate;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  int _sel = 0;
  int _variation = 0;
  bool _playing = false;
  Timer? _timer;

  static const _variations = <(String, String)>[
    ('Bold cut', 'Fast · punchy'),
    ('Calm cut', 'Premium feel'),
    ('Punchy cut', 'High energy'),
  ];

  double get _total =>
      widget.scenes.fold(0.0, (a, s) => a + s.durationSeconds);

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _togglePlay() {
    setState(() => _playing = !_playing);
    _timer?.cancel();
    if (_playing) {
      _timer = Timer.periodic(const Duration(milliseconds: 1400), (_) {
        if (!mounted) return;
        setState(() => _sel = (_sel + 1) % widget.scenes.length);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.app,
      body: AuroraBackground(
        child: SafeArea(
          child: Column(
            children: [
              _header(),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(40, 8, 40, 40),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 42,
                      runSpacing: 28,
                      children: [_player(), _info()],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 16, 30, 8),
      child: Row(
        children: [
          const _Logo(),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: widget.onNewAd,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('New ad'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textMuted,
              side: const BorderSide(color: AppColors.borderStrong),
            ),
          ),
        ],
      ),
    );
  }

  // --- Left: player ----------------------------------------------------------

  Widget _player() {
    final scene = widget.scenes[_sel.clamp(0, widget.scenes.length - 1)];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 300,
          height: 533, // 9:16
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.3),
                blurRadius: 70,
              ),
              const BoxShadow(color: Color(0x99000000), blurRadius: 40, offset: Offset(0, 30)),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: GestureDetector(
            onTap: _togglePlay,
            child: _SceneFrame(scene: scene, playing: _playing),
          ),
        ),
        const SizedBox(height: 16),
        // Filmstrip.
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < widget.scenes.length; i++)
              GestureDetector(
                onTap: () => setState(() => _sel = i),
                child: Container(
                  width: 42,
                  height: 58,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(7),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        widget.scenes[i].accent.withValues(alpha: 0.8),
                        widget.scenes[i].accent.withValues(alpha: 0.3),
                      ],
                    ),
                    border: Border.all(
                      color: i == _sel ? Colors.white : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // --- Right: info -----------------------------------------------------------

  Widget _info() {
    return SizedBox(
      width: 380,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.accentSky,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'READY · ${_total.toStringAsFixed(1)}s',
                style: AppTheme.mono.copyWith(
                  color: AppColors.accentSky,
                  fontSize: 11,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ShaderMask(
            shaderCallback: (r) => const LinearGradient(
              colors: [Color(0xFFF4F4F8), Color(0xFF8B8DF3), Color(0xFF38BDF8)],
            ).createShader(r),
            child: Text(
              'Your ad is ready.',
              style: AppTheme.heading.copyWith(color: Colors.white, fontSize: 36),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metaChip('${widget.scenes.length} scenes'),
              _metaChip('${_total.toStringAsFixed(0)}s'),
              _metaChip('9:16'),
              _metaChip('1080p'),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            '3 VARIATIONS GENERATED',
            style: AppTheme.mono.copyWith(
              color: AppColors.textFaint,
              fontSize: 10,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < _variations.length; i++) ...[
            _variationCard(i),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: _GradientButton(
              icon: Icons.edit_outlined,
              label: 'Open in editor',
              onPressed: widget.onOpenEditor,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.onOpenEditor,
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Export'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.borderStrong),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.onRegenerate,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Regenerate'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.borderStrong),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metaChip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.panel2,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.borderSoft),
        ),
        child: Text(
          text,
          style: AppTheme.mono.copyWith(color: AppColors.textMuted, fontSize: 11),
        ),
      );

  Widget _variationCard(int i) {
    final active = i == _variation;
    final v = _variations[i];
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(() => _variation = i),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: active
              ? AppColors.accent.withValues(alpha: 0.14)
              : AppColors.panel2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? AppColors.accent2 : AppColors.borderSoft,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 62,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(7),
                gradient: LinearGradient(
                  colors: [
                    AppColors.accent.withValues(alpha: 0.8 - i * 0.2),
                    AppColors.accentViolet.withValues(alpha: 0.5),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  v.$1,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  v.$2,
                  style: const TextStyle(color: AppColors.textFaint, fontSize: 11.5),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A scene rendered into the phone frame — gradient backdrop + headline.
class _SceneFrame extends StatelessWidget {
  const _SceneFrame({required this.scene, required this.playing});
  final Scene scene;
  final bool playing;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scene.accent.withValues(alpha: 0.55),
                const Color(0xFF0A0A11),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 28, height: 4, color: scene.accent),
              const SizedBox(height: 12),
              Text(
                scene.headline.isNotEmpty ? scene.headline : scene.title,
                style: AppTheme.heading.copyWith(
                  color: Colors.white,
                  fontSize: 22,
                  height: 1.1,
                ),
              ),
              if (scene.subtitle.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  scene.subtitle,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
              const SizedBox(height: 14),
            ],
          ),
        ),
        if (!playing)
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24),
              ),
              child: const Icon(Icons.play_arrow, color: Colors.white, size: 32),
            ),
          ),
      ],
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: const LinearGradient(
              colors: [AppColors.accent2, AppColors.accentViolet],
            ),
          ),
          child: const Icon(Icons.play_arrow, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 10),
        Text(
          'Open Montage',
          style: AppTheme.heading.copyWith(
            color: AppColors.textPrimary,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        gradient: const LinearGradient(
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
        icon: Icon(icon, size: 17),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 13),
        ),
      ),
    );
  }
}
