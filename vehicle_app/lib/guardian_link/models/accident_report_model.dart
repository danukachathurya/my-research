class AccidentReportModel {
  final String id;
  final String victimId;
  final String responderId;
  final String responderType; // 'Police' or 'Hospital'
  final double latitude;
  final double longitude;
  final int timestamp;
  final String status; // 'Pending', 'Attending', 'Resolved'
  final int speed;
  final int rpm;
  final int fuel;
  final double temp;
  final bool belt;
  final bool angleWarning;
  final String prediction;

  AccidentReportModel({
    required this.id,
    required this.victimId,
    required this.responderId,
    required this.responderType,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.status,
    required this.speed,
    required this.rpm,
    required this.fuel,
    required this.temp,
    required this.belt,
    required this.angleWarning,
    required this.prediction,
  });

  factory AccidentReportModel.fromJson(Map<dynamic, dynamic> json) {
    return AccidentReportModel(
      id: json['id'] ?? '',
      victimId: json['victimId'] ?? '',
      responderId: json['responderId'] ?? '',
      responderType: json['responderType'] ?? '',
      latitude: (json['latitude'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? 0).toDouble(),
      timestamp: json['timestamp'] ?? 0,
      status: json['status'] ?? 'Pending',
      speed: json['speed'] ?? 0,
      rpm: json['rpm'] ?? 0,
      fuel: json['fuel'] ?? 0,
      temp: (json['temp'] ?? 0).toDouble(),
      belt: json['belt'] ?? false,
      angleWarning: json['angleWarning'] ?? false,
      prediction: json['prediction'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'victimId': victimId,
      'responderId': responderId,
      'responderType': responderType,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp,
      'status': status,
      'speed': speed,
      'rpm': rpm,
      'fuel': fuel,
      'temp': temp,
      'belt': belt,
      'angleWarning': angleWarning,
      'prediction': prediction,
    };
  }
}
