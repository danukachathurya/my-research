class VehicleModel {
  final String id;
  final String vehicleName;
  final String licenseNumber;
  final String registrationNumber;
  final String userId; // Owner's user ID
  final DateTime createdAt;
  final DateTime updatedAt;

  VehicleModel({
    required this.id,
    required this.vehicleName,
    required this.licenseNumber,
    required this.registrationNumber,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VehicleModel.fromJson(Map<dynamic, dynamic> json) {
    return VehicleModel(
      id: json['id'] ?? '',
      vehicleName: json['vehicleName'] ?? '',
      licenseNumber: json['licenseNumber'] ?? '',
      registrationNumber: json['registrationNumber'] ?? '',
      userId: json['userId'] ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] ?? 0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updatedAt'] ?? 0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vehicleName': vehicleName,
      'licenseNumber': licenseNumber,
      'registrationNumber': registrationNumber,
      'userId': userId,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  VehicleModel copyWith({
    String? id,
    String? vehicleName,
    String? licenseNumber,
    String? registrationNumber,
    String? userId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VehicleModel(
      id: id ?? this.id,
      vehicleName: vehicleName ?? this.vehicleName,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
