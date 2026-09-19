/// Data models for direct messaging between users.
library;

class DirectMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String text;
  final DateTime createdAt;
  final bool isRead;

  const DirectMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.text,
    required this.createdAt,
    this.isRead = false,
  });

  factory DirectMessage.fromJson(Map<String, dynamic> json) => DirectMessage(
        id: json['id'] as String,
        conversationId: json['conversation_id'] as String,
        senderId: json['sender_id'] as String,
        text: json['text'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        isRead: json['is_read'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'conversation_id': conversationId,
        'sender_id': senderId,
        'text': text,
        'created_at': createdAt.toIso8601String(),
        'is_read': isRead,
      };
}

class Conversation {
  final String id;
  final String participantA;
  final String participantB;
  final DateTime updatedAt;
  final DirectMessage? lastMessage;
  final String otherUserName;
  final String otherUserAvatar;
  final int unreadCount;

  const Conversation({
    required this.id,
    required this.participantA,
    required this.participantB,
    required this.updatedAt,
    this.lastMessage,
    this.otherUserName = '',
    this.otherUserAvatar = '',
    this.unreadCount = 0,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
        id: json['id'] as String,
        participantA: (json['participant_a'] ?? json['participantA']) as String,
        participantB: (json['participant_b'] ?? json['participantB']) as String,
        updatedAt: DateTime.parse(json['updated_at'] ?? json['updatedAt'] as String),
        lastMessage: json['last_message'] != null
            ? DirectMessage.fromJson(json['last_message'] as Map<String, dynamic>)
            : (json['lastMessage'] != null
                ? DirectMessage.fromJson(json['lastMessage'] as Map<String, dynamic>)
                : null),
        otherUserName: (json['other_user_name'] ?? json['otherUserName'] ?? '') as String,
        otherUserAvatar: (json['other_user_avatar'] ?? json['otherUserAvatar'] ?? '') as String,
        unreadCount: (json['unread_count'] ?? json['unreadCount'] ?? 0) as int,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'participant_a': participantA,
        'participant_b': participantB,
        'updated_at': updatedAt.toIso8601String(),
        if (lastMessage != null) 'last_message': lastMessage!.toJson(),
        'other_user_name': otherUserName,
        'other_user_avatar': otherUserAvatar,
        'unread_count': unreadCount,
      };

  Conversation copyWith({
    DirectMessage? lastMessage,
    String? otherUserName,
    String? otherUserAvatar,
    int? unreadCount,
    DateTime? updatedAt,
  }) =>
      Conversation(
        id: id,
        participantA: participantA,
        participantB: participantB,
        updatedAt: updatedAt ?? this.updatedAt,
        lastMessage: lastMessage ?? this.lastMessage,
        otherUserName: otherUserName ?? this.otherUserName,
        otherUserAvatar: otherUserAvatar ?? this.otherUserAvatar,
        unreadCount: unreadCount ?? this.unreadCount,
      );
}
