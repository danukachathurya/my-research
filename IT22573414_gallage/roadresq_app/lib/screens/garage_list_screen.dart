import 'package:flutter/material.dart';
import '../models/garage_recommendation.dart';
import 'package:url_launcher/url_launcher.dart';

class GarageListScreen extends StatelessWidget {
  final List<GarageRecommendation> garages;
  final String damageType;

  const GarageListScreen({
    Key? key,
    required this.garages,
    required this.damageType,
  }) : super(key: key);

  Future<void> _openMaps(BuildContext context, double lat, double lon, String garageName) async {
    try {
      // Try multiple URL schemes for better compatibility
      final urls = [
        // Google Maps app (if installed)
        'google.navigation:q=$lat,$lon',
        // Google Maps web with directions
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lon',
        // Google Maps search (fallback)
        'https://www.google.com/maps/search/?api=1&query=$lat,$lon',
      ];

      bool launched = false;

      for (final urlString in urls) {
        final uri = Uri.parse(urlString);
        print('🗺️ Trying to launch: $urlString');

        try {
          if (await canLaunchUrl(uri)) {
            launched = await launchUrl(
              uri,
              mode: LaunchMode.externalApplication,
            );
            if (launched) {
              print('✅ Successfully launched maps with: $urlString');
              break;
            }
          }
        } catch (e) {
          print('⚠️ Failed to launch $urlString: $e');
          continue;
        }
      }

      if (!launched) {
        // Show error message to user
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not open maps. Coordinates: $lat, $lon'),
              backgroundColor: Colors.red,
              action: SnackBarAction(
                label: 'Copy',
                textColor: Colors.white,
                onPressed: () {
                  // Could add clipboard functionality here
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error opening maps: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _callPhone(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) return;
    final url = 'tel:$phoneNumber';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recommended Garages'),
        backgroundColor: Colors.blue,
      ),
      body: garages.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.location_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No garages found nearby',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Try enabling location services',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: garages.length,
              itemBuilder: (context, index) {
                final garage = garages[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    onTap: () => _openMaps(context, garage.latitude, garage.longitude, garage.name),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header with rank
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: _getRankColor(index),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '#${index + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      garage.name,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.star,
                                            color: Colors.amber, size: 16),
                                        const SizedBox(width: 4),
                                        Text(
                                          garage.rating.toStringAsFixed(1),
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        if (garage.distance != null) ...[
                                          const SizedBox(width: 12),
                                          const Icon(Icons.location_on,
                                              color: Colors.blue, size: 16),
                                          const SizedBox(width: 4),
                                          Text(
                                            garage.formattedDistance,
                                            style: const TextStyle(fontSize: 14),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Address
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.place, size: 16, color: Colors.grey),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  garage.address,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // Scores (if available)
                          if (garage.finalScore != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  if (garage.mlScore != null)
                                    _buildScoreChip(
                                      'ML Score',
                                      garage.mlScore!,
                                      Colors.purple,
                                    ),
                                  _buildScoreChip(
                                    'Match Score',
                                    garage.finalScore!,
                                    Colors.green,
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 12),

                          // Action buttons
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () =>
                                      _openMaps(context, garage.latitude, garage.longitude, garage.name),
                                  icon: const Icon(Icons.directions, size: 18),
                                  label: const Text('Directions'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                ),
                              ),
                              if (garage.phoneNumber != null) ...[
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _callPhone(garage.phoneNumber),
                                    icon: const Icon(Icons.phone, size: 18),
                                    label: const Text('Call'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      padding:
                                          const EdgeInsets.symmetric(vertical: 10),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildScoreChip(String label, double score, Color color) {
    return Column(
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
          '${(score * 100).toStringAsFixed(0)}%',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Color _getRankColor(int index) {
    switch (index) {
      case 0:
        return Colors.amber[700]!; // Gold
      case 1:
        return Colors.grey[600]!; // Silver
      case 2:
        return Colors.brown[400]!; // Bronze
      default:
        return Colors.blue;
    }
  }
}
