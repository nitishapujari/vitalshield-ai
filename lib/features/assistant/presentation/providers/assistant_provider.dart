import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/conversation_model.dart';
import '../../domain/services/assistant_engine.dart';
import '../../domain/services/response_generator.dart';
import '../../data/conversation_storage.dart';

/// State for the assistant screen.
class AssistantState {
  final List<ConversationMessage> messages;
  final bool isLoading;
  final bool isTyping;

  const AssistantState({
    this.messages = const [],
    this.isLoading = false,
    this.isTyping = false,
  });

  AssistantState copyWith({
    List<ConversationMessage>? messages,
    bool? isLoading,
    bool? isTyping,
  }) {
    return AssistantState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isTyping: isTyping ?? this.isTyping,
    );
  }
}

class AssistantNotifier extends StateNotifier<AssistantState> {
  final AssistantEngine _engine;
  final ConversationStorage _storage;

  AssistantNotifier({
    AssistantEngine? engine,
    ConversationStorage? storage,
  })  : _engine = engine ?? AssistantEngine(),
        _storage = storage ?? ConversationStorage(),
        super(const AssistantState());

  /// Loads persisted conversation history.
  Future<void> loadConversation() async {
    state = state.copyWith(isLoading: true);
    try {
      final messages = await _storage.getConversation();
      state = state.copyWith(messages: messages, isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Sends a user message, processes it, and appends the assistant response.
  Future<void> sendMessage(String text) async {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) return;

    // Create and append user message
    final userMessage = ConversationMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sender: MessageSender.user,
      content: trimmedText,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isTyping: true,
    );
    await _storage.saveMessage(userMessage);

    // Simulate a brief thinking delay for natural feel
    await Future.delayed(const Duration(milliseconds: 400));

    // Top-priority Crisis Detection Check
    if (ResponseGenerator.isEmergencyQuery(trimmedText)) {
      final safetyResponse = ConversationMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sender: MessageSender.assistant,
        content: ResponseGenerator.getRegionalCrisisResponse(ResponseGenerator.getSafeLocale()),
        timestamp: DateTime.now(),
        contextTag: 'safety',
      );
      state = state.copyWith(
        messages: [...state.messages, safetyResponse],
        isTyping: false,
      );
      await _storage.saveMessage(safetyResponse);
      return;
    }

    // Generate assistant response
    try {
      final response = await _engine.processMessage(trimmedText);
      state = state.copyWith(
        messages: [...state.messages, response],
        isTyping: false,
      );
      await _storage.saveMessage(response);
    } catch (_) {
      // Catch-all emergency fallback safety check
      if (ResponseGenerator.isEmergencyQuery(trimmedText)) {
        final safetyResponse = ConversationMessage(
          id: '${DateTime.now().millisecondsSinceEpoch}_safety_err',
          sender: MessageSender.assistant,
          content: ResponseGenerator.getRegionalCrisisResponse(ResponseGenerator.getSafeLocale()),
          timestamp: DateTime.now(),
          contextTag: 'safety',
        );
        state = state.copyWith(
          messages: [...state.messages, safetyResponse],
          isTyping: false,
        );
        await _storage.saveMessage(safetyResponse);
        return;
      }

      final fallback = ConversationMessage(
        id: '${DateTime.now().millisecondsSinceEpoch}_err',
        sender: MessageSender.assistant,
        content: 'I wasn\'t able to process that right now. Please try again in a moment.',
        timestamp: DateTime.now(),
        contextTag: 'error',
      );
      state = state.copyWith(
        messages: [...state.messages, fallback],
        isTyping: false,
      );
      await _storage.saveMessage(fallback);
    }
  }

  /// Retries sending the last user message after a failure.
  Future<void> retryLastMessage() async {
    final userMsgs = state.messages.where((m) => m.sender == MessageSender.user).toList();
    if (userMsgs.isEmpty) return;

    final lastUserMsg = userMsgs.last.content;

    // Remove the last message if it was an error message
    if (state.messages.isNotEmpty && state.messages.last.contextTag == 'error') {
      final updatedMsgs = List<ConversationMessage>.from(state.messages)..removeLast();
      state = state.copyWith(messages: updatedMsgs);
      
      // Sync local storage
      await _storage.clearConversation();
      for (final msg in updatedMsgs) {
        await _storage.saveMessage(msg);
      }
    }

    await sendMessage(lastUserMsg);
  }

  /// Clears the conversation history.
  Future<void> clearConversation() async {
    await _storage.clearConversation();
    state = const AssistantState();
  }
}

final assistantProvider =
    StateNotifierProvider<AssistantNotifier, AssistantState>((ref) {
  return AssistantNotifier();
});
