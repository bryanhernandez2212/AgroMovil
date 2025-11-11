import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String chatId;
  final String senderId;
  final String type;
  final String? text;
  final String? imageUrl;
  final DateTime createdAt;
  final List<String> readBy;
  final Map<String, dynamic> metadata;

  ChatMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.type,
    required this.text,
    required this.imageUrl,
    required this.createdAt,
    required this.readBy,
    required this.metadata,
  });

  factory ChatMessage.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? <String, dynamic>{};
    final timestamp = data['createdAt'] as Timestamp?;

    return ChatMessage(
      id: snapshot.id,
      chatId: data['chatId']?.toString() ?? '',
      senderId: data['senderId']?.toString() ?? '',
      type: data['type']?.toString() ?? 'text',
      text: data['text']?.toString(),
      imageUrl: data['imageUrl']?.toString(),
      createdAt: timestamp != null ? timestamp.toDate() : DateTime.now(),
      readBy: List<String>.from(data['readBy'] ?? const <String>[]),
      metadata: Map<String, dynamic>.from(data['metadata'] ?? <String, dynamic>{}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'chatId': chatId,
      'senderId': senderId,
      'type': type,
      if (text != null) 'text': text,
      if (imageUrl != null) 'imageUrl': imageUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'readBy': readBy,
      if (metadata.isNotEmpty) 'metadata': metadata,
    };
  }

  bool isReadBy(String userId) {
    return readBy.contains(userId);
  }

  ChatMessage copyWith({
    String? id,
    String? chatId,
    String? senderId,
    String? type,
    String? text,
    String? imageUrl,
    DateTime? createdAt,
    List<String>? readBy,
    Map<String, dynamic>? metadata,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      type: type ?? this.type,
      text: text ?? this.text,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      readBy: readBy ?? List<String>.from(this.readBy),
      metadata: metadata ?? Map<String, dynamic>.from(this.metadata),
    );
  }
}

