import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import 'flow_chrome.dart';

/// The Export paywall modal from the Open Montage Flow design: Free vs Pro
/// tiers, the plan feature list, a gradient CTA, and a referral banner.
/// Returns the chosen tier ('free' | 'pro') when the user confirms, or null.
Future<String?> showExportModal(BuildContext context) {
  return showDialog<String>(
    context: context,
    barrierColor: const Color(0xB8050508),
    builder: (_) => const _ExportModal(),
  );
}

class _ExportModal extends StatefulWidget {
  const _ExportModal();

  @override
  State<_ExportModal> createState() => _ExportModalState();
}

class _ExportModalState extends State<_ExportModal> {
  String _tier = 'pro';
  bool _copied = false;

  static const _proFeatures = [
    'No watermark',
    '1080p / 4K export',
    'All formats (9:16 / 1:1 / 16:9)',
    'Unlimited brand kits',
    '120 render credits / mo',
  ];
  static const _freeFeatures = [
    '“Made with Open Montage” watermark',
    '720p export only',
    'Single format',
    '3 free renders / mo',
  ];

  @override
  Widget build(BuildContext context) {
    final pro = _tier == 'pro';
    final features = pro ? _proFeatures : _freeFeatures;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xF50D0D16),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderStrong),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header.
              Container(
                padding: const EdgeInsets.fromLTRB(22, 20, 16, 18),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.borderSoft)),
                ),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Export your ad',
                            style: AppTheme.heading.copyWith(
                                color: AppColors.textPrimary, fontSize: 19)),
                        const SizedBox(height: 2),
                        const Text('Choose how you want to ship it',
                            style: TextStyle(
                                color: AppColors.textMuted, fontSize: 12.5)),
                      ],
                    ),
                    const Spacer(),
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.panel2,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.borderStrong),
                        ),
                        child: const Icon(Icons.close,
                            size: 16, color: AppColors.textMuted),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _tierCard(
                            id: 'free',
                            name: 'Free',
                            price: '\$0',
                            note: 'with watermark',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _tierCard(
                            id: 'pro',
                            name: 'Pro',
                            price: '\$29',
                            cadence: '/mo',
                            note: 'no watermark · 4K · all formats',
                            badge: 'MOST POPULAR',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    for (final f in features) ...[
                      Row(
                        children: [
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check,
                                size: 12, color: AppColors.accent2),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(f,
                                style: const TextStyle(
                                    color: AppColors.textMuted, fontSize: 13)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                    ],
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: pro
                          ? FlowGradientButton(
                              label: 'Upgrade to Pro — \$29/mo',
                              onPressed: () => Navigator.of(context).pop('pro'),
                            )
                          : OutlinedButton(
                              onPressed: () => Navigator.of(context).pop('free'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textPrimary,
                                side: const BorderSide(color: AppColors.borderStrong),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: const Text('Export with watermark (free)'),
                            ),
                    ),
                    const SizedBox(height: 14),
                    _referralBanner(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tierCard({
    required String id,
    required String name,
    required String price,
    String? cadence,
    required String note,
    String? badge,
  }) {
    final active = _tier == id;
    return InkWell(
      borderRadius: BorderRadius.circular(13),
      onTap: () => setState(() => _tier = id),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: active ? AppColors.accent.withValues(alpha: 0.12) : AppColors.panel2,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: active ? AppColors.accent2 : AppColors.borderSoft,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [AppColors.accent2, AppColors.accentViolet]),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(badge,
                    style: AppTheme.mono.copyWith(color: Colors.white, fontSize: 9)),
              ),
            if (badge != null) const SizedBox(height: 8),
            Text(name,
                style: TextStyle(
                    color: id == 'pro' ? AppColors.accent2 : AppColors.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(price,
                    style: AppTheme.heading.copyWith(
                        color: AppColors.textPrimary, fontSize: 26)),
                if (cadence != null)
                  Text(cadence,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 4),
            Text(note,
                style: const TextStyle(color: AppColors.textFaint, fontSize: 11.5)),
          ],
        ),
      ),
    );
  }

  Widget _referralBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accentSky.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accentSky.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.send, color: AppColors.accentSky, size: 22),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Invite a friend, both get 1 month Pro free',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600)),
                SizedBox(height: 3),
                Text('Share your link — every signup adds credits.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () {
              Clipboard.setData(
                  const ClipboardData(text: 'https://openmontage.ai/r/MARCO'));
              setState(() => _copied = true);
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accentSky,
              side: BorderSide(color: AppColors.accentSky.withValues(alpha: 0.5)),
            ),
            child: Text(_copied ? 'Copied ✓' : 'Copy link'),
          ),
        ],
      ),
    );
  }
}
