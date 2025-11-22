import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:agromarket/views/auth/login_view.dart';
import 'package:agromarket/estructure/product_estructure.dart';
import 'package:agromarket/controllers/auth_controller.dart';
import 'package:agromarket/controllers/cart_controller.dart';
import 'package:agromarket/controllers/theme_controller.dart';
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
  
  // Manejar errores de inicialización para evitar que la app se cierre
  try {
    // Inicializar Firebase con opciones por defecto
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler);
    
    // Inicializar Stripe con la clave pública
    Stripe.publishableKey = StripeConfig.publishableKey;
    
    // Inicializar AdMob (puede fallar en algunos dispositivos, pero no debe bloquear la app)
    try {
      await AdService.initialize();
    } catch (e) {
      debugPrint('⚠️ Error inicializando AdMob: $e');
    }

    // Inicializar notificaciones
    try {
      await NotificationService.initialize();
    } catch (e) {
      debugPrint('⚠️ Error inicializando notificaciones: $e');
    }
    
    // Ejecutar la app
    runApp(const AgroMarketApp());
    
    // Verificar mensajes iniciales después de un pequeño delay
    // para asegurar que la app esté completamente inicializada
    Future.delayed(const Duration(milliseconds: 500), () {
      NotificationService.checkInitialMessage();
    });
  } catch (e, stackTrace) {
    debugPrint('❌ Error crítico al inicializar la app: $e');
    debugPrint('Stack trace: $stackTrace');
    
    // Ejecutar la app de todos modos para que el usuario vea algo
    // en lugar de solo un crash
    runApp(const AgroMarketApp());
  }
}

class AgroMarketApp extends StatelessWidget {
  const AgroMarketApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeController()),
        ChangeNotifierProvider(create: (_) => AuthController()),
        ChangeNotifierProvider(create: (_) => CartController()),
      ],
      child: Consumer<ThemeController>(
        builder: (context, themeController, _) {
          return MaterialApp(
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
            darkTheme: ThemeData(
              primarySwatch: Colors.green,
              brightness: Brightness.dark,
              scaffoldBackgroundColor: const Color(0xFF121212),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFF1E1E1E),
                elevation: 0,
                iconTheme: IconThemeData(color: Colors.white),
                titleTextStyle: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              colorScheme: const ColorScheme.dark(
                primary: Color(0xFF4CAF50),
                secondary: Color(0xFF66BB6A),
                surface: Color(0xFF1E1E1E),
                background: Color(0xFF121212),
                onSurface: Colors.white,
                onBackground: Colors.white,
                onPrimary: Colors.white,
                onSecondary: Colors.white,
              ),
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              splashFactory: NoSplash.splashFactory,
              cardColor: const Color(0xFF1E1E1E),
              dialogBackgroundColor: const Color(0xFF1E1E1E),
              bottomNavigationBarTheme: const BottomNavigationBarThemeData(
                backgroundColor: Color(0xFF1E1E1E),
                selectedItemColor: Color(0xFF4CAF50),
                unselectedItemColor: Colors.grey,
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: const Color(0xFF1E1E1E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[700]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[700]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
                ),
                hintStyle: TextStyle(color: Colors.grey[400]),
                labelStyle: const TextStyle(color: Colors.white),
              ),
              textTheme: const TextTheme(
                displayLarge: TextStyle(color: Colors.white),
                displayMedium: TextStyle(color: Colors.white),
                displaySmall: TextStyle(color: Colors.white),
                headlineLarge: TextStyle(color: Colors.white),
                headlineMedium: TextStyle(color: Colors.white),
                headlineSmall: TextStyle(color: Colors.white),
                titleLarge: TextStyle(color: Colors.white),
                titleMedium: TextStyle(color: Colors.white),
                titleSmall: TextStyle(color: Colors.white),
                bodyLarge: TextStyle(color: Colors.white),
                bodyMedium: TextStyle(color: Colors.white),
                bodySmall: TextStyle(color: Colors.grey),
                labelLarge: TextStyle(color: Colors.white),
                labelMedium: TextStyle(color: Colors.white),
                labelSmall: TextStyle(color: Colors.grey),
              ),
              iconTheme: const IconThemeData(color: Colors.white),
              dividerColor: Colors.grey[700],
              dividerTheme: DividerThemeData(color: Colors.grey[700]),
              listTileTheme: const ListTileThemeData(
                textColor: Colors.white,
                iconColor: Colors.white,
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                ),
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF4CAF50),
                ),
              ),
              outlinedButtonTheme: OutlinedButtonThemeData(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.grey[700]!),
                ),
              ),
              floatingActionButtonTheme: const FloatingActionButtonThemeData(
                backgroundColor: Color(0xFF4CAF50),
                foregroundColor: Colors.white,
              ),
              chipTheme: ChipThemeData(
                backgroundColor: const Color(0xFF1E1E1E),
                labelStyle: const TextStyle(color: Colors.white),
                secondaryLabelStyle: const TextStyle(color: Colors.white),
                padding: const EdgeInsets.all(8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey[700]!),
                ),
              ),
              switchTheme: SwitchThemeData(
                thumbColor: MaterialStateProperty.resolveWith((states) {
                  if (states.contains(MaterialState.selected)) {
                    return const Color(0xFF4CAF50);
                  }
                  return Colors.grey;
                }),
                trackColor: MaterialStateProperty.resolveWith((states) {
                  if (states.contains(MaterialState.selected)) {
                    return const Color(0xFF4CAF50).withOpacity(0.5);
                  }
                  return Colors.grey[700];
                }),
              ),
            ),
            themeMode: themeController.isDarkMode ? ThemeMode.dark : ThemeMode.light,
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
          );
        },
      ),
    );
  }
}
