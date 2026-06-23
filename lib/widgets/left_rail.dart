import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Region B — the narrow asset rail. Switches the secondary surface between
/// asset families (image / video / audio / music) and the agent conversation.
class LeftRail extends StatelessWidget {
  const LeftRail({super.key, required this.selected, required this.onSelect});

  final int selected;
  final ValueChanged<int> onSelect;

  static const _items = [
    (Icons.image_outlined, 'Images'),
    (Icons.movie_outlined, 'Clips'),
    (Icons.graphic_eq, 'Voice'),
    (Icons.music_note_outlined, 'Music'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          for (var i = 0; i < _items.length; i++)
            _RailButton(
              icon: _items[i].$1,
              label: _items[i].$2,
              active: selected == i,
              onTap: () => onSelect(i),
            ),
          const Spacer(),
          const Divider(height: 1, indent: 12, endIndent: 12),
          const SizedBox(height: 8),
          _RailButton(
            icon: Icons.forum_outlined,
            label: 'Agent chat',
            active: selected == _items.length,
            accent: AppColors.accentPurple,
            onTap: () => onSelect(_items.length),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.accent = AppColors.accentCyan,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Tooltip(
        message: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: active ? accent.withValues(alpha: 0.16) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon,
                size: 20,
                color: active ? accent : AppColors.textMuted),
          ),
        ),
      ),
    );
  }
}
