import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../common/api_config.dart';
import '../common/claim_status.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'dart:io';

import 'utils/image_processor.dart';
import 'claim_history_page.dart';
import 'insurer_dashboard_page.dart';

class VehicleDamageModule extends StatelessWidget {
  const VehicleDamageModule({super.key});

  @override
  Widget build(BuildContext context) {
    return const VehicleDamageApp();
  }
}
 
class VehicleDamageApp extends StatelessWidget {
  const VehicleDamageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoleSelectionPage();
  }
}

// ─── Role Selection (Home Screen) ────────────────────────────────────────────

class RoleSelectionPage extends StatelessWidget {
  const RoleSelectionPage({super.key});

  String get _baseApiUrl => ApiConfig.baseUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
      ),
      body: Stack(
        children: [
          // ── Full-screen gradient background ───────────────────────────
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.blue[600]!, Colors.indigo[800]!],
              ),
            ),
          ),
          // ── Content ───────────────────────────────────────────────────
          Column(
            children: [
              // Top hero section
              Expanded(
                flex: 5,
                child: SafeArea(
                  bottom: false,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(18),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.directions_car,
                                color: Colors.blue[700], size: 48),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Vehicle Damage Assessment',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Insurance claims',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Bottom white panel
              Expanded(
                flex: 6,
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(32)),
                  ),
                  padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Continue as',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _RoleCard(
                        icon: Icons.person_outline,
                        title: 'Customer',
                        subtitle:
                            'Submit vehicle damage claims and track your assessments',
                        gradientColors: [Colors.blue[500]!, Colors.blue[800]!],
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const CustomerShell()),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _RoleCard(
                        icon: Icons.business_center_outlined,
                        title: 'Insurance Partner',
                        subtitle:
                            'Review incoming claims and submit final decisions',
                        gradientColors: [
                          Colors.indigo[400]!,
                          Colors.indigo[800]!
                        ],
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                InsurerDashboardPage(baseApiUrl: _baseApiUrl),
                          ),
                        ),
                      ),
                    ],
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

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradientColors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: gradientColors.last.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          splashColor: Colors.white.withOpacity(0.1),
          highlightColor: Colors.white.withOpacity(0.05),
          onTap: onTap,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.white.withOpacity(0.6)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Customer Shell (Assess + History tabs) ───────────────────────────────────

class CustomerShell extends StatefulWidget {
  const CustomerShell({super.key});

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  int _selectedIndex = 0;

