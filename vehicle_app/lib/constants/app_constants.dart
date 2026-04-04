class AppConstants {
  // API Configuration
  static const String apiPrefix = '/api';

  // API Endpoints
  static const String conversationStartEndpoint = '$apiPrefix/conversation/start';
  static const String conversationMessageEndpoint = '$apiPrefix/conversation/message';
  static const String conversationEndEndpoint = '$apiPrefix/conversation/end';
  static const String vehiclesEndpoint = '$apiPrefix/vehicles';
  static const String warningLightsEndpoint = '$apiPrefix/warning-lights';
  static const String translateEndpoint = '$apiPrefix/translate';
  static const String feedbackEndpoint = '$apiPrefix/feedback';

  // Timeouts
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Supported Vehicles
  static const List<String> supportedVehicles = [
    'Toyota Aqua',
    'Toyota Prius',
    'Toyota Corolla',
    'Toyota Vitz',
    'Suzuki Alto',
  ];

  // Languages
  static const String languageEnglish = 'english';
  static const String languageSinhala = 'sinhala';

  // Storage Keys
  static const String sessionIdKey = 'session_id';
  static const String selectedVehicleKey = 'selected_vehicle';
  static const String conversationHistoryKey = 'conversation_history';
}
