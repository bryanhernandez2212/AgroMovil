import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'package:agromarket/models/chat_message_model.dart';
import 'package:agromarket/models/chat_thread_model.dart';

class ChatService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  static String generateChatId({
    required String currentUserId,
    required String otherUserId,
    required String orderId,
  }) {
    final participants = [currentUserId, otherUserId]..sort();
    return '${orderId}_${participants.join('_')}';
  }

  static CollectionReference<Map<String, dynamic>> get _chatCollection =>
      _firestore.collection('chats');

  static Future<String> ensureChat({
    required String orderId,
    required String currentUserId,
    required String otherUserId,
    String? currentUserName,
    String? otherUserName,
    Map<String, dynamic>? metadata,
  }) async {
    final chatId = generateChatId(
      currentUserId: currentUserId,
      otherUserId: otherUserId,
      orderId: orderId,
    );
    final chatRef = _chatCollection.doc(chatId);
    final chatSnapshot = await chatRef.get();

    if (chatSnapshot.exists) {
      // Actualizar los datos de participantes si faltan campos clave
      await _refreshParticipantsData(
        chatRef: chatRef,
        userIds: [currentUserId, otherUserId],
        overrideNames: {
          if (currentUserName != null) currentUserId: currentUserName,
          if (otherUserName != null) otherUserId: otherUserName,
        },
      );

      final existingMetadata = chatSnapshot.data()?['metadata'] as Map<String, dynamic>? ?? {};
      if (existingMetadata['orderId'] != orderId) {
        await chatRef.update({
          'metadata.orderId': orderId,
        });
      }
      return chatId;
    }

    final participantsData = <String, dynamic>{};
    final currentUserData = await _buildParticipantData(
      userId: currentUserId,
      overrideName: currentUserName,
    );
    final otherUserData = await _buildParticipantData(
      userId: otherUserId,
      overrideName: otherUserName,
    );

    participantsData[currentUserId] = currentUserData;
    participantsData[otherUserId] = otherUserData;

    await chatRef.set({
      'participants': [currentUserId, otherUserId],
      'participantsData': participantsData,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastMessage': null,
      'lastMessageSenderId': null,
      'lastMessageAt': null,
      'unreadCounts': {
        currentUserId: 0,
        otherUserId: 0,
      },
      'metadata': {
        'orderId': orderId,
        if (metadata != null && metadata.isNotEmpty) ...metadata,
      },
    });

    return chatId;
  }

  static Stream<List<ChatThread>> streamUserChats(String userId) {
    return _chatCollection
        .where('participants', arrayContains: userId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(ChatThread.fromSnapshot)
              .toList(growable: false),
        );
  }

  static Stream<List<ChatMessage>> streamChatMessages(String chatId) {
    return _chatCollection
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(ChatMessage.fromSnapshot)
              .toList(growable: false),
        );
  }

  static Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String text,
    Map<String, dynamic>? metadata,
  }) async {
    if (text.trim().isEmpty) return;

    final chatRef = _chatCollection.doc(chatId);
    final messageRef = chatRef.collection('messages').doc();
    final senderProfile = await _buildParticipantData(userId: senderId);

    await _firestore.runTransaction((transaction) async {
      final chatSnapshot = await transaction.get(chatRef);

      if (!chatSnapshot.exists) {
        throw StateError('El chat no existe');
      }

      final chatData = chatSnapshot.data() ?? <String, dynamic>{};
      final participants = List<String>.from(chatData['participants'] ?? const <String>[]);
      final unreadCounts = <String, int>{};
      final storedUnreadCounts = chatData['unreadCounts'];

      for (final participant in participants) {
        final currentCount = storedUnreadCounts is Map
            ? (storedUnreadCounts[participant] as num?)?.toInt() ?? 0
            : 0;
        unreadCounts[participant] =
            participant == senderId ? 0 : currentCount + 1;
      }

      transaction.set(messageRef, {
        'chatId': chatId,
        'senderId': senderId,
        'type': 'text',
        'text': text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'readBy': [senderId],
        if (metadata != null && metadata.isNotEmpty) 'metadata': metadata,
      });

      transaction.update(chatRef, {
        'lastMessage': text.trim(),
        'lastMessageSenderId': senderId,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'unreadCounts': unreadCounts,
        'participantsData.$senderId': senderProfile,
      });
    });
  }

  static Future<void> sendImageMessage({
    required String chatId,
    required String senderId,
    required File imageFile,
    Map<String, dynamic>? metadata,
  }) async {
    final chatRef = _chatCollection.doc(chatId);
    final messageRef = chatRef.collection('messages').doc();
    final storagePath = 'chat_media/$chatId/${messageRef.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final storageRef = _storage.ref().child(storagePath);

    await storageRef.putFile(imageFile);
    final downloadUrl = await storageRef.getDownloadURL();
    final senderProfile = await _buildParticipantData(userId: senderId);

    await _firestore.runTransaction((transaction) async {
      final chatSnapshot = await transaction.get(chatRef);

      if (!chatSnapshot.exists) {
        throw StateError('El chat no existe');
      }

      final chatData = chatSnapshot.data() ?? <String, dynamic>{};
      final participants = List<String>.from(chatData['participants'] ?? const <String>[]);
      final unreadCounts = <String, int>{};
      final storedUnreadCounts = chatData['unreadCounts'];

      for (final participant in participants) {
        final currentCount = storedUnreadCounts is Map
            ? (storedUnreadCounts[participant] as num?)?.toInt() ?? 0
            : 0;
        unreadCounts[participant] =
            participant == senderId ? 0 : currentCount + 1;
      }

      transaction.set(messageRef, {
        'chatId': chatId,
        'senderId': senderId,
        'type': 'image',
        'text': null,
        'imageUrl': downloadUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'readBy': [senderId],
        if (metadata != null && metadata.isNotEmpty) 'metadata': metadata,
      });

      transaction.update(chatRef, {
        'lastMessage': '📷 Imagen',
        'lastMessageSenderId': senderId,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'unreadCounts': unreadCounts,
        'participantsData.$senderId': senderProfile,
      });
    });
  }

  static Future<void> markMessagesAsRead({
    required String chatId,
    required String userId,
    int limit = 100,
  }) async {
    final chatRef = _chatCollection.doc(chatId);
    final messagesQuery = await chatRef
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    final batch = _firestore.batch();
    for (final doc in messagesQuery.docs) {
      final data = doc.data();
      final readBy = List<String>.from(data['readBy'] ?? const <String>[]);
      if (!readBy.contains(userId)) {
        readBy.add(userId);
        batch.update(doc.reference, {'readBy': readBy});
      }
    }

    batch.update(chatRef, {
      'unreadCounts.$userId': 0,
      'participantsData.$userId.lastSeenAt': FieldValue.serverTimestamp(),
      'participantsData.$userId.isOnline': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  static Future<void> updatePresence({
    required String userId,
    required bool isOnline,
    DateTime? lastSeenAt,
  }) async {
    final userDocRef = _firestore.collection('usuarios').doc(userId);
    final userPresenceUpdate = <String, dynamic>{
      'isOnline': isOnline,
      'lastSeenAt': lastSeenAt != null
          ? Timestamp.fromDate(lastSeenAt)
          : FieldValue.serverTimestamp(),
    };

    try {
      await userDocRef.set(userPresenceUpdate, SetOptions(merge: true));
    } catch (_) {}

    final updateData = <String, dynamic>{
      'participantsData.$userId.isOnline': isOnline,
    };
    if (!isOnline) {
      updateData['participantsData.$userId.lastSeenAt'] =
          FieldValue.serverTimestamp();
    } else if (lastSeenAt != null) {
      updateData['participantsData.$userId.lastSeenAt'] = Timestamp.fromDate(lastSeenAt);
    }

    final userChats = await _chatCollection
        .where('participants', arrayContains: userId)
        .get();

    final batch = _firestore.batch();
    for (final chatDoc in userChats.docs) {
      batch.update(chatDoc.reference, updateData);
    }
    await batch.commit();
  }

  static Future<void> _refreshParticipantsData({
    required DocumentReference<Map<String, dynamic>> chatRef,
    required List<String> userIds,
    Map<String, String>? overrideNames,
  }) async {
    final Map<String, dynamic> updates = {};
    for (final userId in userIds) {
      final data = await _buildParticipantData(
        userId: userId,
        overrideName: overrideNames?[userId],
      );
      updates['participantsData.$userId'] = data;
    }

    if (updates.isNotEmpty) {
      await chatRef.update(updates);
    }
  }

  static Future<Map<String, dynamic>> _buildParticipantData({
    required String userId,
    String? overrideName,
  }) async {
    final userDoc =
        await _firestore.collection('usuarios').doc(userId).get();
    final data = userDoc.data() ?? <String, dynamic>{};

    final nombre = overrideName ??
        data['nombre']?.toString() ??
        data['nombre_tienda']?.toString() ??
        'Usuario';

    return {
      'id': userId,
      'nombre': nombre,
      'nombre_tienda': data['nombre_tienda'],
      'email': data['email'],
      'rol_activo': data['rol_activo'],
      'photoUrl': data['photoUrl'],
      'isOnline': data['isOnline'] ?? false,
      'lastSeenAt': data['lastSeenAt'],
    };
  }
}

