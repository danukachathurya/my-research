import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/user_model.dart';
import '../../models/police_model.dart';
import '../../models/hospital_model.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/image_service.dart';
import '../../utils/app_colors.dart';

class UserRegistrationScreen extends StatefulWidget {
  final String adminId;
  final UserModel? user;
  final PoliceModel? policeStation;
  final HospitalModel? hospital;

  const UserRegistrationScreen({
    super.key,
    required this.adminId,
    this.user,
    this.policeStation,
    this.hospital,
  });

  @override
  State<UserRegistrationScreen> createState() => _UserRegistrationScreenState();
}

class _UserRegistrationScreenState extends State<UserRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _nicController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  UserType? _selectedUserType;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;
  File? _photoFile;

  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();

  @override
  void initState() {
    super.initState();
    if (widget.user != null) {
      _nameController.text = widget.user!.name;
      _emailController.text = widget.user!.email;
      _nicController.text = widget.user!.nicNumber ?? '';
      _selectedUserType = widget.user!.userType;
    } else {
      // Set default user type based on context
      if (widget.policeStation != null) {
        _selectedUserType = UserType.police;
      } else if (widget.hospital != null) {
        _selectedUserType = UserType.hospital;
      } else {
        _selectedUserType = UserType.user;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _nicController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        _photoFile = File(image.path);
      });
    }
  }

  Future<void> _handleRegister() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedUserType == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a user type'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      // For new users, photo is required
      if (widget.user == null && _photoFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a profile photo'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      setState(() => _isLoading = true);

      try {
        if (widget.user != null) {
          // Edit existing user
          String? photoBase64;
          if (_photoFile != null) {
            photoBase64 = ImageService.fileToBase64(_photoFile!);
          }

          await _databaseService.updateUser(
            userId: widget.user!.id,
            name: _nameController.text.trim(),
            userType: _selectedUserType!,
            nicNumber: _nicController.text.trim(),
            photoBase64: photoBase64,
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('User updated successfully!'),
                backgroundColor: AppColors.success,
              ),
            );
            Navigator.of(context).pop(true);
          }
        } else {
          // Create new user
          String photoBase64 = ImageService.fileToBase64(_photoFile!);

          await _authService.registerUser(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            name: _nameController.text.trim(),
            userType: _selectedUserType!,
            nicNumber: _nicController.text.trim(),
            photoBase64: photoBase64,
          );

          // Map user to police station or hospital if provided
          if (widget.policeStation != null) {
            // Get the newly created user ID from auth
            final userSnapshot = await _databaseService.getUserByEmail(
              _emailController.text.trim(),
            );
            if (userSnapshot != null) {
              await _databaseService.mapUserToPoliceStation(
                userId: userSnapshot.id,
                policeStationId: widget.policeStation!.id,
              );
            }
          } else if (widget.hospital != null) {
            // Get the newly created user ID from auth
            final userSnapshot = await _databaseService.getUserByEmail(
              _emailController.text.trim(),
            );
            if (userSnapshot != null) {
              await _databaseService.mapUserToHospital(
                userId: userSnapshot.id,
                hospitalId: widget.hospital!.id,
              );
            }
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('User registered successfully!'),
                backgroundColor: AppColors.success,
              ),
            );
            Navigator.of(context).pop(true);
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.user != null
                    ? 'Update failed: $e'
                    : 'Registration failed: $e',
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String screenTitle = widget.user != null ? 'Edit User' : 'Register User';
    if (widget.policeStation != null) {
      screenTitle += ' - ${widget.policeStation!.name}';
    } else if (widget.hospital != null) {
      screenTitle += ' - ${widget.hospital!.name}';
    }

    return Scaffold(
      appBar: AppBar(title: Text(screenTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Show mapping context if police station or hospital is provided
                if (widget.policeStation != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.info.withOpacity(0.1),
                      border: Border.all(color: AppColors.info),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.local_police,
                          color: AppColors.info,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Mapping to: ${widget.policeStation!.name}',
                            style: const TextStyle(
                              color: AppColors.info,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (widget.hospital != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      border: Border.all(color: AppColors.error),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.local_hospital,
                          color: AppColors.error,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Mapping to: ${widget.hospital!.name}',
                            style: const TextStyle(
                              color: AppColors.error,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 16),

                // Photo Picker (only for new users or allow edit)
                Center(
                  child: Stack(
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: AppColors.greyLight,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primary,
                            width: 3,
                          ),
                        ),
                        child: _photoFile != null
                            ? ClipOval(
                                child: Image.file(
                                  _photoFile!,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Icon(
                                Icons.person,
                                size: 60,
                                color: AppColors.grey,
                              ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.camera_alt,
                              color: AppColors.white,
                              size: 20,
                            ),
                            onPressed: _pickImage,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Name Field
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    hintText: 'Enter full name',
                    prefixIcon: Icon(Icons.person_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter full name';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Email Field (disabled for edit)
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  enabled: widget.user == null,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    hintText: 'Enter email',
                    prefixIcon: const Icon(Icons.email_outlined),
                    filled: widget.user != null,
                    fillColor: widget.user != null
                        ? AppColors.greyLight
                        : Colors.transparent,
                  ),
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

                // User Type Dropdown
                DropdownButtonFormField<UserType>(
                  value: _selectedUserType,
                  decoration: const InputDecoration(
                    labelText: 'User Type',
                    prefixIcon: Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: UserType.values.map((type) {
                    String label;
                    switch (type) {
                      case UserType.user:
                        label = 'Regular User';
                        break;
                      case UserType.police:
                        label = 'Police Officer';
                        break;
                      case UserType.hospital:
                        label = 'Hospital Staff';
                        break;
                      case UserType.guardian:
                        label = 'Guardian';
                        break;
                      case UserType.admin:
                        label = 'Administrator';
                        break;
                    }
                    return DropdownMenuItem<UserType>(
                      value: type,
                      child: Text(label),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedUserType = value;
                    });
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'Please select a user type';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // NIC Field
                TextFormField(
                  controller: _nicController,
                  decoration: const InputDecoration(
                    labelText: 'NIC Number',
                    hintText: 'Enter NIC number',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter NIC number';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Password Field (only for new users)
                if (widget.user == null)
                  TextFormField(
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'Enter password',
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),

                if (widget.user == null) const SizedBox(height: 16),

                // Confirm Password Field (only for new users)
                if (widget.user == null)
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: !_isConfirmPasswordVisible,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      hintText: 'Re-enter password',
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isConfirmPasswordVisible
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _isConfirmPasswordVisible =
                                !_isConfirmPasswordVisible;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm password';
                      }
                      if (value != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),

                const SizedBox(height: 32),

                // Register/Update Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleRegister,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          widget.user != null ? 'Update User' : 'Register User',
                          style: const TextStyle(fontSize: 16),
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
