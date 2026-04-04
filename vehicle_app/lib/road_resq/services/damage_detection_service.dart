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
  String get baseUrl => ApiConfig.roadResqBaseUrl;

  Future<http.Response> _postImage(
    File imageFile,
    String path, {
    bool includeAssessFields = false,
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

    if (includeAssessFields) {
      request.fields['vehicle_brand'] = 'Toyota';
      request.fields['vehicle_model'] = 'Corolla';
      request.fields['vehicle_year'] = '2020';
      request.fields['use_ai'] = 'true';
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

  DamageDetectionResult _parseDamageResult(Map<String, dynamic> jsonData) {
    if (jsonData.containsKey('damage_type')) {
      return DamageDetectionResult.fromJson(jsonData);
    }

    final detection = (jsonData['damage_detection'] as Map?) ?? {};
    final rawDamages = (detection['detected_damages'] as List?) ?? const [];
    final detectedDamages = rawDamages.map((e) => e.toString()).toList();

    final rawConfidences = (detection['confidences'] as Map?) ?? {};
    final probabilities = <String, double>{};
    for (final entry in rawConfidences.entries) {
      probabilities[entry.key.toString()] =
          (entry.value as num?)?.toDouble() ?? 0.0;
    }

    final confidence = probabilities.values.isEmpty
        ? 0.0
        : probabilities.values.reduce((a, b) => a > b ? a : b);

    final analysis = ((jsonData['ai_validation'] as Map?)?['damage_validation']
                as Map?)?['analysis']
            ?.toString() ??
        'Damage assessment generated from backend response.';

    return DamageDetectionResult(
      damageType: detectedDamages.isNotEmpty
          ? detectedDamages.first
          : 'unknown_damage',
      severityScore: detectedDamages.length,
      confidence: confidence,
      probabilities: probabilities,
      detectedDamages: detectedDamages,
      damageDetails: DamageDetails(
        description: analysis,
        whatHappened: 'See detected damages list.',
        immediateActions: const [
          'Capture clear images and inspect vehicle safely.',
        ],
        repairOptions: const [
          'Visit recommended garage for detailed inspection.',
        ],
        urgency: detectedDamages.isEmpty ? 'low' : 'medium',
        estimatedTime: 'To be confirmed by garage',
        preventionTips: 'Drive carefully and maintain safe distance.',
      ),
    );
  }

  /// Detect damage from an image file.
  /// Supports both RoadResQ (/detect-damage) and vehicle module (/assess) APIs.
  Future<DamageDetectionResult?> detectDamage(File imageFile) async {
    try {
      final candidates = <Map<String, dynamic>>[
        {'path': '/detect-damage', 'assessFields': false},
        {'path': '/detect-damage/', 'assessFields': false},
        {'path': '/assess', 'assessFields': true},
        {'path': '/assess/', 'assessFields': true},
      ];

      String? lastError;
      for (final candidate in candidates) {
        final path = candidate['path'] as String;
        final includeAssessFields = candidate['assessFields'] as bool;

        final response = await _postImage(
          imageFile,
          path,
          includeAssessFields: includeAssessFields,
        );

        if (response.statusCode == 404) {
          lastError = 'Endpoint not found at $path';
          continue;
        }

        if (response.statusCode == 200) {
          final jsonData = json.decode(response.body) as Map<String, dynamic>;
          return _parseDamageResult(jsonData);
        }

        if (response.statusCode == 400) {
          final detail = _extractErrorDetail(response.body, response.statusCode);
          throw InvalidImageException(detail);
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
      final paths = ['/', '/detect-damage', '/assess'];
      for (final path in paths) {
        final uri = Uri.parse('$baseUrl$path');
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
      final uri = Uri.parse('$baseUrl/complete-assessment');

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
        final uri = Uri.parse('$baseUrl$path');
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

