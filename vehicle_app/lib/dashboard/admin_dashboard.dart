import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../common/api_config.dart';
import '../auth/login_page.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  List<Map<String, dynamic>> _insurers = [];
  bool _isLoadingInsurers = false;
  String? _insurersError;

  String get _baseApiUrl => ApiConfig.baseUrl;

  String get _insurersUrl => '$_baseApiUrl/insurers';

  Future<void> _upsertInsurerPartnerReference({
    required String insurerId,
    required String companyName,
    String? email,
  }) async {
    await FirebaseFirestore.instance
        .collection('insurer_partners')
        .doc(insurerId)
        .set({
          'insurerId': insurerId,
          'companyName': companyName,
          if (email != null && email.isNotEmpty) 'email': email,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  String _displayInsurerName(Map<String, dynamic> insurer) {
    return (insurer['name'] ??
            insurer['company_name'] ??
            insurer['display_name'] ??
            insurer['id'] ??
            'Unknown')
        .toString();
  }

  String _slugify(String value) {
    final slug = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return slug.isEmpty ? 'company' : slug;
  }

  String? _findInsurerIdByCompanyName(String companyName) {
    final needle = companyName.trim().toLowerCase();
    if (needle.isEmpty) return null;
    for (final insurer in _insurers) {
      final name = _displayInsurerName(insurer).trim().toLowerCase();
      if (name == needle) {
        return insurer['id']?.toString();
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadInsurers();
    _syncInsurerPartnersFromUsers();
  }

  Future<void> _syncInsurerPartnersFromUsers() async {
    try {
      final partnerDocs = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'insurance_partner')
          .get();

      for (final doc in partnerDocs.docs) {
        final data = doc.data();
        final insurerId = data['assignedInsurerId']?.toString().trim();
        final companyName = data['insurerCompanyName']?.toString().trim();
        final email = data['email']?.toString().trim();

        if (insurerId == null || insurerId.isEmpty) continue;
        if (companyName == null || companyName.isEmpty) continue;

        await _upsertInsurerPartnerReference(
          insurerId: insurerId,
          companyName: companyName,
          email: email,
        );
      }
    } catch (_) {
      // Best-effort sync; assignment actions still upsert references.
    }
  }

  Future<void> _loadInsurers() async {
    setState(() {
      _isLoadingInsurers = true;
      _insurersError = null;
    });
    try {
      final response = await http
          .get(Uri.parse(_insurersUrl))
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is! List) {
          throw const FormatException('Expected insurers list');
        }
        setState(() {
          _insurers = decoded
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .where((e) => e['id'] != null && e['id'].toString().isNotEmpty)
              .toList();
          _isLoadingInsurers = false;
        });
      } else {
        setState(() {
          _insurersError =
              'Failed to load insurers (HTTP ${response.statusCode})';
          _isLoadingInsurers = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _insurersError = 'Failed to load insurers: $e';
        _isLoadingInsurers = false;
      });
    }
  }

  String _insurerNameById(String? insurerId) {
    if (insurerId == null || insurerId.isEmpty) return 'Not assigned';
    final insurer = _insurers
        .where((i) => i['id']?.toString() == insurerId)
        .toList();
    if (insurer.isEmpty) return insurerId;
    return _displayInsurerName(insurer.first);
  }

  Future<void> _assignAsInsurancePartner(
    String uid,
    String email,
    String? currentInsurerId,
  ) async {
    if (_insurers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No insurers available for assignment')),
      );
      return;
    }

    String selectedInsurerId = currentInsurerId?.isNotEmpty == true
        ? currentInsurerId!
        : _insurers.first['id'].toString();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Assign Insurance Partner'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(email),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedInsurerId,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Insurer',
                ),
                items: _insurers.map((insurer) {
                  final id = insurer['id'].toString();
                  final name =
                      (insurer['name'] ??
                              insurer['company_name'] ??
                              insurer['display_name'] ??
                              id)
                          .toString();
                  return DropdownMenuItem<String>(value: id, child: Text(name));
                }).toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setDialogState(() => selectedInsurerId = value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, selectedInsurerId),
              child: const Text('Assign'),
            ),
          ],
        ),
      ),
    );

    if (result == null || result.isEmpty) return;

    final selected = _insurers.where(
      (insurer) => insurer['id']?.toString() == result,
    );
    final selectedCompanyName = selected.isNotEmpty
        ? _displayInsurerName(selected.first)
        : null;

    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'role': 'insurance_partner',
      'assignedInsurerId': result,
      if (selectedCompanyName != null) 'insurerCompanyName': selectedCompanyName,
      'insurerPartnerEmail': email,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (selectedCompanyName != null && selectedCompanyName.isNotEmpty) {
      await _upsertInsurerPartnerReference(
        insurerId: result,
        companyName: selectedCompanyName,
        email: email,
      );
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('User assigned as insurance partner')),
    );
  }

  Future<void> _addAndAssignInsurancePartner(String uid, String userEmail) async {
    final emailController = TextEditingController(text: userEmail);
    final companyController = TextEditingController();
    String? formError;
    bool isSubmitting = false;

    final createdInsurerId = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Insurer Partner'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Partner Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: companyController,
                  decoration: const InputDecoration(
                    labelText: 'Company Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (formError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    formError!,
                    style: TextStyle(color: Colors.red[700], fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final email = emailController.text.trim();
                      final companyName = companyController.text.trim();
                      if (email.isEmpty || companyName.isEmpty) {
                        setDialogState(() {
                          formError = 'Email and company name are required';
                        });
                        return;
                      }
                      if (!email.contains('@')) {
                        setDialogState(() {
                          formError = 'Enter a valid email address';
                        });
                        return;
                      }

                      setDialogState(() {
                        formError = null;
                        isSubmitting = true;
                      });

                      final existingId = _findInsurerIdByCompanyName(
                        companyName,
                      );
                      if (existingId != null && existingId.isNotEmpty) {
                        Navigator.pop(context, existingId);
                        return;
                      }

                      final payloads = [
                        {
                          'email': email,
                          'company_name': companyName,
                        },
                        {
                          'partner_email': email,
                          'name': companyName,
                        },
                        {
                          'email': email,
                          'name': companyName,
                        },
                      ];

                      for (final payload in payloads) {
                        try {
                          final response = await http
                              .post(
                                Uri.parse(_insurersUrl),
                                headers: {'Content-Type': 'application/json'},
                                body: jsonEncode(payload),
                              )
                              .timeout(const Duration(seconds: 15));

                          if (response.statusCode >= 200 &&
                              response.statusCode < 300) {
                            final decoded = jsonDecode(response.body);
                            if (decoded is Map && decoded['id'] != null) {
                              Navigator.pop(context, decoded['id'].toString());
                              return;
                            }
                          }
                        } catch (_) {}
                      }

                      // Fallback for manual company assignment if insurer-create API is unavailable.
                      Navigator.pop(context, 'manual_${_slugify(companyName)}');
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Add & Assign'),
            ),
          ],
        ),
      ),
    );

    if (createdInsurerId == null || createdInsurerId.isEmpty) return;

    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'role': 'insurance_partner',
      'assignedInsurerId': createdInsurerId,
      'insurerPartnerEmail': emailController.text.trim(),
      'insurerCompanyName': companyController.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _upsertInsurerPartnerReference(
      insurerId: createdInsurerId,
      companyName: companyController.text.trim(),
      email: emailController.text.trim(),
    );

    await _loadInsurers();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          createdInsurerId.startsWith('manual_')
              ? 'Partner assigned with manual company mapping'
              : 'Insurer partner added and assigned',
        ),
      ),
    );
  }

  Future<void> _setCustomer(String uid) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'role': 'customer',
      'assignedInsurerId': null,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('User set as customer')));
  }

  Future<void> _setAdmin(String uid) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'role': 'admin',
      'assignedInsurerId': null,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('User set as admin')));
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            onPressed: _isLoadingInsurers ? null : _loadInsurers,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh insurers',
          ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isLoadingInsurers) const LinearProgressIndicator(),
          if (_insurersError != null)
            Container(
              width: double.infinity,
              color: Colors.orange[50],
              padding: const EdgeInsets.all(10),
              child: Text(
                _insurersError!,
                style: TextStyle(color: Colors.orange[900]),
              ),
            ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Failed to load users: ${snapshot.error}'),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs
                  ..sort((a, b) {
                    final aEmail = (a.data()['email'] ?? '').toString();
                    final bEmail = (b.data()['email'] ?? '').toString();
                    return aEmail.compareTo(bEmail);
                  });

                if (docs.isEmpty) {
                  return const Center(child: Text('No registered users found'));
                }

                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    final uid = doc.id;
                    final email = (data['email'] ?? 'Unknown').toString();
                    final role = (data['role'] ?? 'customer').toString();
                    final assignedInsurerId = data['assignedInsurerId']
                        ?.toString();
                    final manualCompany = data['insurerCompanyName']?.toString();
                    final assignedName =
                        (manualCompany != null && manualCompany.isNotEmpty)
                        ? manualCompany
                        : _insurerNameById(assignedInsurerId);

                    return ListTile(
                      title: Text(email),
                      subtitle: Text(
                        role == 'insurance_partner'
                            ? 'Role: $role | Insurer: $assignedName'
                            : 'Role: $role',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          OutlinedButton(
                            onPressed: () =>
                                _addAndAssignInsurancePartner(uid, email),
                            child: const Text('Add Insurer Partner'),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value == 'customer') {
                                await _setCustomer(uid);
                              } else if (value == 'admin') {
                                await _setAdmin(uid);
                              } else if (value == 'partner') {
                                await _assignAsInsurancePartner(
                                  uid,
                                  email,
                                  assignedInsurerId,
                                );
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: 'customer',
                                child: Text('Set as Customer'),
                              ),
                              PopupMenuItem(
                                value: 'partner',
                                child: Text('Assign Insurance Partner'),
                              ),
                              PopupMenuItem(
                                value: 'admin',
                                child: Text('Set as Admin'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
