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
    // Retrasar la carga del banner para evitar errores con MediaQuery
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _loadBannerAd();
      }
    });
  }

  Future<void> _loadBannerAd() async {
    if (!mounted) return;

    try {
      // Obtener ancho del dispositivo
      final width = MediaQuery.of(context).size.width;
      
      // Obtener tamaño adaptativo del banner
      final size = await AdService.getAnchoredAdaptiveBannerAdSize(width);

      if (size == null) {
        debugPrint('❌ No se pudo obtener el tamaño del banner');
        return;
      }

      // Crear y cargar el banner
      _bannerAd = BannerAd(
        adUnitId: AdService.bannerAdUnitId,
        request: const AdRequest(),
        size: size,
        listener: BannerAdListener(
          onAdLoaded: (_) {
            debugPrint('✅ Banner ad cargado exitosamente');
            if (mounted) {
              setState(() {
                _isBannerAdReady = true;
              });
            }
          },
          onAdFailedToLoad: (ad, error) {
            debugPrint('❌ Banner ad falló al cargar: $error');
            ad.dispose();
            if (mounted) {
              setState(() {
                _isBannerAdReady = false;
              });
            }
          },
          onAdOpened: (ad) {
            debugPrint('✅ Banner ad abierto');
          },
          onAdClosed: (ad) {
            debugPrint('✅ Banner ad cerrado');
          },
          onAdImpression: (ad) {
            debugPrint('✅ Banner ad impresión registrada');
          },
          onAdClicked: (ad) {
            debugPrint('✅ Banner ad clickeado');
          },
        ),
      );

      await _bannerAd!.load();
    } catch (e) {
      debugPrint('❌ Error al cargar banner: $e');
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isBannerAdReady || _bannerAd == null) {
      // No mostrar nada si el anuncio no está listo
      return const SizedBox.shrink();
    }

    // Obtener el ancho completo de la pantalla
    final screenWidth = MediaQuery.of(context).size.width;

    return Align(
      alignment: widget.alignment,
      child: SafeArea(
        child: Container(
          width: screenWidth, // Ancho completo de la pantalla
          height: _bannerAd!.size.height.toDouble(),
          color: Colors.transparent,
          child: Center(
            child: SizedBox(
              width: _bannerAd!.size.width.toDouble(),
              height: _bannerAd!.size.height.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            ),
          ),
        ),
      ),
    );
  }
}

