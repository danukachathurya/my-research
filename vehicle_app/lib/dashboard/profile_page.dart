import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEditing = false;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _emailController = TextEditingController();

  String _role = 'customer';
  String? _selectedInsurerId;
  List<_InsurerOption> _insurerOptions = [];

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<List<_InsurerOption>> _loadInsurerOptions() async {
    final optionsById = <String, _InsurerOption>{};

    try {
      final refDocs = await FirebaseFirestore.instance
          .collection('insurer_partners')
          .get();
      for (final doc in refDocs.docs) {
        final data = doc.data();
        final insurerId = (data['insurerId'] ?? doc.id).toString();
        final companyName = (data['companyName'] ?? '').toString().trim();
        if (insurerId.isEmpty || companyName.isEmpty) continue;
        optionsById[insurerId] = _InsurerOption(
          id: insurerId,
          companyName: companyName,
        );
      }
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
    }

    final options = optionsById.values.toList()
      ..sort((a, b) => a.companyName.compareTo(b.companyName));
    return options;
  }

  Future<void> _loadProfileData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);
    _emailController.text = user.email ?? '';

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data() ?? <String, dynamic>{};

      _emailController.text = (data['email'] ?? user.email ?? '').toString();
      _role = (data['role'] ?? 'customer').toString();

      _nameController.text = (data['fullName'] ?? '').toString();
      _phoneController.text = (data['phone'] ?? '').toString();
      _addressController.text = (data['address'] ?? '').toString();

      _selectedInsurerId = data['assignedInsurerId']?.toString();
      _insurerOptions = await _loadInsurerOptions();

      final selectedExists = _insurerOptions.any((i) => i.id == _selectedInsurerId);
      if (!selectedExists) {
        _selectedInsurerId = null;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to load profile data: $e. '
            'Ensure Firestore rules allow read on insurer_partners for signed-in users.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);
    try {
      var insurerAssignmentDenied = false;
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fullName': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final selected = _insurerOptions.where((i) => i.id == _selectedInsurerId);
      final selectedCompanyName =
          selected.isNotEmpty ? selected.first.companyName : null;
      if (_selectedInsurerId != null && selectedCompanyName != null) {
        try {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'assignedInsurerId': _selectedInsurerId,
            'insurerCompanyName': selectedCompanyName,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } on FirebaseException catch (e) {
          if (e.code == 'permission-denied' && mounted) {
            insurerAssignmentDenied = true;
          } else {
            rethrow;
          }
        }
      }

      if (!mounted) return;
      setState(() => _isEditing = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            insurerAssignmentDenied
                ? 'Basic profile saved. Insurer assignment requires admin permission.'
                : 'Profile updated',
          ),
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      if (e.code == 'permission-denied') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Permission denied while saving profile. Check Firestore rules for users/{uid}.',
            ),
          ),
        );
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: ${e.message ?? e.code}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  InputDecoration inputStyle(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final selectedIsValid = _insurerOptions.any((i) => i.id == _selectedInsurerId);
    final dropdownValue = selectedIsValid ? _selectedInsurerId : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.close : Icons.edit),
            onPressed: () => setState(() => _isEditing = !_isEditing),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Card(
          elevation: 6,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 40,
                  child: Icon(Icons.person, size: 40),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _nameController,
                  enabled: _isEditing,
                  decoration: inputStyle('Full Name'),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _phoneController,
                  enabled: _isEditing,
                  decoration: inputStyle('Phone Number'),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _addressController,
                  enabled: _isEditing,
                  decoration: inputStyle('Address'),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _emailController,
                  enabled: false,
                  decoration: inputStyle('Email'),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Role: $_role',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: dropdownValue,
                  decoration: inputStyle('Select Insurance Company'),
                  items: _insurerOptions
                      .map(
                        (i) => DropdownMenuItem<String>(
                          value: i.id,
                          child: Text(i.companyName),
                        ),
                      )
                      .toList(),
                  onChanged: _isEditing
                      ? (v) => setState(() => _selectedInsurerId = v)
                      : null,
                ),
                if (_insurerOptions.isEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'No insurance companies assigned by admin yet. Ask admin to assign insurer partners first.',
                    style: TextStyle(color: Colors.orange[800]),
                  ),
                ],
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  height: 45,
                  child: ElevatedButton(
                    onPressed: (_isEditing && !_isSaving) ? _saveProfile : null,
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save Profile'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InsurerOption {
  final String id;
  final String companyName;

  const _InsurerOption({required this.id, required this.companyName});
}
