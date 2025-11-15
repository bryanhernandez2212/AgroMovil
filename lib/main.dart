import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:agromarket/views/auth/login_view.dart';
import 'package:agromarket/estructure/product_estructure.dart';
import 'package:agromarket/controllers/auth_controller.dart';
import 'package:agromarket/controllers/cart_controller.dart';
import 'package:agromarket/firebase_options.dart';
import 'package:agromarket/services/ad_service.dart';
import 'package:agromarket/config/stripe_config.dart';
import 'package:agromarket/services/notification_service.dart';
import 'package:agromarket/views/profile/chat_conversation_view.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(
    RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await NotificationService.handleBackgroundMessage(message);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar Firebase con opciones por defecto
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(
      _firebaseMessagingBackgroundHandler);
  
  // Inicializar Stripe con la clave pública
  Stripe.publishableKey = StripeConfig.publishableKey;
  
  // Inicializar AdMob
  await AdService.initialize();

  await NotificationService.initialize();
  
  runApp(const AgroMarketApp());
  await NotificationService.checkInitialMessage();
}

class AgroMarketApp extends StatelessWidget {
  const AgroMarketApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthController()),
        ChangeNotifierProvider(create: (_) => CartController()),
      ],
      child: MaterialApp(
        navigatorKey: NotificationService.navigatorKey,
        debugShowCheckedModeBanner: false,
        title: 'AgroMarket',
        theme: ThemeData(
          primarySwatch: Colors.green,
          scaffoldBackgroundColor: Colors.white,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            elevation: 0,
            iconTheme: IconThemeData(color: Color(0xFF2F4157)),
          ),
          // Eliminar el efecto glow/overscroll rosado
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF226602),
            surface: Colors.white,
            background: Colors.white,
            onSurface: Color(0xFF2F4157),
            onBackground: Color(0xFF2F4157),
          ),
          // Desactivar el efecto splash rosado del Material
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
        ),
        home: const LoginPage(), 
        routes: {
          '/home': (context) => const ProductEstructureView(), 
        },
        onGenerateRoute: (settings) {
          if (settings.name == '/chat/conversation') {
            final args =
                settings.arguments as Map<String, dynamic>?;
            if (args == null) return null;
            return MaterialPageRoute(
              builder: (_) => ChatConversationView(
                chatId: args['chatId']?.toString() ?? '',
                otherUserId: args['otherUserId']?.toString() ?? '',
                userName: args['userName']?.toString() ?? 'Usuario',
                userImage: args['userImage']?.toString(),
                orderId: args['orderId']?.toString() ?? '',
              ),
            );
          }
          return null;
        },
      ),
    );
  }
}
