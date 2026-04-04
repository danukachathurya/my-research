import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
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
  // Update this to your computer's IP address when testing on physical device
  // For iOS Simulator: use 'localhost' or '127.0.0.1'
  // For Android Emulator: use '10.0.2.2'
  // For Physical Device: use your computer's local IP (e.g., '192.168.1.100')
  static const String baseUrl = 'http://192.168.8.162:8002';

  /// Detect damage from an image file
  Future<DamageDetectionResult?> detectDamage(File imageFile) async {
    try {
      final uri = Uri.parse('$baseUrl/detect-damage');

      // Create multipart request
      var request = http.MultipartRequest('POST', uri);

      // Add the image file with proper content type
      var imageStream = http.ByteStream(imageFile.openRead());
      var imageLength = await imageFile.length();

      // Determine content type from file extension
      String contentType = 'image/jpeg';
      if (imageFile.path.toLowerCase().endsWith('.png')) {
        contentType = 'image/png';
      } else if (imageFile.path.toLowerCase().endsWith('.jpg') ||
                 imageFile.path.toLowerCase().endsWith('.jpeg')) {
        contentType = 'image/jpeg';
      }

      var multipartFile = http.MultipartFile(
        'image',
        imageStream,
        imageLength,
        filename: imageFile.path.split('/').last,
        contentType: MediaType.parse(contentType),
      );

      request.files.add(multipartFile);

      // Send request
      print('Sending damage detection request...');
      var streamedResponse = await request.send();

      // Get response
      var response = await http.Response.fromStream(streamedResponse);

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        try {
          final jsonData = json.decode(response.body);
          print('Decoded JSON: $jsonData');
          final result = DamageDetectionResult.fromJson(jsonData);
          print('Successfully created DamageDetectionResult');
          return result;
        } catch (parseError) {
          print('JSON Parse Error: $parseError');
          print('Stack trace: ${StackTrace.current}');
          return null;
        }
      } else if (response.statusCode == 400) {
        // Non-vehicle image — parse and surface the server message
        try {
          final errorData = json.decode(response.body);
          final detail = errorData['detail'] as String? ??
              'Invalid image. Please upload a photo of a damaged vehicle.';
          throw InvalidImageException(detail);
        } on InvalidImageException {
          rethrow;
        } catch (_) {
          throw const InvalidImageException(
              'Invalid image. Please upload a photo of a damaged vehicle.');
        }
      } else {
        print('Error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } on InvalidImageException {
      rethrow; // Let the UI layer handle this specifically
    } catch (e, stackTrace) {
      print('Exception during damage detection: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Check if the API server is reachable
  Future<bool> checkServerConnection() async {
    try {
      final uri = Uri.parse('$baseUrl/');
      final response = await http.get(uri).timeout(
        const Duration(seconds: 5),
      );
      return response.statusCode == 200;
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

      var request = http.MultipartRequest('POST', uri);

      // Add the image file with proper content type
      var imageStream = http.ByteStream(imageFile.openRead());
      var imageLength = await imageFile.length();

      // Determine content type from file extension
      String contentType = 'image/jpeg';
      if (imageFile.path.toLowerCase().endsWith('.png')) {
        contentType = 'image/png';
      } else if (imageFile.path.toLowerCase().endsWith('.jpg') ||
                 imageFile.path.toLowerCase().endsWith('.jpeg')) {
        contentType = 'image/jpeg';
      }

      var multipartFile = http.MultipartFile(
        'image',
        imageStream,
        imageLength,
        filename: imageFile.path.split('/').last,
        contentType: MediaType.parse(contentType),
      );

      request.files.add(multipartFile);

      // Add location if provided
      if (latitude != null && longitude != null) {
        request.fields['latitude'] = latitude.toString();
        request.fields['longitude'] = longitude.toString();
      }

      // Send request
      print('Sending complete assessment request...');
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('Error: ${response.statusCode} - ${response.body}');
        return null;
      }
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

        print('Garage recommendations response ($path): ${currentResponse.statusCode}');
        response = currentResponse;
        usedPath = path;

        if (currentResponse.statusCode == 404) {
          try {
            final Map<String, dynamic> errorBody =
                json.decode(currentResponse.body) as Map<String, dynamic>;
            final detail = (errorBody['detail'] ?? '').toString().toLowerCase();
            if (detail.contains('no garages found')) {
              // Endpoint exists but no results for this location; don't try alternate route names.
              break;
            }
          } catch (_) {
            // Ignore parse errors and continue fallback attempts.
          }
        }

        // Use first non-404 response. This allows compatibility with different backend route styles.
        if (currentResponse.statusCode != 404) {
          break;
        }
      }

      if (response == null) {
        print('No response from garage recommendation endpoint');
        return [];
      }

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);

        // Debug: Print first garage raw JSON
        if (jsonData.isNotEmpty) {
          print('🔍 First garage raw JSON: ${jsonData[0]}');
        }

        return jsonData
            .map((json) => GarageRecommendation.fromJson(json))
            .toList();
      } else {
        print('Error fetching garages (${usedPath ?? 'unknown'}): ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('Exception fetching garage recommendations: $e');
      return [];
    }
  }
}
