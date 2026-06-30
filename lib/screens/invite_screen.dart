import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../widgets/aurora_background.dart';
import '../widgets/flow_chrome.dart';

/// The in-app Invite / Referral screen from the Open Montage Flow design.
class InviteScreen extends StatefulWidget {
  const InviteScreen({super.key, required this.onBack});
  final VoidCallback onBack;

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> {
  static const _link = 'openmontage.ai/r/MARCO';
  bool _copied = false;

  static const _milestones = <(int, String, String)>[
    (1, '+5 credits', 'done'),
    (3, '+20 credits', 'done'),
    (5, '1 mo Pro', 'current'),
    (10, '3 mo Pro', 'locked'),
    (25, 'Creator for life', 'locked'),
  ];

  static const _stats = <(String, String, String, Color)>[
    ('INVITES SENT', '12', 'links', Colors.white),
    ('SIGNED UP', '4', 'joined', AppColors.accentSky),
    ('CREDITS EARNED', '65', 'credits', AppColors.accentGreen),
    ('UPGRADED', '1', 'to Pro', AppColors.accentViolet),
  ];

  static const _activity = <(String, String, String, String, String)>[
    ('S', 'Sarah K.', 'Joined', '2 hours ago', '+5'),
    ('D', 'Dev T.', 'Made first ad', '1 day ago', '+5'),
    ('P', 'Priya M.', 'Upgraded to Pro', '2 days ago', '+30'),
    ('L', 'Leo W.', 'Joined', '3 days ago', '+5'),
    ('A', 'Ana R.', 'Made first ad', '5 days ago', '+5'),
  ];

  void _copy() {
    Clipboard.setData(const ClipboardData(text: 'https://$_link'));
    setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.app,
      body: AuroraBackground(
        child: SafeArea(
          child: Column(
            children: [
              FlowHeader(onBack: widget.onBack),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(30, 8, 30, 60),
                  child: Column(
                    children: [
                      const EyebrowPill(text: 'REFERRALS'),
                      const SizedBox(height: 18),
                      const GradientHeading('Invite friends. Earn free Pro.',
                          fontSize: 42),
                      const SizedBox(height: 16),
                      const SizedBox(
                        width: 560,
                        child: Text(
                          'Every friend who signs up gets 5 free credits — and so do '
                          'you. Hit 5 and you both unlock a month of Pro.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 15, height: 1.5),
                        ),
                      ),
                      const SizedBox(height: 26),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1060),
                        child: Wrap(
                          spacing: 18,
                          runSpacing: 18,
                          alignment: WrapAlignment.center,
                          children: [
                            SizedBox(width: 500, child: _leftColumn()),
                            SizedBox(width: 380, child: _rightColumn()),
                          ],
                        ),
                      ),
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

  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xF00D0D16),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.borderSoft),
        ),
        child: child,
      );

  Widget _leftColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('YOUR INVITE LINK',
                  style: AppTheme.mono.copyWith(
                      color: AppColors.textFaint, fontSize: 10, letterSpacing: 1.2)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                decoration: BoxDecoration(
                  color: AppColors.app,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: AppColors.borderStrong),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.link, size: 16, color: AppColors.textFaint),
                    const SizedBox(width: 8),
                    Text(_link,
                        style: AppTheme.mono.copyWith(
                            color: AppColors.textPrimary, fontSize: 14)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FlowGradientButton(
                  icon: _copied ? Icons.check : Icons.copy,
                  label: _copied ? 'Copied' : 'Copy link',
                  onPressed: _copy,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (final s in ['WhatsApp', 'Post', 'Story', 'Email'])
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.panel2,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.borderStrong),
                          ),
                          child: Text(s,
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 11)),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Next reward · 1 month Pro free',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600)),
                  ),
                  Text('4 / 5',
                      style: AppTheme.mono.copyWith(
                          color: AppColors.accent2, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 6),
              const Text('Just 1 more friend and you both get Pro, free for a month.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: SizedBox(
                  height: 10,
                  child: Row(
                    children: [
                      Expanded(
                        flex: 80,
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              AppColors.accent2,
                              AppColors.accentViolet,
                            ]),
                          ),
                        ),
                      ),
                      Expanded(
                          flex: 20, child: const ColoredBox(color: AppColors.bg2)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [for (final m in _milestones) _milestoneDot(m)],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _milestoneDot((int, String, String) m) {
    final state = m.$3;
    final done = state == 'done';
    final current = state == 'current';
    return Column(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: done
                ? const LinearGradient(colors: [AppColors.accent2, AppColors.accent])
                : null,
            color: current
                ? AppColors.accentViolet.withValues(alpha: 0.18)
                : (done ? null : AppColors.panel2),
            border: Border.all(
              color: current ? AppColors.accentViolet : AppColors.borderStrong,
              width: current ? 2 : 1,
            ),
          ),
          child: Icon(
            done
                ? Icons.check
                : current
                    ? Icons.bolt
                    : Icons.lock_outline,
            size: 14,
            color: done
                ? Colors.white
                : current
                    ? const Color(0xFFC084FC)
                    : AppColors.textFaint,
          ),
        ),
        const SizedBox(height: 5),
        Text('${m.$1}',
            style: AppTheme.mono.copyWith(color: AppColors.textFaint, fontSize: 10)),
        Text(m.$2,
            style: const TextStyle(color: AppColors.textFaint, fontSize: 9)),
      ],
    );
  }

  Widget _rightColumn() {
    return Column(
      children: [
        GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.6,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [for (final s in _stats) _statCard(s)],
        ),
        const SizedBox(height: 14),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Referral activity',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.accentGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: AppColors.accentGreen.withValues(alpha: 0.3)),
                    ),
                    child: Text('+65 credits',
                        style: AppTheme.mono.copyWith(
                            color: AppColors.accentGreen, fontSize: 10)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (final a in _activity) _activityRow(a),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statCard((String, String, String, Color) s) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.panel2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(s.$1,
              style: AppTheme.mono.copyWith(
                  color: AppColors.textFaint, fontSize: 9, letterSpacing: 0.8)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(s.$2,
                  style: AppTheme.heading.copyWith(color: s.$4, fontSize: 28)),
              const SizedBox(width: 5),
              Text(s.$3,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _activityRow((String, String, String, String, String) a) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [AppColors.accent2, AppColors.accent]),
            ),
            child: Text(a.$1,
                style: const TextStyle(
                    color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.$2,
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 13)),
                Text('${a.$3} · ${a.$4}',
                    style: const TextStyle(
                        color: AppColors.textFaint, fontSize: 11)),
              ],
            ),
          ),
          Text(a.$5,
              style: AppTheme.mono.copyWith(
                  color: AppColors.accentGreen, fontSize: 12)),
        ],
      ),
    );
  }
}
