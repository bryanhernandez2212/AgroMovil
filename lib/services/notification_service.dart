import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _defaultChannel =
      AndroidNotificationChannel(
    'chat_messages',
    'Mensajes',
    description: 'Notificaciones de mensajes del chat',
    importance: Importance.high,
  );

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static Future<void> initialize() async {
    await _requestPermissions();
    await _configureLocalNotifications();

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);
  }

  static Future<void> _requestPermissions() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus ==
            AuthorizationStatus.denied ||
        settings.authorizationStatus ==
            AuthorizationStatus.notDetermined) {
      debugPrint('🔕 Notificaciones deshabilitadas por el usuario');
    }
  }

  static Future<void> _configureLocalNotifications() async {
    const androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings =
        InitializationSettings(android: androidInit, iOS: iosInit);

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final data =
              Map<String, dynamic>.from(jsonDecode(payload));
          _navigateFromNotificationData(data);
        } catch (e) {
          debugPrint('❌ Error procesando payload: $e');
        }
      },
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_defaultChannel);

    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  static Future<void> _handleForegroundMessage(
      RemoteMessage message) async {
    final notification = message.notification;
    final notificationType = message.data['type']?.toString() ?? '';
    
    // Determinar título y cuerpo según el tipo de notificación
    String title;
    String body;
    
    if (notificationType == 'order_status') {
      // Notificación de estado de pedido
      title = notification?.title ?? 
          message.data['title'] ?? 
          'Actualización de pedido';
      body = notification?.body ?? 
          message.data['body'] ?? 
          'Tu pedido ha sido actualizado';
    } else {
      // Notificación de chat
      title = notification?.title ??
          message.data['title'] ??
          'Nuevo mensaje';
      body = notification?.body ??
          message.data['body'] ??
          (message.data['type'] == 'image'
              ? '📷 Imagen'
              : 'Tienes un nuevo mensaje');
    }

    // Incluir todos los datos relevantes en el payload
    final payload = jsonEncode({
      'type': notificationType.isEmpty ? 'chat' : notificationType,
      'chatId': message.data['chatId'] ?? '',
      'orderId': message.data['orderId'] ?? '',
      'newStatus': message.data['newStatus'] ?? '',
    });

    await _localNotifications.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _defaultChannel.id,
          _defaultChannel.name,
          channelDescription: _defaultChannel.description,
          icon: '@mipmap/ic_launcher',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          presentBadge: true,
        ),
      ),
      payload: payload,
    );
  }

  static void _handleMessageTap(RemoteMessage message) {
    final data = message.data;
    _navigateFromNotificationData(data);
  }

  /// Navega según el tipo de notificación (chat o estado de pedido)
  static void _navigateFromNotificationData(Map<String, dynamic> data) async {
    final notificationType = data['type']?.toString() ?? '';
    
    // Si es una notificación de estado de pedido
    if (notificationType == 'order_status') {
      _navigateToOrders(data);
      return;
    }
    
    // Si es una notificación de chat (o sin tipo especificado)
    _navigateToChatFromData(data);
  }

  /// Navega a la pantalla de "Mis compras" cuando se toca una notificación de estado de pedido
  static void _navigateToOrders(Map<String, dynamic> data) async {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Navegar a la pantalla de "Mis compras"
      navigator.pushNamed('/orders');
    } catch (e) {
      debugPrint('❌ Error navegando a pedidos desde notificación: $e');
    }
  }

  static void _navigateToChatFromData(Map<String, dynamic> data) async {
    final chatId = data['chatId']?.toString();
    if (chatId == null || chatId.isEmpty) return;

    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final chatDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .get();
      if (!chatDoc.exists) return;

      final chatData = chatDoc.data() ?? <String, dynamic>{};
      final participants =
          List<String>.from(chatData['participants'] ?? const []);
      final otherUserId = participants.firstWhere(
        (uid) => uid != currentUser.uid,
        orElse: () => '',
      );

      if (otherUserId.isEmpty) return;

      final participantsData = chatData['participantsData']
              as Map<String, dynamic>? ??
          <String, dynamic>{};
      final otherUserData =
          participantsData[otherUserId] as Map<String, dynamic>? ??
              {};
      final userName =
          otherUserData['nombre']?.toString() ?? 'Usuario';
      final userImage = otherUserData['photoUrl']?.toString();
      final orderId = chatData['metadata']?['orderId']?.toString() ?? '';

      navigator.pushNamed(
        '/chat/conversation',
        arguments: {
          'chatId': chatId,
          'otherUserId': otherUserId,
          'userName': userName,
          'userImage': userImage,
          'orderId': orderId,
        },
      );
    } catch (e) {
      debugPrint('❌ Error navegando desde notificación: $e');
    }
  }

  static Future<void> registerDeviceToken(String uid) async {
    try {
      final token = await _messaging.getToken();
      if (token == null) return;

      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid)
          .set({
        'fcmTokens': FieldValue.arrayUnion([token]),
      }, SetOptions(merge: true));

      _messaging.onTokenRefresh.listen((newToken) async {
        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(uid)
            .set({
          'fcmTokens': FieldValue.arrayUnion([newToken]),
        }, SetOptions(merge: true));
      });
    } catch (e) {
      debugPrint('❌ Error registrando token FCM: $e');
    }
  }

  static Future<void> unregisterDeviceToken(String uid) async {
    try {
      final token = await _messaging.getToken();
      if (token == null) return;

      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid)
          .update({
        'fcmTokens': FieldValue.arrayRemove([token]),
      });
    } catch (e) {
      debugPrint('❌ Error eliminando token FCM: $e');
    }
  }

  static Future<void> handleBackgroundMessage(
      RemoteMessage message) async {
    // Los mensajes con payload de notificación se muestran automáticamente
    debugPrint('📩 Mensaje en background: ${message.messageId}');
  }

  static Future<void> checkInitialMessage() async {
    final message = await FirebaseMessaging.instance.getInitialMessage();
    if (message != null) {
      _navigateFromNotificationData(message.data);
    }
  }
}

