import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  // ID de unidad de anuncios de prueba para banners
  // IMPORTANTE: Reemplaza con tu propio ID antes de publicar la app
  static const String bannerAdUnitId = 'ca-app-pub-3940256099942544/9214589741';

  // Inicializar el SDK de AdMob
  static Future<void> initialize() async {
    await MobileAds.instance.initialize();
    if (kDebugMode) {
      debugPrint('AdMob inicializado correctamente');
    }
  }
}

