import 'package:cloud_firestore/cloud_firestore.dart';

class ChatThread {
  final String id;
  final List<String> participants;
  final Map<String, dynamic> participantsData;
  final String? lastMessage;
  final String? lastMessageSenderId;
  final DateTime? lastMessageAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, int> unreadCounts;
  final Map<String, dynamic> metadata;

  ChatThread({
    required this.id,
    required this.participants,
    required this.participantsData,
    required this.lastMessage,
    required this.lastMessageSenderId,
    required this.lastMessageAt,
    required this.createdAt,
    required this.updatedAt,
    required this.unreadCounts,
    required this.metadata,
  });

  String? get orderId {
    final value = metadata['orderId'];
    return value?.toString();
  }

  factory ChatThread.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? <String, dynamic>{};
    final createdAt = _timestampToDateTime(data['createdAt']);
    final updatedAt = _timestampToDateTime(data['updatedAt']);
    final lastMessageAt = _timestampToDateTime(data['lastMessageAt']);

    final unreadData = data['unreadCounts'];
    final unreadCounts = <String, int>{};
    if (unreadData is Map) {
      unreadData.forEach((key, value) {
        unreadCounts[key.toString()] = value is num ? value.toInt() : 0;
      });
    }

    return ChatThread(
      id: snapshot.id,
      participants: List<String>.from(data['participants'] ?? const <String>[]),
      participantsData: Map<String, dynamic>.from(
        data['participantsData'] ?? <String, dynamic>{},
      ),
      lastMessage: data['lastMessage']?.toString(),
      lastMessageSenderId: data['lastMessageSenderId']?.toString(),
      lastMessageAt: lastMessageAt,
      createdAt: createdAt ?? DateTime.now(),
      updatedAt: updatedAt ?? DateTime.now(),
      unreadCounts: unreadCounts,
      metadata: Map<String, dynamic>.from(data['metadata'] ?? <String, dynamic>{}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'participants': participants,
      'participantsData': participantsData,
      'lastMessage': lastMessage,
      'lastMessageSenderId': lastMessageSenderId,
      'lastMessageAt': lastMessageAt,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'unreadCounts': unreadCounts,
      if (metadata.isNotEmpty) 'metadata': metadata,
    };
  }

  int unreadCountFor(String userId) {
    return unreadCounts[userId] ?? 0;
  }

  String? otherParticipantId(String myUserId) {
    for (final participant in participants) {
      if (participant != myUserId) {
        return participant;
      }
    }
    return null;
  }

  String? participantName(String userId) {
    final userData = participantsData[userId];
    if (userData is Map<String, dynamic>) {
      return userData['nombre']?.toString();
    }
    return null;
  }

  String? participantPhotoUrl(String userId) {
    final userData = participantsData[userId];
    if (userData is Map<String, dynamic>) {
      return userData['photoUrl']?.toString();
    }
    return null;
  }

  bool participantIsOnline(String userId) {
    final userData = participantsData[userId];
    if (userData is Map<String, dynamic>) {
      return (userData['isOnline'] as bool?) ?? false;
    }
    return false;
  }

  DateTime? participantLastSeenAt(String userId) {
    final userData = participantsData[userId];
    if (userData is Map<String, dynamic>) {
      final timestamp = userData['lastSeenAt'];
      if (timestamp is Timestamp) {
        return timestamp.toDate();
      }
      if (timestamp is DateTime) {
        return timestamp;
      }
    }
    return null;
  }

  static DateTime? _timestampToDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return null;
  }
}

