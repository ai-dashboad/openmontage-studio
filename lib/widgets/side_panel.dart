import 'package:flutter/material.dart';
import '../models/studio_models.dart';
import '../services/agent_service.dart';
import '../services/conversation.dart';
import '../theme/app_theme.dart';

/// The secondary surface between the rail and the preview. It shows either the
/// agent conversation (rail index == chat) or an asset-family gallery, and can
/// be collapsed to give the preview more room.
class SidePanel extends StatelessWidget {
  const SidePanel({
    super.key,
    required this.railIndex,
    required this.chatIndex,
    required this.onCollapse,
    required this.conversation,
  });

  /// Selected rail entry: 0..3 are asset families, [chatIndex] is the agent chat.
  final int railIndex;
  final int chatIndex;
  final VoidCallback onCollapse;
  final ConversationController conversation;

  static const _familyTitles = ['Images', 'Clips', 'Voice', 'Music'];

  @override
  Widget build(BuildContext context) {
    final isChat = railIndex == chatIndex;
    final title = isChat ? 'Agent' : _familyTitles[railIndex];

    return Container(
      width: 300,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          _PanelHeader(
            title: title,
            accent: isChat ? AppColors.accentPurple : AppColors.accentCyan,
            onCollapse: onCollapse,
          ),
          Expanded(
            child: isChat
                ? _AgentChat(conversation: conversation)
                : _AssetGallery(family: _familyTitles[railIndex]),
          ),
        ],
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.title,
    required this.accent,
    required this.onCollapse,
  });
  final String title;
  final Color accent;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.fromLTRB(14, 0, 6, 0),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              letterSpacing: 1.0,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: onCollapse,
            icon: const Icon(
              Icons.chevron_left,
              size: 18,
              color: AppColors.textMuted,
            ),
            tooltip: 'Collapse panel',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _AgentChat extends StatefulWidget {
  const _AgentChat({required this.conversation});
  final ConversationController conversation;

  @override
  State<_AgentChat> createState() => _AgentChatState();
}

class _AgentChatState extends State<_AgentChat> {
  final ScrollController _scroll = ScrollController();
  AgentStatus? _status;

  @override
  void initState() {
    super.initState();
    widget.conversation.addListener(_onConversationChanged);
    _refreshStatus();
  }

  @override
  void dispose() {
    widget.conversation.removeListener(_onConversationChanged);
    _scroll.dispose();
    super.dispose();
  }

  void _onConversationChanged() {
    if (mounted) setState(_scrollToEnd);
  }

  Future<void> _refreshStatus() async {
    final s = await widget.conversation.agent.status();
    if (mounted) setState(() => _status = s);
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = widget.conversation.messages;
    final sending = widget.conversation.sending;
    return Column(
      children: [
        _StatusBar(status: _status),
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.all(12),
            children: [
              for (final m in messages) _Bubble(message: m),
              if (sending) const _Thinking(),
            ],
          ),
        ),
        _Composer(
          enabled: !sending,
          onSend: (t) => widget.conversation.send(t),
        ),
      ],
    );
  }
}

/// Live connection indicator for the local agent.
class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.status});
  final AgentStatus? status;

  @override
  Widget build(BuildContext context) {
    final connected = status?.connected ?? false;
    final color = connected ? AppColors.accentGreen : AppColors.accentAmber;
    final label = status == null
        ? 'connecting…'
        : connected
        ? status!.model
        : 'agent offline';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.mono.copyWith(color: color, fontSize: 11),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'local',
            style: TextStyle(color: AppColors.textFaint, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _Thinking extends StatelessWidget {
  const _Thinking();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Row(
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.accentPurple,
            ),
          ),
          SizedBox(width: 8),
          Text(
            'Agent is thinking…',
            style: TextStyle(color: AppColors.textFaint, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;
    final align = isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bg = isUser ? AppColors.surfaceHigh : AppColors.background;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Text(
            isUser ? 'You' : 'Agent',
            style: const TextStyle(color: AppColors.textFaint, fontSize: 10),
          ),
          const SizedBox(height: 3),
          Container(
            constraints: const BoxConstraints(maxWidth: 240),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              message.text,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
          if (message.artifact != null) _ArtifactCard(label: message.artifact!),
        ],
      ),
    );
  }
}

class _ArtifactCard extends StatelessWidget {
  const _ArtifactCard({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.accentPurple.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.accentPurple.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.description_outlined,
            size: 16,
            color: AppColors.accentPurple,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: AppTheme.mono.copyWith(
                color: AppColors.textPrimary,
                fontSize: 12,
              ),
            ),
          ),
          const Icon(Icons.open_in_new, size: 14, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

class _Composer extends StatefulWidget {
  const _Composer({required this.enabled, required this.onSend});
  final bool enabled;
  final ValueChanged<String> onSend;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text;
    if (text.trim().isEmpty || !widget.enabled) return;
    _controller.clear();
    widget.onSend(text);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 4, 6, 4),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('agentComposer'),
                controller: _controller,
                enabled: widget.enabled,
                onSubmitted: (_) => _submit(),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Message the agent…',
                  hintStyle: TextStyle(
                    color: AppColors.textFaint,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: widget.enabled ? _submit : null,
              icon: const Icon(
                Icons.arrow_upward,
                size: 18,
                color: AppColors.accentPurple,
              ),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

class _AssetGallery extends StatelessWidget {
  const _AssetGallery({required this.family});
  final String family;

  @override
  Widget build(BuildContext context) {
    // Only the image family has mock candidates; others show an empty state.
    final items = family == 'Images'
        ? MockProject.imageAssets
        : const <AssetItem>[];

    if (items.isEmpty) {
      return _EmptyFamily(family: family);
    }

    return GridView.count(
      crossAxisCount: 2,
      padding: const EdgeInsets.all(12),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 0.82,
      children: [
        for (final a in items) _AssetCard(item: a),
        const _AddCard(),
      ],
    );
  }
}

class _AssetCard extends StatelessWidget {
  const _AssetCard({required this.item});
  final AssetItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    item.accent.withValues(alpha: 0.35),
                    AppColors.surfaceHigh,
                  ],
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.image_outlined,
                  color: AppColors.textFaint,
                  size: 22,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.provider} · seed ${item.seed} · \$${item.costUsd.toStringAsFixed(2)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.mono.copyWith(
                    color: AppColors.textFaint,
                    fontSize: 9.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddCard extends StatelessWidget {
  const _AddCard();

  @override
  Widget build(BuildContext context) {
    return DottedPlaceholder(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.add, color: AppColors.textMuted, size: 20),
          SizedBox(height: 4),
          Text(
            'Regenerate',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _EmptyFamily extends StatelessWidget {
  const _EmptyFamily({required this.family});
  final String family;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.inventory_2_outlined,
              color: AppColors.textFaint,
              size: 28,
            ),
            const SizedBox(height: 10),
            Text(
              'No $family yet',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 4),
            const Text(
              'Generated in the assets stage',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textFaint, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

/// A dashed-border placeholder cell used for the "regenerate" action.
class DottedPlaceholder extends StatelessWidget {
  const DottedPlaceholder({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.border,
          style: BorderStyle.solid,
          width: 1,
        ),
        color: AppColors.background.withValues(alpha: 0.4),
      ),
      child: child,
    );
  }
}