  String get _baseApiUrl => ApiConfig.baseUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // HomePage stays alive (preserves form state + assessment results)
          Offstage(
            offstage: _selectedIndex != 0,
            child: const HomePage(),
          ),
          // ClaimHistoryPage is rebuilt every time the History tab is opened
          // so it always fetches fresh data from the server.
          if (_selectedIndex == 1)
            ClaimHistoryPage(baseApiUrl: _baseApiUrl),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: Colors.blue[700],
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_car),
            label: 'Assess',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: 'History',
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ImagePicker _picker = ImagePicker();
  List<File> _selectedImages = [];
  bool _isLoading = false;
  Map<String, dynamic>? _assessmentResult;

  // Form controllers
  final TextEditingController _brandController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();

  // API endpoint - Load from environment variables or use default
  String get apiUrl => ApiConfig.assessUrl;

  String _notifyUrlForClaim(String claimId) {
    final uri = Uri.parse(apiUrl);
    final baseSegments = List<String>.from(uri.pathSegments);
    if (baseSegments.isNotEmpty && baseSegments.last == 'assess') {
      baseSegments.removeLast();
    }
    return uri.replace(
      pathSegments: [...baseSegments, 'claims', claimId, 'notify'],
    ).toString();
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
    try {
      final response = await http.get(Uri.parse(_insurersUrl()));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Failed to load insurers: ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! List) {
        throw Exception('Invalid insurers response format');
      }

      final insurers = decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .where((item) => item['id'] != null && item['id'].toString().isNotEmpty)
          .toList();

      if (insurers.isNotEmpty) {
        return insurers;
      }
    } catch (_) {
      // Fallback below to Firestore-based admin-assigned insurer partners.
    }

    final partnerDocs = await FirebaseFirestore.instance
        .collection('insurer_partners')
        .get();

    final partnerMap = <String, Map<String, dynamic>>{};
    for (final doc in partnerDocs.docs) {
      final data = doc.data();
      final id = (data['insurerId'] ?? doc.id).toString().trim();
      final companyName = (data['companyName'] ?? '').toString().trim();
      if (id.isEmpty || companyName.isEmpty) continue;
      partnerMap[id] = {
        'id': id,
        'name': companyName,
      };
    }

    return partnerMap.values.toList();
  }

  Future<String?> _promptInsurerFromList(List<Map<String, dynamic>> insurers) async {
    if (insurers.isEmpty) return null;
    String selectedInsurerId = insurers.first['id'].toString();

    final insurerId = await showDialog<String>(
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
              final displayName = (insurer['name'] ??
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
              setDialogState(() {
                selectedInsurerId = value;
              });
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
    return insurerId?.trim();
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
      if (_insurerDisplayName(insurer).toLowerCase() == needle) {
        final id = insurer['id']?.toString().trim();
        if (id != null && id.isNotEmpty) return id;
      }
    }
    return null;
  }

  Future<String?> _getCurrentUserAssignedInsurerId(
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
      if (assigned == null || assigned.isEmpty) return null;
      return assigned;
    } catch (_) {
      return null;
    }
  }

  /// Requests location permission and returns the current [Position], or
  /// null if the user denies access or location services are off.
  Future<Position?> _getLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location services are disabled. '
                  'Claim will be sent without location.'),
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
              content: Text('Location permission denied. '
                  'Claim will be sent without location.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
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

    setState(() {
      _isLoading = true;
    });

    try {
      final insurers = await _fetchInsurers();
      if (insurers.isEmpty) {
        _showError('No insurers available to notify.');
        return;
      }

      String? insurerId = await _getCurrentUserAssignedInsurerId(insurers);
      insurerId ??= await _promptInsurerFromList(insurers);
      if (insurerId == null || insurerId.isEmpty) {
        return;
      }

      // Capture GPS location before sending
      final position = await _getLocation();

      final Map<String, dynamic> requestBody = {
        'insurer_id': insurerId,
      };
      if (position != null) {
        requestBody['latitude'] = position.latitude;
        requestBody['longitude'] = position.longitude;
      }

      final notifyUrl = _notifyUrlForClaim(claimId);
      final response = await http.post(
        Uri.parse(notifyUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        setState(() {
          _assessmentResult?['status'] = 'sent_to_insurer';
        });
        if (!mounted) return;
        final locationNote = position != null
            ? ' (with location)'
            : ' (no location attached)';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Claim sent to insurer successfully$locationNote (insurer: $insurerId)',
            ),
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
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
          _assessmentResult = null; // Clear previous results
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
          _assessmentResult = null; // Clear previous results
        });
      }
    } catch (e) {
      _showError('Failed to pick images: $e');
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  void _clearAllImages() {
    setState(() {
      _selectedImages.clear();
      _assessmentResult = null;
    });
  }

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

    setState(() {
      _isLoading = true;
    });

    try {
      // Extract image paths for background processing
      final imagePaths = _selectedImages.map((img) => img.path).toList();

      // Create assessment request
      final request = AssessmentRequest(
        imagePaths: imagePaths,
        vehicleBrand: _brandController.text,
        vehicleModel: _modelController.text,
        vehicleYear: _yearController.text,
        apiUrl: apiUrl,
        useAi: true,
        userUid: FirebaseAuth.instance.currentUser?.uid,
      );

      // Process assessment in background isolate to avoid blocking UI
      final result = await processDamageAssessment(request);

      setState(() {
        _assessmentResult = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog('Error: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showErrorDialog(String message) {
    // Extract just the descriptive detail from exception messages like:
    // "Exception: Assessment failed for image 1: 400 - <detail>"
    String displayMessage = message;
    final detailMatch = RegExp(r'\d{3} - (.+)$', dotAll: true).firstMatch(message);
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

  String _cleanMarkdown(String text) {
    // Remove markdown formatting (asterisks, hashtags, etc.)
    return text
        .replaceAll('**', '')  // Remove bold
        .replaceAll('*', '')   // Remove italic/emphasis
        .replaceAll('###', '') // Remove headers
        .replaceAll('##', '')
        .replaceAll('#', '')
        .replaceAll('`', '')   // Remove code blocks
        .trim();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text('Vehicle Damage Assessment'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image selection section
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
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: _selectedImages.length,
                        itemBuilder: (context, index) {
                          return Stack(
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
                                    decoration: BoxDecoration(
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
                          );
                        },
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

            // Vehicle details form
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

            // Assess button
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
                          'Processing ${_selectedImages.length} image${_selectedImages.length > 1 ? 's' : ''}...',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    )
                  : const Text(
                      'Assess Damage',
                      style: TextStyle(fontSize: 16),
                    ),
            ),

            const SizedBox(height: 16),

            // Results section
            if (_assessmentResult != null) _buildResultsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsCard() {
    final claimId = _assessmentResult!['claim_id']?.toString();
    final claimStatus = _assessmentResult!['status']?.toString();
    final damageDetection = _assessmentResult!['damage_detection'];
    final priceEstimation = _assessmentResult!['price_estimation'];
    final partMapping = _assessmentResult!['part_mapping'];
    final aiValidation = _assessmentResult!['ai_validation'];

    return Column(
      children: [
        // Header Card
        Card(
          elevation: 4,
          color: Colors.green[700],
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 32),
                const SizedBox(width: 12),
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

        // Detected Damages Card
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
                  ...List.generate(
                    damageDetection['detected_damages'].length,
                    (index) {
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
                                  Icon(Icons.circle, size: 8, color: Colors.red[700]),
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
                    },
                  ),
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
                        partMapping['affected_part'].toString().replaceAll('_', ' ').toUpperCase(),
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

        // Cost Breakdown Card
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.receipt_long, color: Colors.orange[700], size: 24),
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
                      // Show breakdown if available from Gemini AI
                      if (priceEstimation['breakdown'] != null &&
                          priceEstimation['breakdown'] is Map &&
                          priceEstimation['breakdown'].isNotEmpty) ...[
                        // Parts Cost
                        if (priceEstimation['breakdown']['parts'] != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.build_circle,
                                        size: 20, color: Colors.blue[700]),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Parts & Materials',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                  ],
                                ),
                                Text(
                                  '${priceEstimation['currency']} ${priceEstimation['breakdown']['parts'].toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // Paint Cost
                        if (priceEstimation['breakdown']['paint'] != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.purple[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.format_paint,
                                        size: 20, color: Colors.purple[700]),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Paint & Finishing',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                  ],
                                ),
                                Text(
                                  '${priceEstimation['currency']} ${priceEstimation['breakdown']['paint'].toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ] else ...[
                        // Fallback: show per-damage breakdown
                        ...List.generate(
                          damageDetection['detected_damages'].length,
                          (index) {
                            final damage = damageDetection['detected_damages'][index];
                            final costPerDamage = priceEstimation['estimated_price'] /
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
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    damage.replaceAll('_', ' ').toUpperCase() + ' repair',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  Text(
                                    '${priceEstimation['currency']} ${costPerDamage.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
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
                              '${priceEstimation['currency']} ${priceEstimation['estimated_price'].toStringAsFixed(2)}',
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

        // Analysis (if available)
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
                      Icon(Icons.analytics, color: Colors.purple[700], size: 24),
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
                        _cleanMarkdown(aiValidation['damage_validation']['analysis'] ?? 'N/A'),
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.5,
                        ),
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
                        _cleanMarkdown(aiValidation['price_explanation']['explanation'] ?? 'N/A'),
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                    onPressed: (_isLoading || claimId == null || claimId.isEmpty)
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
}

