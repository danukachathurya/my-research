class GuardianModel {
  final String id;
  final String name;
  final String address;
  final String phoneNumber;
  final int age;
  final String? email;
  final String userId; // Owner's user ID
  final DateTime createdAt;
  final DateTime updatedAt;

  GuardianModel({
    required this.id,
    required this.name,
    required this.address,
    required this.phoneNumber,
    required this.age,
    this.email,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory GuardianModel.fromJson(Map<dynamic, dynamic> json) {
    return GuardianModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      age: (json['age'] as num?)?.toInt() ?? 0,
      email: json['email'],
      userId: json['userId'] ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] ?? 0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updatedAt'] ?? 0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'phoneNumber': phoneNumber,
      'age': age,
      'email': email,
      'userId': userId,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  GuardianModel copyWith({
    String? id,
    String? name,
    String? address,
    String? phoneNumber,
    int? age,
    String? email,
    String? userId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return GuardianModel(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      age: age ?? this.age,
      email: email ?? this.email,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
