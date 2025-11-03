import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  // ID de banner adaptativo para Android según la documentación oficial
  static String get bannerAdUnitId {
    // ID de prueba para banners adaptativos fijos en Android
    // Usa este ID durante desarrollo y pruebas
    return '';
    
    // TODO: Reemplaza con tu ID real de producción cuando publiques la app
    // return 'ca-app-pub-TU_ID_DE_ADMOB/TU_UNIDAD_DE_ANUNCIOS';
  }

  // Inicializar el SDK de AdMob
  static Future<void> initialize() async {
    await MobileAds.instance.initialize();
    if (kDebugMode) {
      print('✅ AdMob inicializado correctamente');
    }
  }

  // Obtener tamaño adaptativo del banner
  static Future<AdSize?> getAnchoredAdaptiveBannerAdSize(double width) async {
    return await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
      width.truncate(),
    );
  }
}

