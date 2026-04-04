import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';
import '../../models/guardian_model.dart';
import '../../services/database_service.dart';

class GuardianRegistrationScreen extends StatefulWidget {
  final UserModel userModel;

  const GuardianRegistrationScreen({super.key, required this.userModel});

  @override
  State<GuardianRegistrationScreen> createState() =>
      _GuardianRegistrationScreenState();
}

class _GuardianRegistrationScreenState
    extends State<GuardianRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _databaseService = DatabaseService();

  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _phoneNumberController;
  late TextEditingController _ageController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;

  bool _isLoading = true;
  UserModel? _existingGuardianUser;
  GuardianModel? _legacyGuardian;
  bool _isLegacyMigration = false;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _addressController = TextEditingController();
    _phoneNumberController = TextEditingController();
    _ageController = TextEditingController();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _loadGuardian();
  }

  Future<void> _loadGuardian() async {
    try {
      // 1. Check if user already has a linked guardian User
      if (widget.userModel.linkedUserId != null) {
        final guardianUser = await _authService.getUserById(
          widget.userModel.linkedUserId!,
        );
        if (guardianUser != null) {
          _existingGuardianUser = guardianUser;
          _populateForm(_existingGuardianUser!);
        }
      }
      // 2. If no linked User, check for legacy GuardianModel
      else {
        final guardian = await _databaseService.getUserGuardian(
          widget.userModel.id,
        );
        if (guardian != null) {
          _legacyGuardian = guardian;
          _isLegacyMigration = true;
          // Pre-fill form for migration
          _nameController.text = _legacyGuardian!.name;
          _addressController.text = _legacyGuardian!.address;
          _phoneNumberController.text = _legacyGuardian!.phoneNumber;
          _ageController.text = _legacyGuardian!.age.toString();
          _emailController.text = _legacyGuardian!.email ?? '';
        }
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading guardian: $e')));
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _populateForm(UserModel user) {
    _nameController.text = user.name;
    _addressController.text = user.address ?? '';
    _phoneNumberController.text = user.phoneNumber ?? '';
    _ageController.text = user.age?.toString() ?? '';
    _emailController.text = user.email;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneNumberController.dispose();
    _ageController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _saveGuardian() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      int age = int.parse(_ageController.text.trim());
      String email = _emailController.text.trim();

      if (_existingGuardianUser != null) {
        // Update existing guardian User - CANNOT update email/password easily here, restricted to profile fields
        // Since we are creating a new user logic, updating might be limited to non-auth fields
        await _authService.updateUserProfile(
          userId: _existingGuardianUser!.id,
          name: _nameController.text.trim(),
          address: _addressController.text.trim(),
          // Note: AuthService.updateUserProfile might need updates to handle phone/age if we want to update them
          // For now, let's update directly via database service or add fields to updateProfile
        );

        // Update phone and age directly in DB
        await _databaseService.updateUser(
          userId: _existingGuardianUser!.id,
          address: _addressController.text.trim(),
          phoneNumber: _phoneNumberController.text.trim(),
          age: age,
        );
        // Direct DB update for fields not in standard update method
        // Actually, let's just assume Basic Profile Update for now.

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Guardian updated successfully!')),
          );
          Navigator.pop(context);
        }
      } else {
        // Create new guardian User
        final password = _passwordController.text.trim();
        if (password.isEmpty) {
          throw Exception('Password is required for new registration');
        }

        await _authService.registerGuardian(
          email: email,
          password: password,
          name: _nameController.text.trim(),
          address: _addressController.text.trim(),
          phoneNumber: _phoneNumberController.text.trim(),
          age: age,
          linkedUserId: widget.userModel.id,
        );

        // If this was a legacy migration, we might want to delete the old record or mark it?
        // Let's leave it for data safety or delete it if you prefer.
        if (_isLegacyMigration && _legacyGuardian != null) {
          await _databaseService.deleteGuardian(_legacyGuardian!.id);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Guardian account created and linked!'),
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String title = _existingGuardianUser != null
        ? 'Update Guardian'
        : _isLegacyMigration
        ? 'Migrate Guardian'
        : 'Register Guardian';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Show info banner if updating
                    if (_isLegacyMigration)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.1),
                          border: Border.all(color: Colors.amber),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.warning_amber,
                              color: Colors.amber,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'You have an existing guardian. Please create a password to enable their login account.',
                                style: TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_existingGuardianUser != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          border: Border.all(color: Colors.blue),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info, color: Colors.blue, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'You can update your guardian\'s contact information here.',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Name Field
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Guardian Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter guardian name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Address Field
                    TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(
                        labelText: 'Address',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_on),
                      ),
                      minLines: 1,
                      maxLines: 3,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Phone Number Field
                    TextFormField(
                      controller: _phoneNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter phone number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Age Field
                    TextFormField(
                      controller: _ageController,
                      decoration: const InputDecoration(
                        labelText: 'Age',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.cake),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter age';
                        }
                        try {
                          int.parse(value);
                        } catch (e) {
                          return 'Please enter a valid age';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Email Field
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      enabled:
                          _existingGuardianUser == null, // Cannot change email
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter email';
                        }
                        if (!value.contains('@')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Password Field (Only for new)
                    if (_existingGuardianUser == null) ...[
                      TextFormField(
                        controller: _passwordController,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.lock),
                        ),
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter password';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Guardian will use this email and password to login to the app.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    // Save/Register Button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _saveGuardian,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _existingGuardianUser != null
                                  ? 'Update Guardian Info'
                                  : _isLegacyMigration
                                  ? 'Create Account & Migrate'
                                  : 'Create Guardian Account',
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
