import 'dart:io';
import 'package:flutter/material.dart';
import '../models/damage_detection_result.dart';
import '../models/garage_recommendation.dart';
import '../services/damage_detection_service.dart';
import 'garage_list_screen.dart';
import 'towing_screen.dart';
import 'spare_parts_bids_screen.dart';
import 'dart:math' as math;

class ResultScreen extends StatefulWidget {
  final DamageDetectionResult result;
  final File imageFile;
  final double latitude;
  final double longitude;
  final String locationLabel;

  const ResultScreen({
    Key? key,
    required this.result,
    required this.imageFile,
    required this.latitude,
    required this.longitude,
    this.locationLabel = 'Selected Location',
  }) : super(key: key);

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final DamageDetectionService _service = DamageDetectionService();
  bool _loadingGarages = false;

  /// Calculate distance between two coordinates using Haversine formula
  /// Returns distance in kilometers
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadiusKm = 6371.0;

    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);

    final double a = (math.sin(dLat / 2) * math.sin(dLat / 2)) +
        (math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2));

    final double c = 2 * math.asin(math.sqrt(a));
    return earthRadiusKm * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * math.pi / 180.0;
  }

  Future<void> _findNearbyGarages() async {
    setState(() {
      _loadingGarages = true;
    });

    try {
      // Use location passed from HomeScreen
      final double latitude = widget.latitude;
      final double longitude = widget.longitude;

      // Debug: Log the coordinates being used
      print('📍 Using location (${widget.locationLabel}): $latitude, $longitude');

      // Show location to user
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Searching near ${widget.locationLabel} (${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)})'),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 3),
        ),
      );

      // Fetch garage recommendations
      final garages = await _service.getGarageRecommendations(
        latitude: latitude,
        longitude: longitude,
        damageType: widget.result.damageType,
        maxResults: 10,
      );

      setState(() {
        _loadingGarages = false;
      });

      if (!mounted) return;

      if (garages.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No garages found nearby. Try a different location.'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        // Debug: Log first garage coordinates
        if (garages.isNotEmpty) {
          print('🏪 First garage: ${garages.first.name}');
          print('📍 Garage location: ${garages.first.latitude}, ${garages.first.longitude}');
          print('📍 User location: $latitude, $longitude');
        }

        // Calculate distances for all garages
        final garagesWithDistance = garages.map((garage) {
          final distance = _calculateDistance(
            latitude,
            longitude,
            garage.latitude,
            garage.longitude,
          );

          print('📏 ${garage.name}: ${distance.toStringAsFixed(2)} km (${garage.latitude}, ${garage.longitude})');

          // Create a new GarageRecommendation with distance
          return GarageRecommendation(
            name: garage.name,
            address: garage.address,
            rating: garage.rating,
            latitude: garage.latitude,
            longitude: garage.longitude,
            phoneNumber: garage.phoneNumber,
            distance: distance,
            mlScore: garage.mlScore,
            finalScore: garage.finalScore,
          );
        }).toList();

        // Sort by distance (nearest first)
        garagesWithDistance.sort((a, b) {
          if (a.distance == null && b.distance == null) return 0;
          if (a.distance == null) return 1;
          if (b.distance == null) return -1;
          return a.distance!.compareTo(b.distance!);
        });

        print('✅ Found ${garagesWithDistance.length} garages, sorted by distance');
        if (garagesWithDistance.isNotEmpty) {
          print('📍 Nearest garage: ${garagesWithDistance.first.name} - ${garagesWithDistance.first.formattedDistance}');
        }

        // Navigate to garage list screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GarageListScreen(
              garages: garagesWithDistance,
              damageType: widget.result.damageType,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _loadingGarages = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error finding garages: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Color _getUrgencyColor() {
    final urgency = widget.result.damageDetails.urgency.toLowerCase();
    if (urgency.contains('critical') || urgency.contains('immediate')) {
      return Colors.red;
    } else if (urgency.contains('high')) {
      return Colors.orange;
    } else if (urgency.contains('medium')) {
      return Colors.yellow[700]!;
    } else {
      return Colors.green;
    }
  }

  IconData _getDamageIcon() {
    switch (widget.result.damageType.toLowerCase()) {
      case 'dent':
        return Icons.circle_outlined;
      case 'scratch':
        return Icons.linear_scale;
      case 'crack':
        return Icons.broken_image;
      case 'glass shatter':
        return Icons.broken_image_outlined;
      case 'lamp broken':
        return Icons.lightbulb_outline;
      case 'tire flat':
        return Icons.tire_repair;
      default:
        return Icons.car_crash;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Damage Analysis'),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image display
            Container(
              height: 250,
              width: double.infinity,
              color: Colors.black,
              child: Image.file(
                widget.imageFile,
                fit: BoxFit.contain,
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Primary damage card
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Icon(
                            _getDamageIcon(),
                            size: 64,
                            color: Colors.blue,
                          ),
                          const SizedBox(height: 15),
                          Text(
                            widget.result.damageType.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildInfoChip(
                                'Confidence',
                                '${(widget.result.confidence * 100).toStringAsFixed(1)}%',
                                Colors.blue,
                              ),
                              _buildInfoChip(
                                'Severity',
                                '${widget.result.severityScore}/5',
                                Colors.orange,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Urgency banner
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: _getUrgencyColor().withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _getUrgencyColor()),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning, color: _getUrgencyColor()),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Urgency Level',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(widget.result.damageDetails.urgency),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Description section
                  _buildSection(
                    'Description',
                    Icons.description,
                    widget.result.damageDetails.description,
                  ),

                  const SizedBox(height: 20),

                  // What happened section
                  _buildSection(
                    'What Happened',
                    Icons.help_outline,
                    widget.result.damageDetails.whatHappened,
                  ),

                  const SizedBox(height: 20),

                  // Immediate actions
                  _buildListSection(
                    'Immediate Actions',
                    Icons.flash_on,
                    widget.result.damageDetails.immediateActions,
                    Colors.red,
                  ),

                  const SizedBox(height: 20),

                  // Repair options
                  _buildListSection(
                    'Repair Options',
                    Icons.build,
                    widget.result.damageDetails.repairOptions,
                    Colors.blue,
                  ),

                  const SizedBox(height: 20),

                  // Prevention tips
                  _buildSection(
                    'Prevention Tips',
                    Icons.lightbulb_outline,
                    widget.result.damageDetails.preventionTips,
                  ),

                  // Additional detected damages
                  if (widget.result.detectedDamages.length > 1) ...[
                    const SizedBox(height: 20),
                    _buildAdditionalDamages(),
                  ],

                  const SizedBox(height: 30),

                  // Find Garages button
                  ElevatedButton.icon(
                    onPressed: _loadingGarages ? null : _findNearbyGarages,
                    icon: _loadingGarages
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.location_on),
                    label: Text(_loadingGarages ? 'Finding Garages...' : 'Find Nearby Garages'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  const SizedBox(height: 15),

                  // Towing service button
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TowingScreen(
                            latitude: widget.latitude,
                            longitude: widget.longitude,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.local_shipping),
                    label: const Text('Book Towing Service'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      backgroundColor: Colors.orange[700],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  const SizedBox(height: 15),

                  // Spare parts bids button
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SparePartsBidsScreen(
                            damageType: widget.result.damageType,
                            vehicleMake: 'Toyota',
                            latitude: widget.latitude,
                            longitude: widget.longitude,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.build),
                    label: const Text('Get Spare Parts Bids'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      backgroundColor: Colors.purple[700],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  const SizedBox(height: 15),

                  // Back button
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Analyze Another Image'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
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

  Widget _buildInfoChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.blue),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            content,
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
        ),
      ],
    );
  }

  Widget _buildListSection(
    String title,
    IconData icon,
    List<String> items,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: items
                .asMap()
                .entries
                .map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${entry.key + 1}. ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            entry.value,
                            style: const TextStyle(height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalDamages() {
    final otherDamages = widget.result.detectedDamages
        .where((d) => d != widget.result.damageType)
        .toList();

    if (otherDamages.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange),
            SizedBox(width: 10),
            Text(
              'Additional Damages Detected',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: otherDamages
              .map(
                (damage) => Chip(
                  label: Text(damage.toUpperCase()),
                  backgroundColor: Colors.orange[100],
                  side: BorderSide(color: Colors.orange[300]!),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
