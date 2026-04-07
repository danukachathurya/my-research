import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../common/api_config.dart';
import '../models/damage_detection_result.dart';
import '../models/garage_recommendation.dart';

/// Thrown when the server rejects an image because it does not show a vehicle.
class InvalidImageException implements Exception {
  final String message;
  const InvalidImageException(this.message);

  @override
  String toString() => message;
}

class DamageDetectionService {
  String get roadResqBaseUrl => ApiConfig.roadResqBaseUrl;
  String get claimsBaseUrl => ApiConfig.baseUrl;

  Future<http.Response> _postImage(
    File imageFile,
    String baseUrl,
    String path, {
    String? vehicleBrand,
    String? vehicleModel,
    String? vehicleYear,
    bool useAi = true,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final request = http.MultipartRequest('POST', uri);

    final imageStream = http.ByteStream(imageFile.openRead());
    final imageLength = await imageFile.length();

    String contentType = 'image/jpeg';
    if (imageFile.path.toLowerCase().endsWith('.png')) {
      contentType = 'image/png';
    } else if (imageFile.path.toLowerCase().endsWith('.jpg') ||
        imageFile.path.toLowerCase().endsWith('.jpeg')) {
      contentType = 'image/jpeg';
    }

    request.files.add(
      http.MultipartFile(
        'image',
        imageStream,
        imageLength,
        filename: imageFile.path.split('/').last,
        contentType: MediaType.parse(contentType),
      ),
    );

    if (vehicleBrand != null &&
        vehicleModel != null &&
        vehicleYear != null &&
        vehicleBrand.trim().isNotEmpty &&
        vehicleModel.trim().isNotEmpty &&
        vehicleYear.trim().isNotEmpty) {
      request.fields['vehicle_brand'] = vehicleBrand.trim();
      request.fields['vehicle_model'] = vehicleModel.trim();
      request.fields['vehicle_year'] = vehicleYear.trim();
      request.fields['use_ai'] = useAi ? 'true' : 'false';
    }

    final streamedResponse = await request.send();
    return http.Response.fromStream(streamedResponse);
  }

  String _extractErrorDetail(String body, int statusCode) {
    try {
      final decoded = json.decode(body);
      if (decoded is Map && decoded['detail'] != null) {
        return decoded['detail'].toString();
      }
    } catch (_) {}
    return 'HTTP $statusCode: ${body.isEmpty ? 'Unknown server error' : body}';
  }

  /// Detect damage from an image file.
  /// Supports both RoadResQ (/detect-damage) and vehicle module (/assess) APIs.
  Future<DamageDetectionResult?> detectDamage(
    File imageFile, {
    required String vehicleBrand,
    required String vehicleModel,
    required String vehicleYear,
    bool useAi = true,
  }) async {
    try {
      final candidates = <Map<String, dynamic>>[
        {
          'baseUrl': claimsBaseUrl,
          'path': '/assess',
          'vehicleFields': true,
        },
        {
          'baseUrl': claimsBaseUrl,
          'path': '/assess/',
          'vehicleFields': true,
        },
        {
          'baseUrl': roadResqBaseUrl,
          'path': '/detect-damage',
          'vehicleFields': false,
        },
        {
          'baseUrl': roadResqBaseUrl,
          'path': '/detect-damage/',
          'vehicleFields': false,
        },
      ];

      String? lastError;
      for (final candidate in candidates) {
        final baseUrl = candidate['baseUrl'] as String;
        final path = candidate['path'] as String;
        final includeVehicleFields = candidate['vehicleFields'] as bool;

        final response = await _postImage(
          imageFile,
          baseUrl,
          path,
          vehicleBrand: includeVehicleFields ? vehicleBrand : null,
          vehicleModel: includeVehicleFields ? vehicleModel : null,
          vehicleYear: includeVehicleFields ? vehicleYear : null,
          useAi: useAi,
        );

        if (response.statusCode == 404) {
          lastError = 'Endpoint not found at $baseUrl$path';
          continue;
        }

        if (response.statusCode == 200) {
          final jsonData = json.decode(response.body) as Map<String, dynamic>;
          return DamageDetectionResult.fromJson(jsonData);
        }

        if (response.statusCode == 400) {
          final detail = _extractErrorDetail(response.body, response.statusCode);
          throw InvalidImageException(detail);
        }

        if (response.statusCode == 422) {
          lastError = _extractErrorDetail(response.body, response.statusCode);
          continue;
        }

        lastError = _extractErrorDetail(response.body, response.statusCode);
      }

      throw Exception(lastError ?? 'No compatible damage-analysis endpoint found.');
    } on InvalidImageException {
      rethrow;
    } catch (e, stackTrace) {
      print('Exception during damage detection: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Check if the API server is reachable and has at least one relevant endpoint.
  Future<bool> checkServerConnection() async {
    try {
      final endpoints = <String>[
        '$claimsBaseUrl/assess',
        '$roadResqBaseUrl/detect-damage',
        '$roadResqBaseUrl/',
      ];
      for (final endpoint in endpoints) {
        final uri = Uri.parse(endpoint);
        final response = await http.get(uri).timeout(const Duration(seconds: 5));
        if (response.statusCode < 500 && response.statusCode != 404) {
          return true;
        }
      }
      return false;
    } catch (e) {
      print('Server connection check failed: $e');
      return false;
    }
  }

  /// Get complete assessment with location (optional - for future use)
  Future<Map<String, dynamic>?> getCompleteAssessment(
    File imageFile, {
    double? latitude,
    double? longitude,
  }) async {
    try {
      final uri = Uri.parse('$roadResqBaseUrl/complete-assessment');

      final request = http.MultipartRequest('POST', uri);

      final imageStream = http.ByteStream(imageFile.openRead());
      final imageLength = await imageFile.length();

      String contentType = 'image/jpeg';
      if (imageFile.path.toLowerCase().endsWith('.png')) {
        contentType = 'image/png';
      } else if (imageFile.path.toLowerCase().endsWith('.jpg') ||
          imageFile.path.toLowerCase().endsWith('.jpeg')) {
        contentType = 'image/jpeg';
      }

      request.files.add(
        http.MultipartFile(
          'image',
          imageStream,
          imageLength,
          filename: imageFile.path.split('/').last,
          contentType: MediaType.parse(contentType),
        ),
      );

      if (latitude != null && longitude != null) {
        request.fields['latitude'] = latitude.toString();
        request.fields['longitude'] = longitude.toString();
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }

      print('Error: ${response.statusCode} - ${response.body}');
      return null;
    } catch (e) {
      print('Exception during complete assessment: $e');
      return null;
    }
  }

  /// Get garage recommendations based on location and damage type
  Future<List<GarageRecommendation>> getGarageRecommendations({
    required double latitude,
    required double longitude,
    required String damageType,
    int maxResults = 5,
  }) async {
    try {
      final candidatePaths = <String>[
        '/recommend-garages',
        '/recommend-garages/',
        '/recommend_garages',
        '/recommend_garages/',
      ];

      http.Response? response;
      String? usedPath;

      for (final path in candidatePaths) {
        final uri = Uri.parse('$roadResqBaseUrl$path');
        final currentResponse = await http.post(
          uri,
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {
            'latitude': latitude.toString(),
            'longitude': longitude.toString(),
            'damage_type': damageType,
            'max_results': maxResults.toString(),
          },
        );

        response = currentResponse;
        usedPath = path;

        if (currentResponse.statusCode == 404) {
          try {
            final errorBody =
                json.decode(currentResponse.body) as Map<String, dynamic>;
            final detail = (errorBody['detail'] ?? '').toString().toLowerCase();
            if (detail.contains('no garages found')) {
              break;
            }
          } catch (_) {}
        }

        if (currentResponse.statusCode != 404) {
          break;
        }
      }

      if (response == null) {
        return [];
      }

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as List<dynamic>;
        return jsonData
            .map((json) => GarageRecommendation.fromJson(json))
            .toList();
      }

      print(
        'Error fetching garages (${usedPath ?? 'unknown'}): '
        '${response.statusCode} - ${response.body}',
      );
      return [];
    } catch (e) {
      print('Exception fetching garage recommendations: $e');
      return [];
    }
  }
}

