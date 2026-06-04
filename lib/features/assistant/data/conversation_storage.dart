import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/models/conversation_model.dart';
import '../../../../services/storage_service.dart';

/// Persists conversation history locally via SharedPreferences.
/// Designed for future migration to a backend database.
class ConversationStorage {
  static const String _conversationKey = 'assistant_conversation_history';
  static const int _maxMessages = 100;
  
  final StorageService _storage = StorageService();

  Future<String> _getKey() async {
    final prefix = await _storage.getProfilePrefix();
    return '$prefix$_conversationKey';
  }

  /// Saves a single message to the conversation history.
  Future<void> saveMessage(ConversationMessage message) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getKey();
    final existing = prefs.getStringList(key) ?? [];

    existing.add(json.encode(message.toJson()));

    // Keep only the most recent messages
    if (existing.length > _maxMessages) {
      existing.removeRange(0, existing.length - _maxMessages);
    }

    await prefs.setStringList(key, existing);
  }

  /// Retrieves the full conversation history.
  Future<List<ConversationMessage>> getConversation() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getKey();
    final stored = prefs.getStringList(key) ?? [];

    final List<ConversationMessage> messages = [];
    for (final str in stored) {
      try {
        messages.add(ConversationMessage.fromJson(json.decode(str)));
      } catch (_) {
        // Skip corrupted entries
      }
    }
    return messages;
  }

  /// Clears the entire conversation history.
  Future<void> clearConversation() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getKey();
    await prefs.remove(key);
  }
}
