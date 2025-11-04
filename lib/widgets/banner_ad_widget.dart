import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:agromarket/services/ad_service.dart';

class BannerAdWidget extends StatefulWidget {
  final Alignment alignment;
  
  const BannerAdWidget({
    super.key,
    this.alignment = Alignment.bottomCenter,
  });

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isBannerAdReady = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _loadAd();
      }
    });
  }

  void _loadAd() async {
    if (!mounted) return;

    try {
      final screenWidth = MediaQuery.sizeOf(context).width.truncate();
      
      debugPrint('📱 Ancho de pantalla para banner: $screenWidth');
      
      // Obtener el tamaño del anuncio adaptativo para la orientación actual
      // Este método calcula automáticamente el tamaño óptimo basado en el ancho proporcionado
      // IMPORTANTE: El tamaño que devuelve debe usarse directamente, pero el contenedor
      // debe tener el ancho completo para que el banner se adapte horizontalmente
      final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
        screenWidth,
      );

      if (size == null) {
        debugPrint(' No se pudo obtener el tamaño del banner adaptativo');
        return;
      }
      
      debugPrint(' Banner adaptativo: ${size.width}x${size.height} para pantalla: ${screenWidth}px');
      debugPrint(' El banner debería ocupar el ancho completo: ${size.width == screenWidth ? "✅ SÍ" : "❌ NO (${size.width}px vs ${screenWidth}px)"}');

      // Crear y cargar el anuncio
      _bannerAd = BannerAd(
        adUnitId: AdService.bannerAdUnitId,
        request: const AdRequest(),
        size: size,
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            // Llamado cuando un anuncio se recibe exitosamente
            debugPrint(' Ad fue cargado exitosamente');
            if (mounted) {
              setState(() {
                _bannerAd = ad as BannerAd;
                _isBannerAdReady = true;
              });
            }
          },
          onAdFailedToLoad: (ad, err) {
            // Llamado cuando falla una solicitud de anuncio
            debugPrint(' Ad falló al cargar con error: $err');
            ad.dispose();
            if (mounted) {
              setState(() {
                _isBannerAdReady = false;
                _bannerAd = null;
              });
            }
          },
          onAdOpened: (Ad ad) {
            // Llamado cuando un anuncio abre una superposición que cubre la pantalla
            debugPrint('Ad fue abierto');
          },
          onAdClosed: (Ad ad) {
            // Llamado cuando un anuncio elimina una superposición que cubre la pantalla
            debugPrint('Ad fue cerrado');
          },
          onAdImpression: (Ad ad) {
            // Llamado cuando se registra una impresión en el anuncio
            debugPrint('Ad registró una impresión');
          },
          onAdClicked: (Ad ad) {
            // Llamado cuando ocurre un evento de clic en el anuncio
            debugPrint('Ad fue clickeado');
          },
          onAdWillDismissScreen: (Ad ad) {
            // Solo iOS. Llamado antes de descartar una vista de pantalla completa
            debugPrint('Ad será descartado');
          },
        ),
      );

      // Cargar el anuncio
      await _bannerAd!.load();
    } catch (e) {
      debugPrint('Error al cargar banner: $e');
    }
  }

  @override
  void dispose() {
    // Descartar el anuncio cuando ya no sea necesario
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Solo mostrar el anuncio si está listo y cargado
    if (!_isBannerAdReady || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    // EXPLICACIÓN DEL PROBLEMA Y SOLUCIÓN:
    // El BannerAd se crea con un tamaño calculado por AdMob (ej: 360x50)
    // Este tamaño puede ser MENOR que el ancho completo de la pantalla
    // Para que el anuncio se adapte horizontalmente al 100% del ancho:
    // 1. Usamos double.infinity para que el contenedor ocupe TODO el ancho disponible
    // 2. El AdWidget dentro se ajustará al ancho del contenedor
    
    return SafeArea(
      bottom: false,
      child: SizedBox(
        width: double.infinity, // Ocupar TODO el ancho horizontal disponible
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      ),
    );
  }
}

