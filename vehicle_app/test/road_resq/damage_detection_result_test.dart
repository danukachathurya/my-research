import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_app/road_resq/models/damage_detection_result.dart';

void main() {
  group('DamageDetectionResult.fromJson', () {
    test('parses legacy RoadResQ payloads', () {
      final result = DamageDetectionResult.fromJson({
        'damage_type': 'dent',
        'severity_score': 2,
        'confidence': 0.91,
        'probabilities': {
          'dent': 0.91,
          'scratch': 0.12,
        },
        'detected_damages': ['dent'],
        'damage_details': {
          'description': 'Legacy response',
          'what_happened': 'Minor collision',
          'immediate_actions': ['Inspect bumper'],
          'repair_options': ['Visit a garage'],
          'urgency': 'medium',
          'estimated_time': '2 days',
          'prevention_tips': 'Keep safe distance',
        },
      });

      expect(result.damageType, 'dent');
      expect(result.detectedDamages, ['dent']);
      expect(result.priceEstimation, isNull);
      expect(result.vehicle, isNull);
      expect(result.damageDetails.description, 'Legacy response');
    });

    test('parses claims assessment payloads with pricing metadata', () {
      final result = DamageDetectionResult.fromJson({
        'claim_id': 'claim-123',
        'status': 'ready_for_insurer_submission',
        'timestamp': '2026-04-06T10:00:00',
        'vehicle': {
          'brand': 'Toyota',
          'model': 'Corolla',
          'year': '2017',
        },
        'damage_detection': {
          'detected_damages': ['dent', 'scratch'],
          'confidences': {
            'dent': 0.87,
            'scratch': 0.63,
          },
          'num_damages': 2,
        },
        'part_mapping': {
          'affected_part': 'front_bumper',
          'raw_affected_part': 'front_corner',
          'mapped_from': ['dent', 'scratch'],
        },
        'price_estimation': {
          'estimated_price': 42500.0,
          'currency': 'LKR',
          'method': 'price_model_fallback',
          'breakdown': {
            'parts': 22000.0,
            'paint': 20500.0,
          },
          'reference_prices': [
            {
              'part_name': 'Front Bumper',
              'price': 58000,
            },
          ],
          'recommended_photos': ['front_corner_closeup'],
          'review_flags': ['limited_reference_coverage'],
          'estimate_range': {
            'min': 38000.0,
            'max': 47000.0,
            'tolerance_ratio': 0.12,
          },
          'pricing_confidence': {
            'score': 74,
            'level': 'medium',
            'manual_review_required': false,
          },
        },
        'ai_validation': {
          'damage_validation': {
            'analysis': 'Front bumper damage is visible.',
            'confidence_score': '82',
          },
          'price_explanation': {
            'explanation': 'Used nearest matching references.',
          },
        },
        'workflow': {
          'claim_status': 'ready_for_submission',
          'next_action': 'capture_optional_wider_angle',
        },
      });

      expect(result.claimId, 'claim-123');
      expect(result.displayStatus, 'Ready For Insurer Submission');
      expect(result.vehicle?.displayName, 'Toyota Corolla 2017');
      expect(result.partMapping?.displayAffectedPart, 'Front Bumper');
      expect(result.priceEstimation?.estimatedPrice, 42500.0);
      expect(result.priceEstimation?.pricingConfidence?.score, 74);
      expect(result.aiValidation?.priceExplanation, 'Used nearest matching references.');
      expect(result.workflow['claim_status'], 'ready_for_submission');
      expect(result.damageDetails.immediateActions, isNotEmpty);
    });
  });
}
