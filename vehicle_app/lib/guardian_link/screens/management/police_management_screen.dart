import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../models/police_model.dart';
import '../../services/database_service.dart';
import '../../utils/app_colors.dart';
import '../admin/police_registration_screen.dart';
import 'user_management_screen.dart';

class PoliceManagementScreen extends StatefulWidget {
  final UserModel userModel;

  const PoliceManagementScreen({super.key, required this.userModel});

  @override
  State<PoliceManagementScreen> createState() => _PoliceManagementScreenState();
}

class _PoliceManagementScreenState extends State<PoliceManagementScreen> {
  final DatabaseService _databaseService = DatabaseService();
  List<PoliceModel> _policeStations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPoliceStations();
  }

  Future<void> _loadPoliceStations() async {
    try {
      final police = await _databaseService.getAllPoliceStations();
      setState(() {
        _policeStations = police;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading police stations: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deletePoliceStation(String stationId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Police Station'),
        content: const Text(
          'Are you sure you want to delete this police station?',
        ),
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
        await _databaseService.deletePoliceStation(stationId);
        await _loadPoliceStations();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Police station deleted successfully'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting police station: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Police Management'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      PoliceRegistrationScreen(adminId: widget.userModel.id),
                ),
              ).then((value) {
                if (value == true) {
                  _loadPoliceStations();
                }
              });
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _policeStations.isEmpty
          ? const Center(
              child: Text('No police stations found. Add one to get started.'),
            )
          : ListView.builder(
              itemCount: _policeStations.length,
              itemBuilder: (context, index) {
                final station = _policeStations[index];
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    leading: const Icon(
                      Icons.local_police,
                      color: AppColors.info,
                    ),
                    title: Text(station.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(station.address),
                        const SizedBox(height: 4),
                        Text(
                          'Phone: ${station.phoneNumber}',
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
                                  policeStation: station,
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
                                builder: (context) => PoliceRegistrationScreen(
                                  adminId: widget.userModel.id,
                                  policeStation: station,
                                ),
                              ),
                            );
                            if (result == true && mounted) {
                              await _loadPoliceStations();
                            }
                          },
                        ),
                        PopupMenuItem(
                          child: const Text('Delete'),
                          onTap: () => _deletePoliceStation(station.id),
                        ),
                      ],
                    ),
                    onTap: () {
                      // TODO: Show police station details
                    },
                  ),
                );
              },
            ),
    );
  }
}
