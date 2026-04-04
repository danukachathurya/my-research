enum UserType { user, police, hospital, admin, guardian }

enum BloodGroup { aPlus, aMinus, bPlus, bMinus, abPlus, abMinus, oPlus, oMinus }

class UserModel {
  final String id;
  final String name;
  final String email;
  final String? photoBase64;
  final String? nicNumber;
  final String? address;
  final String? phoneNumber;
  final int? age;
  final String?
  linkedUserId; // ID of the linked user (Ward for Guardian, Guardian for Ward)
  final BloodGroup? bloodGroup;
  final String? medicalDescription;
  final UserType userType;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.photoBase64,
    this.nicNumber,
    this.address,
    this.phoneNumber,
    this.age,
    this.linkedUserId,
    this.bloodGroup,
    this.medicalDescription,
    required this.userType,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserModel.fromJson(Map<dynamic, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      photoBase64: json['photoBase64'],
      nicNumber: json['nicNumber'],
      address: json['address'],
      phoneNumber: json['phoneNumber'],
      age: (json['age'] as num?)?.toInt(),
      linkedUserId: json['linkedUserId'],
      bloodGroup: json['bloodGroup'] != null
          ? BloodGroup.values.firstWhere(
              (e) => e.toString() == 'BloodGroup.${json['bloodGroup']}',
              orElse: () => BloodGroup.oPlus,
            )
          : null,
      medicalDescription: json['medicalDescription'],
      userType: UserType.values.firstWhere(
        (e) => e.toString() == 'UserType.${json['userType']}',
        orElse: () => UserType.user,
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] ?? 0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updatedAt'] ?? 0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'photoBase64': photoBase64,
      'nicNumber': nicNumber,
      'address': address,
      'phoneNumber': phoneNumber,
      'age': age,
      'linkedUserId': linkedUserId,
      'bloodGroup': bloodGroup?.toString().split('.').last,
      'medicalDescription': medicalDescription,
      'userType': userType.toString().split('.').last,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? photoBase64,
    String? nicNumber,
    String? address,
    String? phoneNumber,
    int? age,
    String? linkedUserId,
    BloodGroup? bloodGroup,
    String? medicalDescription,
    UserType? userType,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      photoBase64: photoBase64 ?? this.photoBase64,
      nicNumber: nicNumber ?? this.nicNumber,
      address: address ?? this.address,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      age: age ?? this.age,
      linkedUserId: linkedUserId ?? this.linkedUserId,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      medicalDescription: medicalDescription ?? this.medicalDescription,
      userType: userType ?? this.userType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
