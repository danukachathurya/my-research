import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../common/api_config.dart';
import '../models/towing_option.dart';

class TowingService {
  String get baseUrl => ApiConfig.roadResqBaseUrl;

  String _errorDetail(http.Response response) {
    try {
      final body = json.decode(response.body);
      if (body is Map && body['detail'] != null) {
        return body['detail'].toString();
      }
    } catch (_) {}
    return 'HTTP ${response.statusCode}';
  }

  List<TowingOption> _parseTowingList(dynamic decoded) {
    if (decoded is List) {
      return decoded
          .map((item) => TowingOption.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    if (decoded is Map && decoded['options'] is List) {
      final list = decoded['options'] as List<dynamic>;
      return list
          .map((item) => TowingOption.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    if (decoded is Map && decoded['data'] is List) {
      final list = decoded['data'] as List<dynamic>;
      return list
          .map((item) => TowingOption.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Find nearby towing services for a given location.
  Future<List<TowingOption>> findNearbyTowing(
    double latitude,
    double longitude, {
    int maxResults = 5,
  }) async {
    try {
      final paths = <String>[
        '/find-towing',
        '/find-towing/',
        '/find_towing',
        '/find_towing/',
      ];

      String? lastError;
      for (final path in paths) {
        final uri = Uri.parse('$baseUrl$path');
        final response = await http
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: json.encode({
                'latitude': latitude,
                'longitude': longitude,
                'max_results': maxResults,
              }),
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 404) {
          lastError = 'Endpoint not found at $path';
          continue;
        }

        if (response.statusCode == 200) {
          final decoded = json.decode(response.body);
          return _parseTowingList(decoded);
        }

        if (response.statusCode >= 400 && response.statusCode < 500) {
          final detail = _errorDetail(response).toLowerCase();
          if (detail.contains('no towing') || detail.contains('not found')) {
            return [];
          }
          lastError = _errorDetail(response);
          continue;
        }

        if (response.statusCode >= 500) {
          throw Exception('Towing service unavailable: ${_errorDetail(response)}');
        }
      }

      if (lastError != null) {
        if (lastError.toLowerCase().contains('endpoint not found')) {
          return [];
        }
        throw Exception(lastError);
      }
      return [];
    } catch (e) {
      print('Exception during towing search: $e');
      rethrow;
    }
  }

  /// Book a towing service and get a booking reference.
  Future<Map<String, dynamic>> bookTowing({
    required String towingId,
    required double latitude,
    required double longitude,
    String? destination,
  }) async {
    try {
      final paths = <String>[
        '/book-towing',
        '/book-towing/',
        '/book_towing',
        '/book_towing/',
      ];

      String? lastError;
      for (final path in paths) {
        final uri = Uri.parse('$baseUrl$path');
        final response = await http
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: json.encode({
                'towing_id': towingId,
                'latitude': latitude,
                'longitude': longitude,
                if (destination != null) 'destination': destination,
              }),
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 404) {
          lastError = 'Endpoint not found at $path';
          continue;
        }

        if (response.statusCode == 200) {
          return json.decode(response.body) as Map<String, dynamic>;
        }

        lastError = _errorDetail(response);
      }

      throw Exception('Booking failed: ${lastError ?? 'Unknown error'}');
    } catch (e) {
      print('Exception during towing booking: $e');
      rethrow;
    }
  }
}

