import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/aurora_background.dart';
import '../widgets/flow_chrome.dart';

/// The in-app Pricing screen from the Open Montage Flow design: four plan cards
/// over the aurora, the engine pills, and the top-up / referral banners.
class PricingScreen extends StatelessWidget {
  const PricingScreen({
    super.key,
    required this.onBack,
    required this.onInvite,
    required this.onSelectPlan,
  });

  final VoidCallback onBack;
  final VoidCallback onInvite;
  final VoidCallback onSelectPlan;

  static const _engines = ['GPT-4o', 'Claude 3.5', 'Runway', 'ElevenLabs', 'Whisper'];

  static const _plans = <_Plan>[
    _Plan(
      name: 'Free',
      price: '\$0',
      cadence: 'forever',
      sub: 'Try it, ship with a watermark',
      cta: 'Start free',
      features: [
        '3 ad renders / month',
        '720p export, 1 format',
        '“Made with Open Montage” watermark',
        '1 brand kit',
        'Stock + AI scenes',
      ],
    ),
    _Plan(
      name: 'Creator',
      price: '\$29',
      cadence: '/mo',
      tag: 'MOST POPULAR',
      sub: 'For solo marketers & founders',
      cta: 'Start 7-day trial',
      highlight: true,
      features: [
        '120 renders / month',
        'No watermark',
        '1080p / 4K',
        'All formats (9:16 / 1:1 / 16:9)',
        '3 brand kits',
        'Voiceover + auto-captions',
        'All 4 ad styles',
      ],
    ),
    _Plan(
      name: 'Team',
      price: '\$99',
      cadence: '/mo',
      sub: 'For growth & social teams',
      cta: 'Start trial',
      features: [
        '500 renders / month',
        'Everything in Creator',
        'Unlimited brand kits',
        'Collaboration & approvals',
        'Priority render queue',
        'Remix library',
      ],
    ),
    _Plan(
      name: 'Agency',
      price: 'Custom',
      sub: 'White-label & API',
      cta: 'Talk to sales',
      features: [
        'Unlimited renders',
        'White-label exports',
        'Client workspaces',
        'API access',
        'SSO & dedicated support',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.app,
      body: AuroraBackground(
        child: SafeArea(
          child: Column(
            children: [
              FlowHeader(onBack: onBack),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(30, 8, 30, 60),
                  child: Column(
                    children: [
                      const EyebrowPill(text: 'PRICING'),
                      const SizedBox(height: 18),
                      const GradientHeading(
                        'Make ads people\nactually finish watching.',
                        fontSize: 44,
                      ),
                      const SizedBox(height: 16),
                      const SizedBox(
                        width: 540,
                        child: Text(
                          'Start free. Upgrade when you’re ready to ship without a '
                          'watermark. Every plan is powered by the same studio-grade '
                          'pipeline.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 15.5,
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _engineRow(),
                      const SizedBox(height: 28),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1120),
                        child: Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          alignment: WrapAlignment.center,
                          children: [for (final p in _plans) _planCard(p)],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _banners(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _engineRow() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'POWERED BY',
          style: AppTheme.mono.copyWith(color: AppColors.textFaint, fontSize: 10.5),
        ),
        for (final e in _engines)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.accent2.withValues(alpha: 0.28)),
            ),
            child: Text(
              e,
              style: AppTheme.mono.copyWith(color: AppColors.accent2, fontSize: 10.5),
            ),
          ),
      ],
    );
  }

  Widget _planCard(_Plan p) {
    return Container(
      width: 256,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        color: const Color(0xE60D0D16),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: p.highlight ? AppColors.accent2 : AppColors.borderSoft,
          width: p.highlight ? 1.5 : 1,
        ),
        boxShadow: p.highlight
            ? [BoxShadow(color: AppColors.accent.withValues(alpha: 0.25), blurRadius: 40)]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (p.tag != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.accent2, AppColors.accentViolet],
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                p.tag!,
                style: AppTheme.mono.copyWith(color: Colors.white, fontSize: 9),
              ),
            ),
          if (p.tag != null) const SizedBox(height: 10),
          Text(p.name,
              style: AppTheme.heading.copyWith(
                  color: AppColors.textPrimary, fontSize: 16)),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(p.price,
                  style: AppTheme.heading.copyWith(
                      color: AppColors.textPrimary, fontSize: 32)),
              if (p.cadence != null) ...[
                const SizedBox(width: 4),
                Text(p.cadence!,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 13)),
              ],
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 34,
            child: Text(p.sub,
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 12.5, height: 1.3)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: p.highlight
                ? FlowGradientButton(label: p.cta, onPressed: onSelectPlan)
                : OutlinedButton(
                    onPressed: onSelectPlan,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.borderStrong),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(p.cta),
                  ),
          ),
          const SizedBox(height: 14),
          for (final f in p.features) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 18,
                  height: 18,
                  margin: const EdgeInsets.only(top: 1),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, size: 12, color: AppColors.accent2),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(f,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12.5, height: 1.3)),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _banners() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1120),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          _banner(
            icon: Icons.bolt,
            iconColor: AppColors.accent2,
            dashed: false,
            title: 'Out of credits? Top up anytime.',
            body: 'Add render packs from \$9 — no plan change needed. '
                '1 credit = 1 rendered ad.',
          ),
          _banner(
            icon: Icons.send,
            iconColor: AppColors.accentSky,
            dashed: true,
            title: 'Refer a friend, both get Pro free',
            body: 'Every signup from your link adds credits to your account.',
            onTap: onInvite,
          ),
        ],
      ),
    );
  }

  Widget _banner({
    required IconData icon,
    required Color iconColor,
    required bool dashed,
    required String title,
    required String body,
    VoidCallback? onTap,
  }) {
    return SizedBox(
      width: 540,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: dashed
                ? AppColors.accentSky.withValues(alpha: 0.06)
                : AppColors.panel2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: dashed
                  ? AppColors.accentSky.withValues(alpha: 0.4)
                  : AppColors.borderSoft,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(body,
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 11.5, height: 1.35)),
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

class _Plan {
  const _Plan({
    required this.name,
    required this.price,
    this.cadence,
    this.tag,
    required this.sub,
    required this.cta,
    this.highlight = false,
    required this.features,
  });
  final String name;
  final String price;
  final String? cadence;
  final String? tag;
  final String sub;
  final String cta;
  final bool highlight;
  final List<String> features;
}
