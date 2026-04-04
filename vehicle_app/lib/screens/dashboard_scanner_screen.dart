import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/classifier_provider.dart';
import '../widgets/result_card.dart';

class DashboardScannerScreen extends StatefulWidget {
  const DashboardScannerScreen({super.key});

  @override
  State<DashboardScannerScreen> createState() => _DashboardScannerScreenState();
}

class _DashboardScannerScreenState extends State<DashboardScannerScreen> {
  // Provider is created once and held in state — survives camera lifecycle
  final ClassifierProvider _provider = ClassifierProvider();
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (picked != null && mounted) {
        await _provider.classifyImage(File(picked.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not pick image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ClassifierProvider>.value(
      value: _provider,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0D1A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0D0D1A),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white70),
            onPressed: () => Navigator.pop(context),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A237E),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.document_scanner,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dashboard Scanner',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Vehicle Indicator Classifier',
                    style: TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
        body: Consumer<ClassifierProvider>(
          builder: (context, provider, _) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Model status banner ──────────────────────────
                  _ModelStatusBanner(
                    currentState: provider.state,
                    isReady: provider.isModelReady,
                  ),
                  const SizedBox(height: 20),

                  // ── Image preview ────────────────────────────────
                  _ImagePreviewArea(
                    image: provider.selectedImage,
                    currentState: provider.state,
                  ),
                  const SizedBox(height: 20),

                  // ── Camera / Gallery buttons ─────────────────────
                  if (provider.state != AppState.predicting &&
                      provider.state != AppState.modelLoading)
                    _PickerButtons(onPick: _pickImage),

                  // ── Analysing spinner ────────────────────────────
                  if (provider.state == AppState.predicting)
                    const _PredictingIndicator(),

                  const SizedBox(height: 20),

                  // ── Result card ──────────────────────────────────
                  if (provider.state == AppState.done &&
                      provider.result != null)
                    ResultCard(
                      result: provider.result!,
                      warningInfo: provider.warningInfo,
                    ),

                  // ── Error card ───────────────────────────────────
                  if (provider.state == AppState.error)
                    _ErrorCard(
                        message: provider.errorMessage ?? 'Unknown error'),

                  // ── Scan another button ──────────────────────────
                  if (provider.state == AppState.done ||
                      provider.state == AppState.error)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: OutlinedButton.icon(
                        onPressed: provider.reset,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Scan Another'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white24),
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 30),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Camera + Gallery buttons (inline, no separate widget file needed)
// ─────────────────────────────────────────────
class _PickerButtons extends StatelessWidget {
  final Future<void> Function(ImageSource) onPick;
  const _PickerButtons({required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _PickerButton(
            icon: Icons.camera_alt,
            label: 'Camera',
            color: const Color(0xFF1A237E),
            onTap: () => onPick(ImageSource.camera),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _PickerButton(
            icon: Icons.photo_library,
            label: 'Gallery',
            color: const Color(0xFF283593),
            onTap: () => onPick(ImageSource.gallery),
          ),
        ),
      ],
    );
  }
}

class _PickerButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _PickerButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withOpacity(0.7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Model status banner
// ─────────────────────────────────────────────
class _ModelStatusBanner extends StatelessWidget {
  final AppState currentState;
  final bool isReady;

  const _ModelStatusBanner(
      {required this.currentState, required this.isReady});

  @override
  Widget build(BuildContext context) {
    if (currentState == AppState.modelLoading) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.orange.withOpacity(0.4)),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.orange),
            ),
            SizedBox(width: 10),
            Text('Loading AI model...',
                style: TextStyle(color: Colors.orange, fontSize: 13)),
          ],
        ),
      );
    }

    if (isReady) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.green.withOpacity(0.35)),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 16),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'AI Model Ready  •  EfficientNetB0  •  11 Classes',
                style: TextStyle(color: Colors.green, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

// ─────────────────────────────────────────────
// Image preview area
// ─────────────────────────────────────────────
class _ImagePreviewArea extends StatelessWidget {
  final File? image;
  final AppState currentState;

  const _ImagePreviewArea(
      {required this.image, required this.currentState});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 260,
      decoration: BoxDecoration(
        color: const Color(0xFF141428),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      clipBehavior: Clip.antiAlias,
      child: image != null
          ? Stack(
              fit: StackFit.expand,
              children: [
                Image.file(image!, fit: BoxFit.cover),
                Container(color: Colors.black26),
                if (currentState == AppState.predicting)
                  const Center(
                    child:
                        CircularProgressIndicator(color: Colors.white),
                  ),
              ],
            )
          : const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_photo_alternate_outlined,
                    size: 64, color: Colors.white24),
                SizedBox(height: 12),
                Text(
                  'Take or select a photo of your vehicle dashboard indicator',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(color: Colors.white38, fontSize: 14),
                ),
              ],
            ),
    );
  }
}

// ─────────────────────────────────────────────
// Analysing spinner
// ─────────────────────────────────────────────
class _PredictingIndicator extends StatelessWidget {
  const _PredictingIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A237E).withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
              strokeWidth: 2, color: Color(0xFF5C6BC0)),
          SizedBox(width: 14),
          Text(
            'Analysing dashboard indicator...',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Error card
// ─────────────────────────────────────────────
class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: const TextStyle(color: Colors.red, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}