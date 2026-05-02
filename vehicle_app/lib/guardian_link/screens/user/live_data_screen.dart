import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import '../../models/live_data_model.dart';
import '../../models/user_model.dart';
import '../../services/live_data_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/map_helper.dart';

class LiveDataScreen extends StatefulWidget {
  final UserModel userModel;

  const LiveDataScreen({super.key, required this.userModel});

  @override
  State<LiveDataScreen> createState() => _LiveDataScreenState();
}

class _LiveDataScreenState extends State<LiveDataScreen> {
  static const Duration _loadingTimeoutDuration = Duration(seconds: 6);

  final LiveDataService _liveDataService = LiveDataService();
  final Completer<GoogleMapController> _mapController =
      Completer<GoogleMapController>();

  LiveData? _liveData;
  bool _isLoading = true;
  String? _errorMessage;
  Set<Marker> _markers = {};
  Timer? _loadingTimeout;
  StreamSubscription<LiveData?>? _liveDataSubscription;

  @override
  void initState() {
    super.initState();
    _startLoadingTimeout();
    _setupLiveDataListener();
    unawaited(_loadInitialLiveData());
  }

  @override
  void dispose() {
    _loadingTimeout?.cancel();
    _liveDataSubscription?.cancel();
    super.dispose();
  }

