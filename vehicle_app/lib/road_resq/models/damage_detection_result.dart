import '../../common/claim_status.dart';
import '../utils/label_formatters.dart';
import 'assessment_metadata.dart';
import 'json_parsing.dart';

class DamageDetectionResult {
  final String damageType;
  final int severityScore;
  final double confidence;
  final Map<String, double> probabilities;
  final List<String> detectedDamages;
  final DamageDetails damageDetails;
  final VehicleSnapshot? vehicle;
  final PartMapping? partMapping;
  final PriceEstimation? priceEstimation;
  final AiValidation? aiValidation;
  final String? claimId;
  final String? status;
  final String? assessmentId;
  final String? imageHash;
  final String? timestamp;
  final double? processingTimeSeconds;
  final Map<String, dynamic> workflow;

  DamageDetectionResult({
    required this.damageType,
    required this.severityScore,
    required this.confidence,
    required this.probabilities,
    required this.detectedDamages,
    required this.damageDetails,
    this.vehicle,
    this.partMapping,
    this.priceEstimation,
    this.aiValidation,
    this.claimId,
    this.status,
    this.assessmentId,
    this.imageHash,
    this.timestamp,
    this.processingTimeSeconds,
    this.workflow = const <String, dynamic>{},
  });

  bool get hasClaimRecord => claimId != null && claimId!.isNotEmpty;
  bool get hasPriceEstimate =>
      priceEstimation != null && priceEstimation!.estimatedPrice > 0;

  String get displayDamageType => humanizeRoadResqLabel(damageType);

  String get displayStatus {
    return presentClaimStatusLabel(status, hasClaimRecord: hasClaimRecord);
  }

