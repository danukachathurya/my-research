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
      aleart: _asBool(json['aleart'] ?? json['alert']),
      angleWarning: _asBool(json['angle_warning'] ?? json['angleWarning']),
      belt: _asBool(json['belt']),
      fuel: _asInt(json['fuel']),
      latitude: _asDouble(json['latitude'] ?? json['lat']),
      longitude: _asDouble(json['longitude'] ?? json['lng']),
      prediction: _asString(json['prediction']),
      rpm: _asInt(json['rpm']),
      speed: _asInt(json['speed']),
      temp: _asDouble(json['temp'] ?? json['temperature']),
      updatedAt: _asTimestamp(
        json['updatedAt'] ?? json['updated_at'] ?? json['timestamp'],
      ),
      vehicleId: _asString(json['vehicleId'] ?? json['vehicle_id']),
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

  static bool _asBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' || normalized == '1' || normalized == 'yes';
    }
    return false;
  }

  static int _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    if (value is String) {
      return int.tryParse(value) ?? double.tryParse(value)?.round() ?? 0;
    }
    return 0;
  }

  static double _asDouble(dynamic value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value) ?? 0;
    }
    return 0;
  }

  static String _asString(dynamic value) {
    return value?.toString() ?? '';
  }

  static String _asTimestamp(dynamic value) {
    if (value is num) {
      return value.round().toString();
    }
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        return '0';
      }

      final numericTimestamp = int.tryParse(trimmed);
      if (numericTimestamp != null) {
        return numericTimestamp.toString();
      }

      final parsedDate = DateTime.tryParse(trimmed);
      if (parsedDate != null) {
        return parsedDate.millisecondsSinceEpoch.toString();
      }
    }
    return '0';
  }

  bool get hasValidTimestamp {
    final timestamp = int.tryParse(updatedAt);
    return timestamp != null && timestamp > 0;
  }

  // Helper method to get formatted timestamp
  DateTime get lastUpdated {
    final timestamp = int.tryParse(updatedAt);
    if (timestamp == null || timestamp <= 0) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  // Helper method to check if data is recent (within last 5 minutes)
  bool get isRecent {
    if (!hasValidTimestamp) {
      return false;
    }
    final now = DateTime.now();
    final difference = now.difference(lastUpdated);
    return difference.inMinutes < 5;
  }
}
