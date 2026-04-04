import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../models/live_data_model.dart';
import '../models/user_model.dart';
import 'live_data_service.dart';
import 'notification_service.dart';
import 'database_service.dart';

class GlobalAlertService {
  static final GlobalAlertService _instance = GlobalAlertService._internal();

  factory GlobalAlertService() => _instance;

  GlobalAlertService._internal();

  final LiveDataService _liveDataService = LiveDataService();
  final NotificationService _notificationService = NotificationService();
  final DatabaseService _databaseService = DatabaseService();

  StreamSubscription<List<LiveData>>? _globalSubscription;
  bool _isMonitoring = false;
  final Set<String> _activeAlerts = {};
  UserModel? _currentUser;

  Future<void> startMonitoring(UserModel currentUser) async {
    if (_isMonitoring) return;
    _currentUser = currentUser;

    // Initialize notification service
    await _notificationService.init();

    // Get peers (same type: Police or Hospital)
    List<dynamic> peers = [];
    if (_currentUser!.userType == UserType.police) {
      peers = await _databaseService.getAllPoliceStations();
    } else if (_currentUser!.userType == UserType.hospital) {
      peers = await _databaseService.getAllHospitals();
    }

    _globalSubscription = _liveDataService.getGlobalAlertStream().listen((
      alerts,
    ) async {
      try {
        if (_currentUser == null) return;

        final myAlerts = <LiveData>[];

        print('🚨 Global Alert Monitoring Started');

        for (var alert in alerts) {
          dynamic nearestPeer;
          double minDistance = 10000;

          for (var peer in peers) {
            double distance = Geolocator.distanceBetween(
              peer.latitude,
              peer.longitude,
              alert.latitude,
              alert.longitude,
            );

            print('🚨 Distance: $distance');

            if (distance < minDistance) {
              minDistance = distance;
              nearestPeer = peer;
            }
          }

          if (nearestPeer != null) {
            myAlerts.add(alert);
          }
        }

        print('🚨 My Alerts: $myAlerts');

        final currentAlertUserIds = myAlerts.map((a) => a.userId).toSet();

        // Check for NEW alerts (only nearest ones)
        for (var alert in myAlerts) {
          if (!_activeAlerts.contains(alert.userId)) {
            _handleAlert(alert);
            _activeAlerts.add(alert.userId);
          }
        }

        // Remove alerts that are cleared OR I am no longer nearest to
        _activeAlerts.removeWhere(
          (userId) => !currentAlertUserIds.contains(userId),
        );
      } catch (e) {
        print('Global alert monitoring error: $e');
      }
    }, onError: (e) => print('Global alert monitoring stream error: $e'));
    _isMonitoring = true;
    print('🚨 Global Alert Monitoring Started');
  }

  void stopMonitoring() {
    _globalSubscription?.cancel();
    _isMonitoring = false;
    _activeAlerts.clear();
    print('Global Alert Monitoring Stopped');
  }

  Future<void> _handleAlert(LiveData liveData) async {
    print('Called _handleAlert');

    _notificationService.showNotification(
      id: liveData.userId.hashCode,
      title: 'Emergency Alert!',
      body: 'Accident detected! Tap to view details.',
      payload: liveData.userId,
    );

    if (_currentUser != null) {
      String responderType = _currentUser!.userType == UserType.police
          ? 'Police'
          : 'Hospital';

      try {
        await _databaseService.createAccidentReport(
          victimId: liveData.userId,
          responderId: _currentUser!.id,
          responderType: responderType,
          latitude: liveData.latitude,
          longitude: liveData.longitude,
          speed: liveData.speed,
          rpm: liveData.rpm,
          fuel: liveData.fuel,
          temp: liveData.temp,
          belt: liveData.belt,
          angleWarning: liveData.angleWarning,
          prediction: liveData.prediction,
        );
        print('Accident report created for ${liveData.userId}');
      } catch (e) {
        print('Error creating accident report: $e');
      }
    }
  }
}
