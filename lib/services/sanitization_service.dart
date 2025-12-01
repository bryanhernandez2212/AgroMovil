/// Servicio para sanitizar y validar entradas de usuario
/// Previene inyecciones XSS y código malicioso
class SanitizationService {
  // Lista de patrones peligrosos que deben ser eliminados
  static final List<RegExp> _dangerousPatterns = [
    // Etiquetas HTML peligrosas (incluyendo variaciones con espacios y sin cierre correcto)
    RegExp(r'<script[^>]*>.*?</script>', caseSensitive: false, dotAll: true),
    RegExp(r'<script[^>]*>.*?<script', caseSensitive: false, dotAll: true), // Para casos como <script>('hola');<script/>
    RegExp(r'<script[^>]*>', caseSensitive: false), // Etiqueta de apertura sola
    RegExp(r'</script>', caseSensitive: false), // Etiqueta de cierre sola
    RegExp(r'<script/>', caseSensitive: false), // Etiqueta auto-cerrada
    RegExp(r'<iframe[^>]*>.*?</iframe>', caseSensitive: false, dotAll: true),
    RegExp(r'<object[^>]*>.*?</object>', caseSensitive: false, dotAll: true),
    RegExp(r'<embed[^>]*>', caseSensitive: false),
    RegExp(r'<link[^>]*>', caseSensitive: false),
    RegExp(r'<meta[^>]*>', caseSensitive: false),
    RegExp(r'<style[^>]*>.*?</style>', caseSensitive: false, dotAll: true),
    RegExp(r'<form[^>]*>.*?</form>', caseSensitive: false, dotAll: true),
    RegExp(r'<input[^>]*>', caseSensitive: false),
    RegExp(r'<button[^>]*>.*?</button>', caseSensitive: false, dotAll: true),
    RegExp(r'<select[^>]*>.*?</select>', caseSensitive: false, dotAll: true),
    RegExp(r'<textarea[^>]*>.*?</textarea>', caseSensitive: false, dotAll: true),
    RegExp(r'<img[^>]*>', caseSensitive: false),
    RegExp(r'<svg[^>]*>.*?</svg>', caseSensitive: false, dotAll: true),
    RegExp(r'<video[^>]*>.*?</video>', caseSensitive: false, dotAll: true),
    RegExp(r'<audio[^>]*>.*?</audio>', caseSensitive: false, dotAll: true),
    RegExp(r'<source[^>]*>', caseSensitive: false),
    RegExp(r'<track[^>]*>', caseSensitive: false),
    RegExp(r'<canvas[^>]*>.*?</canvas>', caseSensitive: false, dotAll: true),
    RegExp(r'<applet[^>]*>.*?</applet>', caseSensitive: false, dotAll: true),
    RegExp(r'<marquee[^>]*>.*?</marquee>', caseSensitive: false, dotAll: true),
    // Eventos JavaScript
    RegExp(r'on\w+\s*=', caseSensitive: false),
    // JavaScript: URLs
    RegExp(r'javascript:', caseSensitive: false),
    RegExp(r'data:text/html', caseSensitive: false),
    RegExp(r'vbscript:', caseSensitive: false),
    // Expresiones peligrosas
    RegExp(r'eval\s*\(', caseSensitive: false),
    RegExp(r'expression\s*\(', caseSensitive: false),
    RegExp(r'<!\[CDATA\[', caseSensitive: false), // Escapar los corchetes
    // SQL injection básico (aunque Firestore no es SQL, es buena práctica)
    RegExp(r'(\b(SELECT|INSERT|UPDATE|DELETE|DROP|CREATE|ALTER|EXEC|EXECUTE)\b)', caseSensitive: false),
  ];

  // Caracteres que deben ser escapados
  static final Map<String, String> _escapeChars = {
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#x27;',
    '/': '&#x2F;',
    '&': '&amp;',
  };

