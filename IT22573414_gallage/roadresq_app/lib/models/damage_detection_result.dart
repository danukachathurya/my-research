class DamageDetectionResult {
  final String damageType;
  final int severityScore;
  final double confidence;
  final Map<String, double> probabilities;
  final List<String> detectedDamages;
  final DamageDetails damageDetails;

  DamageDetectionResult({
    required this.damageType,
    required this.severityScore,
    required this.confidence,
    required this.probabilities,
    required this.detectedDamages,
    required this.damageDetails,
  });

  factory DamageDetectionResult.fromJson(Map<String, dynamic> json) {
    return DamageDetectionResult(
      damageType: json['damage_type'] ?? '',
      severityScore: json['severity_score'] ?? 0,
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      probabilities: Map<String, double>.from(
        (json['probabilities'] ?? {}).map(
          (key, value) => MapEntry(key, (value ?? 0.0).toDouble()),
        ),
      ),
      detectedDamages: List<String>.from(json['detected_damages'] ?? []),
      damageDetails: DamageDetails.fromJson(json['damage_details'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'damage_type': damageType,
      'severity_score': severityScore,
      'confidence': confidence,
      'probabilities': probabilities,
      'detected_damages': detectedDamages,
      'damage_details': damageDetails.toJson(),
    };
  }
}

class DamageDetails {
  final String description;
  final String whatHappened;
  final List<String> immediateActions;
  final List<String> repairOptions;
  final String urgency;
  final String estimatedTime;
  final String preventionTips;

  DamageDetails({
    required this.description,
    required this.whatHappened,
    required this.immediateActions,
    required this.repairOptions,
    required this.urgency,
    required this.estimatedTime,
    required this.preventionTips,
  });

  factory DamageDetails.fromJson(Map<String, dynamic> json) {
    return DamageDetails(
      description: json['description'] ?? '',
      whatHappened: json['what_happened'] ?? '',
      immediateActions: List<String>.from(json['immediate_actions'] ?? []),
      repairOptions: List<String>.from(json['repair_options'] ?? []),
      urgency: json['urgency'] ?? '',
      estimatedTime: json['estimated_time'] ?? '',
      preventionTips: json['prevention_tips'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'description': description,
      'what_happened': whatHappened,
      'immediate_actions': immediateActions,
      'repair_options': repairOptions,
      'urgency': urgency,
      'estimated_time': estimatedTime,
      'prevention_tips': preventionTips,
    };
  }
}
