import 'dart:typed_data';

class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final bool isSecretary;
  final DateTime timestamp;
  final Uint8List? imageData;
  final String? expertType;
  final String? sessionId;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    this.isSecretary = false,
    required this.timestamp,
    this.imageData,
    this.expertType,
    this.sessionId,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    DateTime timestamp;
    if (json['created_at'] != null) {
      if (json['created_at'] is int) {
        timestamp = DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int);
      } else {
        timestamp = DateTime.parse(json['created_at'] as String);
      }
    } else {
      timestamp = DateTime.now();
    }

    return ChatMessage(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      text: json['content'] as String? ?? json['text'] as String? ?? '',
      isUser: json['message_type'] == 'user' || (json['isUser'] as bool? ?? false),
      isSecretary: json['message_type'] == 'secretary' || (json['isSecretary'] as bool? ?? false),
      timestamp: timestamp,
      expertType: json['expert_type'] as String?,
      sessionId: json['session_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': text,
      'message_type': isUser ? 'user' : (isSecretary ? 'secretary' : 'expert'),
      'created_at': timestamp.toIso8601String(),
      'expert_type': expertType,
      'session_id': sessionId,
    };
  }
}
