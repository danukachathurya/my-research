import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../auth/login_page.dart';
import 'final_report_page.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';

// ─── InsurerDashboardPage ─────────────────────────────────────────────────────
// Shows incoming claims for a selected insurance company.
// The insurer can confirm the AI-estimated cost or submit an adjusted cost.
// Requires baseApiUrl (e.g. "http://10.0.2.2:8000") passed from MainShell.
// ─────────────────────────────────────────────────────────────────────────────

class InsurerDashboardPage extends StatefulWidget {
  final String baseApiUrl;
  final String? assignedInsurerId;
  final String? assignedInsurerName;

  const InsurerDashboardPage({
    super.key,
    required this.baseApiUrl,
    this.assignedInsurerId,
    this.assignedInsurerName,
  });

  @override
  State<InsurerDashboardPage> createState() => _InsurerDashboardPageState();
}

class _InsurerDashboardPageState extends State<InsurerDashboardPage> {
  List<Map<String, dynamic>> _insurers = [];
  String? _selectedInsurerId;
  String? _selectedInsurerName;
  List<Map<String, dynamic>> _claims = [];
  bool _isLoadingInsurers = false;
  bool _isLoadingClaims = false;
  String? _errorMessage;

  bool get _isInsurerLocked =>
      widget.assignedInsurerId != null &&
      widget.assignedInsurerId!.trim().isNotEmpty;

  String get _dashboardTitle {
    final companyName =
        (_selectedInsurerName ?? widget.assignedInsurerName ?? '').trim();
    if (companyName.isEmpty) return 'Insurer Dashboard';
    return '$companyName Dashboard';
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  // ── URL helpers ──────────────────────────────────────────────────────────────
  String get _base {
    final b = widget.baseApiUrl;
    return b.endsWith('/') ? b.substring(0, b.length - 1) : b;
  }

  String get _insurersUrl => '$_base/insurers';

  String _claimsUrl(String insurerId) => '$_base/insurers/$insurerId/claims';

  String _decisionUrl(String claimId) => '$_base/claims/$claimId/decision';

  // ── Lifecycle ─────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadInsurers();
  }

