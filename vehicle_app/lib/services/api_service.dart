import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../common/api_config.dart';
import '../constants/app_constants.dart';
import '../models/conversation_response.dart';

class ApiService {
  final String baseUrl;

  ApiService({String? baseUrl})
      : baseUrl = baseUrl ?? ApiConfig.troubleshootingBaseUrl;

  Future<Map<String, dynamic>> _handleResponse(http.Response response) async {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json.decode(response.body);
    } else {
      throw Exception(
          'API Error: ${response.statusCode} - ${response.body}');
    }
  }

  Future<ConversationResponse> startConversation({
    required String vehicleModel,
    String language = AppConstants.languageEnglish,
  }) async {
    try {
      // The backend expects 'user_id', we'll use vehicle model or generate a UUID
      final response = await http
          .post(
            Uri.parse('$baseUrl${AppConstants.conversationStartEndpoint}'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'user_id': vehicleModel,  // Backend expects user_id, not vehicle_model
              'language': language,
            }),
          )
          .timeout(AppConstants.connectionTimeout);

      final data = await _handleResponse(response);
      return ConversationResponse.fromJson(data);
    } catch (e) {
      throw Exception('Failed to start conversation: $e');
    }
  }

  Future<ConversationResponse> sendMessage({
    required String sessionId,
    required String message,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl${AppConstants.conversationMessageEndpoint}'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'session_id': sessionId,
              'message': message,
            }),
          )
          .timeout(AppConstants.connectionTimeout);

      final data = await _handleResponse(response);

      // Debug logging
      print('Raw API Response: $data');
      print('Message field: ${data['message']}');

      return ConversationResponse.fromJson(data);
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }

  Future<ConversationResponse> sendImageForWarningLight({
    required String sessionId,
    required File imageFile,
  }) async {
    try {
      if (kIsWeb) {
        // Web platform: Convert image to base64 and send as JSON
        final bytes = await imageFile.readAsBytes();
        final base64Image = base64Encode(bytes);

        final response = await http
            .post(
              Uri.parse('$baseUrl${AppConstants.conversationMessageEndpoint}'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode({
                'session_id': sessionId,
                'image_base64': base64Image,
                'message': 'Image uploaded for analysis',
              }),
            )
            .timeout(AppConstants.connectionTimeout);

        final data = await _handleResponse(response);
        return ConversationResponse.fromJson(data);
      } else {
        // Mobile/Desktop platforms: Use multipart upload
        var request = http.MultipartRequest(
          'POST',
          Uri.parse('$baseUrl${AppConstants.conversationMessageEndpoint}'),
        );

        request.fields['session_id'] = sessionId;
        request.fields['message'] = 'Image uploaded for analysis';
        request.files.add(
          await http.MultipartFile.fromPath('image', imageFile.path),
        );

        final streamedResponse = await request.send().timeout(
              AppConstants.connectionTimeout,
            );

        final response = await http.Response.fromStream(streamedResponse);
        final data = await _handleResponse(response);
        return ConversationResponse.fromJson(data);
      }
    } catch (e) {
      throw Exception('Failed to send image: $e');
    }
  }

  Future<void> endConversation({required String sessionId}) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl${AppConstants.conversationEndEndpoint}'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'session_id': sessionId,
            }),
          )
          .timeout(AppConstants.connectionTimeout);

      await _handleResponse(response);
    } catch (e) {
      throw Exception('Failed to end conversation: $e');
    }
  }

  Future<List<String>> getVehicles() async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl${AppConstants.vehiclesEndpoint}'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(AppConstants.connectionTimeout);

      final data = await _handleResponse(response);
      return List<String>.from(data['vehicles'] ?? []);
    } catch (e) {
      // Return default vehicles if API fails
      return AppConstants.supportedVehicles;
    }
  }

  Future<Map<String, dynamic>> translateText({
    required String text,
    required String targetLanguage,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl${AppConstants.translateEndpoint}'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'text': text,
              'target_language': targetLanguage,
            }),
          )
          .timeout(AppConstants.connectionTimeout);

      return await _handleResponse(response);
    } catch (e) {
      throw Exception('Failed to translate text: $e');
    }
  }

  Future<void> submitFeedback({
    required String sessionId,
    required int rating,
    String? comment,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl${AppConstants.feedbackEndpoint}'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'session_id': sessionId,
              'rating': rating,
              'comment': comment,
            }),
          )
          .timeout(AppConstants.connectionTimeout);

      await _handleResponse(response);
    } catch (e) {
      throw Exception('Failed to submit feedback: $e');
    }
  }

  Future<bool> checkServerHealth() async {
    try {
      final rootResponse = await http
          .get(
            Uri.parse(baseUrl),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 5));

      if (rootResponse.statusCode != 200) {
        return false;
      }

      try {
        final rootData = json.decode(rootResponse.body);
        if (rootData is Map<String, dynamic> &&
            rootData['status']?.toString().toLowerCase() == 'online') {
          return true;
        }
      } catch (_) {
        // Continue with an API endpoint probe if root is not JSON.
      }

      final apiResponse = await http
          .get(
            Uri.parse('$baseUrl${AppConstants.vehiclesEndpoint}'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 5));

      return apiResponse.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
