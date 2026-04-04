import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../utils/app_colors.dart';

class MedicalInfoScreen extends StatefulWidget {
  final UserModel userModel;

  const MedicalInfoScreen({super.key, required this.userModel});

  @override
  State<MedicalInfoScreen> createState() => _MedicalInfoScreenState();
}

class _MedicalInfoScreenState extends State<MedicalInfoScreen> {
  final AuthService _authService = AuthService();
  late QuillController _quillController;
  BloodGroup? _selectedBloodGroup;
  bool _isLoading = false;
  bool _isEditMode = false;
  final FocusNode _editorFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);

    try {
      // Fetch fresh user data from database
      final freshUserData = await _authService.getUserById(widget.userModel.id);

      if (freshUserData != null) {
        _selectedBloodGroup = freshUserData.bloodGroup;
        _initializeQuillController(freshUserData.medicalDescription);
      } else {
        // Fallback to passed userModel if fetch fails
        _selectedBloodGroup = widget.userModel.bloodGroup;
        _initializeQuillController(widget.userModel.medicalDescription);
      }
    } catch (e) {
      // Fallback to passed userModel if error occurs
      _selectedBloodGroup = widget.userModel.bloodGroup;
      _initializeQuillController(widget.userModel.medicalDescription);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _initializeQuillController(String? medicalDescription) {
    try {
      if (medicalDescription != null && medicalDescription.isNotEmpty) {
        final json = jsonDecode(medicalDescription);
        _quillController = QuillController(
          document: Document.fromJson(json),
          selection: const TextSelection.collapsed(offset: 0),
        );
      } else {
        _quillController = QuillController.basic();
      }
    } catch (e) {
      // Fallback if JSON parsing fails
      _quillController = QuillController.basic();
    }
  }

  @override
  void dispose() {
    _quillController.dispose();
    _editorFocusNode.dispose();
    super.dispose();
  }

  Future<void> _saveMedicalInfo() async {
    setState(() => _isLoading = true);

    try {
      // Serialize Delta to JSON string
      final json = jsonEncode(_quillController.document.toDelta().toJson());

      await _authService.updateUserProfile(
        userId: widget.userModel.id,
        bloodGroup: _selectedBloodGroup,
        medicalDescription: json,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Medical information updated successfully'),
            backgroundColor: AppColors.success,
          ),
        );

        setState(() {
          _isEditMode = false;
          _loadUserData();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medical Information'),
        actions: [
          if (!_isEditMode && !_isLoading)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() => _isEditMode = true);
              },
              tooltip: 'Edit',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isEditMode
          ? _buildEditMode()
          : _buildViewMode(),
      floatingActionButton: _isEditMode
          ? FloatingActionButton.extended(
              onPressed: _saveMedicalInfo,
              icon: const Icon(Icons.save),
              label: const Text('Save'),
            )
          : null,
    );
  }

  Widget _buildViewMode() {
    final bloodGroupText = _selectedBloodGroup != null
        ? _selectedBloodGroup
              .toString()
              .split('.')
              .last
              .toUpperCase()
              .replaceAll('PLUS', '+')
              .replaceAll('MINUS', '-')
        : 'Not set';

    // Get plain text from Quill document
    final medicalNotesText = _quillController.document.toPlainText().trim();
    final hasMedicalNotes = medicalNotesText.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Info banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.primary, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your medical information can be vital in emergencies',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Blood Type Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.bloodtype,
                          color: AppColors.primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Blood Type',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              bloodGroupText,
                              style: TextStyle(
                                fontSize: 24,
                                color: _selectedBloodGroup != null
                                    ? AppColors.textPrimary
                                    : AppColors.textTertiary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Medical Notes Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.medical_services,
                          color: AppColors.accent,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Medical Notes',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(color: AppColors.greyLight),
                  const SizedBox(height: 16),
                  hasMedicalNotes
                      ? QuillEditor.basic(
                          controller: _quillController,
                          config: QuillEditorConfig(
                            padding: EdgeInsets.zero,
                            enableInteractiveSelection: false,
                            customStyles: DefaultStyles(
                              paragraph: DefaultTextBlockStyle(
                                const TextStyle(
                                  fontSize: 16,
                                  color: AppColors.textPrimary,
                                  height: 1.5,
                                ),
                                const HorizontalSpacing(0, 0),
                                const VerticalSpacing(0, 0),
                                const VerticalSpacing(0, 0),
                                null,
                              ),
                            ),
                          ),
                        )
                      : Text(
                          'No medical notes added yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.textTertiary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditMode() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cancel button
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                setState(() => _isEditMode = false);
              },
              icon: const Icon(Icons.close),
              label: const Text('Cancel'),
            ),
          ),
          const SizedBox(height: 8),

          // Blood Group Dropdown
          DropdownButtonFormField<BloodGroup>(
            value: _selectedBloodGroup,
            decoration: const InputDecoration(
              labelText: 'Blood Type',
              prefixIcon: Icon(Icons.bloodtype),
              border: OutlineInputBorder(),
            ),
            items: BloodGroup.values.map((group) {
              return DropdownMenuItem(
                value: group,
                child: Text(
                  group
                      .toString()
                      .split('.')
                      .last
                      .toUpperCase()
                      .replaceAll('PLUS', '+')
                      .replaceAll('MINUS', '-'),
                  style: const TextStyle(fontSize: 16),
                ),
              );
            }).toList(),
            onChanged: (val) {
              setState(() => _selectedBloodGroup = val);
            },
          ),

          const SizedBox(height: 16),

          // Medical Description with Quill Editor
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Medical Notes',
              border: OutlineInputBorder(),
              prefixIcon: Padding(
                padding: EdgeInsets.only(bottom: 110),
                child: Icon(Icons.medical_services),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Toolbar
                QuillSimpleToolbar(
                  controller: _quillController,
                  config: const QuillSimpleToolbarConfig(
                    showFontFamily: false,
                    showFontSize: true,
                    showCodeBlock: false,
                    showInlineCode: false,
                    showLink: false,
                    showSearchButton: false,
                    headerStyleType: HeaderStyleType.buttons,
                    multiRowsDisplay: false,
                  ),
                ),
                const Divider(),

                // Editor
                SizedBox(
                  height: 200,
                  child: QuillEditor.basic(
                    controller: _quillController,
                    config: QuillEditorConfig(
                      placeholder:
                          'Enter allergies, chronic conditions, etc...',
                      padding: const EdgeInsets.all(8),
                      autoFocus: false,
                      customStyles: DefaultStyles(
                        paragraph: DefaultTextBlockStyle(
                          const TextStyle(
                            fontSize: 16,
                            color: AppColors.textPrimary,
                          ),
                          const HorizontalSpacing(0, 0),
                          const VerticalSpacing(0, 0),
                          const VerticalSpacing(0, 0),
                          null,
                        ),
                        placeHolder: DefaultTextBlockStyle(
                          const TextStyle(
                            fontSize: 16,
                            color: AppColors.textTertiary,
                          ),
                          const HorizontalSpacing(0, 0),
                          const VerticalSpacing(0, 0),
                          const VerticalSpacing(0, 0),
                          null,
                        ),
                      ),
                    ),
                    focusNode: _editorFocusNode,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 80), // Space for FAB
        ],
      ),
    );
  }
}
