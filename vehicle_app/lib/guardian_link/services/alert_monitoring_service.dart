import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import '../models/live_data_model.dart';
import 'live_data_service.dart';
import 'database_service.dart';
import 'package:http/http.dart' as http;

class AlertMonitoringService {
  static final AlertMonitoringService _instance =
      AlertMonitoringService._internal();
  factory AlertMonitoringService() => _instance;
  AlertMonitoringService._internal();

  final LiveDataService _liveDataService = LiveDataService();
  final DatabaseService _databaseService = DatabaseService();
  final DatabaseReference _historyRef = FirebaseDatabase.instance.ref(
    'history',
  );

  StreamSubscription<LiveData?>? _liveDataSubscription;
  String? _currentUserId;
  bool _isMonitoring = false;
  bool _lastAlertState = false;

  /// Start monitoring live data for alerts
  Future<void> startMonitoring(String userId) async {
    if (_isMonitoring && _currentUserId == userId) {
      return;
    }

    await stopMonitoring();
    _currentUserId = userId;

    // Listen to live data changes
    _liveDataSubscription = _liveDataService
        .getLiveDataStream(userId)
        .listen(
          (liveData) async {
            if (liveData != null) {
              await _checkForAlert(liveData);
            }
          },
          onError: (error) {
            print('Alert monitoring error: $error');
          },
        );

    _isMonitoring = true;
  }

  /// Check if alert is triggered and handle it
  Future<void> _checkForAlert(LiveData liveData) async {
    // Check if alert field is true
    final isAlert = liveData.aleart;

    // Only trigger if alert state changed from false to true
    if (isAlert && !_lastAlertState) {
      print('🚨 ALERT DETECTED for user: ${liveData.userId}');
      await _handleAlert(liveData);
    }

    _lastAlertState = isAlert;
  }

  /// Handle alert by creating history and resetting alert flag
  Future<void> _handleAlert(LiveData liveData) async {
    try {
      // Send SMS to guardian
      await _sendSmsToGuardian(liveData);

      // Create history record
      await _createHistoryRecord(liveData);

      // Reset alert flag to false
      await _liveDataService.updateLiveData(liveData.userId, {'aleart': false});

      print('✅ History created and alert reset');
      print('📍 Location: ${liveData.latitude}, ${liveData.longitude}');
      print('⚠️ Prediction: ${liveData.prediction}');
    } catch (e) {
      print('Error handling alert: $e');
    }
  }

  Future<void> _sendSmsToGuardian(LiveData liveData) async {
    try {
      // 1. Get User (Ward) details to find Guardian
      final ward = await _databaseService.getUserById(liveData.userId);
      if (ward == null || ward.linkedUserId == null) {
        print('No linked guardian found for user ${liveData.userId}');
        return;
      }

      // 2. Get Guardian details to find Phone Number
      final guardian = await _databaseService.getUserById(ward.linkedUserId!);
      if (guardian == null ||
          guardian.phoneNumber == null ||
          guardian.phoneNumber!.isEmpty) {
        print('Guardian phone number not found');
        return;
      }

      // 3. Construct Message
      final lat = liveData.latitude.toStringAsFixed(6);
      final lng = liveData.longitude.toStringAsFixed(6);
      final googleMapsLink = 'https://maps.google.com/?q=$lat,$lng';
      final message =
          'EMERGENCY! Your ${ward.name} has been faced to Accident. Location: $googleMapsLink';

      // 4. Send SMS via textit.biz
      final queryParameters = {
        'id': '94719718093',
        'pw': '4284',
        'to': guardian.phoneNumber,
        'text': message,
      };

      final url = Uri.https('textit.biz', '/sendmsg', queryParameters);

      final response = await http.get(url);

      if (response.statusCode == 200) {
        print('SMS sent successfully to ${guardian.phoneNumber}');
      } else {
        print('Failed to send SMS: ${response.statusCode}');
      }
    } catch (e) {
      print('Error sending SMS: $e');
    }
  }

  /// Create history record in Firebase
  Future<void> _createHistoryRecord(LiveData liveData) async {
    final historyId = _historyRef.push().key;
    if (historyId == null) return;

    // Create history data without aleart, updatedAt, and vehicleId
    final historyData = {
      'historyId': historyId,
      'userId': liveData.userId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,

      // Vehicle data
      'latitude': liveData.latitude,
      'longitude': liveData.longitude,
      'speed': liveData.speed,
      'prediction': liveData.prediction,
      'fuel': liveData.fuel,
      'temp': liveData.temp,
      'rpm': liveData.rpm,
      'belt': liveData.belt,
      'angleWarning': liveData.angleWarning,
    };

    // Save to history/{userId}/{historyId}
    await _historyRef.child(liveData.userId).child(historyId).set(historyData);
  }

  /// Stop monitoring
  Future<void> stopMonitoring() async {
    await _liveDataSubscription?.cancel();
    _liveDataSubscription = null;
    _isMonitoring = false;
    _currentUserId = null;
    _lastAlertState = false;
  }

  /// Check if currently monitoring
  bool get isMonitoring => _isMonitoring;

  /// Get current user ID being monitored
  String? get currentUserId => _currentUserId;

  /// Get history for a user with optional date filtering
  Future<List<Map<String, dynamic>>> getHistory({
    required String userId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final snapshot = await _historyRef.child(userId).get();

      if (!snapshot.exists) {
        return [];
      }

      final data = snapshot.value as Map<dynamic, dynamic>;
      final historyList = <Map<String, dynamic>>[];

      data.forEach((key, value) {
        final historyItem = Map<String, dynamic>.from(value as Map);
        final timestamp = historyItem['timestamp'] as int;
        final itemDate = DateTime.fromMillisecondsSinceEpoch(timestamp);

        // Apply date filtering
        bool includeItem = true;

        if (startDate != null && itemDate.isBefore(startDate)) {
          includeItem = false;
        }

        if (endDate != null &&
            itemDate.isAfter(endDate.add(const Duration(days: 1)))) {
          includeItem = false;
        }

        if (includeItem) {
          historyList.add(historyItem);
        }
      });

      // Sort by timestamp (newest first)
      historyList.sort(
        (a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int),
      );

      return historyList;
    } catch (e) {
      print('Error getting history: $e');
      return [];
    }
  }

  /// Get history stream for real-time updates
  Stream<List<Map<String, dynamic>>> getHistoryStream({
    required String userId,
  }) {
    return _historyRef.child(userId).onValue.map((event) {
      final historyList = <Map<String, dynamic>>[];

      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          historyList.add(Map<String, dynamic>.from(value as Map));
        });
      }

      // Sort by timestamp (newest first)
      historyList.sort(
        (a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int),
      );

      return historyList;
    });
  }

  /// Delete a history record
  Future<void> deleteHistory(String userId, String historyId) async {
    await _historyRef.child(userId).child(historyId).remove();
  }

  /// Clear all history for a user
  Future<void> clearAllHistory(String userId) async {
    await _historyRef.child(userId).remove();
  }
}
