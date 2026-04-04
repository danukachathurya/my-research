import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:image/image.dart' as img;

class ClassifierService {
  static const int INPUT_SIZE = 224;

  OrtSession? _classifierSession;
  OrtSession? _featureSession;

  List<String> _labels = [];
  double _threshold = 50.0;
  bool _isLoaded = false;

  String _classifierInputName = 'input';
  String _featureInputName = 'input';

  bool get isLoaded => _isLoaded;

  Future<void> loadModel() async {
    try {
      OrtEnv.instance.init();

      // ── Classifier ONNX ───────────────────────────────────
      final classifierBytes = await rootBundle.load(
        'assets/models/dashboard_classifier_ood.onnx',
      );
      _classifierSession = OrtSession.fromBuffer(
        classifierBytes.buffer.asUint8List(),
        OrtSessionOptions(),
      );
      _classifierInputName = _classifierSession!.inputNames.first;

      // ── Feature extractor ONNX ────────────────────────────
      final featureBytes = await rootBundle.load(
        'assets/models/feature_extractor.onnx',
      );
      _featureSession = OrtSession.fromBuffer(
        featureBytes.buffer.asUint8List(),
        OrtSessionOptions(),
      );
      _featureInputName = _featureSession!.inputNames.first;

      // ── labels.json ───────────────────────────────────────
      final labelsRaw = await rootBundle.loadString(
        'assets/models/labels.json',
      );
      _labels = List<String>.from(jsonDecode(labelsRaw));

      // ── ood_config.json — only need threshold ─────────────
      final oodRaw = await rootBundle.loadString(
        'assets/models/ood_config.json',
      );
      final oodConfig = jsonDecode(oodRaw) as Map<String, dynamic>;
      _threshold = (oodConfig['threshold'] as num).toDouble();

      _isLoaded = true;
      print('✅ Loaded | Labels: ${_labels.length} | Threshold: $_threshold');
    } catch (e, stack) {
      _isLoaded = false;
      print('❌ Load failed: $e\n$stack');
      rethrow;
    }
  }

  /// Raw [0,255] — EfficientNet preprocessing baked into ONNX
  Float32List _preprocessImage(File imageFile) {
    final bytes = imageFile.readAsBytesSync();
    img.Image? image = img.decodeImage(bytes);
    if (image == null) throw Exception('Failed to decode image');
    image = img.copyResize(
      image,
      width: INPUT_SIZE,
      height: INPUT_SIZE,
      interpolation: img.Interpolation.linear,
    );

    final input = Float32List(INPUT_SIZE * INPUT_SIZE * 3);
    int idx = 0;
    for (int y = 0; y < INPUT_SIZE; y++) {
      for (int x = 0; x < INPUT_SIZE; x++) {
        final pixel = image.getPixel(x, y);
        input[idx++] = pixel.r.toDouble();
        input[idx++] = pixel.g.toDouble();
        input[idx++] = pixel.b.toDouble();
      }
    }
    return input;
  }

  List<double> _softmax(List<double> x) {
    final m = x.reduce(max);
    final e = x.map((v) => exp(v - m)).toList();
    final s = e.reduce((a, b) => a + b);
    return e.map((v) => v / s).toList();
  }

  List<double> _extractList(dynamic raw) {
    if (raw is List<List<double>>) return raw[0];
    if (raw is List<List<dynamic>>)
      return raw[0].map((e) => (e as num).toDouble()).toList();
    if (raw is List<double>) return raw;
    if (raw is List<dynamic>)
      return raw.map((e) => (e as num).toDouble()).toList();
    if (raw is Float32List) return raw.map((e) => e.toDouble()).toList();
    if (raw is Float64List) return raw.map((e) => e.toDouble()).toList();
    throw Exception('Cannot extract list from: ${raw.runtimeType}');
  }

  Future<PredictionResult> predict(File imageFile) async {
    if (!_isLoaded) throw Exception('Model not loaded.');

    final inputData = _preprocessImage(imageFile);

    final clsTensor = OrtValueTensor.createTensorWithDataList(inputData, [
      1,
      INPUT_SIZE,
      INPUT_SIZE,
      3,
    ]);
    final clsOutputs = await _classifierSession!.runAsync(OrtRunOptions(), {
      _classifierInputName: clsTensor,
    });

    final rawOutput = _extractList(clsOutputs?.first?.value);
    clsTensor.release();
    clsOutputs?.forEach((e) => e?.release());

    // ── Auto-detect logits vs probabilities ──────────────────
    // Probabilities always sum to ~1.0 and are all in [0,1]
    // Logits can be any value (negative, >1, sum != 1)
    final rawSum = rawOutput.reduce((a, b) => a + b);
    final hasNegative = rawOutput.any((v) => v < 0);
    final isLogits = hasNegative || (rawSum - 1.0).abs() > 0.01;

    final probs = isLogits ? _softmax(rawOutput) : rawOutput;
    final probSum = probs.reduce((a, b) => a + b);

    final maxScore = probs.reduce((a, b) => a > b ? a : b);
    final maxIndex = probs.indexOf(maxScore);
    // ── OOD: confidence threshold ─────────────────────────────
    // Calibrated from real device logs:
    //   Real dashboard images:  45–100% (lowest seen: 45.5%)
    //   Unrelated images:       21–38%
    // Threshold at 70% cleanly separates the two groups
    const double confidenceThreshold = 0.70;
    final bool isOOD = maxScore < confidenceThreshold;
    // ── Sorted scores ─────────────────────────────────────────
    final scores = <String, double>{};
    for (int i = 0; i < _labels.length && i < probs.length; i++) {
      scores[_labels[i]] = probs[i];
    }
    final sortedScores = Map.fromEntries(
      scores.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );

    return PredictionResult(
      prediction: isOOD ? null : _labels[maxIndex],
      confidence: maxScore,
      isOOD: isOOD,
      allScores: sortedScores,
    );
  }

  void dispose() {
    _classifierSession?.release();
    _featureSession?.release();
    OrtEnv.instance.release();
    _isLoaded = false;
  }
}

class PredictionResult {
  final String? prediction;
  final double confidence;
  final bool isOOD;
  final Map<String, double> allScores;

  PredictionResult({
    required this.prediction,
    required this.confidence,
    required this.isOOD,
    required this.allScores,
  });
}
