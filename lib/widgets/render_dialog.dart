import 'package:flutter/material.dart';
import '../services/render_client.dart';
import '../theme/app_theme.dart';

/// Shows the render dialog, which renders a real MP4 via the local provider
/// (`backend/provider_server.py`) and reports the finished file.
Future<void> showRenderDialog(
  BuildContext context, {
  required RenderClient client,
  required List<Map<String, dynamic>> scenes,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    builder: (_) => _RenderDialog(client: client, scenes: scenes),
  );
}

enum _Phase { rendering, done, error }

class _RenderDialog extends StatefulWidget {
  const _RenderDialog({required this.client, required this.scenes});
  final RenderClient client;
  final List<Map<String, dynamic>> scenes;

  @override
  State<_RenderDialog> createState() => _RenderDialogState();
}

class _RenderDialogState extends State<_RenderDialog> {
  _Phase _phase = _Phase.rendering;
  RenderResult? _result;

  @override
  void initState() {
    super.initState();
    _render();
  }

  Future<void> _render() async {
    try {
      final result = await widget.client.render(widget.scenes);
      if (!mounted) return;
      setState(() {
        _result = result;
        _phase = _Phase.done;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _phase = _Phase.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(),
            const SizedBox(height: 20),
            ..._body(),
            const SizedBox(height: 20),
            _actions(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    final (icon, color, title) = switch (_phase) {
      _Phase.rendering => (
        Icons.movie_creation_outlined,
        AppColors.accentCyan,
        'Rendering',
      ),
      _Phase.done => (
        Icons.check_circle,
        AppColors.accentGreen,
        'Render complete',
      ),
      _Phase.error => (
        Icons.error_outline,
        AppColors.accentAmber,
        'Render failed',
      ),
    };
    return Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'ffmpeg · 1080p',
          overflow: TextOverflow.ellipsis,
          style: AppTheme.mono.copyWith(
            color: AppColors.textFaint,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  List<Widget> _body() {
    switch (_phase) {
      case _Phase.rendering:
        return [
          const ClipRRect(
            borderRadius: BorderRadius.all(Radius.circular(4)),
            child: LinearProgressIndicator(
              minHeight: 6,
              backgroundColor: AppColors.surfaceHigh,
              valueColor: AlwaysStoppedAnimation(AppColors.accentCyan),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Compositing ${widget.scenes.length} scenes with ffmpeg + narration…',
            style: AppTheme.mono.copyWith(
              color: AppColors.textMuted,
              fontSize: 12,
            ),
          ),
        ];
      case _Phase.done:
        final r = _result!;
        return [_OutputRow(result: r)];
      case _Phase.error:
        return [
          Text(
            'Could not reach the render provider.\n'
            'Start it with:  python3 backend/provider_server.py',
            style: AppTheme.mono.copyWith(
              color: AppColors.textMuted,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ];
    }
  }

  Widget _actions() {
    return Align(
      alignment: Alignment.centerRight,
      child: switch (_phase) {
        _Phase.rendering => TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
        _Phase.done => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: () => widget.client.open(_result!.path),
              child: const Text(
                'Play',
                style: TextStyle(color: AppColors.accentCyan),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accentGreen,
                foregroundColor: AppColors.background,
              ),
              child: const Text('Done'),
            ),
          ],
        ),
        _Phase.error => FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.surfaceHigh,
            foregroundColor: AppColors.textPrimary,
          ),
          child: const Text('Close'),
        ),
      },
    );
  }
}

class _OutputRow extends StatelessWidget {
  const _OutputRow({required this.result});
  final RenderResult result;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.movie_outlined,
            size: 16,
            color: AppColors.accentGreen,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              result.path.split('/').last,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.mono.copyWith(
                color: AppColors.textPrimary,
                fontSize: 12,
              ),
            ),
          ),
          Text(
            '${result.seconds.toStringAsFixed(0)}s · '
            '${(result.bytes / 1024).round()} KB',
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
