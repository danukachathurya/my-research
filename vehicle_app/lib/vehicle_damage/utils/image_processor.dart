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
  final String? userUid;

  AssessmentRequest({
    required this.imagePaths,
    required this.vehicleBrand,
    required this.vehicleModel,
    required this.vehicleYear,
    required this.apiUrl,
    this.useAi = true,
    this.userUid,
  });

  Map<String, dynamic> toJson() => {
        'imagePaths': imagePaths,
        'vehicleBrand': vehicleBrand,
        'vehicleModel': vehicleModel,
        'vehicleYear': vehicleYear,
        'apiUrl': apiUrl,
        'useAi': useAi,
        'userUid': userUid,
      };
}

/// Processes the damage assessment in a background isolate
Future<Map<String, dynamic>> processDamageAssessment(
  AssessmentRequest request,
) async {
  return compute(_processDamageAssessmentIsolate, request.toJson());
}

double _toDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? 0.0;
}

Map<String, dynamic> _asStringKeyedMap(dynamic value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return <String, dynamic>{};
}

List<String> _asStringList(dynamic value) {
  if (value is List) {
    return value.map((item) => item.toString()).toList();
  }
  return <String>[];
}

Map<String, dynamic> _mergeAssessmentResults(
  Map<String, dynamic> currentResult,
  Map<String, dynamic> newResult,
) {
  final currentDamageDetection =
      _asStringKeyedMap(currentResult['damage_detection']);
  final newDamageDetection = _asStringKeyedMap(newResult['damage_detection']);

  final mergedDamages =
      _asStringList(currentDamageDetection['detected_damages']);
  final mergedConfidences =
      _asStringKeyedMap(currentDamageDetection['confidences']);

  for (final damage in _asStringList(newDamageDetection['detected_damages'])) {
    if (!mergedDamages.contains(damage)) {
      mergedDamages.add(damage);
    }

    final currentConfidence = _toDouble(mergedConfidences[damage]);
    final newConfidence =
        _toDouble(_asStringKeyedMap(newDamageDetection['confidences'])[damage]);
    if (newConfidence > currentConfidence) {
      mergedConfidences[damage] = newConfidence;
    }
  }

  currentDamageDetection['detected_damages'] = mergedDamages;
  currentDamageDetection['confidences'] = mergedConfidences;
  currentDamageDetection['num_damages'] = mergedDamages.length;
  currentResult['damage_detection'] = currentDamageDetection;

  final currentPartMapping = _asStringKeyedMap(currentResult['part_mapping']);
  final newPartMapping = _asStringKeyedMap(newResult['part_mapping']);
  final currentAffectedPart =
      (currentPartMapping['affected_part'] ?? '').toString();
  final newAffectedPart = (newPartMapping['affected_part'] ?? '').toString();

  final currentPriceEstimation =
      _asStringKeyedMap(currentResult['price_estimation']);
  final newPriceEstimation = _asStringKeyedMap(newResult['price_estimation']);
  final currentEstimatedPrice =
      _toDouble(currentPriceEstimation['estimated_price']);
  final newEstimatedPrice = _toDouble(newPriceEstimation['estimated_price']);

  if (newEstimatedPrice > currentEstimatedPrice) {
    currentResult['price_estimation'] = newPriceEstimation;
    if (newResult['ai_validation'] != null) {
      currentResult['ai_validation'] = newResult['ai_validation'];
    }
    if (newPartMapping.isNotEmpty) {
      currentResult['part_mapping'] = newPartMapping;
    }
  }

  final mergedPartMapping = _asStringKeyedMap(currentResult['part_mapping']);
  if (currentAffectedPart.isNotEmpty &&
      newAffectedPart.isNotEmpty &&
      currentAffectedPart != newAffectedPart) {
    mergedPartMapping['affected_part'] = 'multiple_areas';
  }
  mergedPartMapping['mapped_from'] = mergedDamages;
  currentResult['part_mapping'] = mergedPartMapping;

  return currentResult;
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
  final userUid = params['userUid']?.toString().trim();

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
    if (userUid != null && userUid.isNotEmpty) {
      request.fields['user_uid'] = userUid;
    }

    // Send request
    var response = await request.send();
    var responseBody = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      var result = json.decode(responseBody);

      // For first image, use it as base
      if (i == 0) {
        combinedResult = result;
      } else {
        combinedResult = _mergeAssessmentResults(combinedResult, result);
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

  if (imagePaths.length > 1 && combinedResult.isNotEmpty) {
    final priceEstimation = _asStringKeyedMap(combinedResult['price_estimation']);
    priceEstimation['aggregation_method'] = 'highest_single_view';
    priceEstimation['images_considered'] = imagePaths.length;
    combinedResult['price_estimation'] = priceEstimation;
  }

  return combinedResult;
}
