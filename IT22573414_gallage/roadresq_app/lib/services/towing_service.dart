import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/towing_option.dart';

class TowingService {
  static const String baseUrl = 'http://192.168.8.162:8002';

  /// Find nearby towing services for a given location.
  Future<List<TowingOption>> findNearbyTowing(
    double latitude,
    double longitude, {
    int maxResults = 5,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/find-towing');
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

      print('Towing response status: ${response.statusCode}');
      print('Towing response body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        return jsonData
            .map((item) => TowingOption.fromJson(item as Map<String, dynamic>))
            .toList();
      } else if (response.statusCode == 404) {
        return []; // No towing services found nearby
      } else {
        throw Exception(
            'Failed to find towing services (${response.statusCode})');
      }
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
      final uri = Uri.parse('$baseUrl/book-towing');
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

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Booking failed (${response.statusCode})');
      }
    } catch (e) {
      print('Exception during towing booking: $e');
      rethrow;
    }
  }
}
