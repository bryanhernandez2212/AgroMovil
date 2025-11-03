import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';

class MicrosoftAuthService {
  static const String _clientId = '59f0fcc3-2aac-481a-9f60-c877b70de41f'; // ID del cliente
  static const String _tenantId = '400d4047-e5e5-4ae6-96d7-e2eb8cfe4435'; // Tu Directory (tenant) ID
  static const String _redirectUri = 'msauth://com.example.agromarket/oauth2redirect';
  static const String _authority = 'https://login.microsoftonline.com/400d4047-e5e5-4ae6-96d7-e2eb8cfe4435/oauth2/v2.0';
  static const String _scope = 'openid profile email User.Read';
  
  static String? _codeVerifier;
  static String? _codeChallenge;

  static void _generatePKCE() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (i) => random.nextInt(256));
    _codeVerifier = base64Url.encode(bytes).replaceAll('=', '');
    
    // Generar code de verificacion
    final digest = sha256.convert(utf8.encode(_codeVerifier!));
    _codeChallenge = base64Url.encode(digest.bytes).replaceAll('=', '');
    
  }

  static String getAuthorizationUrl() {
    _generatePKCE();
    
    final params = {
      'response_type': 'code',
      'client_id': _clientId,
      'redirect_uri': _redirectUri,
      'scope': _scope,
      'code_challenge': _codeChallenge!,
      'code_challenge_method': 'S256',
    };
    
    final uri = Uri.parse('$_authority/authorize').replace(queryParameters: params);
    return uri.toString();
  }

  // Iniciar el proceso de login
  static Future<Map<String, dynamic>?> loginWithMicrosoft(BuildContext context) async {
    try {
      final authUrl = getAuthorizationUrl();
      print('URL de autorización: $authUrl');
      print('Redirect URI: $_redirectUri');
      
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MicrosoftLoginWebView(
            authUrl: authUrl,
            redirectUri: _redirectUri,
          ),
        ),
      );

      print('Resultado del WebView: $result');

      if (result != null && result['code'] != null) {
        final token = await _exchangeCodeForToken(result['code']);
        if (token != null) {
          print('Token obtenido: ${token.substring(0, 20)}...');

          final userInfo = await _getUserInfo(token);
          return userInfo;
        } else {
          print('No se pudo obtener el token');
        }
      } else if (result != null && result['error'] != null) {
      } else {
        print('Login cancelado por el usuario');
      }
      
      return null;
    } catch (e) {
      print('Error en login con Microsoft: $e');
      return null;
    }
  }

  // Intercambiar código de autorización por token de acceso
  static Future<String?> _exchangeCodeForToken(String code) async {
    try {
      print('Intercambiando código por token...');
      print('Usando Code Verifier: $_codeVerifier');

      final tokenEndpoint = Uri.parse('$_authority/token');
      
      final response = await http.post(
        tokenEndpoint,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'client_id': _clientId,
          'code': code,
          'redirect_uri': _redirectUri,
          'grant_type': 'authorization_code',
          'code_verifier': _codeVerifier!,
          'scope': _scope,
        },
      );

      if (response.statusCode == 200) {
        final tokenData = json.decode(response.body);
        final accessToken = tokenData['access_token'] as String?;
        
        if (accessToken != null) {
          print('Token obtenido exitosamente');
          return accessToken;
        } else {
          print('No se encontró access_token en la respuesta');
          return null;
        }
      } else {
        print('Error del servidor: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error intercambiando código por token: $e');
      return null;
    }
  }

  // Obtener información del usuario desde Microsoft Graph
  static Future<Map<String, dynamic>?> _getUserInfo(String accessToken) async {
    try {
      print('Obteniendo información del usuario...');
      
      final response = await http.get(
        Uri.parse('https://graph.microsoft.com/v1.0/me'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final userData = json.decode(response.body);
        return {
          'id': userData['id'],
          'name': userData['displayName'],
          'email': userData['mail'] ?? userData['userPrincipalName'],
          'accessToken': accessToken,
        };
      } else {
        print('Error obteniendo información del usuario: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error obteniendo información del usuario: $e');
      return null;
    }
  }
}

// Widget WebView para mostrar el login de Microsoft
class MicrosoftLoginWebView extends StatefulWidget {
  final String authUrl;
  final String redirectUri;

  const MicrosoftLoginWebView({
    super.key,
    required this.authUrl,
    required this.redirectUri,
  });

  @override
  State<MicrosoftLoginWebView> createState() => _MicrosoftLoginWebViewState();
}

class _MicrosoftLoginWebViewState extends State<MicrosoftLoginWebView> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onNavigationRequest: (NavigationRequest request) {
            // Detectar cuando se redirige al URI de callback
            if (request.url.startsWith(widget.redirectUri)) {
              _handleRedirect(request.url);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.authUrl));
  }

  void _handleRedirect(String url) {
    print('Redirección detectada: $url');
    final uri = Uri.parse(url);
    final code = uri.queryParameters['code'];
    final error = uri.queryParameters['error'];
    final errorDescription = uri.queryParameters['error_description'];

    print('Parámetros de la URL:');
    print('  - code: $code');
    print('  - error: $error');
    print('  - error_description: $errorDescription');

    if (code != null) {
      print('Código de autorización recibido');
      Navigator.pop(context, {'code': code});
    } else if (error != null) {
      print('Error en OAuth: $error - $errorDescription');
      Navigator.pop(context, {'error': error, 'description': errorDescription});
    } else {
      print('Login cancelado por el usuario');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Iniciar sesión con Microsoft'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF2E7D32),
              ),
            ),
        ],
      ),
    );
  }
}
