import 'package:flutter/foundation.dart';
import '../models/studio_models.dart';
import 'agent_service.dart';

/// Owns the single agent conversation for a production so every surface shares
/// it: the home brief seeds it, the side-panel chat shows and extends it, and
/// pipeline approvals append a grounded line. Lifting it out of the chat widget
/// is what makes "type a brief, then talk to the same agent" feel continuous.
class ConversationController extends ChangeNotifier {
  ConversationController({required this.agent, List<ChatMessage>? seed})
    : _messages = [...(seed ?? const <ChatMessage>[])];

  final AgentService agent;
  final List<ChatMessage> _messages;

  bool _sending = false;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get sending => _sending;

  /// Appends an agent line (optionally carrying an [artifact] tag) without a
  /// round-trip — used by approvals and other system events.
  void addAgentLine(String text, {String? artifact}) {
    _messages.add(
      ChatMessage(role: ChatRole.agent, text: text, artifact: artifact),
    );
    notifyListeners();
  }

  /// Sends a user [text] to the agent and appends the reply. Failures append a
  /// friendly offline note rather than throwing.
  Future<void> send(String text) async {
    if (text.trim().isEmpty || _sending) return;
    _messages.add(ChatMessage(role: ChatRole.user, text: text.trim()));
    _sending = true;
    notifyListeners();
    try {
      final reply = await agent.reply(_messages);
      _messages.add(ChatMessage(role: ChatRole.agent, text: reply));
    } catch (_) {
      _messages.add(
        const ChatMessage(
          role: ChatRole.agent,
          text:
              'Could not reach the local agent. Is Ollama running with a model '
              'pulled? (ollama serve · ollama pull qwen2.5)',
        ),
      );
    } finally {
      _sending = false;
      notifyListeners();
    }
  }
}
