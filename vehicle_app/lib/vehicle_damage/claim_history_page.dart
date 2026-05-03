import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';
import '../common/insurance_claim_service.dart';
import 'final_report_page.dart';

// ─── ClaimHistoryPage ─────────────────────────────────────────────────────────
// Displays a scrollable list of past damage assessment claims.
// Fetches data from GET /claims on the backend (no Firebase SDK needed).
// Requires baseApiUrl (e.g. "http://10.0.2.2:8000") passed from MainShell.
// ─────────────────────────────────────────────────────────────────────────────

class ClaimHistoryPage extends StatefulWidget {
  final String baseApiUrl;

  const ClaimHistoryPage({super.key, required this.baseApiUrl});

  @override
  State<ClaimHistoryPage> createState() => _ClaimHistoryPageState();
}

class _ClaimHistoryPageState extends State<ClaimHistoryPage> {
  final InsuranceClaimService _insuranceClaimService = InsuranceClaimService();
  StreamSubscription<User?>? _authSubscription;
  List<Map<String, dynamic>> _claims = [];
  bool _isLoading = false;
  String? _errorMessage;

  // ── URL helper ──────────────────────────────────────────────────────────────
  Uri _buildClaimsUri(String ownerUid) {
    var base = Uri.decodeFull(widget.baseApiUrl).trim();
    if (!base.contains('://')) {
      base = 'http://$base';
    }

    final parsed = Uri.tryParse(base);
    if (parsed == null || parsed.host.isEmpty) {
      throw const FormatException('Invalid API URL configuration');
    }

    return parsed.replace(
      pathSegments: [...parsed.pathSegments, 'claims'],
      queryParameters: {'owner_uid': ownerUid},
    );
  }