  void _startLoadingTimeout() {
    _loadingTimeout?.cancel();
    _loadingTimeout = Timer(_loadingTimeoutDuration, () {
      if (!mounted || !_isLoading) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage =
            'Live data is taking longer than expected. Pull to refresh or try again shortly.';
      });
    });
  }

  Future<void> _loadInitialLiveData() async {
    try {
      final liveData = await _liveDataService.getLiveDataOnce(
        widget.userModel.id,
      );

      if (!mounted || !_isLoading) {
        return;
      }

      if (liveData == null) {
        _loadingTimeout?.cancel();
        setState(() {
          _liveData = null;
          _markers = {};
          _isLoading = false;
        });
        return;
      }

      _applyLiveData(liveData, animateCamera: false);
    } catch (_) {
      if (!mounted || !_isLoading) {
        return;
      }

      _loadingTimeout?.cancel();
      setState(() {
        _liveData = null;
        _markers = {};
        _isLoading = false;
        _errorMessage =
            'We could not load the latest live data right now. Please try again.';
      });
    }
  }

  void _setupLiveDataListener() {
    _liveDataSubscription = _liveDataService
        .getLiveDataStream(widget.userModel.id)
        .listen(
          (liveData) {
            if (!mounted) {
              return;
            }

            if (liveData == null) {
              _loadingTimeout?.cancel();
              setState(() {
                _liveData = null;
                _markers = {};
                _isLoading = false;
              });
              return;
            }

            _applyLiveData(liveData);
          },
          onError: (_, _) {
            if (!mounted) {
              return;
            }

            _loadingTimeout?.cancel();
            setState(() {
              _liveData = null;
              _markers = {};
              _isLoading = false;
              _errorMessage =
                  'We could not read live data for this vehicle right now.';
            });
          },
        );
  }

  void _applyLiveData(LiveData liveData, {bool animateCamera = true}) {
    _loadingTimeout?.cancel();

    final fallbackMarker = _buildVehicleMarker(
      liveData,
      _defaultVehicleIcon(liveData.prediction.toUpperCase() == 'SAFE'),
    );

    setState(() {
      _liveData = liveData;
      _markers = {fallbackMarker};
      _isLoading = false;
      _errorMessage = null;
    });

    unawaited(_updateVehicleMarkerIcon(liveData));
    if (animateCamera) {
      unawaited(_animateCameraToVehicle(liveData));
    }
  }

  Marker _buildVehicleMarker(LiveData liveData, BitmapDescriptor icon) {
    return Marker(
      markerId: MarkerId('vehicle_${widget.userModel.id}'),
      position: LatLng(liveData.latitude, liveData.longitude),
      onTap: () async {
        await MapHelper.openMapsNavigation(
          liveData.latitude,
          liveData.longitude,
          label: 'Your Vehicle',
        );
      },
      infoWindow: InfoWindow(
        title: 'Your Vehicle',
        snippet:
            'Speed: ${liveData.speed} km/h | ${liveData.prediction.toUpperCase()}',
      ),
      icon: icon,
      rotation: 0,
      anchor: const Offset(0.5, 0.5),
    );
  }

  BitmapDescriptor _defaultVehicleIcon(bool isSafe) {
    return BitmapDescriptor.defaultMarkerWithHue(
      isSafe ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed,
    );
  }

  Future<void> _updateVehicleMarkerIcon(LiveData liveData) async {
    try {
      final vehicleIcon = await _createVehicleIcon(
        liveData.prediction.toUpperCase() == 'SAFE',
      );

      if (!mounted ||
          _liveData == null ||
          _liveData!.updatedAt != liveData.updatedAt) {
        return;
      }

      setState(() {
        _markers = {_buildVehicleMarker(liveData, vehicleIcon)};
      });
    } catch (_) {
      // Keep the default marker if the custom marker creation fails.
    }
  }

  Future<void> _animateCameraToVehicle(LiveData liveData) async {
    if (!_mapController.isCompleted) {
      return;
    }

    final controller = await _mapController.future;
    await controller.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(liveData.latitude, liveData.longitude),
        15,
      ),
    );
  }

  Future<void> _retryLoad() async {
    _loadingTimeout?.cancel();

    final subscription = _liveDataSubscription;
    _liveDataSubscription = null;
    if (subscription != null) {
      await subscription.cancel();
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _liveData = null;
      _markers = {};
      _isLoading = true;
      _errorMessage = null;
    });

    _startLoadingTimeout();
    _setupLiveDataListener();
    await _loadInitialLiveData();
  }

  Future<BitmapDescriptor> _createVehicleIcon(bool isSafe) async {
    final color = isSafe ? AppColors.success : AppColors.error;

    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    final paint = Paint()..color = color;

    canvas.drawCircle(const Offset(50, 50), 40, paint);

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(const Offset(50, 50), 40, borderPaint);

    final carPaint = Paint()..color = Colors.white;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(30, 40, 40, 20),
        const Radius.circular(4),
      ),
      carPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(38, 30, 24, 15),
        const Radius.circular(4),
      ),
      carPaint,
    );

    final wheelPaint = Paint()..color = Colors.black87;
    canvas.drawCircle(const Offset(38, 60), 4, wheelPaint);
    canvas.drawCircle(const Offset(62, 60), 4, wheelPaint);

    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(100, 100);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Data'),
        actions: [
          if (_liveData != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _liveData!.isRecent
                        ? AppColors.success.withValues(alpha: 0.2)
                        : Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _liveData!.isRecent
                              ? AppColors.success
                              : Colors.orange,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _liveData!.isRecent ? 'LIVE' : 'DELAYED',
                        style: TextStyle(
                          color: _liveData!.isRecent
                              ? AppColors.success
                              : Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _liveData == null
          ? _buildNoDataView()
          : _buildLiveDataView(),
    );
  }

  Widget _buildNoDataView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.signal_wifi_off,
              size: 80,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 24),
            Text(
              'No Live Data Available',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage ??
                  'Your vehicle is not currently transmitting data',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _retryLoad,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveDataView() {
    final liveData = _liveData!;
    final lastUpdatedText = liveData.hasValidTimestamp
        ? DateFormat('MMM dd, yyyy - hh:mm a').format(liveData.lastUpdated)
        : 'Unavailable';

    return RefreshIndicator(
      onRefresh: _retryLoad,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.greyLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Last updated: $lastUpdatedText',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildSectionTitle('Safety Status'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildSafetyCard(
                    'Seatbelt',
                    liveData.belt,
                    Icons.safety_check,
                    liveData.belt ? AppColors.success : AppColors.error,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSafetyCard(
                    'Angle Warning',
                    !liveData.angleWarning,
                    Icons.warning_amber,
                    liveData.angleWarning ? AppColors.error : AppColors.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildPredictionCard(liveData.prediction),
            const SizedBox(height: 24),
            _buildSectionTitle('Vehicle Metrics'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Speed',
                    '${liveData.speed}',
                    'km/h',
                    Icons.speed,
                    AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    'RPM',
                    '${liveData.rpm}',
                    '',
                    Icons.rotate_right,
                    AppColors.accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Fuel',
                    '${liveData.fuel}',
                    '%',
                    Icons.local_gas_station,
                    _getFuelColor(liveData.fuel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    'Temperature',
                    liveData.temp.toStringAsFixed(1),
                    '\u00B0C',
                    Icons.thermostat,
                    _getTempColor(liveData.temp),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Location'),
            const SizedBox(height: 12),
            _buildLocationCard(liveData.latitude, liveData.longitude),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildSafetyCard(String label, bool isOk, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isOk ? 'OK' : 'Alert',
              style: TextStyle(
                fontSize: 16,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPredictionCard(String prediction) {
    final predictionColor = prediction.toUpperCase() == 'SAFE'
        ? AppColors.success
        : AppColors.error;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              predictionColor.withValues(alpha: 0.1),
              predictionColor.withValues(alpha: 0.05),
            ],
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: predictionColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                prediction.toUpperCase() == 'SAFE'
                    ? Icons.check_circle
                    : Icons.warning,
                color: predictionColor,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Driving Status',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    prediction.toUpperCase(),
                    style: TextStyle(
                      fontSize: 24,
                      color: predictionColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    String label,
    String value,
    String unit,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 32,
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (unit.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      unit,
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard(double latitude, double longitude) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: AppColors.primary.withValues(alpha: 0.1),
              child: Row(
                children: [
                  Icon(Icons.location_on, color: AppColors.primary, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Vehicle Location',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 300,
              child: GoogleMap(
                onMapCreated: (controller) {
                  if (!_mapController.isCompleted) {
                    _mapController.complete(controller);
                  }
                },
                initialCameraPosition: CameraPosition(
                  target: LatLng(latitude, longitude),
                  zoom: 15,
                ),
                markers: _markers,
                myLocationEnabled: false,
                myLocationButtonEnabled: false,
                mapType: MapType.normal,
                zoomControlsEnabled: true,
                compassEnabled: true,
                mapToolbarEnabled: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getFuelColor(int fuel) {
    if (fuel > 50) {
      return AppColors.success;
    }
    if (fuel > 25) {
      return Colors.orange;
    }
    return AppColors.error;
  }

  Color _getTempColor(double temp) {
    if (temp < 80) {
      return AppColors.success;
    }
    if (temp < 100) {
      return Colors.orange;
    }
    return AppColors.error;
  }
}
