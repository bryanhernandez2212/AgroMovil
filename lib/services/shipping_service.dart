/// Servicio para calcular costos de envío basado en distancia entre ciudades
class ShippingService {
  // Lista de todas las ciudades disponibles
  static const List<String> availableCities = [
    'Ocosingo',
    'Yajalón',
    'San Cristóbal de las Casas',
    'Chilón',
    'Palenque',
    'Altamirano',
    'Tuxtla Gutiérrez',
    'Comitán de Dominguez',
    'Teopisca',
    'Bachajón',
    'Tila',
  ];

  // Matriz de distancias entre ciudades (en kilómetros)
  // Usamos un mapa de mapas para facilitar el acceso
  static final Map<String, Map<String, int>> _distances = {
    'Ocosingo': {
      'Yajalón': 54,
      'San Cristóbal de las Casas': 95,
      'Chilón': 42,
      'Palenque': 119,
      'Altamirano': 30,
    },
    'Yajalón': {
      'Ocosingo': 54,
      'Chilón': 11,
      'Bachajón': 25,
      'Tila': 26,
    },
    'San Cristóbal de las Casas': {
      'Ocosingo': 95,
      'Tuxtla Gutiérrez': 59,
      'Comitán de Dominguez': 90,
      'Teopisca': 33,
    },
    'Chilón': {
      'Ocosingo': 42,
      'Yajalón': 12,
      'Bachajón': 13,
      'Tila': 37,
    },
    'Palenque': {
      'Ocosingo': 119,
    },
    'Altamirano': {
      'Ocosingo': 30,
    },
    'Tuxtla Gutiérrez': {
      'San Cristóbal de las Casas': 59,
      'Comitán de Dominguez': 146,
    },
    'Comitán de Dominguez': {
      'San Cristóbal de las Casas': 90,
      'Tuxtla Gutiérrez': 146,
    },
    'Teopisca': {
      'San Cristóbal de las Casas': 33,
    },
    'Bachajón': {
      'Yajalón': 25,
      'Chilón': 13,
    },
    'Tila': {
      'Yajalón': 26,
      'Chilón': 37,
    },
  };

  /// Normalizar nombre de ciudad para comparación
  static String _normalizeCity(String city) {
    return city.trim();
  }

  /// Obtener distancia directa entre dos ciudades
  static int? _getDirectDistance(String fromCity, String toCity) {
    final from = _normalizeCity(fromCity);
    final to = _normalizeCity(toCity);
    
    if (from == to) return 0;
    
    return _distances[from]?[to];
  }

  /// Calcular la distancia mínima entre dos ciudades usando Dijkstra
  static int calculateDistance(String fromCity, String toCity) {
    final from = _normalizeCity(fromCity);
    final to = _normalizeCity(toCity);
    
    if (from == to) return 0;
    
    // Verificar si existe conexión directa
    final directDistance = _getDirectDistance(from, to);
    if (directDistance != null) {
      return directDistance;
    }

    // Usar algoritmo de Dijkstra para encontrar el camino más corto
    final distances = <String, int>{};
    final visited = <String>{};
    final queue = <String>[from];
    
    // Inicializar distancias
    for (final city in availableCities) {
      distances[city] = city == from ? 0 : 999999;
    }
    
    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      
      if (visited.contains(current)) continue;
      visited.add(current);
      
      if (current == to) break;
      
      // Explorar vecinos
      final neighbors = _distances[current];
      if (neighbors != null) {
        for (final entry in neighbors.entries) {
          final neighbor = entry.key;
          final edgeWeight = entry.value;
          
          final newDistance = distances[current]! + edgeWeight;
          if (newDistance < distances[neighbor]!) {
            distances[neighbor] = newDistance;
            if (!visited.contains(neighbor)) {
              queue.add(neighbor);
            }
          }
        }
      }
    }
    
    final result = distances[to];
    if (result == null || result >= 999999) {
      // Si no hay ruta, retornar una distancia muy grande o lanzar error
      throw Exception('No se encontró ruta entre $fromCity y $toCity');
    }
    
    return result;
  }

  /// Calcular costo de envío
  /// Fórmula: 10 + (2 × kilos) + (3 × km)
  /// 
  /// [fromCity] Ciudad de origen (vendedor)
  /// [toCity] Ciudad de destino (comprador)
  /// [weightKg] Peso total en kilogramos
  static double calculateShippingCost({
    required String fromCity,
    required String toCity,
    required double weightKg,
  }) {
    try {
      final distanceKm = calculateDistance(fromCity, toCity);
      final baseCost = 10.0;
      final costPerKg = 2.0;
      final costPerKm = 3.0;
      
      final totalCost = baseCost + (costPerKg * weightKg) + (costPerKm * distanceKm);
      return totalCost;
    } catch (e) {
      print('Error calculando costo de envío: $e');
      // Retornar un costo por defecto alto si hay error
      return 100.0;
    }
  }

  /// Verificar si una ciudad está disponible
  static bool isCityAvailable(String city) {
    return availableCities.contains(_normalizeCity(city));
  }

  /// Obtener todas las ciudades disponibles
  static List<String> getAvailableCities() {
    return List.from(availableCities);
  }

  /// Extraer nombre de ciudad de una dirección completa
  /// Intenta encontrar el nombre de ciudad en la dirección
  static String? extractCityFromAddress(String address) {
    final normalizedAddress = address.toLowerCase();
    
    for (final city in availableCities) {
      if (normalizedAddress.contains(city.toLowerCase())) {
        return city;
      }
    }
    
    return null;
  }
}

