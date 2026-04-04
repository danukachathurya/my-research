import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../models/accident_report_model.dart';
import '../../services/database_service.dart';
import '../../utils/app_colors.dart';
import 'package:intl/intl.dart';
import '../../utils/map_helper.dart';
import '../../utils/string_extensions.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../widgets/medical_notes_viewer.dart';

class RecordedAccidentsScreen extends StatefulWidget {
  final UserModel userModel;

  const RecordedAccidentsScreen({super.key, required this.userModel});

  @override
  State<RecordedAccidentsScreen> createState() =>
      _RecordedAccidentsScreenState();
}

class _RecordedAccidentsScreenState extends State<RecordedAccidentsScreen> {
  final DatabaseService _databaseService = DatabaseService();
  List<AccidentReportModel> _reports = [];
  bool _isLoading = true;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  Future<void> _selectStartDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (pickedDate != null) {
      if (!mounted) return;
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_startDate ?? DateTime.now()),
      );

      if (pickedTime != null) {
        setState(() {
          _startDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
        _fetchReports();
      }
    }
  }

  Future<void> _selectEndDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (pickedDate != null) {
      if (!mounted) return;
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_endDate ?? DateTime.now()),
      );

      if (pickedTime != null) {
        setState(() {
          _endDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
        _fetchReports();
      }
    }
  }

  void _clearFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
    _fetchReports();
  }

  Future<void> _fetchReports() async {
    try {
      final allReports = await _databaseService.getResponderReports(
        widget.userModel.id,
      );

      final reports = allReports.where((report) {
        final reportDate = DateTime.fromMillisecondsSinceEpoch(
          report.timestamp,
        );
        if (_startDate != null && reportDate.isBefore(_startDate!)) {
          return false;
        }
        if (_endDate != null && reportDate.isAfter(_endDate!)) {
          return false;
        }
        return true;
      }).toList();
      setState(() {
        _reports = reports;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading reports: $e')));
      }
    }
  }

  Future<void> _updateStatus(
    AccidentReportModel report,
    String newStatus,
  ) async {
    try {
      await _databaseService.updateAccidentReportStatus(report.id, newStatus);
      _fetchReports(); // Refresh list
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating status: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recorded Accidents'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchReports,
            tooltip: 'Refresh',
          ),
          if (_startDate != null || _endDate != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _clearFilters,
              tooltip: 'Clear Filters',
            ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterSection(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _reports.isEmpty
                ? const Center(
                    child: Text(
                      'No accident reports found',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _reports.length,
                    itemBuilder: (context, index) {
                      final report = _reports[index];
                      return Card(
                        elevation: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: InkWell(
                          onTap: () => _showReportDetails(report),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Report #${report.id.substring(report.id.length - 6)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(report.status),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        report.status,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildInfoRow(
                                        Icons.location_on,
                                        'Location: ${report.latitude.toStringAsFixed(4)}, ${report.longitude.toStringAsFixed(4)}',
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.directions,
                                        color: AppColors.primary,
                                      ),
                                      onPressed: () =>
                                          MapHelper.openMapsNavigation(
                                            report.latitude,
                                            report.longitude,
                                          ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Tap for details',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                _buildInfoRow(
                                  Icons.calendar_today,
                                  'Date: ${DateFormat('yyyy-MM-dd').format(DateTime.fromMillisecondsSinceEpoch(report.timestamp))}',
                                ),
                                const SizedBox(height: 8),
                                _buildInfoRow(
                                  Icons.access_time,
                                  'Time: ${DateFormat('HH:mm:ss').format(DateTime.fromMillisecondsSinceEpoch(report.timestamp))}',
                                ),
                                const SizedBox(height: 8),
                                _buildInfoRow(
                                  Icons.person,
                                  'Victim ID: ${report.victimId}',
                                ),
                                const SizedBox(height: 16),
                                const Divider(),
                                const SizedBox(height: 8),
                                const Text(
                                  'Update Status:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SingleChildScrollView(
                                  // Added to prevent overflow if many statuses
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _buildStatusButton(
                                        report,
                                        'Pending',
                                        Colors.orange,
                                      ),
                                      const SizedBox(width: 8), // Spacing
                                      _buildStatusButton(
                                        report,
                                        'Attending',
                                        Colors.blue,
                                      ),
                                      const SizedBox(width: 8), // Spacing
                                      _buildStatusButton(
                                        report,
                                        'Resolved',
                                        Colors.green,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filter by Date Range',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDateButton(
                  label: 'Start Date',
                  date: _startDate,
                  onTap: _selectStartDate,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDateButton(
                  label: 'End Date',
                  date: _endDate,
                  onTap: _selectEndDate,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateButton({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  Text(
                    date != null
                        ? DateFormat('MMM dd, yyyy HH:mm').format(date)
                        : 'Select',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
      ],
    );
  }

  Widget _buildStatusButton(
    AccidentReportModel report,
    String status,
    Color color,
  ) {
    final isSelected = report.status == status;
    return ElevatedButton(
      onPressed: isSelected ? null : () => _updateStatus(report, status),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        disabledBackgroundColor: color.withOpacity(0.5),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: const TextStyle(fontSize: 12),
      ),
      child: Text(status),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.orange;
      case 'Attending':
        return Colors.blue;
      case 'Resolved':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Future<void> _showGuardianDetails(String victimId) async {
    Navigator.pop(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final guardian = await _databaseService.getUserGuardian(victimId);
      Navigator.pop(context); // Dismiss loading

      if (guardian == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No guardian details found for this user'),
            ),
          );
        }
        return;
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Guardian Details'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Name', guardian.name),
                _buildDetailRow('Phone', guardian.phoneNumber),
                _buildDetailRow('Address', guardian.address),
                _buildDetailRow(
                  'Relation',
                  'Guardian',
                ), // Model doesn't have relation yet
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final Uri launchUri = Uri(
                    scheme: 'tel',
                    path: guardian.phoneNumber,
                  );
                  if (await canLaunchUrl(launchUri)) {
                    await launchUrl(launchUri);
                  }
                },
                icon: const Icon(Icons.call),
                label: const Text('Call'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context); // Dismiss loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching guardian details: $e')),
        );
      }
    }
  }

  void _showReportDetails(AccidentReportModel report) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Accident Report Details',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Report #${report.id.substring(report.id.length - 6)}',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              _buildDetailRow(
                'Status',
                report.status,
                color: _getStatusColor(report.status),
              ),
              _buildDetailRow(
                'Time',
                DateFormat(
                  'yyyy-MM-dd HH:mm:ss',
                ).format(DateTime.fromMillisecondsSinceEpoch(report.timestamp)),
              ),
              _buildDetailRow('Victim ID', report.victimId),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                'Medical Information',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              FutureBuilder<UserModel?>(
                future: _databaseService.getUserById(report.victimId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  if (snapshot.hasError || !snapshot.hasData) {
                    return const Text(
                      'Could not load medical information',
                      style: TextStyle(color: Colors.grey),
                    );
                  }

                  final user = snapshot.data!;
                  return Column(
                    children: [
                      _buildDetailRow(
                        'Blood Group',
                        user.bloodGroup
                                ?.toString()
                                .split('.')
                                .last
                                .toBloodGroup() ??
                            'Unknown',
                        color: Colors.red,
                      ),
                      if (user.medicalDescription != null &&
                          user.medicalDescription!.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Medical Description:',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.shade100),
                              ),
                              child: MedicalNotesViewer(
                                medicalDescription: user.medicalDescription,
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                    ],
                  );
                },
              ),
              const Divider(height: 32),
              const Text(
                'Vehicle Data',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildModernInfoChip(
                    icon: Icons.speed_rounded,
                    label: '${report.speed} km/h',
                    color: Colors.blue.shade600,
                  ),
                  _buildModernInfoChip(
                    icon: Icons.local_gas_station_rounded,
                    label: '${report.fuel}%',
                    color: report.fuel < 20
                        ? Colors.orange.shade600
                        : Colors.green.shade600,
                  ),
                  _buildModernInfoChip(
                    icon: Icons.thermostat_rounded,
                    label: '${report.temp.toStringAsFixed(1)}°C',
                    color: report.temp > 90
                        ? Colors.red.shade600
                        : Colors.blue.shade600,
                  ),
                  _buildModernInfoChip(
                    icon: Icons.settings_rounded,
                    label: '${report.rpm} RPM',
                    color: Colors.purple.shade600,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (!report.belt || report.angleWarning) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (!report.belt)
                      _buildModernWarningChip(
                        icon: Icons.warning_rounded,
                        label: 'No Seatbelt',
                      ),
                    if (report.angleWarning)
                      _buildModernWarningChip(
                        icon: Icons.warning_rounded,
                        label: 'Angle Warning',
                      ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              _buildDetailRow(
                'Prediction',
                report.prediction.toUpperCase(),
                color: report.prediction.toUpperCase() == 'DANGEROUS'
                    ? AppColors.error
                    : AppColors.success,
              ),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showGuardianDetails(report.victimId),
                  icon: const Icon(Icons.contact_phone),
                  label: const Text('View Guardian Details'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    MapHelper.openMapsNavigation(
                      report.latitude,
                      report.longitude,
                      label: 'Accident Location',
                    );
                  },
                  icon: const Icon(Icons.map),
                  label: const Text('Navigate to Location'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernWarningChip({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade100, Colors.red.shade100],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade300, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.orange.shade700),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.orange.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
