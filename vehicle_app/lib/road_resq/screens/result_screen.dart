import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../common/claim_status.dart';
import '../../common/insurance_claim_service.dart';
import '../models/damage_detection_result.dart';
import '../models/garage_recommendation.dart';
import '../services/damage_detection_service.dart';
import '../widgets/assessment_result_sections.dart';
import 'garage_list_screen.dart';
import 'spare_parts_bids_screen.dart';
import 'towing_screen.dart';

class ResultScreen extends StatefulWidget {
  final DamageDetectionResult result;
  final File imageFile;
  final double latitude;
  final double longitude;
  final String locationLabel;
  final String vehicleBrand;
  final String vehicleModel;
  final String vehicleYear;

  const ResultScreen({
    Key? key,
    required this.result,
    required this.imageFile,
    required this.latitude,
    required this.longitude,
    this.locationLabel = 'Selected Location',
    required this.vehicleBrand,
    required this.vehicleModel,
    required this.vehicleYear,
  }) : super(key: key);

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final DamageDetectionService _service = DamageDetectionService();
  final InsuranceClaimService _insuranceClaimService = InsuranceClaimService();
  bool _loadingGarages = false;
  bool _sendingToInsurer = false;
  String? _claimStatusOverride;

  String? get _claimId {
    final claimId = widget.result.claimId?.trim();
    if (claimId == null || claimId.isEmpty) {
      return null;
    }
    return claimId;
  }

  String? get _effectiveClaimStatus {
    final override = _claimStatusOverride?.trim();
    if (override != null && override.isNotEmpty) {
      return override;
    }

    final initialStatus = widget.result.status?.trim();
    if (initialStatus != null && initialStatus.isNotEmpty) {
      return initialStatus;
    }

    return widget.result.hasClaimRecord ? 'ai_generated' : null;
  }

  bool get _claimAlreadySentToInsurer =>
      isClaimSentToInsurer(_effectiveClaimStatus);

  String get _claimStatusLabel => presentClaimStatusLabel(
    _effectiveClaimStatus,
    hasClaimRecord: widget.result.hasClaimRecord,
  );

  Color get _claimStatusColor {
    if (_claimAlreadySentToInsurer) {
      return Colors.green;
    }
    return Colors.lightBlue;
  }

  Color get _claimStatusTextColor {
    if (_claimAlreadySentToInsurer) {
      return Colors.green.shade700;
    }
    return Colors.lightBlue.shade700;
  }

  bool get _canNotifyInsurer =>
      _claimId != null && !_claimAlreadySentToInsurer && !_sendingToInsurer;

  String get _vehicleBrand =>
      widget.result.vehicle?.brand.trim().isNotEmpty == true
      ? widget.result.vehicle!.brand
      : widget.vehicleBrand;

  String get _vehicleModel =>
      widget.result.vehicle?.model.trim().isNotEmpty == true
      ? widget.result.vehicle!.model
      : widget.vehicleModel;

  String get _vehicleYear =>
      widget.result.vehicle?.year.trim().isNotEmpty == true
      ? widget.result.vehicle!.year
      : widget.vehicleYear;

  int? get _vehicleYearInt => int.tryParse(_vehicleYear);

