import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';

import 'guardian_firebase.dart';

class LocationTrackingService {
  static final LocationTrackingService _instance =
      LocationTrackingService._internal();
  factory LocationTrackingService() => _instance;
  LocationTrackingService._internal();

  StreamSubscription<Position>? _positionStreamSubscription;
  DatabaseReference get _liveDataRef => GuardianFirebase.database.ref(
    'liveData',
  );
  String? _currentUserId;
  bool _isTracking = false;

  /// Start tracking user's location and update Firebase in real-time
  Future<void> startLocationTracking(String userId) async {
    // Don't start if already tracking for this user
    if (_isTracking && _currentUserId == userId) {
      return;
    }

    // Stop any existing tracking
    await stopLocationTracking();

    _currentUserId = userId;

    // Check if location services are enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled');
    }

    // Check permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied');
    }

    // Configure location settings
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update every 10 meters
    );

    // Start listening to position updates
    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
            _updateLocationInFirebase(position);
          },
          onError: (error) {
            print('Location tracking error: $error');
          },
        );

    _isTracking = true;

    // Get initial position immediately
    try {
      final initialPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _updateLocationInFirebase(initialPosition);
    } catch (e) {
      print('Error getting initial position: $e');
    }
  }

  /// Update location data in Firebase
  void _updateLocationInFirebase(Position position) {
    final userId = _currentUserId;
    if (userId == null) return;

    final updates = {
      'latitude': position.latitude,
      'longitude': position.longitude,
    };

    _liveDataRef.child(userId).update(updates).catchError((error) {
      print('Error updating location in Firebase: $error');
    });
  }

  /// Stop tracking location
  Future<void> stopLocationTracking() async {
    await _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _isTracking = false;
    _currentUserId = null;
  }

  /// Check if currently tracking
  bool get isTracking => _isTracking;

  /// Get current user ID being tracked
  String? get currentUserId => _currentUserId;

  /// Manually update location once (useful for testing or manual updates)
  Future<void> updateLocationOnce(String userId) async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final updates = {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };

      await _liveDataRef.child(userId).update(updates);
    } catch (e) {
      print('Error updating location once: $e');
      rethrow;
    }
  }
}
