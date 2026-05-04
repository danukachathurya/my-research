import 'package:flutter/material.dart';

import '../models/assessment_metadata.dart';
import '../models/damage_detection_result.dart';
import '../utils/label_formatters.dart';

class RoadResqResultHeaderCard extends StatelessWidget {
  final DamageDetectionResult result;
  final IconData icon;

  const RoadResqResultHeaderCard({
    super.key,
    required this.result,
    required this.icon,
  });

  String get _severityLabel {
    final score = result.severityScore;
    if (score >= 4) {
      return 'High';
    }
    if (score >= 2) {
      return 'Medium';
    }
    return 'Low';
  }

  Color get _severityColor {
    switch (_severityLabel) {
      case 'High':
        return Colors.red;
      case 'Medium':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    final extraDamages = result.detectedDamages
        .where(
          (damage) => damage.toLowerCase() != result.damageType.toLowerCase(),
        )
        .map(humanizeRoadResqLabel)
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, size: 34, color: Colors.blue[700]),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Primary Damage Type',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                          color: Colors.blue[700],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        result.displayDamageType,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                RoadResqSectionChip(
                  text: 'Severity $_severityLabel',
                  color: _severityColor,
                ),
              ],
            ),
            if (extraDamages.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Additional detected damage types',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: extraDamages
                    .map(
                      (damage) => RoadResqSectionChip(
                        text: damage,
                        color: Colors.deepOrange,
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class RoadResqAssessmentSummaryCard extends StatelessWidget {
  final DamageDetectionResult result;
  final String vehicleDisplayName;
  final String locationLabel;
  final String statusLabel;
  final Color statusColor;

  const RoadResqAssessmentSummaryCard({
    super.key,
    required this.result,
    required this.vehicleDisplayName,
    required this.locationLabel,
    required this.statusLabel,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const RoadResqCardTitle(
              icon: Icons.assignment_outlined,
              color: Colors.blue,
              title: 'Assessment Summary',
            ),
            const SizedBox(height: 12),
            RoadResqInfoTile(
              label: 'Vehicle',
              value: vehicleDisplayName,
              icon: Icons.directions_car,
            ),
            const SizedBox(height: 10),
            RoadResqInfoTile(
              label: 'Affected Part',
              value: result.partMapping?.displayAffectedPart ?? 'Not mapped',
              icon: Icons.build_circle_outlined,
            ),
            if (locationLabel.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              RoadResqInfoTile(
                label: 'Incident Location',
                value: locationLabel,
                icon: Icons.place_outlined,
              ),
            ],
            if (result.hasClaimRecord) ...[
              const SizedBox(height: 10),
              RoadResqInfoTile(
                label: 'Claim Reference',
                value: result.claimId!,
                icon: Icons.confirmation_number_outlined,
              ),
              const SizedBox(height: 10),
              RoadResqInfoTile(
                label: 'Claim Status',
                value: statusLabel,
                icon: Icons.shield_outlined,
                color: statusColor,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class RoadResqPricingSummaryCard extends StatelessWidget {
  final PriceEstimation pricing;
  final String damageType;

  const RoadResqPricingSummaryCard({
    super.key,
    required this.pricing,
    required this.damageType,
  });

  String _currency(double amount) =>
      '${pricing.currency} ${amount.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const RoadResqCardTitle(
              icon: Icons.receipt_long,
              color: Colors.orange,
              title: 'Price Estimate',
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Estimate based on damage type',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                      color: Colors.orange[800],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    damageType,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            RoadResqInfoTile(
              label: 'Estimated Total',
              value: _currency(pricing.estimatedPrice),
              icon: Icons.attach_money,
              color: Colors.orange,
            ),
            if (pricing.breakdown.parts > 0) ...[
              const SizedBox(height: 10),
              RoadResqInfoTile(
                label: 'Parts & Materials',
                value: _currency(pricing.breakdown.parts),
                icon: Icons.build_circle,
                color: Colors.blue,
              ),
            ],
            if (pricing.breakdown.paint > 0) ...[
              const SizedBox(height: 10),
              RoadResqInfoTile(
                label: 'Paint & Finishing',
                value: _currency(pricing.breakdown.paint),
                icon: Icons.format_paint,
                color: Colors.purple,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class RoadResqInsuranceNotificationCard extends StatelessWidget {
  final String claimId;
  final String claimStatusLabel;
  final bool isSending;
  final VoidCallback? onNotify;

  const RoadResqInsuranceNotificationCard({
    super.key,
    required this.claimId,
    required this.claimStatusLabel,
    required this.isSending,
    required this.onNotify,
  });

  @override
  Widget build(BuildContext context) {
    final sentToInsurer =
        claimStatusLabel.trim().toLowerCase() == 'sent to insurer';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const RoadResqCardTitle(
              icon: Icons.policy_outlined,
              color: Colors.blue,
              title: 'Insurance',
            ),
            const SizedBox(height: 12),
            RoadResqInfoTile(
              label: 'Claim ID',
              value: claimId,
              icon: Icons.confirmation_number_outlined,
            ),
            if (claimStatusLabel.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              RoadResqSectionChip(
                text: claimStatusLabel,
                color: sentToInsurer ? Colors.green : Colors.blue,
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isSending ? null : onNotify,
                icon: isSending
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
                    : const Icon(Icons.send),
                label: Text(
                  isSending
                      ? 'Sending to Insurance Company...'
                      : 'Notify Insurance Company',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RoadResqInsuranceReadinessCard extends StatelessWidget {
  final PriceEstimation? pricing;
  final bool hasClaimRecord;
  final Map<String, dynamic> workflow;

  const RoadResqInsuranceReadinessCard({
    super.key,
    required this.pricing,
    required this.hasClaimRecord,
    required this.workflow,
  });

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class RoadResqUrgencyBanner extends StatelessWidget {
  final String urgency;
  final Color color;

  const RoadResqUrgencyBanner({
    super.key,
    required this.urgency,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color),
      ),
      child: Row(
        children: [
          Icon(Icons.warning, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text('Urgency: $urgency')),
        ],
      ),
    );
  }
}

class RoadResqInfoTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const RoadResqInfoTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (color ?? Colors.grey).withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: color ?? Colors.blue),
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
                  value,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RoadResqSectionChip extends StatelessWidget {
  final String text;
  final Color color;

  const RoadResqSectionChip({
    super.key,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(text),
      backgroundColor: color.withOpacity(0.08),
      side: BorderSide(color: color.withOpacity(0.25)),
    );
  }
}

class RoadResqCardTitle extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;

  const RoadResqCardTitle({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