  double _degreesToRadians(double degrees) => degrees * math.pi / 180.0;

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusKm = 6371.0;
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);
    final a =
        (math.sin(dLat / 2) * math.sin(dLat / 2)) +
        (math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2));
    final c = 2 * math.asin(math.sqrt(a));
    return earthRadiusKm * c;
  }

  Future<String?> _promptInsurerFromList(
    List<Map<String, dynamic>> insurers,
  ) async {
    if (insurers.isEmpty) {
      return null;
    }

    String selectedInsurerId = insurers.first['id'].toString();
    return showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Select Insurer'),
          content: DropdownButtonFormField<String>(
            initialValue: selectedInsurerId,
            decoration: const InputDecoration(
              labelText: 'Insurance Company',
              border: OutlineInputBorder(),
            ),
            items: insurers.map((insurer) {
              final id = insurer['id'].toString();
              return DropdownMenuItem<String>(
                value: id,
                child: Text(_insuranceClaimService.insurerDisplayName(insurer)),
              );
            }).toList(),
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setDialogState(() => selectedInsurerId = value);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(selectedInsurerId),
              child: const Text('Send'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _notifyInsurer() async {
    final claimId = _claimId;
    if (claimId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No claim ID found. Please assess damage first.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _sendingToInsurer = true);
    try {
      final insurers = await _insuranceClaimService.loadInsurers();
      if (insurers.isEmpty) {
        throw Exception(
          'No insurers available to notify. Ask admin to assign your insurer partner.',
        );
      }

      String? insurerId = await _insuranceClaimService
          .resolveCurrentUserInsurerId(insurers);
      insurerId ??= await _promptInsurerFromList(insurers);
      if (insurerId == null || insurerId.isEmpty) {
        return;
      }

      final damageImagePayload = await _insuranceClaimService
          .buildDamageImagePayload(widget.imageFile);

      await _insuranceClaimService.notifyInsurer(
        claimId: claimId,
        insurerId: insurerId,
        latitude: widget.latitude,
        longitude: widget.longitude,
        damageImage: damageImagePayload,
      );

      if (!mounted) {
        return;
      }

      setState(() => _claimStatusOverride = 'sent_to_insurer');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Claim sent to insurer successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to notify insurer: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _sendingToInsurer = false);
      }
    }
  }

  Future<void> _findNearbyGarages() async {
    setState(() => _loadingGarages = true);
    try {
      final garages = await _service.getGarageRecommendations(
        latitude: widget.latitude,
        longitude: widget.longitude,
        damageType: widget.result.damageType,
        maxResults: 10,
      );
      if (!mounted) return;

      if (garages.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No garages found nearby. Try a different location.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final garagesWithDistance =
          garages.map((garage) {
            final distance = _calculateDistance(
              widget.latitude,
              widget.longitude,
              garage.latitude,
              garage.longitude,
            );
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
          }).toList()..sort((left, right) {
            if (left.distance == null && right.distance == null) return 0;
            if (left.distance == null) return 1;
            if (right.distance == null) return -1;
            return left.distance!.compareTo(right.distance!);
          });

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GarageListScreen(
            garages: garagesWithDistance,
            damageType: widget.result.damageType,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error finding garages: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loadingGarages = false);
      }
    }
  }

  IconData _damageIcon() {
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

  List<Widget> _buildDetailSections() {
    final details = widget.result.damageDetails;
    final sections = <Widget>[];

    void appendSection(Widget? section) {
      if (section == null) {
        return;
      }
      if (sections.isNotEmpty) {
        sections.add(const SizedBox(height: 20));
      }
      sections.add(section);
    }

    appendSection(
      _buildSection('Description', Icons.description, details.description),
    );
    appendSection(
      _buildSection('What Happened', Icons.help_outline, details.whatHappened),
    );
    appendSection(
      _buildListSection(
        'Immediate Actions',
        Icons.flash_on,
        details.immediateActions,
        Colors.red,
      ),
    );
    appendSection(
      _buildListSection(
        'Repair Options',
        Icons.build,
        details.repairOptions,
        Colors.blue,
      ),
    );
    appendSection(
      _buildSection(
        'Prevention Tips',
        Icons.lightbulb_outline,
        details.preventionTips,
      ),
    );

    return sections;
  }

  Widget? _buildSection(String title, IconData icon, String content) {
    final text = content.trim();
    if (text.isEmpty) {
      return null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.blue),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
          child: Text(text, style: const TextStyle(fontSize: 14, height: 1.5)),
        ),
      ],
    );
  }

  Widget? _buildListSection(
    String title,
    IconData icon,
    List<String> items,
    Color color,
  ) {
    final visibleItems = items
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    if (visibleItems.isEmpty) {
      return null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
            children: visibleItems
                .asMap()
                .entries
                .map(
                  (entry) => Padding(
                    padding: EdgeInsets.only(
                      bottom: entry.key == visibleItems.length - 1 ? 0 : 8,
                    ),
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

  Widget? _buildInfoRow(String label, String value, IconData icon) {
    final text = value.trim();
    if (text.isEmpty) {
      return null;
    }

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
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
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

  Widget _buildActionButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color backgroundColor,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 15),
      ),
    );
  }

  Widget _buildInsuranceSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Insurance',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Claim ID: $_claimId',
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _claimStatusColor.withOpacity(0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _claimStatusLabel,
                style: TextStyle(
                  color: _claimStatusTextColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _canNotifyInsurer ? _notifyInsurer : null,
                icon: _sendingToInsurer
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send, size: 20),
                label: Text(
                  _claimAlreadySentToInsurer
                      ? 'Insurance Company Notified'
                      : 'Notify Insurance Company',
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  foregroundColor: Colors.blueGrey[700],
                  side: BorderSide(color: Colors.blueGrey.withOpacity(0.18)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
            SizedBox(
              height: 250,
              child: Image.file(widget.imageFile, fit: BoxFit.cover),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RoadResqResultHeaderCard(
                    result: widget.result,
                    icon: _damageIcon(),
                  ),
                  const SizedBox(height: 16),
                  if (widget.result.hasPriceEstimate) ...[
                    RoadResqPricingSummaryCard(
                      pricing: widget.result.priceEstimation!,
                      damageType: widget.result.displayDamageType,
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (widget.result.hasClaimRecord) ...[
                    _buildInsuranceSection(),
                    const SizedBox(height: 16),
                  ],

                  ..._buildDetailSections(),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _loadingGarages ? null : _findNearbyGarages,
                    icon: _loadingGarages
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Icon(Icons.location_on),
                    label: Text(
                      _loadingGarages
                          ? 'Finding Garages...'
                          : 'Find Nearby Garages',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildActionButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TowingScreen(
                          latitude: widget.latitude,
                          longitude: widget.longitude,
                        ),
                      ),
                    ),
                    icon: Icons.local_shipping,
                    label: 'Book Towing Service',
                    backgroundColor: Colors.orange[700]!,
                  ),
                  const SizedBox(height: 12),
                  _buildActionButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SparePartsBidsScreen(
                          damageType: widget.result.damageType,
                          vehicleMake: _vehicleBrand,
                          vehicleModel: _vehicleModel.isEmpty
                              ? null
                              : _vehicleModel,
                          vehicleYear: _vehicleYearInt,
                          latitude: widget.latitude,
                          longitude: widget.longitude,
                        ),
                      ),
                    ),
                    icon: Icons.build,
                    label: 'Get Spare Parts Bids',
                    backgroundColor: Colors.purple[700]!,
                  ),
                  const SizedBox(height: 12),
                  _buildActionButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icons.arrow_back,
                    label: 'Analyze Another Image',
                    backgroundColor: Colors.blue,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
