import 'json_parsing.dart';
import '../utils/label_formatters.dart';

class VehicleSnapshot {
  final String brand;
  final String model;
  final String year;

  const VehicleSnapshot({
    required this.brand,
    required this.model,
    required this.year,
  });

  String get displayName =>
      [brand, model, year].where((value) => value.trim().isNotEmpty).join(' ');

  factory VehicleSnapshot.fromJson(Map<String, dynamic> json) {
    return VehicleSnapshot(
      brand: json['brand']?.toString() ?? '',
      model: json['model']?.toString() ?? '',
      year: json['year']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'brand': brand,
      'model': model,
      'year': year,
    };
  }
}

class PartMapping {
  final String? affectedPart;
  final String? rawAffectedPart;
  final List<String> mappedFrom;

  const PartMapping({
    this.affectedPart,
    this.rawAffectedPart,
    this.mappedFrom = const <String>[],
  });

  String get displayAffectedPart =>
      humanizeRoadResqLabel(affectedPart ?? 'unknown area');

  factory PartMapping.fromJson(Map<String, dynamic> json) {
    return PartMapping(
      affectedPart: jsonNullableString(json['affected_part']),
      rawAffectedPart: jsonNullableString(json['raw_affected_part']),
      mappedFrom: jsonAsStringList(json['mapped_from']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'affected_part': affectedPart,
      'raw_affected_part': rawAffectedPart,
      'mapped_from': mappedFrom,
    };
  }
}

class PriceEstimation {
  final double estimatedPrice;
  final String currency;
  final String method;
  final PriceBreakdown breakdown;
  final List<Map<String, dynamic>> referencePrices;
  final List<String> severitySummary;
  final int? confidenceScore;
  final List<String> recommendedPhotos;
  final List<String> assumptions;
  final Map<String, dynamic> scope;
  final EstimateRange? estimateRange;
  final PricingConfidence? pricingConfidence;
  final ReferenceQuality? referenceQuality;
  final List<String> reviewFlags;
  final PricingPolicy? pricingPolicy;

  const PriceEstimation({
    required this.estimatedPrice,
    required this.currency,
    required this.method,
    required this.breakdown,
    required this.referencePrices,
    required this.severitySummary,
    required this.confidenceScore,
    required this.recommendedPhotos,
    required this.assumptions,
    required this.scope,
    required this.estimateRange,
    required this.pricingConfidence,
    required this.referenceQuality,
    required this.reviewFlags,
    required this.pricingPolicy,
  });

  bool get hasBreakdown => !breakdown.isEmpty;
  bool get manualReviewRequired =>
      pricingConfidence?.manualReviewRequired ?? false;
  String get displayMethod => humanizeRoadResqLabel(method);

