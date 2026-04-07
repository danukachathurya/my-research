import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/damage_detection_service.dart';
import '../services/location_service.dart';
import 'result_screen.dart';

// Sri Lanka cities with coordinates
const List<Map<String, dynamic>> _sriLankaCities = [
  {'name': 'Colombo', 'lat': 6.9271, 'lon': 79.8612},
  {'name': 'Kandy', 'lat': 7.2906, 'lon': 80.6337},
  {'name': 'Galle', 'lat': 6.0535, 'lon': 80.2210},
  {'name': 'Jaffna', 'lat': 9.6615, 'lon': 80.0255},
  {'name': 'Negombo', 'lat': 7.2096, 'lon': 79.8379},
  {'name': 'Matara', 'lat': 5.9549, 'lon': 80.5550},
  {'name': 'Kurunegala', 'lat': 7.4867, 'lon': 80.3647},
  {'name': 'Anuradhapura', 'lat': 8.3114, 'lon': 80.4037},
  {'name': 'Ratnapura', 'lat': 6.6828, 'lon': 80.3992},
  {'name': 'Trincomalee', 'lat': 8.5874, 'lon': 81.2152},
  {'name': 'Batticaloa', 'lat': 7.7167, 'lon': 81.7000},
  {'name': 'Badulla', 'lat': 6.9934, 'lon': 81.0550},
  {'name': 'Kalmunai', 'lat': 7.4167, 'lon': 81.8167},
  {'name': 'Nuwara Eliya', 'lat': 6.9497, 'lon': 80.7891},
  {'name': 'Kegalle', 'lat': 7.2513, 'lon': 80.3464},
  {'name': 'Polonnaruwa', 'lat': 7.9403, 'lon': 81.0188},
  {'name': 'Hambantota', 'lat': 6.1241, 'lon': 81.1185},
  {'name': 'Gampaha', 'lat': 7.0890, 'lon': 80.0029},
  {'name': 'Moratuwa', 'lat': 6.7736, 'lon': 79.8813},
  {'name': 'Kalutara', 'lat': 6.5854, 'lon': 79.9607},
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DamageDetectionService _service = DamageDetectionService();
  final LocationService _locationService = LocationService();
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _brandController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();

  File? _selectedImage;
  bool _isLoading = false;
  bool _serverConnected = false;

  // Location state
  double? _latitude;
  double? _longitude;
  String _locationLabel = '';
  bool _isDetectingLocation = false;
  String? _selectedCity; // null = no city chosen manually

  @override
  void initState() {
    super.initState();
    _checkServerConnection();
  }

  @override
  void dispose() {
    _brandController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  Future<void> _checkServerConnection() async {
    final connected = await _service.checkServerConnection();
    setState(() {
      _serverConnected = connected;
    });
  }

  // ───────────────────────────────────────────────────────
  // Location helpers
  // ───────────────────────────────────────────────────────

  /// Return the name of the nearest preset city for a GPS fix.
  String _nearestCityName(double lat, double lon) {
    String best = 'Your Location';
    double bestDist = double.infinity;
    for (final city in _sriLankaCities) {
      final dLat = (city['lat'] as double) - lat;
      final dLon = (city['lon'] as double) - lon;
      final dist = math.sqrt(dLat * dLat + dLon * dLon);
      if (dist < bestDist) {
        bestDist = dist;
        best = city['name'] as String;
      }
    }
    // Only label it as a city if it is within ~30 km (≈0.27°)
    return bestDist < 0.27 ? 'Near $best' : 'Your Location';
  }

  Future<void> _detectGpsLocation() async {
    setState(() {
      _isDetectingLocation = true;
    });

    try {
      final position = await _locationService.getCurrentPositionWithTimeout(
        timeout: const Duration(seconds: 12),
      );

      if (position != null) {
        final label = _nearestCityName(position.latitude, position.longitude);
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
          _locationLabel = label;
          _selectedCity = null; // GPS overrides city dropdown
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not get GPS location. Please enable Location Services or choose a city below.',
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDetectingLocation = false;
        });
      }
    }
  }

  void _selectCity(String cityName) {
    final city = _sriLankaCities.firstWhere((c) => c['name'] == cityName);
    setState(() {
      _latitude = city['lat'] as double;
      _longitude = city['lon'] as double;
      _locationLabel = cityName;
      _selectedCity = cityName;
    });
  }

  // ───────────────────────────────────────────────────────
  // Image helpers
  // ───────────────────────────────────────────────────────

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select Image Source',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.blue),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.green),
                title: const Text('Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────
  // Analysis
  // ───────────────────────────────────────────────────────

  Future<void> _analyzeImage() async {
    if (_selectedImage == null || _latitude == null || !_hasVehicleDetails) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await _service.detectDamage(
        _selectedImage!,
        vehicleBrand: _brandController.text,
        vehicleModel: _modelController.text,
        vehicleYear: _yearController.text,
      );
      setState(() => _isLoading = false);

      if (result != null) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ResultScreen(
              result: result,
              imageFile: _selectedImage!,
              latitude: _latitude!,
              longitude: _longitude!,
              locationLabel: _locationLabel,
              vehicleBrand: _brandController.text.trim(),
              vehicleModel: _modelController.text.trim(),
              vehicleYear: _yearController.text.trim(),
            ),
          ),
        );
      } else {
        _showError('Failed to analyze image. Please try again.');
      }
    } on InvalidImageException catch (e) {
      setState(() => _isLoading = false);
      _showInvalidImageDialog(e.message);
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Error: $e');
    }
  }

  // ───────────────────────────────────────────────────────
  // Dialogs / snackbars
  // ───────────────────────────────────────────────────────

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showInvalidImageDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text(
              'Invalid Image',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'OK',
              style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────
  // Build
  // ───────────────────────────────────────────────────────

  /// Determine what the Analyze button should say based on missing prerequisites.
  String get _analyzeButtonLabel {
    if (_latitude == null && _selectedImage == null && !_hasVehicleDetails) {
      return 'Set Location, Photo, and Vehicle Details';
    }
    if (_latitude == null) return 'Set Location First';
    if (_selectedImage == null) return 'Select a Photo First';
    if (!_isVehicleYearValid) return 'Enter a Valid Vehicle Year';
    if (!_hasVehicleDetails) return 'Enter Vehicle Details First';
    return 'Analyze Damage';
  }

  bool get _isVehicleYearValid {
    final year = int.tryParse(_yearController.text.trim());
    final currentYear = DateTime.now().year;
    return year != null && year >= 1980 && year <= currentYear + 1;
  }

  bool get _hasVehicleDetails =>
      _brandController.text.trim().isNotEmpty &&
      _modelController.text.trim().isNotEmpty &&
      _yearController.text.trim().isNotEmpty &&
      _isVehicleYearValid;

  bool get _canAnalyze =>
      _selectedImage != null &&
      _latitude != null &&
      _hasVehicleDetails &&
      _serverConnected &&
      !_isLoading;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RoadResQ'),
        centerTitle: true,
        backgroundColor: Colors.blue,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Tooltip(
                message: _serverConnected ? 'Server connected' : 'Server offline',
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _serverConnected ? Colors.green : Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text('Analyzing damage…', style: TextStyle(fontSize: 16)),
                ],
              ),
            )
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Header ──────────────────────────────────────
                    const Text(
                      'Vehicle Damage Detection',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Set your location, add vehicle details, then upload a damage photo',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 24),

                    // ── Location Card ────────────────────────────────
                    _buildLocationCard(),

                    const SizedBox(height: 20),

                    // ── Image Card ───────────────────────────────────
                    _buildImageCard(),

                    const SizedBox(height: 20),

                    _buildVehicleDetailsCard(),

                    const SizedBox(height: 24),

                    // ── Analyze Button ───────────────────────────────
                    ElevatedButton.icon(
                      onPressed: _canAnalyze ? _analyzeImage : null,
                      icon: const Icon(Icons.analytics),
                      label: Text(_analyzeButtonLabel),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey[300],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),

                    // ── Server offline warning ───────────────────────
                    if (!_serverConnected) ...[
                      const SizedBox(height: 16),
                      _buildServerOfflineBanner(),
                    ],

                    const SizedBox(height: 24),

                    // ── How it works ─────────────────────────────────
                    _buildHowItWorks(),
                  ],
                ),
              ),
            ),
    );
  }

  // ───────────────────────────────────────────────────────
  // Sub-widgets
  // ───────────────────────────────────────────────────────

  Widget _buildLocationCard() {
    final bool locationSet = _latitude != null;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Title row ──────────────────────────────────
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: locationSet ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  'Your Location',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: locationSet ? Colors.black87 : Colors.grey[700],
                  ),
                ),
                const Spacer(),
                if (locationSet)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle,
                            color: Colors.green, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          _locationLabel,
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            if (locationSet) ...[
              const SizedBox(height: 6),
              Text(
                '${_latitude!.toStringAsFixed(4)}°N, ${_longitude!.toStringAsFixed(4)}°E',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],

            const SizedBox(height: 14),

            // ── GPS button ─────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isDetectingLocation ? null : _detectGpsLocation,
                icon: _isDetectingLocation
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.gps_fixed),
                label: Text(
                  _isDetectingLocation
                      ? 'Detecting…'
                      : locationSet && _selectedCity == null
                          ? 'Re-detect GPS'
                          : 'Detect My Location (GPS)',
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── OR divider ─────────────────────────────────
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    'OR choose city',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),

            const SizedBox(height: 12),

            // ── City dropdown ──────────────────────────────
            DropdownButtonFormField<String>(
              key: ValueKey(_selectedCity), // Rebuild when GPS clears selection
              initialValue: _selectedCity,
              decoration: InputDecoration(
                hintText: 'Select nearest city…',
                prefixIcon: const Icon(Icons.location_city),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              items: _sriLankaCities.map((city) {
                return DropdownMenuItem<String>(
                  value: city['name'] as String,
                  child: Text(city['name'] as String),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) _selectCity(value);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Title ──────────────────────────────────────
            Row(
              children: [
                Icon(
                  Icons.photo_camera,
                  color: _selectedImage != null ? Colors.blue : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  'Damage Photo',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _selectedImage != null
                        ? Colors.black87
                        : Colors.grey[700],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ── Image preview ──────────────────────────────
            Container(
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: _selectedImage != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        _selectedImage!,
                        fit: BoxFit.cover,
                      ),
                    )
                  : const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate,
                              size: 56, color: Colors.grey),
                          SizedBox(height: 8),
                          Text(
                            'No image selected',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
            ),

            const SizedBox(height: 14),

            // ── Pick image button ──────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showImageSourceDialog,
                icon: const Icon(Icons.image),
                label: Text(
                  _selectedImage == null ? 'Select Photo' : 'Change Photo',
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerOfflineBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        children: [
          const Icon(Icons.error, color: Colors.red),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Server Not Connected',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Make sure the claims API and the RoadResQ API are running.',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: _checkServerConnection,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Retry Connection'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleDetailsCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.directions_car,
                  color: _hasVehicleDetails ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  'Vehicle Details',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _hasVehicleDetails ? Colors.black87 : Colors.grey[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _brandController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Brand',
                hintText: 'e.g. Toyota',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _modelController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Model',
                hintText: 'e.g. Corolla',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _yearController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Year',
                hintText: 'e.g. 2017',
                border: const OutlineInputBorder(),
                errorText: _yearController.text.isEmpty || _isVehicleYearValid
                    ? null
                    : 'Enter a year between 1980 and ${DateTime.now().year + 1}',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHowItWorks() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue),
              SizedBox(width: 8),
              Text(
                'How it works',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          _StepRow(step: '1', text: 'Set your location via GPS or city picker'),
          _StepRow(step: '2', text: 'Enter vehicle brand, model, and year'),
          _StepRow(step: '3', text: 'Take or select a photo of the damage'),
          _StepRow(step: '4', text: 'Analyze for damage, price estimate, and roadside next steps'),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final String step;
  final String text;

  const _StepRow({required this.step, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: Colors.blue,
            child: Text(
              step,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
