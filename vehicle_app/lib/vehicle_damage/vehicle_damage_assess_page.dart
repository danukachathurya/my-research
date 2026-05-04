import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'dart:io';
import '../common/api_config.dart';
import '../common/claim_status.dart';
import 'utils/image_processor.dart'; 
import 'insurer_dashboard_page.dart'; 

class VehicleDamageAssessPage extends StatefulWidget {
  const VehicleDamageAssessPage({super.key});

  @override
  State<VehicleDamageAssessPage> createState() =>
      _VehicleDamageAssessPageState();
}

class _VehicleDamageAssessPageState extends State<VehicleDamageAssessPage> {
  final ImagePicker _picker = ImagePicker();
  List<File> _selectedImages = [];
  bool _isLoading = false;
  Map<String, dynamic>? _assessmentResult;

  final TextEditingController _brandController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();

  String get apiUrl => ApiConfig.assessUrl;

  String _notifyUrlForClaim(String claimId) {
    final uri = Uri.parse(apiUrl);
    final baseSegments = List<String>.from(uri.pathSegments);
    if (baseSegments.isNotEmpty && baseSegments.last == 'assess') {
      baseSegments.removeLast();
    }
    return uri
        .replace(pathSegments: [...baseSegments, 'claims', claimId, 'notify'])
        .toString();
  }

  String _insurersUrl() {
    final uri = Uri.parse(apiUrl);
    final baseSegments = List<String>.from(uri.pathSegments);
    if (baseSegments.isNotEmpty && baseSegments.last == 'assess') {
      baseSegments.removeLast();
    }
    return uri.replace(pathSegments: [...baseSegments, 'insurers']).toString();
  }

