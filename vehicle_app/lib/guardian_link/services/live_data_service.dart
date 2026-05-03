import 'dart:async';
import 'dart:developer' as developer;

import 'package:firebase_database/firebase_database.dart';

import '../models/live_data_model.dart';
import 'guardian_firebase.dart';

class LiveDataService {
  static final LiveDataService _instance = LiveDataService._internal();
  factory LiveDataService() => _instance;
  LiveDataService._internal();

  DatabaseReference get _liveDataRef => GuardianFirebase.database.ref(
    'liveData',
  );
  final Map<String, StreamSubscription<DatabaseEvent>> _subscriptions = {};

  LiveData? _parseLiveDataSnapshot(String userId, DataSnapshot snapshot) {
    if (!snapshot.exists || snapshot.value == null) {
      return null;
    }

    final rawValue = snapshot.value;
    if (rawValue is! Map) {
      throw const FormatException('Unexpected live data format.');
    }

    final jsonData = Map<String, dynamic>.from(
      rawValue.map((key, value) => MapEntry(key.toString(), value)),
    );

    return LiveData.fromJson(userId, jsonData);
  }

  /// Listen to live data updates for a specific user
  Stream<LiveData?> getLiveDataStream(String userId) {
    final controller = StreamController<LiveData?>();

    final subscription = _liveDataRef
        .child(userId)
        .onValue
        .listen(
          (event) {
            try {
              final liveData = _parseLiveDataSnapshot(userId, event.snapshot);
              controller.add(liveData);
            } catch (error) {
              controller.addError(error);
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
        final data = event.snapshot.value;
        if (data is! Map) {
          return alerts;
        }

        data.forEach((userId, userData) {
          if (userData is! Map) {
            return;
          }

          final jsonData = Map<String, dynamic>.from(
            userData.map((key, value) => MapEntry(key.toString(), value)),
          );
          alerts.add(LiveData.fromJson(userId.toString(), jsonData));
        });
      }
      return alerts;
    });
  }

  /// Get live data once (no real-time updates)
  Future<LiveData?> getLiveDataOnce(String userId) async {
    try {
      final snapshot = await _liveDataRef.child(userId).get();
      return _parseLiveDataSnapshot(userId, snapshot);
    } catch (e) {
      developer.log(
        'Error getting live data',
        name: 'LiveDataService',
        error: e,
      );
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
      developer.log(
        'Error updating live data',
        name: 'LiveDataService',
        error: e,
      );
      rethrow;
    }
  }

  /// Set complete live data
  Future<void> setLiveData(String userId, Map<String, dynamic> data) async {
    try {
      await _liveDataRef.child(userId).set(data);
    } catch (e) {
      developer.log(
        'Error setting live data',
        name: 'LiveDataService',
        error: e,
      );
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
      developer.log(
        'Error checking live data availability',
        name: 'LiveDataService',
        error: e,
      );
      return false;
    }
  }
}