  // ── Data fetching ─────────────────────────────────────────────────────────────
  Future<void> _loadInsurers() async {
    setState(() {
      _isLoadingInsurers = true;
      _errorMessage = null;
    });

    try {
      final response = await http
          .get(Uri.parse(_insurersUrl))
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is! List) {
          throw const FormatException('Expected JSON array');
        }

        final insurers = decoded
            .whereType<Map>()
            .map((i) => Map<String, dynamic>.from(i))
            .toList();

        setState(() {
          _insurers = insurers;
          _isLoadingInsurers = false;
          if (_isInsurerLocked) {
            final assignedId = widget.assignedInsurerId!.trim();
            final matching = insurers.where(
              (ins) => ins['id']?.toString() == assignedId,
            );
            if (matching.isNotEmpty) {
              final selected = matching.first;
              _selectedInsurerId = selected['id']?.toString();
              _selectedInsurerName = _getInsurerName(selected);
            } else {
              _selectedInsurerId = assignedId;
              _selectedInsurerName =
                  widget.assignedInsurerName?.trim().isNotEmpty == true
                  ? widget.assignedInsurerName!.trim()
                  : assignedId;
              _errorMessage = 'Assigned insurer was not found in insurer list.';
            }
          } else if (insurers.isNotEmpty) {
            _selectedInsurerId = insurers.first['id']?.toString();
            _selectedInsurerName = _getInsurerName(insurers.first);
          }
        });

        if (_selectedInsurerId != null) {
          await _loadClaims();
        }
      } else {
        setState(() {
          _errorMessage =
              'Failed to load insurers: HTTP ${response.statusCode}';
          _isLoadingInsurers = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (e is TimeoutException) {
          _errorMessage =
              'Could not reach server at $_base (timeout). '
              'Set API_URL in .env. On real phone use your PC LAN IP '
              '(example: http://192.168.1.10:8000/assess).';
        } else {
          _errorMessage = 'Network error: $e';
        }
        _isLoadingInsurers = false;
      });
      if (_isInsurerLocked && _selectedInsurerId == null) {
        setState(() {
          _selectedInsurerId = widget.assignedInsurerId!.trim();
          _selectedInsurerName =
              widget.assignedInsurerName?.trim().isNotEmpty == true
              ? widget.assignedInsurerName!.trim()
              : widget.assignedInsurerId!.trim();
        });
        await _loadClaims();
      }
    }
  }

  Future<void> _loadClaims() async {
    final id = _selectedInsurerId;
    if (id == null) return;

    setState(() {
      _isLoadingClaims = true;
      _errorMessage = null;
    });

    try {
      final response = await http
          .get(Uri.parse(_claimsUrl(id)))
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is! List) {
          throw const FormatException('Expected JSON array');
        }
        setState(() {
          _claims = decoded
              .whereType<Map>()
              .map((c) => Map<String, dynamic>.from(c))
              .toList();
          _isLoadingClaims = false;
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
          _isLoadingClaims = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (e is TimeoutException) {
          _errorMessage =
              'Could not reach server at $_base (timeout). '
              'Set API_URL in .env. On real phone use your PC LAN IP.';
        } else {
          _errorMessage = 'Network error: $e';
        }
        _isLoadingClaims = false;
      });
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────
  String _getInsurerName(Map<String, dynamic> insurer) {
    return (insurer['name'] ??
            insurer['company_name'] ??
            insurer['display_name'] ??
            insurer['id'] ??
            'Unknown')
        .toString();
  }

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

  double? _getAiPrice(Map<String, dynamic> claim) {
    try {
      final pe = claim['ai_result']?['price_estimation'];
      if (pe is Map) {
        final price = pe['estimated_price'];
        if (price != null) return (price as num).toDouble();
      }
    } catch (_) {}
    return null;
  }

  String _getCurrency(Map<String, dynamic> claim) {
    try {
      return claim['ai_result']?['price_estimation']?['currency']?.toString() ??
          'LKR';
    } catch (_) {
      return 'LKR';
    }
  }

  // ── Location helpers ──────────────────────────────────────────────────────────
  bool _hasLocation(Map<String, dynamic> claim) {
    final loc = claim['location'];
    if (loc is! Map) return false;
    return loc['latitude'] != null && loc['longitude'] != null;
  }

  String _locationLabel(Map<String, dynamic> claim) {
    final loc = claim['location'] as Map;
    final address = loc['address']?.toString() ?? '';
    if (address.isNotEmpty) return address;
    final lat = (loc['latitude'] as num).toStringAsFixed(5);
    final lng = (loc['longitude'] as num).toStringAsFixed(5);
    return '$lat, $lng';
  }

  void _copyMapsUrl(BuildContext context, Map<String, dynamic> claim) {
    final loc = claim['location'] as Map;
    final url = loc['maps_url']?.toString() ?? '';
    if (url.isEmpty) return;
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Maps link copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  String _getVehicleLabel(Map<String, dynamic> claim) {
    try {
      final v = claim['vehicle'];
      if (v is Map) {
        return '${v['brand'] ?? ''} ${v['model'] ?? ''} ${v['year'] ?? ''}'
            .trim();
      }
    } catch (_) {}
    return 'Unknown Vehicle';
  }

  // ── Decision badge ────────────────────────────────────────────────────────────
  Widget _buildDecisionBadge(Map<String, dynamic> claim) {
    final decision = claim['decision']?.toString();
    if (decision == 'confirmed') {
      return _badge('Confirmed', Colors.green[700]!, Colors.green[100]!);
    } else if (decision == 'adjusted') {
      return _badge('Adjusted', Colors.blue[700]!, Colors.blue[100]!);
    }
    return _badge('Pending', Colors.grey[600]!, Colors.grey[100]!);
  }

  Widget _badge(String label, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  // ── Claim card ────────────────────────────────────────────────────────────────
  Widget _buildClaimCard(Map<String, dynamic> claim) {
    final damages = _getDamages(claim);
    final aiPrice = _getAiPrice(claim);
    final currency = _getCurrency(claim);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showDecisionSheet(claim),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Vehicle + decision badge
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
                  _buildDecisionBadge(claim),
                ],
              ),
              const SizedBox(height: 6),
              // Date sent
              Row(
                children: [
                  Icon(Icons.send, size: 13, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Sent: ${_formatDate(claim['sent_at'])}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
              // Location row (shown only when lat/lng was captured)
              if (_hasLocation(claim)) ...[
                const SizedBox(height: 4),
                GestureDetector(
                  onLongPress: () => _copyMapsUrl(context, claim),
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 13,
                        color: Colors.blue[600],
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _locationLabel(claim),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[700],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
              // AI cost vs final cost
              Row(
                children: [
                  Icon(Icons.auto_awesome, size: 14, color: Colors.orange[700]),
                  const SizedBox(width: 4),
                  Text(
                    aiPrice != null
                        ? 'Predicted: $currency ${aiPrice.toStringAsFixed(0)}'
                        : 'Predicted: N/A',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange[800],
                    ),
                  ),
                  if (claim['final_cost'] != null) ...[
                    const SizedBox(width: 12),
                    Icon(
                      Icons.check_circle,
                      size: 14,
                      color: Colors.green[700],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Final: $currency ${(claim['final_cost'] as num).toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.green[800],
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
  }

  void _showDecisionSheet(Map<String, dynamic> claim) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _InsurerDecisionSheet(
        claim: claim,
        formatDate: _formatDate,
        decisionUrl: _decisionUrl(claim['id']?.toString() ?? ''),
        onDecisionSubmitted: _loadClaims,
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_dashboardTitle),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
        bottom: _insurers.isEmpty
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(52),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.business,
                        size: 18,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _isInsurerLocked
                            ? Text(
                                _selectedInsurerName ??
                                    _selectedInsurerId ??
                                    '',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              )
                            : DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedInsurerId,
                                  isExpanded: true,
                                  dropdownColor: Theme.of(
                                    context,
                                  ).colorScheme.inversePrimary,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                  icon: const Icon(
                                    Icons.arrow_drop_down,
                                    color: Colors.white,
                                  ),
                                  items: _insurers.map((ins) {
                                    return DropdownMenuItem<String>(
                                      value: ins['id']?.toString(),
                                      child: Text(_getInsurerName(ins)),
                                    );
                                  }).toList(),
                                  onChanged: (id) {
                                    if (id == null) return;
                                    setState(() {
                                      _selectedInsurerId = id;
                                      _selectedInsurerName = _getInsurerName(
                                        _insurers.firstWhere(
                                          (i) => i['id']?.toString() == id,
                                          orElse: () => {},
                                        ),
                                      );
                                    });
                                    _loadClaims();
                                  },
                                ),
                              ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        tooltip: 'Refresh',
                        onPressed: _isLoadingClaims ? null : _loadClaims,
                      ),
                    ],
                  ),
                ),
              ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final canUseAssignedInsurer = _selectedInsurerId != null;
    final isMappingWarning =
        _errorMessage == 'Assigned insurer was not found in insurer list.';

    if (_isLoadingInsurers) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null &&
        !isMappingWarning &&
        _insurers.isEmpty &&
        !canUseAssignedInsurer) {
      return _buildError(_errorMessage!, _loadInsurers);
    }

    if (_insurers.isEmpty && !canUseAssignedInsurer) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.business_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'No insurers found',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_isLoadingClaims) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && !isMappingWarning) {
      return _buildError(_errorMessage!, _loadClaims);
    }

    if (_claims.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              'No claims for ${_selectedInsurerName ?? 'this insurer'}',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            const Text(
              'Claims sent to this insurer will appear here.',
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

  Widget _buildError(String message, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red[700], fontSize: 14),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── InsurerDecisionSheet ─────────────────────────────────────────────────────
// Full claim detail + decision form shown in a draggable bottom sheet.
// StatefulWidget because it manages the cost field and submit-loading state.
// ─────────────────────────────────────────────────────────────────────────────

class _InsurerDecisionSheet extends StatefulWidget {
  final Map<String, dynamic> claim;
  final String Function(dynamic) formatDate;
  final String decisionUrl;
  final Future<void> Function() onDecisionSubmitted;

  const _InsurerDecisionSheet({
    required this.claim,
    required this.formatDate,
    required this.decisionUrl,
    required this.onDecisionSubmitted,
  });

  @override
  State<_InsurerDecisionSheet> createState() => _InsurerDecisionSheetState();
}

class _InsurerDecisionSheetState extends State<_InsurerDecisionSheet> {
  late final TextEditingController _costController;
  final TextEditingController _notesController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final aiPrice = _getAiPrice();
    _costController = TextEditingController(
      text: aiPrice != null ? aiPrice.toStringAsFixed(0) : '',
    );
  }

  @override
  void dispose() {
    _costController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────
  double? _getAiPrice() {
    try {
      final pe = widget.claim['ai_result']?['price_estimation'];
      if (pe is Map) {
        final price = pe['estimated_price'];
        if (price != null) return (price as num).toDouble();
      }
    } catch (_) {}
    return null;
  }

  String _getCurrency() {
    try {
      return widget.claim['ai_result']?['price_estimation']?['currency']
              ?.toString() ??
          'LKR';
    } catch (_) {
      return 'LKR';
    }
  }

  Future<void> _submitDecision(String decision) async {
    final rawCost = _costController.text.trim();
    final finalCost = double.tryParse(rawCost);
    if (finalCost == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid cost amount'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final response = await http
          .patch(
            Uri.parse(widget.decisionUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'final_cost': finalCost,
              'decision': decision,
              'notes': _notesController.text.trim(),
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        Navigator.of(context).pop();
        await widget.onDecisionSubmitted();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                decision == 'confirmed'
                    ? 'AI estimate confirmed successfully'
                    : 'Adjusted cost submitted successfully',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        String detail = 'HTTP ${response.statusCode}';
        try {
          final body = jsonDecode(response.body);
          if (body is Map && body['detail'] != null) {
            detail = body['detail'].toString();
          }
        } catch (_) {}
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to submit decision: $detail'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Network error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final claim = widget.claim;
    final aiResult = claim['ai_result'] as Map? ?? {};
    final dd = aiResult['damage_detection'] as Map? ?? {};
    final pe = aiResult['price_estimation'] as Map? ?? {};
    final vehicle = claim['vehicle'] as Map? ?? {};
    final breakdown = pe['breakdown'] as Map? ?? {};
    final estimatedPrice = pe['estimated_price'];
    final currency = _getCurrency();
    final claimId = claim['id']?.toString() ?? 'N/A';
    final damages =
        (dd['detected_damages'] as List?)?.map((d) => d.toString()).toList() ??
        [];
    final confidences = dd['confidences'] as Map? ?? {};
    final decision = claim['decision']?.toString();
    final alreadyDecided = decision != null;

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.5,
      maxChildSize: 0.95,
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
                  const Icon(Icons.rate_review_outlined, color: Colors.blue),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Review Claim',
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
                  // ── Claim summary ──────────────────────────────────────────
                  _ISection(
                    icon: Icons.confirmation_number_outlined,
                    iconColor: Colors.blue[700]!,
                    title: 'Claim ID',
                    child: SelectableText(
                      claimId,
                      style: const TextStyle(
                        fontSize: 13,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  _ISection(
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

                  _ISection(
                    icon: Icons.access_time,
                    iconColor: Colors.grey[700]!,
                    title: 'Received',
                    child: Text(
                      widget.formatDate(claim['sent_at']),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Detected damages ───────────────────────────────────────
                  _ISection(
                    icon: Icons.warning_amber,
                    iconColor: Colors.red[700]!,
                    title: 'Detected Damages',
                    child: damages.isEmpty
                        ? const Text(
                            'No damages detected',
                            style: TextStyle(color: Colors.green),
                          )
                        : Column(
                            children: damages.map((damage) {
                              final conf = confidences[damage];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.red[200]!),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      damage.replaceAll('_', ' ').toUpperCase(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    if (conf != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue[700],
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
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
                  const SizedBox(height: 12),

                  // ── AI cost breakdown ──────────────────────────────────────
                  _ISection(
                    icon: Icons.receipt_long,
                    iconColor: Colors.orange[700]!,
                    title: 'AI Cost Breakdown',
                    child: Column(
                      children: [
                        if (breakdown['parts'] != null)
                          _IBreakdownRow(
                            icon: Icons.build_circle,
                            iconColor: Colors.blue[700]!,
                            bgColor: Colors.blue[50]!,
                            label: 'Parts & Materials',
                            value:
                                '$currency ${(breakdown['parts'] as num).toStringAsFixed(2)}',
                          ),
                        if (breakdown['labor'] != null)
                          _IBreakdownRow(
                            icon: Icons.engineering,
                            iconColor: Colors.green[700]!,
                            bgColor: Colors.green[50]!,
                            label: 'Labor',
                            value:
                                '$currency ${(breakdown['labor'] as num).toStringAsFixed(2)}',
                          ),
                        if (breakdown['paint'] != null)
                          _IBreakdownRow(
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
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'AI TOTAL ESTIMATE',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: 13,
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
                  const SizedBox(height: 16),

                  // ── Decision section ───────────────────────────────────────
                  if (!alreadyDecided) ...[
                    _ISection(
                      icon: Icons.gavel,
                      iconColor: Colors.indigo[700]!,
                      title: 'Submit Decision',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Review the AI estimate and confirm or enter an adjusted cost.',
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                          const SizedBox(height: 12),
                          // Final cost field
                          TextFormField(
                            controller: _costController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Final Cost ($currency)',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.monetization_on),
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Notes field
                          TextFormField(
                            controller: _notesController,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Notes (optional)',
                              hintText:
                                  'Additional observations, adjustments...',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.notes),
                              alignLabelWithHint: true,
                            ),
                          ),
                          const SizedBox(height: 14),
                          // Action buttons
                          if (_isSubmitting)
                            const Center(child: CircularProgressIndicator())
                          else
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      // Pre-fill with AI estimate before confirming
                                      final aiPrice = _getAiPrice();
                                      if (aiPrice != null) {
                                        _costController.text = aiPrice
                                            .toStringAsFixed(0);
                                      }
                                      _submitDecision('confirmed');
                                    },
                                    icon: const Icon(
                                      Icons.check_circle_outline,
                                      color: Colors.green,
                                    ),
                                    label: const Text(
                                      'Confirm AI Estimate',
                                      style: TextStyle(color: Colors.green),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                        color: Colors.green,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () =>
                                        _submitDecision('adjusted'),
                                    icon: const Icon(
                                      Icons.edit,
                                      color: Colors.white,
                                    ),
                                    label: const Text(
                                      'Submit Adjusted',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue[700],
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // ── Decision already submitted ─────────────────────────
                    _ISection(
                      icon: Icons.gavel,
                      iconColor: decision == 'confirmed'
                          ? Colors.green[700]!
                          : Colors.blue[700]!,
                      title: 'Decision Submitted',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: decision == 'confirmed'
                                  ? Colors.green[50]
                                  : Colors.blue[50],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: decision == 'confirmed'
                                    ? Colors.green[300]!
                                    : Colors.blue[300]!,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  decision == 'confirmed'
                                      ? Icons.check_circle
                                      : Icons.edit_note,
                                  color: decision == 'confirmed'
                                      ? Colors.green[700]
                                      : Colors.blue[700],
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  decision == 'confirmed'
                                      ? 'AI Estimate Confirmed'
                                      : 'Cost Adjusted',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: decision == 'confirmed'
                                        ? Colors.green[800]
                                        : Colors.blue[800],
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (claim['final_cost'] != null)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'FINAL COST',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    '$currency ${(claim['final_cost'] as num).toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (claim['notes'] != null &&
                              claim['notes'].toString().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Notes: ${claim['notes']}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                          if (claim['decided_at'] != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Decided: ${widget.formatDate(claim['decided_at'])}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => FinalReportPage(
                                  claim: claim,
                                  formatDate: widget.formatDate,
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.summarize),
                            label: const Text('View Final Report'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo[700],
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(48),
                            ),
                          ),
                        ],
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
          Text(
            '$key: ',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          Text(value, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

// ─── Shared sub-widgets ────────────────────────────────────────────────────────

class _ISection extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget child;

  const _ISection({
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
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _IBreakdownRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String label;
  final String value;

  const _IBreakdownRow({
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
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
