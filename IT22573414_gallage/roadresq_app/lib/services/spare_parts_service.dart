import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/spare_part_bid.dart';

class SparePartsService {
  static const String baseUrl = 'http://192.168.8.162:8002';

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
      final uri = Uri.parse('$baseUrl/get-spare-parts-bids');
      final body = <String, dynamic>{
        'damage_type': damageType,
        'vehicle_make': vehicleMake,
        if (vehicleModel != null) 'vehicle_model': vehicleModel,
        if (vehicleYear != null) 'vehicle_year': vehicleYear,
        if (userLatitude != null) 'user_latitude': userLatitude,
        if (userLongitude != null) 'user_longitude': userLongitude,
      };

      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 15));

      print('Spare parts response status: ${response.statusCode}');
      print('Spare parts response body: ${response.body.substring(0, response.body.length.clamp(0, 300))}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        return SparePartsBidsResult.fromJson(jsonData);
      } else if (response.statusCode == 404) {
        throw Exception('No parts data found for damage type: $damageType');
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['detail'] ?? 'Failed to get spare parts bids');
      }
    } catch (e) {
      print('Exception during spare parts bids: $e');
      rethrow;
    }
  }
}
