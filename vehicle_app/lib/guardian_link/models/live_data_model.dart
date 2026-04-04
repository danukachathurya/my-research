class LiveData {
  final String userId;
  final bool aleart;
  final bool angleWarning;
  final bool belt;
  final int fuel;
  final double latitude;
  final double longitude;
  final String prediction;
  final int rpm;
  final int speed;
  final double temp;
  final String updatedAt;
  final String vehicleId;

  LiveData({
    required this.userId,
    required this.aleart,
    required this.angleWarning,
    required this.belt,
    required this.fuel,
    required this.latitude,
    required this.longitude,
    required this.prediction,
    required this.rpm,
    required this.speed,
    required this.temp,
    required this.updatedAt,
    required this.vehicleId,
  });

  factory LiveData.fromJson(String userId, Map<String, dynamic> json) {
    return LiveData(
      userId: userId,
      aleart: json['aleart'] ?? false,
      angleWarning: json['angle_warning'] ?? false,
      belt: json['belt'] ?? false,
      fuel: json['fuel'] ?? 0,
      latitude: (json['latitude'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? 0).toDouble(),
      prediction: json['prediction'] ?? '',
      rpm: json['rpm'] ?? 0,
      speed: json['speed'] ?? 0,
      temp: (json['temp'] ?? 0).toDouble(),
      updatedAt: json['updatedAt'] ?? 0,
      vehicleId: json['vehicleId'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'aleart': aleart,
      'angle_warning': angleWarning,
      'belt': belt,
      'fuel': fuel,
      'latitude': latitude,
      'longitude': longitude,
      'prediction': prediction,
      'rpm': rpm,
      'speed': speed,
      'temp': temp,
      'updatedAt': updatedAt,
      'vehicleId': vehicleId,
    };
  }

  // Helper method to get formatted timestamp
  DateTime get lastUpdated => DateTime.fromMillisecondsSinceEpoch(int.parse(updatedAt));
  
  // Helper method to check if data is recent (within last 5 minutes)
  bool get isRecent {
    final now = DateTime.now();
    final difference = now.difference(lastUpdated);
    return difference.inMinutes < 5;
  }
}
