import 'package:flutter/material.dart';
import '../../models/police_model.dart';
import '../../services/database_service.dart';
import '../shared/location_picker_widget.dart';

class PoliceRegistrationScreen extends StatefulWidget {
  final String adminId;
  final PoliceModel? policeStation;

  const PoliceRegistrationScreen({
    super.key,
    required this.adminId,
    this.policeStation,
  });

  @override
  State<PoliceRegistrationScreen> createState() =>
      _PoliceRegistrationScreenState();
}

class _PoliceRegistrationScreenState extends State<PoliceRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _databaseService = DatabaseService();

  late TextEditingController _nameController;
  late TextEditingController _phoneNumberController;
  late TextEditingController _addressController;
  late TextEditingController _latitudeController;
  late TextEditingController _longitudeController;

  double? _latitude;
  double? _longitude;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneNumberController = TextEditingController();
    _addressController = TextEditingController();
    _latitudeController = TextEditingController();
    _longitudeController = TextEditingController();

    // If editing, populate fields with existing police station data
    if (widget.policeStation != null) {
      _nameController.text = widget.policeStation!.name;
      _phoneNumberController.text = widget.policeStation!.phoneNumber;
      _addressController.text = widget.policeStation!.address;
      _latitude = widget.policeStation!.latitude;
      _longitude = widget.policeStation!.longitude;
      _latitudeController.text = _latitude.toString();
      _longitudeController.text = _longitude.toString();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneNumberController.dispose();
    _addressController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  Future<void> _registerPolice() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a location')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (widget.policeStation != null) {
        // Edit existing police station
        await _databaseService.updatePoliceStation(
          policeId: widget.policeStation!.id,
          name: _nameController.text.trim(),
          phoneNumber: _phoneNumberController.text.trim(),
          address: _addressController.text.trim(),
          latitude: _latitude!,
          longitude: _longitude!,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Police station updated successfully!'),
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        // Create new police station
        await _databaseService.createPoliceStation(
          name: _nameController.text.trim(),
          phoneNumber: _phoneNumberController.text.trim(),
          address: _addressController.text.trim(),
          latitude: _latitude!,
          longitude: _longitude!,
          adminId: widget.adminId,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Police station registered successfully!'),
            ),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.policeStation != null
                  ? 'Update failed: $e'
                  : 'Registration failed: $e',
            ),
          ),
        );
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.policeStation != null
              ? 'Edit Police Station'
              : 'Police Station Registration',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Name Field
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Police Station Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.security),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter police station name';
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
                  hintText: 'e.g., +94701234567',
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
                    return 'Please enter police station address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Location Picker
              LocationPickerWidget(
                title: 'Police Station Location',
                onLocationSelected: (latitude, longitude) {
                  setState(() {
                    _latitude = latitude;
                    _longitude = longitude;
                    _latitudeController.text = latitude.toString();
                    _longitudeController.text = longitude.toString();
                  });
                },
              ),
              const SizedBox(height: 16),
              // Latitude Field
              TextFormField(
                controller: _latitudeController,
                decoration: const InputDecoration(
                  labelText: 'Latitude',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.public),
                  hintText: 'e.g., 6.9271',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter latitude';
                  }
                  try {
                    double.parse(value);
                  } catch (e) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
                onChanged: (value) {
                  if (value.isNotEmpty) {
                    try {
                      _latitude = double.parse(value);
                    } catch (e) {
                      // Invalid number
                    }
                  }
                },
              ),
              const SizedBox(height: 16),
              // Longitude Field
              TextFormField(
                controller: _longitudeController,
                decoration: const InputDecoration(
                  labelText: 'Longitude',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.public),
                  hintText: 'e.g., 80.7718',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter longitude';
                  }
                  try {
                    double.parse(value);
                  } catch (e) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
                onChanged: (value) {
                  if (value.isNotEmpty) {
                    try {
                      _longitude = double.parse(value);
                    } catch (e) {
                      // Invalid number
                    }
                  }
                },
              ),
              const SizedBox(height: 24),
              // Register/Update Button
              ElevatedButton(
                onPressed: _isLoading ? null : _registerPolice,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        widget.policeStation != null
                            ? 'Update Police Station'
                            : 'Register Police Station',
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
