// Conversation model for the VitalShield AI Assistant.
// Stores individual messages with sender, content, timestamp, and optional context.

enum MessageSender { user, assistant }

class ConversationMessage {
  final String id;
  final MessageSender sender;
  final String content;
  final DateTime timestamp;
  final String? contextTag;

  const ConversationMessage({
    required this.id,
    required this.sender,
    required this.content,
    required this.timestamp,
    this.contextTag,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender': sender == MessageSender.user ? 'user' : 'assistant',
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'context_tag': contextTag,
    };
  }

  factory ConversationMessage.fromJson(Map<String, dynamic> json) {
    return ConversationMessage(
      id: json['id'] as String,
      sender: json['sender'] == 'user' ? MessageSender.user : MessageSender.assistant,
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      contextTag: json['context_tag'] as String?,
    );
  }
}
