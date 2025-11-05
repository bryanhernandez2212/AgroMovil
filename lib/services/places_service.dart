import 'dart:convert';
import 'package:http/http.dart' as http;

class PlacesService {
  static const String _apiKey = 'AIzaSyCCm9SIv6WBmkejLHJ4X7WaTm8xf6DBpCo'; // TODO: Reemplazar con tu API key
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api/place';

  /// Obtener sugerencias de lugares basadas en el texto de búsqueda
  static Future<List<PlacePrediction>> getPlacePredictions(String input) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/autocomplete/json?input=$input&key=$_apiKey&components=country:mx&language=es',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK' && data['predictions'] != null) {
          return (data['predictions'] as List)
              .map((prediction) => PlacePrediction.fromJson(prediction))
              .toList();
        }
      }
      
      return [];
    } catch (e) {
      print('Error obteniendo predicciones de lugares: $e');
      return [];
    }
  }

  /// Obtener detalles de un lugar por su place_id
  static Future<PlaceDetails?> getPlaceDetails(String placeId) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/details/json?place_id=$placeId&key=$_apiKey&language=es',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK' && data['result'] != null) {
          return PlaceDetails.fromJson(data['result']);
        }
      }
      
      return null;
    } catch (e) {
      print('Error obteniendo detalles del lugar: $e');
      return null;
    }
  }
}

class PlacePrediction {
  final String description;
  final String placeId;
  final List<String> types;

  PlacePrediction({
    required this.description,
    required this.placeId,
    required this.types,
  });

  factory PlacePrediction.fromJson(Map<String, dynamic> json) {
    return PlacePrediction(
      description: json['description'] ?? '',
      placeId: json['place_id'] ?? '',
      types: json['types'] != null ? List<String>.from(json['types']) : [],
    );
  }
}

class PlaceDetails {
  final String name;
  final String formattedAddress;
  final double? lat;
  final double? lng;
  final Map<String, dynamic>? geometry;

  PlaceDetails({
    required this.name,
    required this.formattedAddress,
    this.lat,
    this.lng,
    this.geometry,
  });

  factory PlaceDetails.fromJson(Map<String, dynamic> json) {
    final geometry = json['geometry'] as Map<String, dynamic>?;
    final location = geometry?['location'] as Map<String, dynamic>?;
    
    return PlaceDetails(
      name: json['name'] ?? '',
      formattedAddress: json['formatted_address'] ?? '',
      lat: location != null ? (location['lat'] as num?)?.toDouble() : null,
      lng: location != null ? (location['lng'] as num?)?.toDouble() : null,
      geometry: geometry,
    );
  }
}