  // ── Lifecycle ────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((_) {
      if (!mounted) return;
      _loadClaims();
    });
    _loadClaims();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  // ── Data fetching ────────────────────────────────────────────────────────────
  Future<void> _loadClaims() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.uid.trim().isEmpty) {
        if (!mounted) return;
        setState(() {
          _claims = [];
          _isLoading = false;
        });
        return;
      }

      final response = await http
          .get(_buildClaimsUri(user.uid.trim()))
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is! List) {
          throw const FormatException('Expected a JSON array from /claims');
        }
        setState(() {
          _claims = decoded
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
          _isLoading = false;
        });
      } else {
        String detail = 'HTTP ${response.statusCode}';
        try {
          final body = jsonDecode(response.body);
          if (body is Map && body['detail'] != null) {
            detail = body['detail'].toString();
          }
        } catch (_) {}
        setState(() {
          _errorMessage = 'Failed to load claims: $detail';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Network error: $e';
        _isLoading = false;
      });
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  /// Formats an ISO 8601 timestamp from the backend into a readable local time.
  /// Python's isoformat() omits the trailing 'Z' — we append it to force UTC
  /// interpretation, then convert to the device's local timezone.
  String _formatDate(dynamic rawDate) {
    if (rawDate == null) return 'Unknown date';
    try {
      String s = rawDate.toString();
      if (!s.endsWith('Z') && !s.contains('+')) s = '${s}Z';
      final dt = DateTime.parse(s).toLocal();
      return DateFormat('MMM dd, yyyy – HH:mm').format(dt);
    } catch (_) {
      return rawDate.toString();
    }
  }

  List<String> _getDamages(Map<String, dynamic> claim) {
    try {
      final dd = claim['ai_result']?['damage_detection'];
      if (dd is Map) {
        final damages = dd['detected_damages'];
        if (damages is List) return damages.map((d) => d.toString()).toList();
      }
    } catch (_) {}
    return [];
  }

  String _getPrice(Map<String, dynamic> claim) {
    try {
      final pe = claim['ai_result']?['price_estimation'];
      if (pe is Map) {
        final price = pe['estimated_price'];
        final currency = pe['currency'] ?? 'LKR';
        if (price != null) {
          return '$currency ${(price as num).toStringAsFixed(0)}';
        }
      }
    } catch (_) {}
    return 'N/A';
  }

  String _getVehicleLabel(Map<String, dynamic> claim) {
    try {
      final v = claim['vehicle'];
      if (v is Map) {
        final brand = v['brand'] ?? '';
        final model = v['model'] ?? '';
        final year = v['year'] ?? '';
        return '$brand $model $year'.trim();
      }
    } catch (_) {}
    return 'Unknown Vehicle';
  }

  // ── Status badge ─────────────────────────────────────────────────────────────
  Widget _buildStatusBadge(String? status) {
    if (status == 'sent_to_insurer') {
      return _chip('Sent to insurer', Colors.green[100]!, Colors.green[400]!, Colors.green[800]!);
    } else if (status == 'decision_submitted') {
      return _chip('Decision Submitted', Colors.indigo[100]!, Colors.indigo[400]!, Colors.indigo[800]!);
    }
    return const SizedBox.shrink();
  }

  Widget _chip(String label, Color bg, Color border, Color text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: text),
      ),
    );
  }

  // ── Claim list card ───────────────────────────────────────────────────────────
  Widget _buildClaimCard(Map<String, dynamic> claim) {
    final damages = _getDamages(claim);
    final status = claim['status']?.toString();

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showDetailSheet(claim),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Vehicle label + status badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      _getVehicleLabel(claim),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildStatusBadge(status),
                ],
              ),
              const SizedBox(height: 6),
              // Date
              Row(
                children: [
                  Icon(Icons.access_time, size: 13, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(claim['created_at']),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Damage chips
              if (damages.isEmpty)
                Chip(
                  label: const Text(
                    'No damages detected',
                    style: TextStyle(fontSize: 11),
                  ),
                  backgroundColor: Colors.green[50],
                  side: BorderSide(color: Colors.green[200]!),
                  visualDensity: VisualDensity.compact,
                )
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: damages.map((d) {
                    return Chip(
                      label: Text(
                        d.replaceAll('_', ' ').toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      backgroundColor: Colors.red[600],
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 8),
              // Estimated price
              Row(
                children: [
                  Icon(Icons.monetization_on_outlined,
                      size: 14, color: Colors.orange[700]),
                  const SizedBox(width: 4),
                  Text(
                    'Est. repair: ${_getPrice(claim)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange[800],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetailSheet(Map<String, dynamic> claim) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _ClaimDetailSheet(
        claim: claim,
        formatDate: _formatDate,
        onOpenFinalReport: () => _openFinalReport(context, claim),
      ),
    );
  }

  Future<void> _openFinalReport(
    BuildContext context,
    Map<String, dynamic> claim,
  ) async {
    final latestClaim = await _loadLatestClaim(claim);

    if (!context.mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FinalReportPage(
          claim: latestClaim,
          formatDate: _formatDate,
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> _loadLatestClaim(
    Map<String, dynamic> claim,
  ) async {
    final claimId = claim['id']?.toString().trim();
    var latestClaim = claim;

    if (claimId != null && claimId.isNotEmpty) {
      try {
        latestClaim = await _insuranceClaimService.fetchClaim(claimId);
      } catch (_) {
        // Fall back to the currently loaded claim if refresh fails.
      }
    }

    return latestClaim;
  }

  // ── Build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Claim History'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadClaims,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red[700], fontSize: 14),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadClaims,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_claims.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'No claims yet',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            SizedBox(height: 4),
            Text(
              'Assessments you create will appear here.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadClaims,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _claims.length,
        itemBuilder: (context, index) => _buildClaimCard(_claims[index]),
      ),
    );
  }
}

// ─── ClaimDetailSheet ─────────────────────────────────────────────────────────
// Full claim details shown in a draggable bottom sheet.
// Extracted as a StatelessWidget to keep _ClaimHistoryPageState clean.
// ─────────────────────────────────────────────────────────────────────────────

class _ClaimDetailSheet extends StatelessWidget {
  final Map<String, dynamic> claim;
  final String Function(dynamic) formatDate;
  final VoidCallback onOpenFinalReport;

  const _ClaimDetailSheet({
    required this.claim,
    required this.formatDate,
    required this.onOpenFinalReport,
  });

  @override
  Widget build(BuildContext context) {
    final aiResult = claim['ai_result'] as Map? ?? {};
    final dd = aiResult['damage_detection'] as Map? ?? {};
    final pe = aiResult['price_estimation'] as Map? ?? {};
    final pm = aiResult['part_mapping'] as Map? ?? {};
    final vehicle = claim['vehicle'] as Map? ?? {};
    final status = claim['status']?.toString() ?? '';
    final claimId = claim['id']?.toString() ??
        aiResult['claim_id']?.toString() ??
        'N/A';

    final damages = (dd['detected_damages'] as List?)
            ?.map((d) => d.toString())
            .toList() ??
        [];
    final confidences = dd['confidences'] as Map? ?? {};
    final breakdown = pe['breakdown'] as Map? ?? {};
    final estimatedPrice = pe['estimated_price'];
    final currency = pe['currency'] ?? 'LKR';
    final affectedPart = pm['affected_part']?.toString() ?? '';

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.description_outlined, color: Colors.blue),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Claim Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Scrollable content
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  // Claim ID
                  _DetailSection(
                    icon: Icons.confirmation_number_outlined,
                    iconColor: Colors.blue[700]!,
                    title: 'Claim ID',
                    child: SelectableText(
                      claimId,
                      style: const TextStyle(
                          fontSize: 13, fontFamily: 'monospace'),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Vehicle
                  _DetailSection(
                    icon: Icons.directions_car,
                    iconColor: Colors.blue[700]!,
                    title: 'Vehicle',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _kv('Brand', vehicle['brand']?.toString() ?? 'N/A'),
                        _kv('Model', vehicle['model']?.toString() ?? 'N/A'),
                        _kv('Year', vehicle['year']?.toString() ?? 'N/A'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Date & status
                  _DetailSection(
                    icon: Icons.access_time,
                    iconColor: Colors.grey[700]!,
                    title: 'Submitted',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formatDate(claim['created_at']),
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 6),
                        _StatusBadgeLarge(status: status),
                        if (claim['sent_at'] != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Sent: ${formatDate(claim['sent_at'])}',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Detected damages
                  _DetailSection(
                    icon: Icons.warning_amber,
                    iconColor: Colors.red[700]!,
                    title: 'Detected Damages',
                    child: damages.isEmpty
                        ? const Text('No damages detected',
                            style: TextStyle(color: Colors.green))
                        : Column(
                            children: damages.map((damage) {
                              final conf = confidences[damage];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.red[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                      Border.all(color: Colors.red[200]!),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      damage
                                          .replaceAll('_', ' ')
                                          .toUpperCase(),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13),
                                    ),
                                    if (conf != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.blue[700],
                                          borderRadius:
                                              BorderRadius.circular(12),
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
                            }).toList(),
                          ),
                  ),

                  if (affectedPart.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.build,
                              size: 16, color: Colors.blue[700]),
                          const SizedBox(width: 6),
                          const Text('Affected Part: ',
                              style:
                                  TextStyle(fontWeight: FontWeight.w600)),
                          Text(
                            affectedPart
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
                  const SizedBox(height: 12),

                  // Cost breakdown
                  _DetailSection(
                    icon: Icons.receipt_long,
                    iconColor: Colors.orange[700]!,
                    title: 'Cost Breakdown',
                    child: (damages.isEmpty && estimatedPrice == null)
                        ? const Text('No repair costs')
                        : Column(
                            children: [
                              if (breakdown['parts'] != null)
                                _BreakdownRow(
                                  icon: Icons.build_circle,
                                  iconColor: Colors.blue[700]!,
                                  bgColor: Colors.blue[50]!,
                                  label: 'Parts & Materials',
                                  value:
                                      '$currency ${(breakdown['parts'] as num).toStringAsFixed(2)}',
                                ),
                              if (breakdown['paint'] != null)
                                _BreakdownRow(
                                  icon: Icons.format_paint,
                                  iconColor: Colors.purple[700]!,
                                  bgColor: Colors.purple[50]!,
                                  label: 'Paint & Finishing',
                                  value:
                                      '$currency ${(breakdown['paint'] as num).toStringAsFixed(2)}',
                                ),
                              if (estimatedPrice != null) ...[
                                const Divider(thickness: 1.5),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.orange[700],
                                    borderRadius:
                                        BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'TOTAL COST',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        '$currency ${(estimatedPrice as num).toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          fontSize: 18,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                  ),
                  if (claim['status'] == 'decision_submitted') ...[
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: onOpenFinalReport,
                      icon: const Icon(Icons.summarize),
                      label: const Text('View Final Report'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo[700],
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _kv(String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Text('$key: ',
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13)),
          Text(value, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

// ─── Shared sub-widgets ────────────────────────────────────────────────────────

class _DetailSection extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget child;

  const _DetailSection({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _StatusBadgeLarge extends StatelessWidget {
  final String status;

  const _StatusBadgeLarge({required this.status});

  @override
  Widget build(BuildContext context) {
    if (status == 'sent_to_insurer') {
      return _badge('Sent to insurer', Colors.green[100]!, Colors.green[400]!, Colors.green[800]!);
    } else if (status == 'decision_submitted') {
      return _badge('Decision Submitted', Colors.indigo[100]!, Colors.indigo[400]!, Colors.indigo[800]!);
    }
    return const SizedBox.shrink();
  }

  Widget _badge(String label, Color bg, Color border, Color text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: text),
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String label;
  final String value;

  const _BreakdownRow({
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
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 13)),
            ],
          ),
          Text(
            value,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
