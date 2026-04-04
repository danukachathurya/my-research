import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ─── FinalReportPage ──────────────────────────────────────────────────────────
// A read-only report showing the full claim lifecycle after an insurer has
// submitted their decision. Accessible from both the insurer decision sheet
// and the customer's claim history detail sheet.
// ─────────────────────────────────────────────────────────────────────────────

class FinalReportPage extends StatelessWidget {
  final Map<String, dynamic> claim;
  final String Function(dynamic) formatDate;

  const FinalReportPage({
    super.key,
    required this.claim,
    required this.formatDate,
  });

  // ── Data helpers ──────────────────────────────────────────────────────────────
  Map<String, dynamic> get _aiResult =>
      (claim['ai_result'] as Map?)?.cast<String, dynamic>() ?? {};

  Map<String, dynamic> get _dd =>
      (_aiResult['damage_detection'] as Map?)?.cast<String, dynamic>() ?? {};

  Map<String, dynamic> get _pe =>
      (_aiResult['price_estimation'] as Map?)?.cast<String, dynamic>() ?? {};

  Map<String, dynamic> get _pm =>
      (_aiResult['part_mapping'] as Map?)?.cast<String, dynamic>() ?? {};

  Map<String, dynamic> get _vehicle =>
      (claim['vehicle'] as Map?)?.cast<String, dynamic>() ?? {};

  List<String> get _damages =>
      (_dd['detected_damages'] as List?)?.map((d) => d.toString()).toList() ??
      [];

  Map get _confidences => (_dd['confidences'] as Map?) ?? {};

  Map get _breakdown => (_pe['breakdown'] as Map?) ?? {};

  double? get _aiPrice {
    final p = _pe['estimated_price'];
    return p != null ? (p as num).toDouble() : null;
  }

  double? get _finalCost {
    final f = claim['final_cost'];
    return f != null ? (f as num).toDouble() : null;
  }

  String get _currency => _pe['currency']?.toString() ?? 'LKR';

  String get _claimId =>
      claim['id']?.toString() ?? _aiResult['claim_id']?.toString() ?? 'N/A';

  String get _decision => claim['decision']?.toString() ?? '';

  String get _vehicleLabel {
    final b = _vehicle['brand'] ?? '';
    final m = _vehicle['model'] ?? '';
    final y = _vehicle['year'] ?? '';
    return '$b $m $y'.trim().isEmpty ? 'Unknown Vehicle' : '$b $m $y'.trim();
  }

  String _fmt(num value) =>
      NumberFormat('#,##0.00', 'en_US').format(value);