  factory PriceEstimation.fromJson(Map<String, dynamic> json) {
    final references = json['reference_prices'] is List
        ? (json['reference_prices'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : const <Map<String, dynamic>>[];

    final rawConfidenceScore = json['confidence_score'];
    return PriceEstimation(
      estimatedPrice: jsonToDouble(json['estimated_price']),
      currency: jsonNullableString(json['currency']) ?? 'LKR',
      method: jsonNullableString(json['method']) ?? 'unknown',
      breakdown: PriceBreakdown.fromJson(jsonAsMap(json['breakdown'])),
      referencePrices: references,
      severitySummary: jsonAsStringList(json['severity_summary']),
      confidenceScore:
          rawConfidenceScore == null ? null : jsonToInt(rawConfidenceScore),
      recommendedPhotos: jsonAsStringList(json['recommended_photos']),
      assumptions: jsonAsStringList(json['assumptions']),
      scope: jsonAsMap(json['scope']),
      estimateRange: jsonAsMap(json['estimate_range']).isEmpty
          ? null
          : EstimateRange.fromJson(jsonAsMap(json['estimate_range'])),
      pricingConfidence: jsonAsMap(json['pricing_confidence']).isEmpty
          ? null
          : PricingConfidence.fromJson(jsonAsMap(json['pricing_confidence'])),
      referenceQuality: jsonAsMap(json['reference_quality']).isEmpty
          ? null
          : ReferenceQuality.fromJson(jsonAsMap(json['reference_quality'])),
      reviewFlags: jsonAsStringList(json['review_flags']),
      pricingPolicy: jsonAsMap(json['pricing_policy']).isEmpty
          ? null
          : PricingPolicy.fromJson(jsonAsMap(json['pricing_policy'])),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'estimated_price': estimatedPrice,
      'currency': currency,
      'method': method,
      'breakdown': breakdown.toJson(),
      'reference_prices': referencePrices,
      'severity_summary': severitySummary,
      'confidence_score': confidenceScore,
      'recommended_photos': recommendedPhotos,
      'assumptions': assumptions,
      'scope': scope,
      'estimate_range': estimateRange?.toJson(),
      'pricing_confidence': pricingConfidence?.toJson(),
      'reference_quality': referenceQuality?.toJson(),
      'review_flags': reviewFlags,
      'pricing_policy': pricingPolicy?.toJson(),
    };
  }
}

class PriceBreakdown {
  final double parts;
  final double paint;

  const PriceBreakdown({
    this.parts = 0.0,
    this.paint = 0.0,
  });

  bool get isEmpty => parts <= 0 && paint <= 0;

  factory PriceBreakdown.fromJson(Map<String, dynamic> json) {
    return PriceBreakdown(
      parts: jsonToDouble(json['parts']),
      paint: jsonToDouble(json['paint']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'parts': parts,
      'paint': paint,
    };
  }
}

class EstimateRange {
  final double min;
  final double max;
  final double toleranceRatio;

  const EstimateRange({
    required this.min,
    required this.max,
    required this.toleranceRatio,
  });

  factory EstimateRange.fromJson(Map<String, dynamic> json) {
    return EstimateRange(
      min: jsonToDouble(json['min']),
      max: jsonToDouble(json['max']),
      toleranceRatio: jsonToDouble(json['tolerance_ratio']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'min': min,
      'max': max,
      'tolerance_ratio': toleranceRatio,
    };
  }
}

class PricingConfidence {
  final int score;
  final String level;
  final bool manualReviewRequired;

  const PricingConfidence({
    required this.score,
    required this.level,
    required this.manualReviewRequired,
  });

  factory PricingConfidence.fromJson(Map<String, dynamic> json) {
    return PricingConfidence(
      score: jsonToInt(json['score']),
      level: jsonNullableString(json['level']) ?? 'unknown',
      manualReviewRequired: json['manual_review_required'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'score': score,
      'level': level,
      'manual_review_required': manualReviewRequired,
    };
  }
}

class ReferenceQuality {
  final String matchLevel;
  final int referencePartsCount;
  final int? maxYearGap;
  final double? averageYearGap;
  final List<String> sources;

  const ReferenceQuality({
    required this.matchLevel,
    required this.referencePartsCount,
    this.maxYearGap,
    this.averageYearGap,
    required this.sources,
  });

  factory ReferenceQuality.fromJson(Map<String, dynamic> json) {
    final rawAverage = json['avg_year_gap'];
    return ReferenceQuality(
      matchLevel: jsonNullableString(json['match_level']) ?? 'unknown',
      referencePartsCount: jsonToInt(json['reference_parts_count']),
      maxYearGap:
          json['max_year_gap'] == null ? null : jsonToInt(json['max_year_gap']),
      averageYearGap: rawAverage == null ? null : jsonToDouble(rawAverage),
      sources: jsonAsStringList(json['sources']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'match_level': matchLevel,
      'reference_parts_count': referencePartsCount,
      'max_year_gap': maxYearGap,
      'avg_year_gap': averageYearGap,
      'sources': sources,
    };
  }
}

class PricingPolicy {
  final String version;
  final String source;

  const PricingPolicy({
    required this.version,
    required this.source,
  });

  factory PricingPolicy.fromJson(Map<String, dynamic> json) {
    return PricingPolicy(
      version: jsonNullableString(json['version']) ?? '',
      source: jsonNullableString(json['source']) ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'source': source,
    };
  }
}

class AiValidation {
  final String? damageAnalysis;
  final String? damageConfidenceScore;
  final String? priceExplanation;

  const AiValidation({
    this.damageAnalysis,
    this.damageConfidenceScore,
    this.priceExplanation,
  });

  factory AiValidation.fromJson(Map<String, dynamic> json) {
    final damageValidation = jsonAsMap(json['damage_validation']);
    final priceExplanation = jsonAsMap(json['price_explanation']);
    return AiValidation(
      damageAnalysis: jsonNullableString(damageValidation['analysis']),
      damageConfidenceScore:
          jsonNullableString(damageValidation['confidence_score']),
      priceExplanation: jsonNullableString(priceExplanation['explanation']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'damage_validation': {
        'analysis': damageAnalysis,
        'confidence_score': damageConfidenceScore,
      },
      'price_explanation': {
        'explanation': priceExplanation,
      },
    };
  }
}