  Future<List<Map<String, dynamic>>> _fetchInsurers() async {
    final response = await http.get(Uri.parse(_insurersUrl()));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load insurers: ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) throw Exception('Invalid insurers response format');
    return decoded
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((item) => item['id'] != null && item['id'].toString().isNotEmpty)
        .toList();
  }

  String _insurerDisplayName(Map<String, dynamic> insurer) {
    return (insurer['name'] ??
            insurer['company_name'] ??
            insurer['display_name'] ??
            insurer['companyName'] ??
            insurer['id'] ??
            '')
        .toString()
        .trim();
  }

  String? _findInsurerIdByCompanyName(
    String? companyName,
    List<Map<String, dynamic>> insurers,
  ) {
    final needle = companyName?.trim().toLowerCase();
    if (needle == null || needle.isEmpty) return null;

    for (final insurer in insurers) {
      final name = _insurerDisplayName(insurer).toLowerCase();
      if (name == needle) {
        final id = insurer['id']?.toString().trim();
        if (id != null && id.isNotEmpty) return id;
      }
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> _fetchInsurersFromFirestore() async {
    final docs = await FirebaseFirestore.instance
        .collection('insurer_partners')
        .get();

    return docs.docs
        .map((d) {
          final data = d.data();
          final id = (data['insurerId'] ?? d.id).toString().trim();
          final name = (data['companyName'] ?? '').toString().trim();
          if (id.isEmpty || name.isEmpty) return null;
          return <String, dynamic>{'id': id, 'name': name};
        })
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  Future<String?> _resolveCurrentUserInsurerId(
    List<Map<String, dynamic>> insurers,
  ) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return null;

    try {
      final profile = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final data = profile.data() ?? <String, dynamic>{};
      final preferred = data['preferredInsurerId']?.toString().trim();
      if (preferred != null && preferred.isNotEmpty) return preferred;

      final preferredCompany = data['preferredInsurerName']?.toString().trim();
      final preferredCompanyId = _findInsurerIdByCompanyName(
        preferredCompany,
        insurers,
      );
      if (preferredCompanyId != null && preferredCompanyId.isNotEmpty) {
        return preferredCompanyId;
      }

      final assigned = data['assignedInsurerId']?.toString().trim();
      if (assigned != null && assigned.isNotEmpty) return assigned;

      final company = data['insurerCompanyName']?.toString().trim();
      return _findInsurerIdByCompanyName(company, insurers);
    } catch (_) {
      return null;
    }
  }

  Future<String?> _promptInsurerFromList(
    List<Map<String, dynamic>> insurers,
  ) async {
    if (insurers.isEmpty) return null;
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
              final displayName =
                  (insurer['name'] ??
                          insurer['company_name'] ??
                          insurer['display_name'] ??
                          id)
                      .toString();
              return DropdownMenuItem<String>(
                value: id,
                child: Text(displayName),
              );
            }).toList(),
            onChanged: (value) {
              if (value == null) return;
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

  Future<Position?> _getLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location services are disabled. Claim will be sent without location.',
              ),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location permission denied. Claim will be sent without location.',
              ),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Location unavailable ($e). Claim will be sent without location.',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return null;
    }
  }

  Future<void> _notifyInsurer() async {
    final claimId = _assessmentResult?['claim_id']?.toString();
    if (claimId == null || claimId.isEmpty) {
      _showError('No claim_id found. Please assess damage first.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      List<Map<String, dynamic>> insurers = [];
      try {
        insurers = await _fetchInsurers();
      } catch (_) {
        // Fallback to Firestore list below.
      }

      if (insurers.isEmpty) {
        try {
          insurers = await _fetchInsurersFromFirestore();
        } catch (_) {
          // Keep empty if Firestore list cannot be read.
        }
      }

      String? insurerId = await _resolveCurrentUserInsurerId(insurers);

      if (insurerId == null || insurerId.isEmpty) {
        if (insurers.isEmpty) {
          _showError(
            'No insurers available to notify. Ask admin to assign your insurer partner.',
          );
          return;
        }
        insurerId = await _promptInsurerFromList(insurers);
        if (insurerId == null || insurerId.isEmpty) return;
      }

      final position = await _getLocation();
      final Map<String, dynamic> requestBody = {'insurer_id': insurerId};
      if (position != null) {
        requestBody['latitude'] = position.latitude;
        requestBody['longitude'] = position.longitude;
      }

      final response = await http.post(
        Uri.parse(_notifyUrlForClaim(claimId)),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        setState(() => _assessmentResult?['status'] = 'sent_to_insurer');
        if (!mounted) return;
        final locationNote = position != null
            ? ' (with location)'
            : ' (no location attached)';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Claim sent to insurer successfully$locationNote'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        String message = 'Notify failed: ${response.statusCode}';
        try {
          final body = jsonDecode(response.body);
          if (body is Map<String, dynamic> && body['detail'] != null) {
            message = '$message - ${body['detail']}';
          }
        } catch (_) {}
        _showError(message);
      }
    } catch (e) {
      _showError('Failed to notify insurer: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _brandController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null) {
        setState(() {
          _selectedImages.add(File(image.path));
          _assessmentResult = null;
        });
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
    }
  }

  Future<void> _pickMultipleImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage();
      if (images.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(images.map((img) => File(img.path)).toList());
          _assessmentResult = null;
        });
      }
    } catch (e) {
      _showError('Failed to pick images: $e');
    }
  }

  void _removeImage(int index) =>
      setState(() => _selectedImages.removeAt(index));

  void _clearAllImages() => setState(() {
    _selectedImages.clear();
    _assessmentResult = null;
  });

  Future<void> _assessDamage() async {
    if (_selectedImages.isEmpty) {
      _showError('Please select at least one image');
      return;
    }
    if (_brandController.text.isEmpty ||
        _modelController.text.isEmpty ||
        _yearController.text.isEmpty) {
      _showError('Please fill in all vehicle details');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final request = AssessmentRequest(
        imagePaths: _selectedImages.map((img) => img.path).toList(),
        vehicleBrand: _brandController.text,
        vehicleModel: _modelController.text,
        vehicleYear: _yearController.text,
        apiUrl: apiUrl,
        useAi: true,
        userUid: FirebaseAuth.instance.currentUser?.uid,
      );
      final result = await processDamageAssessment(request);
      setState(() {
        _assessmentResult = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorDialog('Error: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showErrorDialog(String message) {
    String displayMessage = message;
    final detailMatch = RegExp(
      r'\d{3} - (.+)$',
      dotAll: true,
    ).firstMatch(message);
    if (detailMatch != null) {
      displayMessage = detailMatch.group(1)!.trim();
    } else if (message.startsWith('Error: Exception: ')) {
      displayMessage = message.replaceFirst('Error: Exception: ', '').trim();
    } else if (message.startsWith('Error: ')) {
      displayMessage = message.replaceFirst('Error: ', '').trim();
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('Invalid Image'),
          ],
        ),
        content: Text(displayMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _cleanMarkdown(String text) => text
      .replaceAll('**', '')
      .replaceAll('*', '')
      .replaceAll('###', '')
      .replaceAll('##', '')
      .replaceAll('#', '')
      .replaceAll('`', '')
      .trim();

  // ── UI ──────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehicle Damage Assessment'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Image picker card ────────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Vehicle Images (${_selectedImages.length})',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_selectedImages.isNotEmpty)
                          TextButton.icon(
                            onPressed: _clearAllImages,
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text('Clear All'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_selectedImages.isEmpty)
                      Container(
                        height: 180,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate,
                                size: 60,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Add vehicle photos',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                        itemCount: _selectedImages.length,
                        itemBuilder: (context, index) => Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                _selectedImages[index],
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => _removeImage(index),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _pickImage(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Camera'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _pickMultipleImages,
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Gallery'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Vehicle details form ─────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Vehicle Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _brandController,
                      decoration: const InputDecoration(
                        labelText: 'Brand',
                        hintText: 'e.g., Toyota',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _modelController,
                      decoration: const InputDecoration(
                        labelText: 'Model',
                        hintText: 'e.g., Corolla',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _yearController,
                      decoration: const InputDecoration(
                        labelText: 'Year',
                        hintText: 'e.g., 2016',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Assess button ────────────────────────────────────────────
            ElevatedButton(
              onPressed: _isLoading ? null : _assessDamage,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.blue[300],
              ),
              child: _isLoading
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Processing ${_selectedImages.length} '
                          'image${_selectedImages.length > 1 ? 's' : ''}...',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    )
                  : const Text('Assess Damage', style: TextStyle(fontSize: 16)),
            ),

            const SizedBox(height: 16),

            if (_assessmentResult != null) _buildResultsCard(),
          ],
        ),
      ),
    );
  }

  // ── Results card (unchanged from app 1) ────────────────────────────────────
  Widget _buildResultsCard() {
    final claimId = _assessmentResult!['claim_id']?.toString();
    final claimStatus = _assessmentResult!['status']?.toString();
    final damageDetection = _assessmentResult!['damage_detection'];
    final priceEstimation = _assessmentResult!['price_estimation'];
    final partMapping = _assessmentResult!['part_mapping'];
    final aiValidation = _assessmentResult!['ai_validation'];

    return Column(
      children: [
        // Header
        Card(
          elevation: 4,
          color: Colors.green[700],
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.white, size: 32),
                SizedBox(width: 12),
                Text(
                  'Assessment Complete',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Detected Damages
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.red[700], size: 24),
                    const SizedBox(width: 8),
                    const Text(
                      'Detected Damages',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (damageDetection['detected_damages'].isEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check, color: Colors.green[700]),
                        const SizedBox(width: 8),
                        const Text('No damages detected'),
                      ],
                    ),
                  )
                else
                  ...List.generate(damageDetection['detected_damages'].length, (
                    index,
                  ) {
                    final damage = damageDetection['detected_damages'][index];
                    final confidence = damageDetection['confidences'][damage];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(
                                  Icons.circle,
                                  size: 8,
                                  color: Colors.red[700],
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    damage.replaceAll('_', ' ').toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue[700],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${(confidence * 100).toStringAsFixed(1)}%',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.build, color: Colors.blue[700], size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Affected Part: ',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        partMapping['affected_part']
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
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Cost Breakdown
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.receipt_long,
                      color: Colors.orange[700],
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Cost Breakdown',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (damageDetection['detected_damages'].isEmpty)
                  const Text('No repair costs')
                else
                  Column(
                    children: [
                      if (priceEstimation['breakdown'] != null &&
                          priceEstimation['breakdown'] is Map &&
                          priceEstimation['breakdown'].isNotEmpty) ...[
                        if (priceEstimation['breakdown']['parts'] != null)
                          _costRow(
                            Icons.build_circle,
                            Colors.blue[700]!,
                            Colors.blue[50]!,
                            'Parts & Materials',
                            priceEstimation['currency'],
                            priceEstimation['breakdown']['parts'],
                          ),
                        if (priceEstimation['breakdown']['paint'] != null)
                          _costRow(
                            Icons.format_paint,
                            Colors.purple[700]!,
                            Colors.purple[50]!,
                            'Paint & Finishing',
                            priceEstimation['currency'],
                            priceEstimation['breakdown']['paint'],
                          ),
                      ] else ...[
                        ...List.generate(
                          damageDetection['detected_damages'].length,
                          (index) {
                            final damage =
                                damageDetection['detected_damages'][index];
                            final cost =
                                priceEstimation['estimated_price'] /
                                damageDetection['detected_damages'].length;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    damage.replaceAll('_', ' ').toUpperCase() +
                                        ' repair',
                                  ),
                                  Text(
                                    '${priceEstimation['currency']} ${cost.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                      const Divider(thickness: 2),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange[700],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'TOTAL COST',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              '${priceEstimation['currency']} '
                              '${priceEstimation['estimated_price'].toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),

        // AI Analysis
        if (aiValidation != null) ...[
          const SizedBox(height: 12),
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.analytics,
                        color: Colors.purple[700],
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Analysis',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (aiValidation['damage_validation'] != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.purple[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _cleanMarkdown(
                          aiValidation['damage_validation']['analysis'] ??
                              'N/A',
                        ),
                        style: const TextStyle(fontSize: 14, height: 1.5),
                      ),
                    ),
                  if (aiValidation['price_explanation'] != null) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Price Explanation:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _cleanMarkdown(
                          aiValidation['price_explanation']['explanation'] ??
                              'N/A',
                        ),
                        style: const TextStyle(fontSize: 14, height: 1.5),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],

        // Insurance / notify
        const SizedBox(height: 12),
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Insurance',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('Claim ID: ${claimId ?? "N/A"}'),
                if (claimStatus != null && claimStatus.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: claimStatus == 'sent_to_insurer'
                          ? Colors.green[100]
                          : Colors.blue[100],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      claimStatus == 'sent_to_insurer'
                          ? 'Sent to insurer'
                          : presentClaimStatusLabel(
                              claimStatus,
                              hasClaimRecord:
                                  claimId != null && claimId.isNotEmpty,
                            ),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: claimStatus == 'sent_to_insurer'
                            ? Colors.green[800]
                            : Colors.blue[800],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed:
                        (_isLoading || claimId == null || claimId.isEmpty)
                        ? null
                        : _notifyInsurer,
                    icon: const Icon(Icons.send),
                    label: const Text('Notify Insurance Company'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _costRow(
    IconData icon,
    Color iconColor,
    Color bgColor,
    String label,
    String currency,
    num amount,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontSize: 14)),
            ],
          ),
          Text(
            '$currency ${amount.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

