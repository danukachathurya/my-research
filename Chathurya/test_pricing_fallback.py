from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))

from pricing_fallback import (
    PRICING_POLICY_VERSION,
    build_reference_quality,
    enrich_price_result_for_claims,
)


class PricingFallbackMetadataTests(unittest.TestCase):
    def test_reference_quality_reports_exact_model_match(self):
        quality = build_reference_quality(
            [
                {
                    "reference_match": "exact_model",
                    "year_gap": 1,
                    "source": "ikman.lk",
                },
                {
                    "reference_match": "exact_model",
                    "year_gap": 2,
                    "source": "daraz.lk",
                },
            ]
        )

        self.assertEqual(quality["match_level"], "exact_model")
        self.assertEqual(quality["reference_parts_count"], 2)
        self.assertEqual(quality["max_year_gap"], 2)
        self.assertEqual(quality["avg_year_gap"], 1.5)

    def test_formula_fallback_requires_manual_review(self):
        result = enrich_price_result_for_claims(
            price_result={
                "estimated_price": 18000.0,
                "breakdown": {"parts": 12000.0, "labor": 0.0, "paint": 6000.0},
                "method": "formula_fallback",
                "explanation": "Fallback formula used.",
            },
            reference_prices=[],
            detected_damages=["dent"],
            affected_part="body_panel",
        )

        self.assertIsNotNone(result)
        self.assertEqual(result["pricing_policy"]["version"], PRICING_POLICY_VERSION)
        self.assertTrue(result["pricing_confidence"]["manual_review_required"])
        self.assertIn("formula_fallback_used", result["review_flags"])
        self.assertEqual(result["reference_quality"]["match_level"], "none")
        self.assertGreater(result["estimate_range"]["max"], result["estimate_range"]["min"])

    def test_price_model_result_gets_stable_metadata(self):
        result = enrich_price_result_for_claims(
            price_result={
                "estimated_price": 99515.85,
                "breakdown": {"parts": 77115.85, "labor": 0.0, "paint": 22400.0},
                "method": "price_model_fallback",
                "scope": {
                    "replacement_families": ["Headlight"],
                    "repair_families": ["Front Bumper", "Fender"],
                },
                "resolved_affected_part": "front_corner",
            },
            reference_prices=[
                {
                    "reference_match": "exact_model",
                    "year_gap": 1,
                    "source": "ikman.lk",
                },
                {
                    "reference_match": "exact_model",
                    "year_gap": 1,
                    "source": "newpgenterprises.com",
                },
            ],
            detected_damages=["dent", "scratch", "lamp broken"],
            affected_part="corner_impact",
        )

        self.assertIsNotNone(result)
        self.assertEqual(result["pricing_confidence"]["level"], "medium")
        self.assertFalse(result["pricing_confidence"]["manual_review_required"])
        self.assertEqual(result["reference_quality"]["match_level"], "exact_model")
        self.assertIn("multi_panel_scope", result["review_flags"])


if __name__ == "__main__":
    unittest.main()