  /// Sanitiza un texto eliminando código malicioso
  /// [input] - Texto a sanitizar
  /// [allowHtml] - Si es true, permite HTML básico seguro (por defecto false)
  /// [maxLength] - Longitud máxima permitida (opcional)
  static String sanitize(String input, {bool allowHtml = false, int? maxLength}) {
    if (input.isEmpty) return input;

    // Limpiar espacios en blanco al inicio y final
    String cleaned = input.trim();

    // Aplicar longitud máxima si se especifica
    if (maxLength != null && cleaned.length > maxLength) {
      cleaned = cleaned.substring(0, maxLength);
    }

    // Eliminar patrones peligrosos
    for (var pattern in _dangerousPatterns) {
      cleaned = cleaned.replaceAll(pattern, '');
    }

    // Si no se permite HTML, escapar todos los caracteres HTML
    if (!allowHtml) {
      // Primero escapar caracteres especiales
      _escapeChars.forEach((char, escaped) {
        cleaned = cleaned.replaceAll(char, escaped);
      });
    } else {
      // Si se permite HTML, solo permitir etiquetas seguras
      cleaned = _sanitizeHtml(cleaned);
    }

    // Eliminar caracteres de control (excepto saltos de línea y tabs)
    cleaned = cleaned.replaceAll(RegExp(r'[\x00-\x08\x0B-\x0C\x0E-\x1F\x7F]'), '');

    // Normalizar espacios múltiples a uno solo
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');

    return cleaned.trim();
  }

  /// Sanitiza HTML permitiendo solo etiquetas seguras
  static String _sanitizeHtml(String input) {
    // Por ahora, si se permite HTML, solo permitimos texto plano
    // Esto es más seguro. Si necesitas HTML rico, considera usar un paquete especializado
    // como html_unescape o sanitize_html de pub.dev
    return sanitize(input, allowHtml: false);
  }

  /// Valida si un texto contiene código potencialmente malicioso
  /// Retorna true si es seguro, false si contiene código peligroso
  static bool isSafe(String input) {
    if (input.isEmpty) return true;

    // Verificar si contiene patrones peligrosos
    for (var pattern in _dangerousPatterns) {
      if (pattern.hasMatch(input)) {
        return false;
      }
    }

    return true;
  }

  /// Sanitiza un nombre (más restrictivo)
  static String sanitizeName(String input, {int maxLength = 100}) {
    String cleaned = sanitize(input, maxLength: maxLength);
    
    // Eliminar caracteres especiales que no deberían estar en nombres
    cleaned = cleaned.replaceAll(RegExp(r'[<>{}[\]\\|`~!@#\$%\^&\*\(\)_\+=\?;:,\/]'), '');
    
    return cleaned.trim();
  }

  /// Sanitiza una descripción (permite más caracteres pero sin código)
  static String sanitizeDescription(String input, {int maxLength = 2000}) {
    return sanitize(input, maxLength: maxLength);
  }

  /// Sanitiza un comentario
  static String sanitizeComment(String input, {int maxLength = 1000}) {
    return sanitize(input, maxLength: maxLength);
  }

  /// Sanitiza una dirección
  static String sanitizeAddress(String input, {int maxLength = 500}) {
    String cleaned = sanitize(input, maxLength: maxLength);
    
    // Permitir caracteres comunes en direcciones pero eliminar código
    // Los caracteres especiales como #, -, / son comunes en direcciones
    return cleaned.trim();
  }

  /// Sanitiza un email (solo valida formato, no sanitiza el contenido)
  static bool isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email.trim());
  }

  /// Sanitiza un número (solo permite dígitos y punto decimal)
  static String sanitizeNumber(String input) {
    // Eliminar todo excepto dígitos y punto decimal
    return input.replaceAll(RegExp(r'[^\d.]'), '');
  }

  /// Sanitiza un campo de búsqueda
  static String sanitizeSearch(String input, {int maxLength = 100}) {
    String cleaned = sanitize(input, maxLength: maxLength);
    
    // Eliminar caracteres especiales de búsqueda peligrosos
    cleaned = cleaned.replaceAll(RegExp(r'[<>{}[\]\\|`~!@#\$%\^&\*\(\)_\+=\?;:,\/]'), '');
    
    return cleaned.trim();
  }
}

