import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import '../models/live_data_model.dart';

class LiveDataService {
  static final LiveDataService _instance = LiveDataService._internal();
  factory LiveDataService() => _instance;
  LiveDataService._internal();

  final DatabaseReference _liveDataRef = FirebaseDatabase.instance.ref(
    'liveData',
  );
  final Map<String, StreamSubscription<DatabaseEvent>> _subscriptions = {};

  /// Listen to live data updates for a specific user
  Stream<LiveData?> getLiveDataStream(String userId) {
    final controller = StreamController<LiveData?>();

    final subscription = _liveDataRef
        .child(userId)
        .onValue
        .listen(
          (event) {
            if (event.snapshot.exists) {
              final data = event.snapshot.value as Map<dynamic, dynamic>;
              final jsonData = Map<String, dynamic>.from(data);
              final liveData = LiveData.fromJson(userId, jsonData);
              controller.add(liveData);
            } else {
              controller.add(null);
            }
          },
          onError: (error) {
            controller.addError(error);
          },
        );

    // Store subscription for cleanup
    _subscriptions[userId] = subscription;

    // Clean up when stream is cancelled
    controller.onCancel = () {
      subscription.cancel();
      _subscriptions.remove(userId);
    };

    return controller.stream;
  }

  /// Listen to ACTIVE ALERTS (aleart == true) for Police/Hospital
  Stream<List<LiveData>> getGlobalAlertStream() {
    return _liveDataRef.orderByChild('aleart').equalTo(true).onValue.map((
      event,
    ) {
      final alerts = <LiveData>[];
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        data.forEach((userId, userData) {
          final jsonData = Map<String, dynamic>.from(userData as Map);
          alerts.add(LiveData.fromJson(userId as String, jsonData));
        });
      }
      return alerts;
    });
  }

  /// Get live data once (no real-time updates)
  Future<LiveData?> getLiveDataOnce(String userId) async {
    try {
      final snapshot = await _liveDataRef.child(userId).get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        final jsonData = Map<String, dynamic>.from(data);
        return LiveData.fromJson(userId, jsonData);
      }
      return null;
    } catch (e) {
      print('Error getting live data: $e');
      return null;
    }
  }

  /// Update specific fields in live data
  Future<void> updateLiveData(
    String userId,
    Map<String, dynamic> updates,
  ) async {
    try {
      await _liveDataRef.child(userId).update(updates);
    } catch (e) {
      print('Error updating live data: $e');
      rethrow;
    }
  }

  /// Set complete live data
  Future<void> setLiveData(String userId, Map<String, dynamic> data) async {
    try {
      await _liveDataRef.child(userId).set(data);
    } catch (e) {
      print('Error setting live data: $e');
      rethrow;
    }
  }

  /// Cancel a specific user's subscription
  void cancelSubscription(String userId) {
    _subscriptions[userId]?.cancel();
    _subscriptions.remove(userId);
  }

  /// Cancel all subscriptions
  void cancelAllSubscriptions() {
    for (var subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();
  }

  /// Check if user has active live data
  Future<bool> hasLiveData(String userId) async {
    try {
      final snapshot = await _liveDataRef.child(userId).get();
      return snapshot.exists;
    } catch (e) {
      print('Error checking live data: $e');
      return false;
    }
  }
}
