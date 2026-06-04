import 'dart:io';
import 'package:flutter/foundation.dart';

import '../models/conversation_model.dart';
import 'context_builder.dart';
import 'response_generator.dart';
import '../../../../services/api_service.dart';
import '../../../../services/storage_service.dart';
import '../../data/conversation_storage.dart';

/// Orchestrates the assistant workflow:
/// 1. Builds context from user data
/// 2. Generates a contextual response
/// 3. Returns a complete ConversationMessage
///
/// This service is designed to be replaceable with an LLM API call
/// (e.g., Gemini, OpenAI) without changing the provider or UI layers.
class AssistantEngine {
  final ContextBuilder _contextBuilder;
  final ResponseGenerator _responseGenerator;

  AssistantEngine({
    ContextBuilder? contextBuilder,
    ResponseGenerator? responseGenerator,
  })  : _contextBuilder = contextBuilder ?? ContextBuilder(),
        _responseGenerator = responseGenerator ?? ResponseGenerator();

  Future<ConversationMessage> processMessage(String userMessage) async {
    // Intercept emergency messages immediately on the client side to avoid latency/network dependency
    if (ResponseGenerator.isEmergencyQuery(userMessage)) {
      return ConversationMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sender: MessageSender.assistant,
        content: ResponseGenerator.getRegionalCrisisResponse(ResponseGenerator.getSafeLocale()),
        timestamp: DateTime.now(),
        contextTag: 'safety',
      );
    }

    // 1. Build context from latest check-in and prediction data
    final context = await _contextBuilder.buildContext();

    // Load conversation history for context and remote API
    final historyMessages = await ConversationStorage().getConversation();
    final List<Map<String, String>> historyJson = historyMessages.map((m) {
      return {
        'role': m.sender == MessageSender.user ? 'user' : 'assistant',
        'content': m.content,
      };
    }).toList();
    context['conversation_history'] = historyJson;

    // 2. Generate response text, first trying backend
    String responseText = '';
    bool loadedFromBackend = false;

    try {
      final profileId = await StorageService().getCurrentProfileId();
      if (profileId != null) {
        final apiService = ApiService();
        final response = await apiService.post(
          '/assistant/message',
          {
            'message': userMessage,
            'conversation_history': historyJson,
          },
          queryParams: {
            'profile_id': profileId,
            'locale': ResponseGenerator.getSafeLocale(),
          },
        );

        if (response != null && response['reply'] != null) {
          responseText = response['reply'] as String;
          loadedFromBackend = true;
        }
      }
    } catch (e) {
      debugPrint('Assistant remote message failed, using local offline fallback: $e');
    }

    if (!loadedFromBackend) {
      // Local fallback
      final localText = _responseGenerator.generate(userMessage, context);
      responseText = ResponseGenerator.isEmergencyQuery(userMessage)
          ? localText
          : '[Offline Local Companion]\n$localText';
    }

    // 3. Determine context tag based on the query
    final contextTag = _determineContextTag(userMessage.toLowerCase());

    // 4. Return a structured assistant message
    return ConversationMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sender: MessageSender.assistant,
      content: responseText,
      timestamp: DateTime.now(),
      contextTag: contextTag,
    );
  }


  String? _determineContextTag(String msg) {
    if (msg.contains('sleep')) return 'sleep';
    if (msg.contains('activity') || msg.contains('step')) return 'activity';
    if (msg.contains('heart') || msg.contains('pulse')) return 'heart';
    if (msg.contains('blood pressure') || msg.contains('bp')) return 'blood_pressure';
    if (msg.contains('glucose') || msg.contains('sugar')) return 'glucose';
    if (msg.contains('score') || msg.contains('overall')) return 'wellness_score';
    if (msg.contains('insight') || msg.contains('trend')) return 'insights';
    return null;
  }
}