  // ── Build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final now = DateFormat('MMM dd, yyyy – HH:mm').format(DateTime.now());

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Final Report'),
        backgroundColor: Colors.indigo[700],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ── Report header card ─────────────────────────────────────────
            _ReportCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.indigo[50],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.summarize,
                            color: Colors.indigo[700], size: 26),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Claim Assessment Report',
                              style: TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              _vehicleLabel,
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  _kv('Claim ID', _claimId, monospace: true),
                  _kv('Generated', now),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Vehicle details ────────────────────────────────────────────
            _ReportSection(
              icon: Icons.directions_car,
              iconColor: Colors.blue[700]!,
              title: 'Vehicle Details',
              child: Column(
                children: [
                  _kv('Brand', _vehicle['brand']?.toString() ?? 'N/A'),
                  _kv('Model', _vehicle['model']?.toString() ?? 'N/A'),
                  _kv('Year', _vehicle['year']?.toString() ?? 'N/A'),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Timeline ──────────────────────────────────────────────────
            _ReportSection(
              icon: Icons.timeline,
              iconColor: Colors.teal[700]!,
              title: 'Claim Timeline',
              child: Column(
                children: [
                  _TimelineEvent(
                    icon: Icons.upload_file,
                    color: Colors.blue[700]!,
                    label: 'Submitted',
                    date: formatDate(claim['created_at']),
                  ),
                  if (claim['sent_at'] != null)
                    _TimelineEvent(
                      icon: Icons.send,
                      color: Colors.orange[700]!,
                      label: 'Sent to insurer',
                      date: formatDate(claim['sent_at']),
                    ),
                  if (claim['decided_at'] != null)
                    _TimelineEvent(
                      icon: Icons.gavel,
                      color: Colors.green[700]!,
                      label: 'Decision submitted',
                      date: formatDate(claim['decided_at']),
                      isLast: true,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── AI damage assessment ───────────────────────────────────────
            _ReportSection(
              icon: Icons.auto_awesome,
              iconColor: Colors.orange[700]!,
              title: 'AI Damage Assessment',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_damages.isEmpty)
                    const Text('No damages detected',
                        style: TextStyle(color: Colors.green))
                  else
                    ..._damages.map((damage) {
                      final conf = _confidences[damage];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              damage.replaceAll('_', ' ').toUpperCase(),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            if (conf != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.blue[700],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${((conf as num) * 100).toStringAsFixed(1)}%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                  if (_pm['affected_part'] != null &&
                      _pm['affected_part'].toString().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.build, size: 15, color: Colors.blue[700]),
                          const SizedBox(width: 6),
                          const Text('Affected Part: ',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          Text(
                            _pm['affected_part']
                                .toString()
                                .replaceAll('_', ' ')
                                .toUpperCase(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Predicted cost breakdown ──────────────────────────────────
            _ReportSection(
              icon: Icons.receipt_long,
              iconColor: Colors.orange[700]!,
              title: 'Predicted Cost Breakdown',
              child: Column(
                children: [
                  if (_breakdown['parts'] != null)
                    _CostRow(
                      icon: Icons.build_circle,
                      iconColor: Colors.blue[700]!,
                      bgColor: Colors.blue[50]!,
                      label: 'Parts & Materials',
                      value:
                          '$_currency ${_fmt(_breakdown['parts'] as num)}',
                    ),
                  if (_breakdown['labor'] != null)
                    _CostRow(
                      icon: Icons.engineering,
                      iconColor: Colors.green[700]!,
                      bgColor: Colors.green[50]!,
                      label: 'Labor',
                      value:
                          '$_currency ${_fmt(_breakdown['labor'] as num)}',
                    ),
                  if (_breakdown['paint'] != null)
                    _CostRow(
                      icon: Icons.format_paint,
                      iconColor: Colors.purple[700]!,
                      bgColor: Colors.purple[50]!,
                      label: 'Paint & Finishing',
                      value:
                          '$_currency ${_fmt(_breakdown['paint'] as num)}',
                    ),
                  if (_aiPrice != null) ...[
                    const Divider(thickness: 1.5),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange[700],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'AI PREDICTED TOTAL',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 13),
                          ),
                          Text(
                            '$_currency ${_fmt(_aiPrice!)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 18),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Insurer decision ──────────────────────────────────────────
            _ReportSection(
              icon: Icons.gavel,
              iconColor: _decision == 'confirmed'
                  ? Colors.green[700]!
                  : Colors.blue[700]!,
              title: 'Insurer Decision',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _decision == 'confirmed'
                          ? Colors.green[50]
                          : Colors.blue[50],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _decision == 'confirmed'
                            ? Colors.green[300]!
                            : Colors.blue[300]!,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _decision == 'confirmed'
                              ? Icons.check_circle
                              : Icons.edit_note,
                          color: _decision == 'confirmed'
                              ? Colors.green[700]
                              : Colors.blue[700],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _decision == 'confirmed'
                              ? 'AI Estimate Confirmed'
                              : 'Cost Adjusted by Insurer',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _decision == 'confirmed'
                                ? Colors.green[800]
                                : Colors.blue[800],
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Final cost box
                  if (_finalCost != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'FINAL APPROVED COST',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[600],
                                letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$_currency ${_fmt(_finalCost!)}',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[900],
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Notes
                  if (claim['notes'] != null &&
                      claim['notes'].toString().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.notes,
                                  size: 15, color: Colors.amber[800]),
                              const SizedBox(width: 6),
                              Text(
                                'Insurer Notes',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Colors.amber[800]),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            claim['notes'].toString(),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Cost comparison (only if adjusted) ────────────────────────
            if (_decision == 'adjusted' &&
                _aiPrice != null &&
                _finalCost != null) ...[
              _ReportSection(
                icon: Icons.compare_arrows,
                iconColor: Colors.indigo[700]!,
                title: 'Cost Comparison',
                child: Column(
                  children: [
                    _CompareRow(
                      label: 'AI Predicted',
                      value: '$_currency ${_fmt(_aiPrice!)}',
                      valueColor: Colors.orange[800]!,
                    ),
                    _CompareRow(
                      label: 'Final (Insurer)',
                      value: '$_currency ${_fmt(_finalCost!)}',
                      valueColor: Colors.blue[800]!,
                    ),
                    const Divider(thickness: 1),
                    Builder(builder: (context) {
                      final diff = _finalCost! - _aiPrice!;
                      final isHigher = diff > 0;
                      final diffStr =
                          '${isHigher ? '+' : ''}$_currency ${_fmt(diff.abs())}';
                      return _CompareRow(
                        label: 'Difference',
                        value: isHigher ? '▲ $diffStr' : '▼ $diffStr',
                        valueColor:
                            isHigher ? Colors.red[700]! : Colors.green[700]!,
                        bold: true,
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // ── Footer ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'This report was generated by the Chathurya AI Assessment System.\n'
                'AI predictions are indicative only. Final cost is determined by the insurer.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11, color: Colors.grey[500], height: 1.5),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _kv(String key, String value, {bool monospace = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$key:',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Colors.grey[700]),
            ),
          ),
          Expanded(
            child: monospace
                ? SelectableText(
                    value,
                    style: const TextStyle(
                        fontSize: 12, fontFamily: 'monospace'),
                  )
                : Text(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// ─── Sub-widgets ───────────────────────────────────────────────────────────────

class _ReportCard extends StatelessWidget {
  final Widget child;

  const _ReportCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ReportSection extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget child;

  const _ReportSection({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return _ReportCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Divider(height: 20),
          child,
        ],
      ),
    );
  }
}

class _TimelineEvent extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String date;
  final bool isLast;

  const _TimelineEvent({
    required this.icon,
    required this.color,
    required this.label,
    required this.date,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icon + line
        Column(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 24,
                color: Colors.grey[300],
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 2),
                Text(date,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CostRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String label;
  final String value;

  const _CostRow({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: iconColor),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 13)),
            ],
          ),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}

class _CompareRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final bool bold;

  const _CompareRow({
    required this.label,
    required this.value,
    required this.valueColor,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: Colors.grey[800],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: bold ? 16 : 14,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
