import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Processes images in a background isolate to avoid blocking the UI thread
class ImageProcessor {
  /// Encodes a list of image files to base64 in a background isolate
  static Future<List<String>> encodeImages(List<String> imagePaths) async {
    return compute(_encodeImagesIsolate, imagePaths);
  }

  /// Resizes and encodes images for optimal API transmission
  static Future<List<Map<String, dynamic>>> prepareImagesForApi(
    List<String> imagePaths,
  ) async {
    return compute(_prepareImagesIsolate, imagePaths);
  }
}

/// Background isolate function for encoding images to base64
List<String> _encodeImagesIsolate(List<String> paths) {
  return paths.map((path) {
    try {
      final bytes = File(path).readAsBytesSync();
      return base64Encode(bytes);
    } catch (e) {
      throw Exception('Failed to encode image at $path: $e');
    }
  }).toList();
}

/// Background isolate function for preparing images for API
List<Map<String, dynamic>> _prepareImagesIsolate(List<String> paths) {
  return paths.map((path) {
    try {
      final bytes = File(path).readAsBytesSync();
      final base64Image = base64Encode(bytes);

      // Determine mime type based on file extension
      String mimeType = 'image/jpeg';
      if (path.toLowerCase().endsWith('.png')) {
        mimeType = 'image/png';
      } else if (path.toLowerCase().endsWith('.jpg') ||
                 path.toLowerCase().endsWith('.jpeg')) {
        mimeType = 'image/jpeg';
      }

      return {
        'data': base64Image,
        'mimeType': mimeType,
      };
    } catch (e) {
      throw Exception('Failed to prepare image at $path: $e');
    }
  }).toList();
}

/// Data class for API request parameters
class AssessmentRequest {
  final List<String> imagePaths;
  final String vehicleBrand;
  final String vehicleModel;
  final String vehicleYear;
  final String apiUrl;
  final bool useAi;

  AssessmentRequest({
    required this.imagePaths,
    required this.vehicleBrand,
    required this.vehicleModel,
    required this.vehicleYear,
    required this.apiUrl,
    this.useAi = true,
  });

  Map<String, dynamic> toJson() => {
        'imagePaths': imagePaths,
        'vehicleBrand': vehicleBrand,
        'vehicleModel': vehicleModel,
        'vehicleYear': vehicleYear,
        'apiUrl': apiUrl,
        'useAi': useAi,
      };
}

/// Processes the damage assessment in a background isolate
Future<Map<String, dynamic>> processDamageAssessment(
  AssessmentRequest request,
) async {
  return compute(_processDamageAssessmentIsolate, request.toJson());
}

/// Background isolate function for damage assessment
Future<Map<String, dynamic>> _processDamageAssessmentIsolate(
  Map<String, dynamic> params,
) async {
  final imagePaths = List<String>.from(params['imagePaths']);
  final vehicleBrand = params['vehicleBrand'] as String;
  final vehicleModel = params['vehicleModel'] as String;
  final vehicleYear = params['vehicleYear'] as String;
  final apiUrl = params['apiUrl'] as String;
  final useAi = params['useAi'] as bool;

  Map<String, dynamic> combinedResult = {};

  for (int i = 0; i < imagePaths.length; i++) {
    var request = http.MultipartRequest('POST', Uri.parse(apiUrl));

    // Add image file
    request.files.add(
      await http.MultipartFile.fromPath('image', imagePaths[i]),
    );

    // Add form fields
    request.fields['vehicle_brand'] = vehicleBrand;
    request.fields['vehicle_model'] = vehicleModel;
    request.fields['vehicle_year'] = vehicleYear;
    request.fields['use_ai'] = useAi ? 'true' : 'false';

    // Send request
    var response = await request.send();
    var responseBody = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      var result = json.decode(responseBody);

      // For first image, use it as base
      if (i == 0) {
        combinedResult = result;
      } else {
        // Combine damages from subsequent images
        var damages = result['damage_detection']['detected_damages'] as List;
        var confidences = result['damage_detection']['confidences'] as Map;
        var newPrice = result['price_estimation']['estimated_price'];

        // Track if we added any new damages
        bool addedNewDamages = false;

        for (var damage in damages) {
          if (!combinedResult['damage_detection']['detected_damages']
              .contains(damage)) {
            combinedResult['damage_detection']['detected_damages'].add(damage);
            combinedResult['damage_detection']['confidences'][damage] =
                confidences[damage];
            addedNewDamages = true;
          }
        }

        // Update affected part if different (keep the first one or combine if needed)
        // Since affected_part is a string, we just keep the primary one from first image
        // mapped_from contains the list of damages, not parts

        // Sum up the price from backend instead of recalculating
        // Only add if we found new damages to avoid double counting
        if (addedNewDamages && newPrice != null) {
          var currentPrice = combinedResult['price_estimation']['estimated_price'] ?? 0;
          combinedResult['price_estimation']['estimated_price'] = currentPrice + newPrice;
        }
      }
    } else {
      String errorMessage = 'Assessment failed for image ${i + 1}: ${response.statusCode}';
      try {
        final errorJson = json.decode(responseBody);
        if (errorJson is Map<String, dynamic> && errorJson['detail'] != null) {
          errorMessage = '$errorMessage - ${errorJson['detail']}';
        } else if (responseBody.isNotEmpty) {
          errorMessage = '$errorMessage - $responseBody';
        }
      } catch (_) {
        if (responseBody.isNotEmpty) {
          errorMessage = '$errorMessage - $responseBody';
        }
      }
      throw Exception(errorMessage);
    }
  }

  return combinedResult;
}
