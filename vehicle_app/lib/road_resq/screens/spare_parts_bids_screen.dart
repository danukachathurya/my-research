import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/spare_part_bid.dart';
import '../services/spare_parts_service.dart';

class SparePartsBidsScreen extends StatefulWidget {
  final String damageType;
  final String vehicleMake;
  final String? vehicleModel;
  final int? vehicleYear;
  final double? latitude;
  final double? longitude;

  const SparePartsBidsScreen({
    Key? key,
    required this.damageType,
    this.vehicleMake = 'Toyota',
    this.vehicleModel,
    this.vehicleYear,
    this.latitude,
    this.longitude,
  }) : super(key: key);

  @override
  State<SparePartsBidsScreen> createState() => _SparePartsBidsScreenState();
}

class _SparePartsBidsScreenState extends State<SparePartsBidsScreen> {
  final SparePartsService _service = SparePartsService();
  SparePartsBidsResult? _result;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBids();
  }

  Future<void> _loadBids() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await _service.getSparepartsBids(
        widget.damageType,
        vehicleMake: widget.vehicleMake,
        vehicleModel: widget.vehicleModel,
        vehicleYear: widget.vehicleYear,
        userLatitude: widget.latitude,
        userLongitude: widget.longitude,
      );
      setState(() {
        _result = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load spare parts bids: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _callVendor(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch phone dialer')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.build, color: Colors.white, size: 22),
            SizedBox(width: 8),
            Text('Spare Parts Bids'),
          ],
        ),
        backgroundColor: Colors.purple[700],
        foregroundColor: Colors.white,
        centerTitle: false,
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.purple),
                  SizedBox(height: 16),
                  Text('Fetching vendor bids...'),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16)),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _loadBids,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final result = _result!;
    return Column(
      children: [
        // Header info card
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.purple[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.purple[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.directions_car, color: Colors.purple[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      result.vehicleInfo.isEmpty
                          ? widget.vehicleMake
                          : result.vehicleInfo,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange[700], size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Damage: ${result.damageType.toUpperCase()}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green[300]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.attach_money, color: Colors.green[700], size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Total Est: ${result.formattedTotalRange}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.green[800],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Parts list
        Expanded(
          child: result.partsNeeded.isEmpty
              ? const Center(child: Text('No parts data available.'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
                  itemCount: result.partsNeeded.length,
                  itemBuilder: (context, index) {
                    return _buildPartCard(result.partsNeeded[index]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPartCard(PartWithBids part) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        childrenPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.purple[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.settings, color: Colors.purple[700], size: 22),
        ),
        title: Text(
          part.partName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            part.formattedPriceRange,
            style: TextStyle(
              color: Colors.green[700],
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        trailing: Text(
          '${part.bids.length} bids',
          style: TextStyle(color: Colors.purple[700], fontSize: 12),
        ),
        children: [
          const Divider(height: 1),
          ...part.bids.asMap().entries.map((entry) {
            final i = entry.key;
            final bid = entry.value;
            final isLowest = i == 0;
            return _buildBidRow(bid, isLowest);
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildBidRow(SparePartBid bid, bool isLowest) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isLowest ? Colors.green[50] : Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isLowest ? Colors.green[200]! : Colors.grey[200]!,
        ),
      ),
      child: Row(
        children: [
          // Best badge
          if (isLowest)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.green[700],
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'BEST',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold),
              ),
            ),

          // Vendor info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bid.vendorName,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 12, color: Colors.grey[600]),
                    const SizedBox(width: 2),
                    Text(bid.city,
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(width: 10),
                    Icon(Icons.star, size: 12, color: Colors.amber[600]),
                    const SizedBox(width: 2),
                    Text(bid.rating.toStringAsFixed(1),
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 12, color: Colors.grey[600]),
                    const SizedBox(width: 2),
                    Text('${bid.leadTimeDays}d delivery',
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(width: 10),
                    Icon(Icons.verified_user, size: 12, color: Colors.grey[600]),
                    const SizedBox(width: 2),
                    Text('${bid.warrantyMonths}m warranty',
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),

          // Price + call button
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                bid.formattedPrice,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isLowest ? Colors.green[700] : Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 28,
                child: OutlinedButton.icon(
                  onPressed: () => _callVendor(bid.phone),
                  icon: const Icon(Icons.phone, size: 14),
                  label: const Text('Call', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.purple[700],
                    side: BorderSide(color: Colors.purple[700]!),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
