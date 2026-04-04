class HistoryModel {
  final String historyId;
  final String userId;
  final int timestamp;
  final double latitude;
  final double longitude;
  final int speed;
  final String prediction;
  final int fuel;
  final double temp;
  final int rpm;
  final bool belt;
  final bool angleWarning;

  HistoryModel({
    required this.historyId,
    required this.userId,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.speed,
    required this.prediction,
    required this.fuel,
    required this.temp,
    required this.rpm,
    required this.belt,
    required this.angleWarning,
  });

  factory HistoryModel.fromJson(Map<String, dynamic> json) {
    return HistoryModel(
      historyId: json['historyId'] ?? '',
      userId: json['userId'] ?? '',
      timestamp: json['timestamp'] ?? 0,
      latitude: (json['latitude'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? 0).toDouble(),
      speed: json['speed'] ?? 0,
      prediction: json['prediction'] ?? '',
      fuel: json['fuel'] ?? 0,
      temp: (json['temp'] ?? 0).toDouble(),
      rpm: json['rpm'] ?? 0,
      belt: json['belt'] ?? false,
      angleWarning: json['angleWarning'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'historyId': historyId,
      'userId': userId,
      'timestamp': timestamp,
      'latitude': latitude,
      'longitude': longitude,
      'speed': speed,
      'prediction': prediction,
      'fuel': fuel,
      'temp': temp,
      'rpm': rpm,
      'belt': belt,
      'angleWarning': angleWarning,
    };
  }

  // Helper method to get formatted timestamp
  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(timestamp);

  // Helper method to get formatted date string
  String get formattedDate {
    final date = dateTime;
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // Helper method to get formatted time string
  String get formattedTime {
    final date = dateTime;
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  // Helper method to check if prediction is dangerous
  bool get isDangerous => prediction.toUpperCase() == 'DANGEROUS';
}
