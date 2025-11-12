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
  Orientation? _lastOrientation;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final currentOrientation = MediaQuery.of(context).orientation;
    if (_lastOrientation != currentOrientation) {
      _lastOrientation = currentOrientation;
      _reloadAd();
    }
  }

  void _reloadAd() {
    if (!mounted) return;

    _bannerAd?.dispose();
    _bannerAd = null;

    setState(() {
      _isBannerAdReady = false;
    });

    _loadAd();
  }

  void _loadAd() async {
    if (!mounted) return;

    try {
      final screenWidth = MediaQuery.sizeOf(context).width.truncate();
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
            debugPrint(' Ad fue cargado exitosamente');
            if (mounted) {
              setState(() {
                _bannerAd = ad as BannerAd;
                _isBannerAdReady = true;
              });
            }
          },
          onAdFailedToLoad: (ad, err) {
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
            debugPrint('Ad fue abierto');
          },
          onAdClosed: (Ad ad) {
            debugPrint('Ad fue cerrado');
          },
          onAdImpression: (Ad ad) {
            debugPrint('Ad registró una impresión');
          },
          onAdClicked: (Ad ad) {
            debugPrint('Ad fue clickeado');
          },
          onAdWillDismissScreen: (Ad ad) {
            debugPrint('Ad será descartado');
          },
        ),
      );

      await _bannerAd!.load();
    } catch (e) {
      debugPrint('Error al cargar banner: $e');
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
      return const SizedBox.shrink();
    }
    
    return SafeArea(
      bottom: false,
      child: SizedBox(
        width: double.infinity, 
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      ),
    );
  }
}