  factory DamageDetectionResult.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('damage_type')) {
      return DamageDetectionResult._fromLegacyJson(json);
    }
    return DamageDetectionResult._fromAssessmentJson(json);
  }

  factory DamageDetectionResult._fromLegacyJson(Map<String, dynamic> json) {
    return DamageDetectionResult(
      damageType: json['damage_type']?.toString() ?? '',
      severityScore: jsonToInt(json['severity_score']),
      confidence: jsonToDouble(json['confidence']),
      probabilities: jsonAsDoubleMap(json['probabilities']),
      detectedDamages: jsonAsStringList(json['detected_damages']),
      damageDetails: DamageDetails.fromJson(jsonAsMap(json['damage_details'])),
    );
  }

  factory DamageDetectionResult._fromAssessmentJson(Map<String, dynamic> json) {
    final detection = jsonAsMap(json['damage_detection']);
    final detectedDamages = jsonAsStringList(detection['detected_damages']);
    final probabilities = jsonAsDoubleMap(detection['confidences']);
    final confidence = probabilities.values.isEmpty
        ? 0.0
        : probabilities.values.reduce(
            (left, right) => left > right ? left : right,
          );
    final vehicle = VehicleSnapshot.fromJson(jsonAsMap(json['vehicle']));
    final partMapping = PartMapping.fromJson(jsonAsMap(json['part_mapping']));
    final priceEstimation =
        PriceEstimation.fromJson(jsonAsMap(json['price_estimation']));
    final aiValidation = json['ai_validation'] == null
        ? null
        : AiValidation.fromJson(jsonAsMap(json['ai_validation']));

    return DamageDetectionResult(
      damageType: detectedDamages.isNotEmpty
          ? detectedDamages.first
          : (partMapping.affectedPart?.isNotEmpty ?? false)
              ? partMapping.affectedPart!
              : 'unknown_damage',
      severityScore: jsonToInt(detection['num_damages']) == 0
          ? detectedDamages.length
          : jsonToInt(detection['num_damages']),
      confidence: confidence,
      probabilities: probabilities,
      detectedDamages: detectedDamages,
      damageDetails: DamageDetails.fromAssessmentJson(
        detectedDamages: detectedDamages,
        partMapping: partMapping,
        priceEstimation: priceEstimation,
        aiValidation: aiValidation,
      ),
      vehicle: vehicle,
      partMapping: partMapping,
      priceEstimation: priceEstimation,
      aiValidation: aiValidation,
      claimId: jsonNullableString(json['claim_id']),
      status: jsonNullableString(json['status']),
      assessmentId: jsonNullableString(json['assessment_id']),
      imageHash: jsonNullableString(json['image_hash']),
      timestamp: jsonNullableString(json['timestamp']),
      processingTimeSeconds: json['processing_time_seconds'] == null
          ? null
          : jsonToDouble(json['processing_time_seconds']),
      workflow: jsonAsMap(json['workflow']),
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
      'vehicle': vehicle?.toJson(),
      'part_mapping': partMapping?.toJson(),
      'price_estimation': priceEstimation?.toJson(),
      'ai_validation': aiValidation?.toJson(),
      'claim_id': claimId,
      'status': status,
      'assessment_id': assessmentId,
      'image_hash': imageHash,
      'timestamp': timestamp,
      'processing_time_seconds': processingTimeSeconds,
      'workflow': workflow,
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
      description: json['description']?.toString() ?? '',
      whatHappened: json['what_happened']?.toString() ?? '',
      immediateActions: jsonAsStringList(json['immediate_actions']),
      repairOptions: jsonAsStringList(json['repair_options']),
      urgency: json['urgency']?.toString() ?? '',
      estimatedTime: json['estimated_time']?.toString() ?? '',
      preventionTips: json['prevention_tips']?.toString() ?? '',
    );
  }

  factory DamageDetails.fromAssessmentJson({
    required List<String> detectedDamages,
    required PartMapping partMapping,
    required PriceEstimation priceEstimation,
    required AiValidation? aiValidation,
  }) {
    final affectedPart = partMapping.displayAffectedPart;
    final reviewFlags = priceEstimation.reviewFlags;
    final recommendedPhotos = priceEstimation.recommendedPhotos;
    final damageLabels =
        detectedDamages.map(humanizeRoadResqLabel).toList();
    final hasCriticalDamage = detectedDamages.any(
      (damage) => const {
        'glass_shatter',
        'glass shatter',
        'tire_flat',
        'tire flat',
        'lamp_broken',
        'lamp broken',
      }.contains(damage.toLowerCase()),
    );

    final immediateActions = <String>[
      if (priceEstimation.manualReviewRequired)
        'Arrange a manual inspection before final insurer approval.',
      if (recommendedPhotos.isNotEmpty)
        'Capture additional views: ${recommendedPhotos.map(humanizeRoadResqLabel).join(', ')}.',
      if (detectedDamages.isNotEmpty)
        'Document the damaged area and keep the vehicle safe until inspection.',
      if (detectedDamages.isEmpty)
        'No visible damage was detected. Re-take the photo if you expected a different result.',
    ];

    final repairOptions = <String>[
      if (priceEstimation.estimatedPrice > 0)
        'Use the estimated range as a guide when comparing garage and insurer quotes.',
      if (partMapping.affectedPart != null)
        'Request a panel-by-panel inspection for the $affectedPart.',
      if (reviewFlags.isNotEmpty)
        'Review flagged estimate assumptions before approving repairs.',
      if (priceEstimation.estimatedPrice <= 0)
        'Visit a recommended garage for a detailed inspection.',
    ];

    final urgency = hasCriticalDamage
        ? 'high'
        : priceEstimation.manualReviewRequired
            ? 'medium-high'
            : detectedDamages.isEmpty
                ? 'low'
                : 'medium';

    return DamageDetails(
      description: aiValidation?.damageAnalysis ??
          'Damage assessment generated from the claims estimator.',
      whatHappened: detectedDamages.isEmpty
          ? 'No visible damage was detected in the submitted image.'
          : 'Detected ${damageLabels.join(', ')} around the ${affectedPart.toLowerCase()}.',
      immediateActions: immediateActions,
      repairOptions: repairOptions,
      urgency: urgency,
      estimatedTime: detectedDamages.isEmpty
          ? 'No repair required'
          : priceEstimation.manualReviewRequired
              ? 'Inspection required before confirming the timeline'
              : 'Timeline to be confirmed by the garage',
      preventionTips:
          'Take clear, well-lit photos from multiple angles and keep repair records for insurer follow-up.',
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
