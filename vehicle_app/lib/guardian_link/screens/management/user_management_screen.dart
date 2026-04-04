import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../models/police_model.dart';
import '../../models/hospital_model.dart';
import '../../services/database_service.dart';
import '../../utils/app_colors.dart';
import '../admin/user_registration_screen.dart';

class UserManagementScreen extends StatefulWidget {
  final UserModel userModel;
  final PoliceModel? policeStation;
  final HospitalModel? hospital;

  const UserManagementScreen({
    super.key,
    required this.userModel,
    this.policeStation,
    this.hospital,
  });

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final DatabaseService _databaseService = DatabaseService();
  List<UserModel> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      List<UserModel> users;
      if (widget.policeStation != null) {
        users = await _databaseService.getPoliceStationUsers(
          widget.policeStation!.id,
        );
      } else if (widget.hospital != null) {
        users = await _databaseService.getHospitalUsers(widget.hospital!.id);
      } else {
        users = await _databaseService.getAllUsers();
      }
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading users: $e')));
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteUser(String userId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: const Text('Are you sure you want to delete this user?'),
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
        await _databaseService.deleteUser(userId);
        await _loadUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error deleting user: $e')));
        }
      }
    }
  }

  String _getUserTypeDisplayName(UserType userType) {
    switch (userType) {
      case UserType.user:
        return 'Regular User';
      case UserType.police:
        return 'Police Officer';
      case UserType.hospital:
        return 'Hospital Staff';
      case UserType.guardian:
        return 'Guardian';
      case UserType.admin:
        return 'Administrator';
    }
  }

  IconData _getUserTypeIcon(UserType userType) {
    switch (userType) {
      case UserType.user:
        return Icons.person;
      case UserType.police:
        return Icons.local_police;
      case UserType.hospital:
        return Icons.local_hospital;
      case UserType.guardian:
        return Icons.verified_user;
      case UserType.admin:
        return Icons.admin_panel_settings;
    }
  }

  Color _getUserTypeColor(UserType userType) {
    switch (userType) {
      case UserType.user:
        return AppColors.primary;
      case UserType.police:
        return AppColors.info;
      case UserType.hospital:
        return AppColors.error;
      case UserType.guardian:
        return Colors.teal;
      case UserType.admin:
        return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    String screenTitle = 'User Management';
    if (widget.policeStation != null) {
      screenTitle = 'Police Users - ${widget.policeStation!.name}';
    } else if (widget.hospital != null) {
      screenTitle = 'Hospital Users - ${widget.hospital!.name}';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(screenTitle),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UserRegistrationScreen(
                    adminId: widget.userModel.id,
                    policeStation: widget.policeStation,
                    hospital: widget.hospital,
                  ),
                ),
              ).then((value) {
                if (value == true) {
                  _loadUsers();
                }
              });
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
          ? const Center(child: Text('No users found. Add one to get started.'))
          : ListView.builder(
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final user = _users[index];
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: _getUserTypeColor(user.userType),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getUserTypeIcon(user.userType),
                        color: AppColors.white,
                      ),
                    ),
                    title: Text(user.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.email),
                        const SizedBox(height: 4),
                        Text(
                          _getUserTypeDisplayName(user.userType),
                          style: TextStyle(
                            color: _getUserTypeColor(user.userType),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    trailing: PopupMenuButton(
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          child: const Text('Edit'),
                          onTap: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => UserRegistrationScreen(
                                  adminId: widget.userModel.id,
                                  user: user,
                                  policeStation: widget.policeStation,
                                  hospital: widget.hospital,
                                ),
                              ),
                            );
                            if (result == true && mounted) {
                              await _loadUsers();
                            }
                          },
                        ),
                        PopupMenuItem(
                          child: const Text('Delete'),
                          onTap: () => _deleteUser(user.id),
                        ),
                      ],
                    ),
                    onTap: () {
                      // TODO: Show user details
                    },
                  ),
                );
              },
            ),
    );
  }
}
