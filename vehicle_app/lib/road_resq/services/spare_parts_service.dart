import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../common/api_config.dart';
import '../models/spare_part_bid.dart';

class SparePartsService {
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

  SparePartsBidsResult _emptyResult(String damageType, String vehicleMake) {
    return SparePartsBidsResult(
      damageType: damageType,
      vehicleInfo: vehicleMake,
      partsNeeded: const [],
      totalMinCostLkr: 0,
      totalMaxCostLkr: 0,
    );
  }

  /// Get competitive vendor bids for spare parts needed to repair the given damage type.
  /// Pass [userLatitude] and [userLongitude] so the backend prioritises nearby vendors.
  Future<SparePartsBidsResult> getSparepartsBids(
    String damageType, {
    String vehicleMake = 'Toyota',
    String? vehicleModel,
    int? vehicleYear,
    double? userLatitude,
    double? userLongitude,
  }) async {
    try {
      final body = <String, dynamic>{
        'damage_type': damageType,
        'vehicle_make': vehicleMake,
        if (vehicleModel != null) 'vehicle_model': vehicleModel,
        if (vehicleYear != null) 'vehicle_year': vehicleYear,
        if (userLatitude != null) 'user_latitude': userLatitude,
        if (userLongitude != null) 'user_longitude': userLongitude,
      };

      final paths = <String>[
        '/get-spare-parts-bids',
        '/get-spare-parts-bids/',
        '/get_spare_parts_bids',
        '/get_spare_parts_bids/',
      ];

      String? lastError;
      for (final path in paths) {
        final uri = Uri.parse('$baseUrl$path');
        final response = await http
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: json.encode(body),
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 404) {
          lastError = 'Endpoint not found at $path';
          continue;
        }

        if (response.statusCode == 200) {
          final decoded = json.decode(response.body);
          if (decoded is Map<String, dynamic>) {
            return SparePartsBidsResult.fromJson(decoded);
          }
          return _emptyResult(damageType, vehicleMake);
        }

        if (response.statusCode >= 400 && response.statusCode < 500) {
          final detail = _errorDetail(response).toLowerCase();
          if (detail.contains('no parts') || detail.contains('not found')) {
            return _emptyResult(damageType, vehicleMake);
          }
          lastError = _errorDetail(response);
          continue;
        }

        if (response.statusCode >= 500) {
          throw Exception(
            'Spare parts service unavailable: ${_errorDetail(response)}',
          );
        }
      }

      if (lastError != null) {
        if (lastError.toLowerCase().contains('endpoint not found')) {
          return _emptyResult(damageType, vehicleMake);
        }
        throw Exception(lastError);
      }
      return _emptyResult(damageType, vehicleMake);
    } catch (e) {
      print('Exception during spare parts bids: $e');
      rethrow;
    }
  }
}

