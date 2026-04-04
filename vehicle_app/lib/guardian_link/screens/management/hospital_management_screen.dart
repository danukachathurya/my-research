import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../models/hospital_model.dart';
import '../../services/database_service.dart';
import '../../utils/app_colors.dart';
import '../admin/hospital_registration_screen.dart';
import 'user_management_screen.dart';

class HospitalManagementScreen extends StatefulWidget {
  final UserModel userModel;

  const HospitalManagementScreen({super.key, required this.userModel});

  @override
  State<HospitalManagementScreen> createState() =>
      _HospitalManagementScreenState();
}

class _HospitalManagementScreenState extends State<HospitalManagementScreen> {
  final DatabaseService _databaseService = DatabaseService();
  List<HospitalModel> _hospitals = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHospitals();
  }

  Future<void> _loadHospitals() async {
    try {
      final hospitals = await _databaseService.getAllHospitals();
      setState(() {
        _hospitals = hospitals;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading hospitals: $e')));
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteHospital(String hospitalId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Hospital'),
        content: const Text('Are you sure you want to delete this hospital?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _databaseService.deleteHospital(hospitalId);
        await _loadHospitals();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Hospital deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting hospital: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hospital Management'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      HospitalRegistrationScreen(adminId: widget.userModel.id),
                ),
              ).then((value) {
                if (value == true) {
                  _loadHospitals();
                }
              });
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hospitals.isEmpty
          ? const Center(
              child: Text('No hospitals found. Add one to get started.'),
            )
          : ListView.builder(
              itemCount: _hospitals.length,
              itemBuilder: (context, index) {
                final hospital = _hospitals[index];
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    leading: const Icon(
                      Icons.local_hospital,
                      color: AppColors.error,
                    ),
                    title: Text(hospital.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(hospital.address),
                        const SizedBox(height: 4),
                        Text(
                          'Phone: ${hospital.phoneNumber}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    trailing: PopupMenuButton(
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          child: const Text('Manage Users'),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => UserManagementScreen(
                                  userModel: widget.userModel,
                                  hospital: hospital,
                                ),
                              ),
                            );
                          },
                        ),
                        PopupMenuItem(
                          child: const Text('Edit'),
                          onTap: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    HospitalRegistrationScreen(
                                      adminId: widget.userModel.id,
                                      hospital: hospital,
                                    ),
                              ),
                            );
                            if (result == true && mounted) {
                              await _loadHospitals();
                            }
                          },
                        ),
                        PopupMenuItem(
                          child: const Text('Delete'),
                          onTap: () => _deleteHospital(hospital.id),
                        ),
                      ],
                    ),
                    onTap: () {
                      // TODO: Show hospital details
                    },
                  ),
                );
              },
            ),
    );
  }
}
