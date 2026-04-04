import 'dart:io';
import 'package:flutter/material.dart';
import '../services/classifier_service.dart';
import '../models/warning_info.dart';

enum AppState { initial, modelLoading, modelReady, predicting, done, error }

class ClassifierProvider extends ChangeNotifier {
  final ClassifierService _service = ClassifierService();

  AppState _state = AppState.initial;
  File? _selectedImage;
  PredictionResult? _result;
  WarningInfo? _warningInfo;
  String? _errorMessage;

  AppState get state => _state;
  File? get selectedImage => _selectedImage;
  PredictionResult? get result => _result;
  WarningInfo? get warningInfo => _warningInfo;
  String? get errorMessage => _errorMessage;
  bool get isModelReady => _service.isLoaded;

  ClassifierProvider() {
    _initModel();
  }

  Future<void> _initModel() async {
    _state = AppState.modelLoading;
    notifyListeners();

    try {
      await _service.loadModel();
      _state = AppState.modelReady;
    } catch (e) {
      _state = AppState.error;
      _errorMessage = 'Failed to load model: $e';
    }
    notifyListeners();
  }

  /// Called after image is picked from camera or gallery
  Future<void> classifyImage(File imageFile) async {
    _selectedImage = imageFile;
    _result = null;
    _warningInfo = null;
    _state = AppState.predicting;
    notifyListeners();

    try {
      final prediction = await _service.predict(imageFile); 
      _result = prediction;
      _warningInfo = WarningDatabase.getWarning(prediction.prediction);
      _state = AppState.done;
    } catch (e) {
      _state = AppState.error;
      _errorMessage = 'Prediction failed: $e';
    }
    notifyListeners();
  }

  void reset() {
    _selectedImage = null;
    _result = null;
    _warningInfo = null;
    _errorMessage = null;
    _state = AppState.modelReady;
    notifyListeners();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}
