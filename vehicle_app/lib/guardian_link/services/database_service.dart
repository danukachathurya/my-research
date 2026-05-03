import 'package:firebase_database/firebase_database.dart';
import '../models/hospital_model.dart';
import '../models/police_model.dart';
import '../models/vehicle_model.dart';
import '../models/guardian_model.dart';
import '../models/user_model.dart';
import '../models/accident_report_model.dart';
import 'guardian_firebase.dart';

class DatabaseService {
  FirebaseDatabase get _database => GuardianFirebase.database;

  // ============== Hospital Operations ==============

  // Create hospital
  Future<HospitalModel> createHospital({
    required String name,
    required String phoneNumber,
    required String address,
    required double latitude,
    required double longitude,
    required String adminId,
  }) async {
    try {
      await GuardianFirebase.ensureInitialized();
      String hospitalId = _database.ref('hospitals').push().key!;

      final hospital = HospitalModel(
        id: hospitalId,
        name: name,
        phoneNumber: phoneNumber,
        address: address,
        latitude: latitude,
        longitude: longitude,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: adminId,
      );

      await _database.ref('hospitals/$hospitalId').set(hospital.toJson());
      return hospital;
    } catch (e) {
      throw Exception('Failed to create hospital: $e');
    }
  }

  // Get hospital by ID
  Future<HospitalModel?> getHospitalById(String hospitalId) async {
    try {
      await GuardianFirebase.ensureInitialized();
      final snapshot = await _database.ref('hospitals/$hospitalId').get();
      if (snapshot.exists) {
        return HospitalModel.fromJson(snapshot.value as Map<dynamic, dynamic>);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get hospital: $e');
    }
  }

  // Get all hospitals
  Future<List<HospitalModel>> getAllHospitals() async {
    List<HospitalModel> hospitals = [];

    try {
      await GuardianFirebase.ensureInitialized();
      final snapshot = await _database.ref('hospitals').get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          hospitals.add(HospitalModel.fromJson(value as Map<dynamic, dynamic>));
        });
      }
    } catch (e) {
      throw Exception('Failed to fetch hospitals: $e');
    }

    return hospitals;
  }

  // Update hospital
  Future<void> updateHospital({
    required String hospitalId,
    String? name,
    String? phoneNumber,
    String? address,
    double? latitude,
    double? longitude,
  }) async {
    try {
      await GuardianFirebase.ensureInitialized();
      Map<String, dynamic> updates = {
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };

      if (name != null) updates['name'] = name;
      if (phoneNumber != null) updates['phoneNumber'] = phoneNumber;
      if (address != null) updates['address'] = address;
      if (latitude != null) updates['latitude'] = latitude;
      if (longitude != null) updates['longitude'] = longitude;

      await _database.ref('hospitals/$hospitalId').update(updates);
    } catch (e) {
      throw Exception('Failed to update hospital: $e');
    }
  }

  // Delete hospital
  Future<void> deleteHospital(String hospitalId) async {
    try {
      await GuardianFirebase.ensureInitialized();
      await _database.ref('hospitals/$hospitalId').remove();
    } catch (e) {
      throw Exception('Failed to delete hospital: $e');
    }
  }

  // ============== Police Operations ==============

  // Create police station
  Future<PoliceModel> createPoliceStation({
    required String name,
    required String phoneNumber,
    required String address,
    required double latitude,
    required double longitude,
    required String adminId,
  }) async {
    try {
      await GuardianFirebase.ensureInitialized();
      String policeId = _database.ref('police').push().key!;

      final police = PoliceModel(
        id: policeId,
        name: name,
        phoneNumber: phoneNumber,
        address: address,
        latitude: latitude,
        longitude: longitude,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: adminId,
      );

      await _database.ref('police/$policeId').set(police.toJson());
      return police;
    } catch (e) {
      throw Exception('Failed to create police station: $e');
    }
  }

  // Get police station by ID
  Future<PoliceModel?> getPoliceStationById(String policeId) async {
    try {
      await GuardianFirebase.ensureInitialized();
      final snapshot = await _database.ref('police/$policeId').get();
      if (snapshot.exists) {
        return PoliceModel.fromJson(snapshot.value as Map<dynamic, dynamic>);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get police station: $e');
    }
  }

  // Get all police stations
  Future<List<PoliceModel>> getAllPoliceStations() async {
    try {
      await GuardianFirebase.ensureInitialized();
      final snapshot = await _database.ref('police').get();
      List<PoliceModel> policeStations = [];

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          policeStations.add(
            PoliceModel.fromJson(value as Map<dynamic, dynamic>),
          );
        });
      }

      return policeStations;
    } catch (e) {
      throw Exception('Failed to fetch police stations: $e');
    }
  }

  // Update police station
  Future<void> updatePoliceStation({
    required String policeId,
    String? name,
    String? phoneNumber,
    String? address,
    double? latitude,
    double? longitude,
  }) async {
    try {
      await GuardianFirebase.ensureInitialized();
      Map<String, dynamic> updates = {
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };

      if (name != null) updates['name'] = name;
      if (phoneNumber != null) updates['phoneNumber'] = phoneNumber;
      if (address != null) updates['address'] = address;
      if (latitude != null) updates['latitude'] = latitude;
      if (longitude != null) updates['longitude'] = longitude;

      await _database.ref('police/$policeId').update(updates);
    } catch (e) {
      throw Exception('Failed to update police station: $e');
    }
  }

  // Delete police station
  Future<void> deletePoliceStation(String policeId) async {
    try {
      await GuardianFirebase.ensureInitialized();
      await _database.ref('police/$policeId').remove();
    } catch (e) {
      throw Exception('Failed to delete police station: $e');
    }
  }

  // ============== Vehicle Operations ==============

  // Create vehicle
  Future<VehicleModel> createVehicle({
    required String vehicleName,
    required String licenseNumber,
    required String registrationNumber,
    required String userId,
  }) async {
    try {
      await GuardianFirebase.ensureInitialized();
      String vehicleId = _database.ref('vehicles').push().key!;

      final vehicle = VehicleModel(
        id: vehicleId,
        vehicleName: vehicleName,
        licenseNumber: licenseNumber,
        registrationNumber: registrationNumber,
        userId: userId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _database.ref('vehicles/$vehicleId').set(vehicle.toJson());
      return vehicle;
    } catch (e) {
      throw Exception('Failed to create vehicle: $e');
    }
  }

  // Get vehicle by ID
  Future<VehicleModel?> getVehicleById(String vehicleId) async {
    try {
      await GuardianFirebase.ensureInitialized();
      final snapshot = await _database.ref('vehicles/$vehicleId').get();
      if (snapshot.exists) {
        return VehicleModel.fromJson(snapshot.value as Map<dynamic, dynamic>);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get vehicle: $e');
    }
  }

  // Get all vehicles for a user
  Future<List<VehicleModel>> getUserVehicles(String userId) async {
    try {
      await GuardianFirebase.ensureInitialized();
      final snapshot = await _database.ref('vehicles').get();
      List<VehicleModel> vehicles = [];

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          final vehicle = VehicleModel.fromJson(value as Map<dynamic, dynamic>);
          if (vehicle.userId == userId) {
            vehicles.add(vehicle);
          }
        });
      }

      return vehicles;
    } catch (e) {
      throw Exception('Failed to fetch vehicles: $e');
    }
  }

  // Update vehicle
  Future<void> updateVehicle({
    required String vehicleId,
    String? vehicleName,
    String? licenseNumber,
    String? registrationNumber,
  }) async {
    try {
      await GuardianFirebase.ensureInitialized();
      Map<String, dynamic> updates = {
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };

      if (vehicleName != null) updates['vehicleName'] = vehicleName;
      if (licenseNumber != null) updates['licenseNumber'] = licenseNumber;
      if (registrationNumber != null)
        updates['registrationNumber'] = registrationNumber;

      await _database.ref('vehicles/$vehicleId').update(updates);
    } catch (e) {
      throw Exception('Failed to update vehicle: $e');
    }
  }

  // Delete vehicle
  Future<void> deleteVehicle(String vehicleId) async {
    try {
      await GuardianFirebase.ensureInitialized();
      await _database.ref('vehicles/$vehicleId').remove();
    } catch (e) {
      throw Exception('Failed to delete vehicle: $e');
    }
  }

  // ============== Guardian Operations ==============

  // Create guardian
  Future<GuardianModel> createGuardian({
    required String name,
    required String address,
    required String phoneNumber,
    required int age,
    required String userId,
    String? email,
  }) async {
    try {
      await GuardianFirebase.ensureInitialized();
      String guardianId = _database.ref('guardians').push().key!;

      final guardian = GuardianModel(
        id: guardianId,
        name: name,
        address: address,
        phoneNumber: phoneNumber,
        age: age,
        email: email,
        userId: userId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _database.ref('guardians/$guardianId').set(guardian.toJson());
      return guardian;
    } catch (e) {
      throw Exception('Failed to create guardian: $e');
    }
  }

  // Get guardian by ID
  Future<GuardianModel?> getGuardianById(String guardianId) async {
    try {
      await GuardianFirebase.ensureInitialized();
      final snapshot = await _database.ref('guardians/$guardianId').get();
      if (snapshot.exists) {
        return GuardianModel.fromJson(snapshot.value as Map<dynamic, dynamic>);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get guardian: $e');
    }
  }

  // Get all guardians for a user
  Future<GuardianModel?> getUserGuardian(String userId) async {
    try {
      await GuardianFirebase.ensureInitialized();
      print(userId);

      final snapshot = await _database.ref('users/$userId').get();
      if (snapshot.exists) {
        final userRecord = snapshot.value as Map<dynamic, dynamic>;

        print(userRecord['linkedUserId']);

        final snapshotGuardian = await _database
            .ref('users/${userRecord['linkedUserId']}')
            .get();
        if (snapshotGuardian.exists) {
          final guardian = snapshotGuardian.value as Map<dynamic, dynamic>;
          return GuardianModel.fromJson(guardian);
        }
      }

      return null;
    } catch (e) {
      throw Exception('Failed to fetch guardians: $e');
    }
  }

  // Update guardian
  Future<void> updateGuardian({
    required String guardianId,
    String? name,
    String? address,
    String? phoneNumber,
    int? age,
    String? email,
  }) async {
    try {
      await GuardianFirebase.ensureInitialized();
      Map<String, dynamic> updates = {
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };

      if (name != null) updates['name'] = name;
      if (address != null) updates['address'] = address;
      if (phoneNumber != null) updates['phoneNumber'] = phoneNumber;
      if (age != null) updates['age'] = age;
      if (email != null) updates['email'] = email;

      await _database.ref('guardians/$guardianId').update(updates);
    } catch (e) {
      throw Exception('Failed to update guardian: $e');
    }
  }

  // Delete guardian
  Future<void> deleteGuardian(String guardianId) async {
    try {
      await GuardianFirebase.ensureInitialized();
      await _database.ref('guardians/$guardianId').remove();
    } catch (e) {
      throw Exception('Failed to delete guardian: $e');
    }
  }

  // ============== User Operations ==============

  // Get all users
  Future<List<UserModel>> getAllUsers() async {
    List<UserModel> users = [];

    try {
      await GuardianFirebase.ensureInitialized();
      final snapshot = await _database.ref('users').get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          users.add(UserModel.fromJson(value as Map<dynamic, dynamic>));
        });
      }
    } catch (e) {
      throw Exception('Failed to fetch users: $e');
    }

    return users;
  }

  // Get user by ID
  Future<UserModel?> getUserById(String userId) async {
    try {
      await GuardianFirebase.ensureInitialized();
      final snapshot = await _database.ref('users/$userId').get();
      if (snapshot.exists) {
        return UserModel.fromJson(snapshot.value as Map<dynamic, dynamic>);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get user: $e');
    }
  }

  // Update user
  Future<void> updateUser({
    required String userId,
    String? name,
    String? email,
    UserType? userType,
    String? nicNumber,
    String? photoBase64,
    String? address,
    String? bloodGroup,
    String? phoneNumber,
    int? age,
    String? linkedUserId,
  }) async {
    try {
      await GuardianFirebase.ensureInitialized();
      Map<String, dynamic> updates = {
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };

      if (name != null) updates['name'] = name;
      if (email != null) updates['email'] = email;
      if (userType != null)
        updates['userType'] = userType.toString().split('.').last;
      if (nicNumber != null) updates['nicNumber'] = nicNumber;
      if (photoBase64 != null) updates['photoBase64'] = photoBase64;
      if (address != null) updates['address'] = address;
      if (phoneNumber != null) updates['phoneNumber'] = phoneNumber;
      if (age != null) updates['age'] = age;
      if (linkedUserId != null) updates['linkedUserId'] = linkedUserId;
      if (bloodGroup != null) updates['bloodGroup'] = bloodGroup;

      await _database.ref('users/$userId').update(updates);
    } catch (e) {
      throw Exception('Failed to update user: $e');
    }
  }

  // Delete user
  Future<void> deleteUser(String userId) async {
    try {
      await GuardianFirebase.ensureInitialized();
      await _database.ref('users/$userId').remove();
    } catch (e) {
      throw Exception('Failed to delete user: $e');
    }
  }

  // Get user by email
  Future<UserModel?> getUserByEmail(String email) async {
    try {
      await GuardianFirebase.ensureInitialized();
      final snapshot = await _database.ref('users').get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        for (var value in data.values) {
          final user = UserModel.fromJson(value as Map<dynamic, dynamic>);
          if (user.email == email) {
            return user;
          }
        }
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get user by email: $e');
    }
  }

  // Map user to police station
  Future<void> mapUserToPoliceStation({
    required String userId,
    required String policeStationId,
  }) async {
    try {
      await GuardianFirebase.ensureInitialized();
      await _database
          .ref('police_station_users/$policeStationId/$userId')
          .set(true);
      await _database.ref('user_police_stations/$userId/$policeStationId').set({
        'mappedAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      throw Exception('Failed to map user to police station: $e');
    }
  }

  // Map user to hospital
  Future<void> mapUserToHospital({
    required String userId,
    required String hospitalId,
  }) async {
    try {
      await GuardianFirebase.ensureInitialized();
      await _database.ref('hospital_users/$hospitalId/$userId').set(true);
      await _database.ref('user_hospitals/$userId/$hospitalId').set({
        'mappedAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      throw Exception('Failed to map user to hospital: $e');
    }
  }

  // Get users for a police station
  Future<List<UserModel>> getPoliceStationUsers(String policeStationId) async {
    List<UserModel> users = [];
    try {
      await GuardianFirebase.ensureInitialized();
      final snapshot = await _database
          .ref('police_station_users/$policeStationId')
          .get();
      if (snapshot.exists) {
        final userIds = (snapshot.value as Map<dynamic, dynamic>).keys;
        for (String userId in userIds) {
          final user = await getUserById(userId);
          if (user != null) {
            users.add(user);
          }
        }
      }
    } catch (e) {
      throw Exception('Failed to fetch police station users: $e');
    }
    return users;
  }

  // Get users for a hospital
  Future<List<UserModel>> getHospitalUsers(String hospitalId) async {
    List<UserModel> users = [];
    try {
      await GuardianFirebase.ensureInitialized();
      final snapshot = await _database.ref('hospital_users/$hospitalId').get();
      if (snapshot.exists) {
        final userIds = (snapshot.value as Map<dynamic, dynamic>).keys;
        for (String userId in userIds) {
          final user = await getUserById(userId);
          if (user != null) {
            users.add(user);
          }
        }
      }
    } catch (e) {
      throw Exception('Failed to fetch hospital users: $e');
    }
    return users;
  }

  // ============== Accident Report Operations ==============

  // Create accident report
  Future<AccidentReportModel> createAccidentReport({
    required String victimId,
    required String responderId,
    required String responderType,
    required double latitude,
    required double longitude,
    required int speed,
    required int rpm,
    required int fuel,
    required double temp,
    required bool belt,
    required bool angleWarning,
    required String prediction,
  }) async {
    try {
      await GuardianFirebase.ensureInitialized();
      String reportId = _database.ref('accident_reports').push().key!;

      final report = AccidentReportModel(
        id: reportId,
        victimId: victimId,
        responderId: responderId,
        responderType: responderType,
        latitude: latitude,
        longitude: longitude,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        status: 'Pending',
        speed: speed,
        rpm: rpm,
        fuel: fuel,
        temp: temp,
        belt: belt,
        angleWarning: angleWarning,
        prediction: prediction,
      );

      await _database.ref('accident_reports/$reportId').set(report.toJson());

      // Also map this report to the responder for easy lookup
      await _database.ref('responder_reports/$responderId/$reportId').set(true);

      return report;
    } catch (e) {
      throw Exception('Failed to create accident report: $e');
    }
  }

  // Get accident reports for a responder
  Future<List<AccidentReportModel>> getResponderReports(
    String responderId,
  ) async {
    List<AccidentReportModel> reports = [];
    try {
      await GuardianFirebase.ensureInitialized();
      final snapshot = await _database
          .ref('responder_reports/$responderId')
          .get();
      if (snapshot.exists) {
        final reportIds = (snapshot.value as Map<dynamic, dynamic>).keys;
        for (String reportId in reportIds) {
          final reportSnapshot = await _database
              .ref('accident_reports/$reportId')
              .get();
          if (reportSnapshot.exists) {
            reports.add(
              AccidentReportModel.fromJson(
                reportSnapshot.value as Map<dynamic, dynamic>,
              ),
            );
          }
        }
      }

      // Sort reports by timestamp descending (newest first)
      reports.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } catch (e) {
      throw Exception('Failed to fetch responder reports: $e');
    }
    return reports;
  }

  // Update accident report status
  Future<void> updateAccidentReportStatus(
    String reportId,
    String status,
  ) async {
    try {
      await GuardianFirebase.ensureInitialized();
      await _database.ref('accident_reports/$reportId').update({
        'status': status,
      });
    } catch (e) {
      throw Exception('Failed to update accident report status: $e');
    }
  }
}
