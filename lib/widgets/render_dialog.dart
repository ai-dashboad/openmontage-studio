import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import '../services/provider_manager.dart';
import '../services/render_client.dart';
import '../theme/app_theme.dart';

/// Shows the render dialog, which renders a real MP4 via the local provider
/// (`backend/provider_server.py`) and reports the finished file. On success it
/// can be saved to a chosen location or revealed in Finder; if the provider is
/// down, [provider] is used to start it and retry without a terminal.
Future<void> showRenderDialog(
  BuildContext context, {
  required RenderClient client,
  required List<Map<String, dynamic>> scenes,
  ProviderManager? provider,
  ValueChanged<RenderResult>? onComplete,
  String projectName = 'video',
  String? voice,
  String runtime = 'ffmpeg',
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    builder: (_) => _RenderDialog(
      client: client,
      scenes: scenes,
      provider: provider,
      onComplete: onComplete,
      projectName: projectName,
      voice: voice,
      runtime: runtime,
    ),
  );
}

enum _Phase { rendering, done, error }

class _RenderDialog extends StatefulWidget {
  const _RenderDialog({
    required this.client,
    required this.scenes,
    required this.projectName,
    this.provider,
    this.onComplete,
    this.voice,
    this.runtime = 'ffmpeg',
  });
  final RenderClient client;
  final List<Map<String, dynamic>> scenes;
  final String projectName;
  final ProviderManager? provider;
  final ValueChanged<RenderResult>? onComplete;
  final String? voice;
  final String runtime;

  @override
  State<_RenderDialog> createState() => _RenderDialogState();
}

class _RenderDialogState extends State<_RenderDialog> {
  _Phase _phase = _Phase.rendering;
  RenderResult? _result;
  bool _startingProvider = false;

  @override
  void initState() {
    super.initState();
    _render();
  }

  Future<void> _render() async {
    setState(() => _phase = _Phase.rendering);
    try {
      final result = await widget.client.render(
        widget.scenes,
        voice: widget.voice,
        runtime: widget.runtime,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _phase = _Phase.done;
      });
      widget.onComplete?.call(result);
    } catch (_) {
      if (!mounted) return;
      setState(() => _phase = _Phase.error);
    }
  }

  /// Starts the media provider, then retries the render.
  Future<void> _startAndRetry() async {
    if (widget.provider == null) return;
    setState(() => _startingProvider = true);
    await widget.provider!.ensureRunning();
    if (!mounted) return;
    setState(() => _startingProvider = false);
    if (widget.provider!.mediaUp) {
      await _render();
    }
  }

  Future<void> _saveCopy() async {
    final result = _result;
    if (result == null) return;
    final location = await getSaveLocation(
      suggestedName: '${_safeName(widget.projectName)}.mp4',
      acceptedTypeGroups: const [
        XTypeGroup(label: 'MP4 video', extensions: ['mp4']),
      ],
    );
    if (location == null) return;
    try {
      await File(result.path).copy(location.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.surfaceHigh,
            content: Text(
              'Saved to ${location.path}',
              style: const TextStyle(color: AppColors.textPrimary),
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save the file.')),
        );
      }
    }
  }

  String _safeName(String name) =>
      name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Container(
        width: 460,
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
          '${widget.runtime} · 1080p',
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
            widget.runtime == 'remotion'
                ? 'Rendering ${widget.scenes.length} cinematic scenes '
                      '(motion graphics + narration)…'
                : 'Compositing ${widget.scenes.length} scenes with ffmpeg '
                      '+ narration…',
            style: AppTheme.mono.copyWith(
              color: AppColors.textMuted,
              fontSize: 12,
            ),
          ),
        ];
      case _Phase.done:
        return [_OutputRow(result: _result!)];
      case _Phase.error:
        return [
          Text(
            widget.provider != null
                ? 'The media provider is not running.\n'
                      'Click "Start & retry" to launch it automatically.'
                : 'Could not reach the render provider.\n'
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
        _Phase.done => Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TextButton.icon(
              onPressed: () => widget.client.reveal(_result!.path),
              icon: const Icon(Icons.folder_open, size: 16),
              label: const Text('Reveal'),
              style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
            ),
            TextButton.icon(
              onPressed: _saveCopy,
              icon: const Icon(Icons.download, size: 16),
              label: const Text('Save a copy'),
              style: TextButton.styleFrom(foregroundColor: AppColors.accentCyan),
            ),
            TextButton.icon(
              onPressed: () => widget.client.open(_result!.path),
              icon: const Icon(Icons.play_arrow, size: 16),
              label: const Text('Play'),
              style: TextButton.styleFrom(foregroundColor: AppColors.accentCyan),
            ),
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
        _Phase.error => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Close',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
            if (widget.provider != null) ...[
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _startingProvider ? null : _startAndRetry,
                icon: _startingProvider
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.background,
                        ),
                      )
                    : const Icon(Icons.play_circle_outline, size: 18),
                label: Text(_startingProvider ? 'Starting…' : 'Start & retry'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accentCyan,
                  foregroundColor: AppColors.background,
                ),
              ),
            ],
          ],
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
