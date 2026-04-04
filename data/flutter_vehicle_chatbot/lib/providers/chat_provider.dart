import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/chat_message.dart';
import '../models/conversation_response.dart';
import '../services/api_service.dart';

class ChatProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final List<ChatMessage> _messages = [];
  final SpeechToText _speechToText = SpeechToText();
  String? _sessionId;
  String? _selectedVehicle;
  bool _isLoading = false;
  String? _error;
  bool _isServerOnline = false;
  bool _isListening = false;
  String _recognizedText = '';

  List<ChatMessage> get messages => _messages;
  String? get sessionId => _sessionId;
  String? get selectedVehicle => _selectedVehicle;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isServerOnline => _isServerOnline;
  bool get isListening => _isListening;
  String get recognizedText => _recognizedText;

  ChatProvider() {
    _checkServerStatus();
  }

  Future<void> _checkServerStatus() async {
    _isServerOnline = await _apiService.checkServerHealth();
    notifyListeners();
  }

  Future<void> startConversation(String vehicleModel) async {
    _isLoading = true;
    _error = null;
    _selectedVehicle = vehicleModel;
    notifyListeners();

    try {
      final response = await _apiService.startConversation(
        vehicleModel: vehicleModel,
      );

      _sessionId = response.sessionId;

      // Add welcome message from bot
      _addBotMessage(response.response);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> startConversationWithoutVehicle() async {
    _isLoading = true;
    _error = null;
    _selectedVehicle = null;
    notifyListeners();

    try {
      // Start with a generic vehicle model or empty
      // The chatbot will ask the user for their vehicle during conversation
      final response = await _apiService.startConversation(
        vehicleModel: 'General',
      );

      _sessionId = response.sessionId;

      // Add custom welcome message
      _addBotMessage(
        'Hello! I\'m your vehicle troubleshooting assistant. I can help you diagnose and solve problems with your vehicle. What vehicle do you have, and what issue are you experiencing?',
      );

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendMessage(String messageText) async {
    if (messageText.trim().isEmpty) return;
    if (_sessionId == null) {
      _error = 'No active session. Please start a conversation first.';
      notifyListeners();
      return;
    }

    // Add user message
    _addUserMessage(messageText);

    // Show loading indicator
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.sendMessage(
        sessionId: _sessionId!,
        message: messageText,
      );

      // Debug: print response to console
      print('API Response: ${response.response}');
      print('Session ID: ${response.sessionId}');

      // Add bot response - check if response is empty
      if (response.response.isEmpty) {
        _addBotMessage('Sorry, I received an empty response. Please try again.');
        _error = 'Empty response from server';
      } else {
        _addBotMessage(response.response);
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendImage(File imageFile) async {
    if (_sessionId == null) {
      _error = 'No active session. Please start a conversation first.';
      notifyListeners();
      return;
    }

    // Add user message with image
    final messageId = const Uuid().v4();
    final userMessage = ChatMessage(
      id: messageId,
      text: 'Sent an image for warning light detection',
      sender: MessageSender.user,
      timestamp: DateTime.now(),
      imageUrl: imageFile.path,
    );
    _messages.add(userMessage);

    // Show loading indicator
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.sendImageForWarningLight(
        sessionId: _sessionId!,
        imageFile: imageFile,
      );

      // Add bot response
      _addBotMessage(response.response);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendImageFromXFile(XFile imageFile) async {
    if (_sessionId == null) {
      _error = 'No active session. Please start a conversation first.';
      notifyListeners();
      return;
    }

    // Add user message with image
    final messageId = const Uuid().v4();
    final userMessage = ChatMessage(
      id: messageId,
      text: 'Sent an image for warning light detection',
      sender: MessageSender.user,
      timestamp: DateTime.now(),
      imageUrl: imageFile.path,
    );
    _messages.add(userMessage);

    // Show loading indicator
    _isLoading = true;
    notifyListeners();

    try {
      // Convert XFile to File (works on both web and mobile)
      final File file = File(imageFile.path);

      final response = await _apiService.sendImageForWarningLight(
        sessionId: _sessionId!,
        imageFile: file,
      );

      // Add bot response
      _addBotMessage(response.response);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> endConversation() async {
    if (_sessionId == null) return;

    try {
      await _apiService.endConversation(sessionId: _sessionId!);
      _clearConversation();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> submitFeedback(int rating, String? comment) async {
    if (_sessionId == null) return;

    try {
      await _apiService.submitFeedback(
        sessionId: _sessionId!,
        rating: rating,
        comment: comment,
      );
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void _addUserMessage(String text) {
    final messageId = const Uuid().v4();
    final message = ChatMessage(
      id: messageId,
      text: text,
      sender: MessageSender.user,
      timestamp: DateTime.now(),
    );
    _messages.add(message);
    notifyListeners();
  }

  void _addBotMessage(String text) {
    final messageId = const Uuid().v4();
    final message = ChatMessage(
      id: messageId,
      text: text,
      sender: MessageSender.bot,
      timestamp: DateTime.now(),
    );
    _messages.add(message);
    notifyListeners();
  }

  void _clearConversation() {
    _messages.clear();
    _sessionId = null;
    _selectedVehicle = null;
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void refreshServerStatus() {
    _checkServerStatus();
  }

  Future<void> startListening() async {
    if (_isListening) return;

    // Check microphone permission
    final permissionStatus = await Permission.microphone.request();
    if (!permissionStatus.isGranted) {
      _error = 'Microphone permission denied';
      notifyListeners();
      return;
    }

    // Initialize speech recognition
    bool available = await _speechToText.initialize(
      onError: (error) {
        // Don't show error_no_match as it's just waiting for speech
        if (error.errorMsg != 'error_no_match') {
          _error = 'Speech recognition error: ${error.errorMsg}';
        }
        print('Speech error: ${error.errorMsg}');
      },
      onStatus: (status) {
        print('Speech status: $status');
        if (status == 'done' || status == 'notListening') {
          if (_isListening) {
            // Auto-send when speech recognition stops
            stopListening();
          }
        }
      },
    );

    if (!available) {
      _error = 'Speech recognition not available';
      notifyListeners();
      return;
    }

    // Start listening
    _isListening = true;
    _recognizedText = '';
    notifyListeners();

    await _speechToText.listen(
      onResult: (result) {
        _recognizedText = result.recognizedWords;
        print('Recognized: $_recognizedText');
        notifyListeners();
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
    );
  }

  Future<void> stopListening() async {
    if (!_isListening) return;

    print('Stopping listening. Recognized text: "$_recognizedText"');

    await _speechToText.stop();
    _isListening = false;
    notifyListeners();

    // Send the recognized text if it's not empty
    if (_recognizedText.isNotEmpty) {
      print('Sending message: $_recognizedText');
      await sendMessage(_recognizedText);
      _recognizedText = '';
    } else {
      print('No text recognized, not sending message');
      _error = 'No speech recognized. Please try again.';
      notifyListeners();
    }
  }

  void cancelListening() {
    if (!_isListening) return;

    _speechToText.stop();
    _isListening = false;
    _recognizedText = '';
    notifyListeners();
  }
}
