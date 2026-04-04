import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

class MedicalNotesViewer extends StatefulWidget {
  final String? medicalDescription;

  const MedicalNotesViewer({super.key, required this.medicalDescription});

  @override
  State<MedicalNotesViewer> createState() => _MedicalNotesViewerState();
}

class _MedicalNotesViewerState extends State<MedicalNotesViewer> {
  late QuillController _quillController;
  bool _isValidJson = false;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  @override
  void didUpdateWidget(covariant MedicalNotesViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.medicalDescription != oldWidget.medicalDescription) {
      _initializeController();
    }
  }

  void _initializeController() {
    try {
      if (widget.medicalDescription != null &&
          widget.medicalDescription!.isNotEmpty) {
        final json = jsonDecode(widget.medicalDescription!);
        _quillController = QuillController(
          document: Document.fromJson(json),
          selection: const TextSelection.collapsed(offset: 0),
          readOnly: true,
        );
        _isValidJson = true;
      } else {
        _setEmptyController();
      }
    } catch (e) {
      // Fallback if JSON parsing fails - might be plain text or invalid
      _isValidJson = false;
      _setEmptyController();
    }
  }

  void _setEmptyController() {
    _quillController = QuillController(
      document: Document(),
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: true,
    );
  }

  @override
  void dispose() {
    _quillController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.medicalDescription == null ||
        widget.medicalDescription!.isEmpty) {
      return Container(); // Or a placeholder if preferred
    }

    if (!_isValidJson) {
      // If not valid valid JSON, display as plain text (legacy support)
      return Text(
        widget.medicalDescription!,
        style: const TextStyle(fontSize: 14, color: Colors.black87),
      );
    }

    return QuillEditor.basic(
      controller: _quillController,
      config: QuillEditorConfig(
        padding: EdgeInsets.zero,
        enableInteractiveSelection: false,
        customStyles: DefaultStyles(
          paragraph: DefaultTextBlockStyle(
            const TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
            const HorizontalSpacing(0, 0),
            const VerticalSpacing(0, 0),
            const VerticalSpacing(0, 0),
            null,
          ),
        ),
      ),
    );
  }
}
