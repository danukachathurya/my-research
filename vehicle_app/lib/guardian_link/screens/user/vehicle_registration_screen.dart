import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../models/vehicle_model.dart';
import '../../services/database_service.dart';

class VehicleRegistrationScreen extends StatefulWidget {
  final UserModel userModel;

  const VehicleRegistrationScreen({super.key, required this.userModel});

  @override
  State<VehicleRegistrationScreen> createState() =>
      _VehicleRegistrationScreenState();
}

class _VehicleRegistrationScreenState extends State<VehicleRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _databaseService = DatabaseService();

  late TextEditingController _vehicleNameController;
  late TextEditingController _licenseNumberController;
  late TextEditingController _registrationNumberController;

  bool _isLoading = true;
  VehicleModel? _existingVehicle;

  @override
  void initState() {
    super.initState();
    _vehicleNameController = TextEditingController();
    _licenseNumberController = TextEditingController();
    _registrationNumberController = TextEditingController();
    _loadVehicle();
  }

  Future<void> _loadVehicle() async {
    try {
      final vehicles = await _databaseService.getUserVehicles(
        widget.userModel.id,
      );
      if (vehicles.isNotEmpty) {
        _existingVehicle = vehicles[0]; // Get first vehicle
        _vehicleNameController.text = _existingVehicle!.vehicleName;
        _licenseNumberController.text = _existingVehicle!.licenseNumber;
        _registrationNumberController.text =
            _existingVehicle!.registrationNumber;
      }
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading vehicle: $e')));
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _vehicleNameController.dispose();
    _licenseNumberController.dispose();
    _registrationNumberController.dispose();
    super.dispose();
  }

  Future<void> _saveVehicle() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_existingVehicle != null) {
        // Update existing vehicle
        await _databaseService.updateVehicle(
          vehicleId: _existingVehicle!.id,
          vehicleName: _vehicleNameController.text.trim(),
          licenseNumber: _licenseNumberController.text.trim(),
          registrationNumber: _registrationNumberController.text.trim(),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vehicle updated successfully!')),
          );
          Navigator.pop(context);
        }
      } else {
        // Create new vehicle
        await _databaseService.createVehicle(
          vehicleName: _vehicleNameController.text.trim(),
          licenseNumber: _licenseNumberController.text.trim(),
          registrationNumber: _registrationNumberController.text.trim(),
          userId: widget.userModel.id,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vehicle registered successfully!')),
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
    String title = _existingVehicle != null
        ? 'Update Vehicle'
        : 'Register Vehicle';

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
                    if (_existingVehicle != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
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
                                'You can update your existing vehicle information',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Vehicle Name Field
                    TextFormField(
                      controller: _vehicleNameController,
                      decoration: const InputDecoration(
                        labelText: 'Vehicle Name',
                        hintText: 'e.g., Toyota Corolla',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.directions_car),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter vehicle name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // License Number Field
                    TextFormField(
                      controller: _licenseNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Driver License Number',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.badge),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter driver license number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Registration Number Field
                    TextFormField(
                      controller: _registrationNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Vehicle Registration Number',
                        hintText: 'e.g., ABC-1234',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.assignment),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter registration number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    // Save/Register Button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _saveVehicle,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _existingVehicle != null
                                  ? 'Update Vehicle'
                                  : 'Register Vehicle',
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
