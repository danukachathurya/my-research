import csv
import json
import warnings
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional, Set

import numpy as np

PRICING_POLICY_PATH = Path(__file__).with_name("pricing_policy.json")
with open(PRICING_POLICY_PATH, encoding="utf-8") as pricing_policy_file:
    PRICING_POLICY = json.load(pricing_policy_file)

PRICING_POLICY_VERSION = str(PRICING_POLICY["version"])
PARTS_PRICE_INFLATION_FACTOR = float(PRICING_POLICY["parts_price_inflation_factor"])
SIMPLE_FORMULA_PER_DAMAGE_LKR = float(PRICING_POLICY["simple_formula_per_damage_lkr"])
PAINT_RELEVANT_DAMAGES = {"dent", "scratch", "crack"}

DAMAGE_TO_PART_FAMILIES = {
    "dent": ["Fender", "Front Bumper", "Front Door", "Rear Door", "Hood/Bonnet"],
    "scratch": ["Front Bumper", "Fender", "Front Door", "Hood/Bonnet"],
    "crack": ["Front Bumper", "Front Windshield"],
    "glass shatter": ["Front Windshield"],
    "lamp broken": ["Headlight", "Tail Light"],
    "tire flat": ["Alloy Wheel (Single)"],
}

AFFECTED_PART_FAMILY_ORDER = {
    "headlight": ["Headlight", "Front Bumper", "Fender", "Hood/Bonnet"],
    "tail_light": ["Tail Light", "Front Bumper", "Rear Door", "Fender"],
    "lighting": ["Headlight", "Tail Light", "Front Bumper", "Fender"],
    "corner_impact": [
        "Headlight",
        "Tail Light",
        "Front Bumper",
        "Fender",
        "Front Door",
        "Rear Door",
        "Hood/Bonnet",
    ],
    "bumper": ["Front Bumper", "Fender", "Headlight", "Tail Light", "Hood/Bonnet"],
    "body_panel": ["Fender", "Front Bumper", "Front Door", "Rear Door", "Hood/Bonnet"],
    "windshield": ["Front Windshield"],
    "tire": ["Alloy Wheel (Single)"],
}

DEFAULT_FAMILY_ORDER = [
    "Headlight",
    "Front Bumper",
    "Fender",
    "Front Door",
    "Rear Door",
    "Hood/Bonnet",
    "Tail Light",
    "Front Windshield",
    "Alloy Wheel (Single)",
]

REPLACEMENT_PAINT_BY_FAMILY = {
    str(family): float(amount)
    for family, amount in PRICING_POLICY["replacement_paint_by_family"].items()
}

REPAIR_RULES = {
    str(family): {
        "ratio": float(rule["ratio"]),
        "min_parts": float(rule["min_parts"]),
        "max_parts": float(rule["max_parts"]),
        "paint": float(rule["paint"]),
    }
    for family, rule in PRICING_POLICY["repair_rules"].items()
}

ADDITIONAL_PANEL_PAINT_FACTOR = float(PRICING_POLICY["additional_panel_paint_factor"])
QUALITY_POLICY = dict(PRICING_POLICY.get("quality") or {})
BASE_CONFIDENCE_BY_METHOD = {
    str(method): int(score)
    for method, score in (QUALITY_POLICY.get("base_confidence_by_method") or {}).items()
}
BASE_RANGE_RATIO_BY_METHOD = {
    str(method): float(ratio)
    for method, ratio in (QUALITY_POLICY.get("base_range_ratio_by_method") or {}).items()
}
CONFIDENCE_PENALTIES = {
    str(flag): int(value)
    for flag, value in (QUALITY_POLICY.get("confidence_penalties") or {}).items()
}
RANGE_ADJUSTMENTS = {
    str(flag): float(value)
    for flag, value in (QUALITY_POLICY.get("range_adjustments") or {}).items()
}
MANUAL_REVIEW_THRESHOLD = int(QUALITY_POLICY.get("manual_review_threshold", 70))
CRITICAL_REVIEW_FLAGS = {
    str(flag) for flag in (QUALITY_POLICY.get("critical_flags") or [])
}


@dataclass(frozen=True)
class DamageScope:
    affected_part: str
    reference_families: List[str]
    replacement_families: List[str]
    repair_families: List[str]
    resolved_affected_part: str


def round_money(value: float) -> float:
    return round(float(value or 0.0), 2)


def parse_numeric_confidence(value: Optional[object]) -> Optional[int]:
    if value is None or isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        return max(0, min(100, int(round(float(value)))))

    text = str(value).strip()
    if not text:
        return None

    try:
        return max(0, min(100, int(round(float(text)))))
    except ValueError:
        return None


def confidence_level(score: int) -> str:
    if score >= 85:
        return "high"
    if score >= MANUAL_REVIEW_THRESHOLD:
        return "medium"
    return "low"


def normalize_damage_label(damage: str) -> str:
    return damage.lower().replace("_", " ").strip()


def normalize_affected_part(affected_part: Optional[str]) -> str:
    return (affected_part or "").strip().lower().replace("-", "_").replace(" ", "_")


def infer_affected_part(detected_damages: List[str]) -> str:
    normalized_damages = {normalize_damage_label(damage) for damage in detected_damages}
    if not normalized_damages:
        return "body_panel"
    if "glass shatter" in normalized_damages:
        return "windshield"
    if "tire flat" in normalized_damages:
        return "tire"
    if "lamp broken" in normalized_damages:
        if normalized_damages.intersection({"dent", "scratch", "crack"}):
            return "corner_impact"
        return "lighting"
    if "crack" in normalized_damages:
        return "bumper"
    return "body_panel"


def summarize_fallback_reason(reason: Optional[str]) -> str:
    if not reason:
        return ""

    clean_reason = reason.strip()
    if not clean_reason:
        return ""

    if clean_reason.lower().startswith("error:"):
        clean_reason = clean_reason[6:].strip()
    clean_reason = clean_reason.rstrip(".!?")

    return f" Reason: {clean_reason}."


def build_no_damage_price_result() -> dict:
    return {
        "estimated_price": 0.0,
        "breakdown": {"parts": 0.0, "labor": 0.0, "paint": 0.0},
        "explanation": "No repair cost because no damage was detected.",
        "method": "no_damage",
    }


def exclude_labor_from_price_result(price_result: Optional[dict]) -> Optional[dict]:
    if price_result is None:
        return None

    normalized_result = dict(price_result)
    breakdown = dict(normalized_result.get("breakdown") or {})

    parts_cost = round(float(breakdown.get("parts", 0.0) or 0.0), 2)
    paint_cost = round(float(breakdown.get("paint", 0.0) or 0.0), 2)
    breakdown["parts"] = parts_cost
    breakdown["labor"] = 0.0
    breakdown["paint"] = paint_cost

    normalized_result["breakdown"] = breakdown
    if normalized_result.get("estimated_price") is not None or breakdown:
        normalized_result["estimated_price"] = round(parts_cost + paint_cost, 2)

    explanation = str(normalized_result.get("explanation") or "").strip()
    labor_note = "Labor cost was excluded from this estimate."
    if labor_note not in explanation:
        separator = " " if explanation else ""
        normalized_result["explanation"] = f"{explanation}{separator}{labor_note}".strip()

    return normalized_result


def build_formula_price_result(
    detected_damages: List[str],
    reference_prices: Optional[List[Dict]] = None,
    reason: Optional[str] = None,
) -> dict:
    if not detected_damages:
        return build_no_damage_price_result()

    num_damages = len(detected_damages)
    total = float(num_damages * SIMPLE_FORMULA_PER_DAMAGE_LKR)
    paint_damage_count = sum(
        1
        for damage in detected_damages
        if normalize_damage_label(damage) in PAINT_RELEVANT_DAMAGES
    )
    parts_ratio = 0.50 if reference_prices else 0.35
    paint_ratio = 0.20 if paint_damage_count else 0.0

    parts_cost = round(total * parts_ratio, 2)
    labor_cost = 0.0
    paint_cost = round(total * paint_ratio, 2)

    return {
        "estimated_price": round(parts_cost + paint_cost, 2),
        "breakdown": {
            "parts": parts_cost,
            "labor": labor_cost,
            "paint": paint_cost,
        },
        "explanation": (
            "Gemini pricing and the trained Random Forest price model were unavailable, "
            f"so a simple fallback formula was used ({num_damages} damage(s) x "
            f"LKR {SIMPLE_FORMULA_PER_DAMAGE_LKR:,}) with labor removed."
            f"{summarize_fallback_reason(reason)}"
        ),
        "method": "formula_fallback",
    }


def part_family(part_name: str) -> str:
    normalized = part_name.strip().lower()
    if normalized.startswith("headlight"):
        return "Headlight"
    if normalized.startswith("tail light"):
        return "Tail Light"
    if normalized.startswith("fender"):
        return "Fender"
    if normalized.startswith("front door"):
        return "Front Door"
    if normalized.startswith("rear door"):
        return "Rear Door"
    if normalized == "front bumper":
        return "Front Bumper"
    if normalized == "hood/bonnet":
        return "Hood/Bonnet"
    if normalized == "front windshield":
        return "Front Windshield"
    if normalized == "alloy wheel (single)":
        return "Alloy Wheel (Single)"
    return part_name.strip()


def build_relevant_part_families(
    detected_damages: List[str],
    affected_part: Optional[str] = None,
) -> List[str]:
    normalized_damages = [normalize_damage_label(damage) for damage in detected_damages]
    normalized_damage_set = set(normalized_damages)
    families: Set[str] = {
        family
        for damage in normalized_damages
        for family in DAMAGE_TO_PART_FAMILIES.get(damage, [])
    }
    if not families:
        return []

    affected_key = normalize_affected_part(affected_part)
    preferred_order = AFFECTED_PART_FAMILY_ORDER.get(affected_key, DEFAULT_FAMILY_ORDER)
    preferred_filter = set(preferred_order)
    if preferred_filter:
        filtered_families = families & preferred_filter
        if filtered_families:
            families = filtered_families

    if "lamp broken" in normalized_damage_set:
        if affected_key == "headlight":
            families.discard("Tail Light")
            families.add("Headlight")
        elif affected_key in {"tail_light", "rear_corner"}:
            families.discard("Headlight")
            families.add("Tail Light")
        elif affected_key not in {"lighting", "taillight"} and "Headlight" in families:
            families.discard("Tail Light")

    ordered = [family for family in preferred_order if family in families]
    for family in DEFAULT_FAMILY_ORDER:
        if family in families and family not in ordered:
            ordered.append(family)

    if affected_key == "body_panel":
        if normalized_damage_set.issubset({"dent", "scratch"}):
            return ordered[: min(len(ordered), 2 if len(normalized_damage_set) == 1 else 3)]
    if affected_key in {"bumper", "lighting", "corner_impact"}:
        return ordered[: min(len(ordered), 4)]
    return ordered


def choose_family_by_priority(
    candidates: List[str],
    family_costs: Dict[str, float],
) -> Optional[str]:
    available = [family for family in candidates if family in family_costs]
    if not available:
        return None
    return min(
        available,
        key=lambda family: (
            family_costs.get(family, float("inf")),
            DEFAULT_FAMILY_ORDER.index(family)
            if family in DEFAULT_FAMILY_ORDER
            else len(DEFAULT_FAMILY_ORDER),
        ),
    )


def choose_replacement_families(
    normalized_damages: Set[str],
    affected_part: Optional[str],
    family_costs: Dict[str, float],
) -> List[str]:
    affected_key = normalize_affected_part(affected_part)
    available_families = set(family_costs.keys())
    replacements: List[str] = []

    if "lamp broken" in normalized_damages:
        if affected_key in {"tail_light", "rear_corner"}:
            preferred_family = choose_family_by_priority(
                ["Tail Light", "Headlight"],
                family_costs,
            )
        elif affected_key in {"headlight", "front_corner", "corner_impact"}:
            preferred_family = choose_family_by_priority(
                ["Headlight", "Tail Light"],
                family_costs,
            )
        else:
            preferred_family = choose_family_by_priority(
                ["Tail Light", "Headlight"],
                family_costs,
            )

        if preferred_family in available_families:
            replacements.append(preferred_family)

    if "glass shatter" in normalized_damages:
        preferred_family = choose_family_by_priority(["Front Windshield"], family_costs)
        if preferred_family is not None:
            replacements.append(preferred_family)

    if "tire flat" in normalized_damages:
        preferred_family = choose_family_by_priority(["Alloy Wheel (Single)"], family_costs)
        if preferred_family is not None:
            replacements.append(preferred_family)

    if "crack" in normalized_damages:
        preferred_family = choose_family_by_priority(["Front Bumper"], family_costs)
        if preferred_family is not None:
            replacements.append(preferred_family)

    deduped: List[str] = []
    for family in replacements:
        if family not in deduped:
            deduped.append(family)
    return deduped


def choose_repair_families(
    normalized_damages: Set[str],
    affected_part: Optional[str],
    available_families: Set[str],
    replacement_families: List[str],
) -> List[str]:
    if not normalized_damages.intersection({"dent", "scratch"}):
        return []

    affected_key = normalize_affected_part(affected_part)
    if affected_key in {"headlight", "front_corner", "corner_impact"}:
        preferred_families = ["Front Bumper", "Fender", "Hood/Bonnet"]
        max_repairs = 2 if {"dent", "scratch"}.issubset(normalized_damages) else 1
    elif affected_key in {"tail_light", "rear_corner", "lighting"}:
        preferred_families = ["Front Bumper", "Rear Door", "Fender"]
        max_repairs = 1
    elif affected_key == "bumper":
        preferred_families = ["Front Bumper", "Fender"]
        max_repairs = 1
    elif affected_key == "body_panel":
        preferred_families = ["Fender", "Front Bumper", "Front Door", "Rear Door", "Hood/Bonnet"]
        max_repairs = 1
    else:
        preferred_families = ["Front Bumper", "Fender", "Front Door", "Rear Door", "Hood/Bonnet"]
        max_repairs = 1

    repairs: List[str] = []
    for family in preferred_families:
        if family in available_families and family not in replacement_families:
            repairs.append(family)
        if len(repairs) >= max_repairs:
            break

    if not repairs and "Front Bumper" in available_families and "Front Bumper" not in replacement_families:
        repairs.append("Front Bumper")

    return repairs


def combine_paint_costs(panel_costs: List[float]) -> float:
    if not panel_costs:
        return 0.0

    sorted_costs = sorted(panel_costs, reverse=True)
    total = sorted_costs[0]
    for extra_cost in sorted_costs[1:]:
        total += extra_cost * ADDITIONAL_PANEL_PAINT_FACTOR
    return round(total, 2)


def resolve_estimated_affected_part(
    affected_part: Optional[str],
    replacement_families: List[str],
    repair_families: List[str],
) -> str:
    replacement_set = set(replacement_families)
    repair_set = set(repair_families)
    combined_families = replacement_set | repair_set

    if "Front Windshield" in combined_families:
        return "windshield"
    if "Alloy Wheel (Single)" in combined_families:
        return "tire"
    if "Tail Light" in replacement_set:
        return "rear_corner" if repair_set else "tail_light"
    if "Headlight" in replacement_set:
        return "front_corner" if repair_set else "headlight"
    if repair_set == {"Front Bumper"}:
        return "bumper"
    if combined_families.intersection({"Fender", "Front Door", "Rear Door", "Hood/Bonnet"}):
        return "body_panel"

    normalized = normalize_affected_part(affected_part)
    return normalized or "body_panel"


def build_damage_scope(
    detected_damages: List[str],
    affected_part: Optional[str],
    family_costs: Dict[str, float],
) -> DamageScope:
    normalized_damages = {normalize_damage_label(damage) for damage in detected_damages}
    replacement_families = choose_replacement_families(
        normalized_damages,
        affected_part,
        family_costs,
    )
    repair_families = choose_repair_families(
        normalized_damages,
        affected_part,
        set(family_costs.keys()),
        replacement_families,
    )
    return DamageScope(
        affected_part=normalize_affected_part(affected_part) or "body_panel",
        reference_families=list(family_costs.keys()),
        replacement_families=replacement_families,
        repair_families=repair_families,
        resolved_affected_part=resolve_estimated_affected_part(
            affected_part,
            replacement_families,
            repair_families,
        ),
    )


def build_reference_quality(reference_prices: List[Dict]) -> Dict[str, object]:
    if not reference_prices:
        return {
            "match_level": "none",
            "reference_parts_count": 0,
            "max_year_gap": None,
            "avg_year_gap": None,
            "sources": [],
        }

    match_levels = {
        str(reference.get("reference_match") or "unknown") for reference in reference_prices
    }
    year_gaps = [
        int(reference.get("year_gap", 0) or 0)
        for reference in reference_prices
        if reference.get("year_gap") is not None
    ]
    sources = sorted(
        {
            str(reference.get("source") or "").strip()
            for reference in reference_prices
            if str(reference.get("source") or "").strip()
        }
    )

    if match_levels == {"exact_model"}:
        match_level = "exact_model"
    elif match_levels == {"brand_only"}:
        match_level = "brand_only"
    elif not match_levels:
        match_level = "unknown"
    else:
        match_level = "mixed"

    average_year_gap = (
        round(sum(year_gaps) / len(year_gaps), 2) if year_gaps else None
    )
    return {
        "match_level": match_level,
        "reference_parts_count": len(reference_prices),
        "max_year_gap": max(year_gaps) if year_gaps else None,
        "avg_year_gap": average_year_gap,
        "sources": sources,
    }


def build_review_flags(
    price_result: Dict,
    reference_prices: List[Dict],
    detected_damages: List[str],
    affected_part: Optional[str],
) -> List[str]:
    flags: List[str] = []
    method = str(price_result.get("method") or "")
    reference_quality = build_reference_quality(reference_prices)

    if not reference_prices:
        flags.append("no_reference_prices")

    match_level = reference_quality["match_level"]
    if match_level == "brand_only":
        flags.append("brand_only_reference_used")
    elif match_level == "mixed":
        flags.append("mixed_reference_match")

    max_year_gap = reference_quality.get("max_year_gap")
    if isinstance(max_year_gap, int):
        if max_year_gap > 5:
            flags.append("reference_year_gap_gt_5")
        elif max_year_gap > 2:
            flags.append("reference_year_gap_gt_2")

    normalized_damages = {normalize_damage_label(damage) for damage in detected_damages}
    if (
        normalized_damages
        and normalize_affected_part(affected_part) == "body_panel"
        and normalized_damages.issubset({"dent", "scratch"})
    ):
        flags.append("generic_panel_scope")

    scope = dict(price_result.get("scope") or {})
    scoped_families = set(scope.get("replacement_families") or []) | set(
        scope.get("repair_families") or []
    )
    if len(reference_prices) <= 1 and method != "no_damage":
        flags.append("limited_reference_coverage")
    if len(scoped_families) >= 3:
        flags.append("multi_panel_scope")

    if method == "formula_fallback":
        flags.append("formula_fallback_used")

    if method in {"gemini_ai", "gemini_ai_cached"} and not price_result.get("severity_summary"):
        flags.append("ai_summary_missing")

    deduped: List[str] = []
    for flag in flags:
        if flag not in deduped:
            deduped.append(flag)
    return deduped


def build_pricing_confidence(
    price_result: Dict,
    review_flags: List[str],
) -> Dict[str, object]:
    method = str(price_result.get("method") or "price_model_fallback")
    base_score = int(BASE_CONFIDENCE_BY_METHOD.get(method, 60))
    raw_confidence = parse_numeric_confidence(price_result.get("confidence_score"))
    if raw_confidence is not None:
        base_score = int(round((base_score + raw_confidence) / 2))

    score = base_score
    for flag in review_flags:
        score -= int(CONFIDENCE_PENALTIES.get(flag, 0))
    score = max(15, min(99, score))

    manual_review_required = (
        score < MANUAL_REVIEW_THRESHOLD
        or any(flag in CRITICAL_REVIEW_FLAGS for flag in review_flags)
    )

    return {
        "score": score,
        "level": confidence_level(score),
        "manual_review_required": manual_review_required,
    }


def build_estimate_range(
    price_result: Dict,
    review_flags: List[str],
) -> Dict[str, float]:
    total = round_money(price_result.get("estimated_price", 0.0) or 0.0)
    if total <= 0:
        return {"min": 0.0, "max": 0.0, "tolerance_ratio": 0.0}

    method = str(price_result.get("method") or "price_model_fallback")
    tolerance_ratio = float(BASE_RANGE_RATIO_BY_METHOD.get(method, 0.2))
    for flag in review_flags:
        tolerance_ratio += float(RANGE_ADJUSTMENTS.get(flag, 0.0))
    tolerance_ratio = max(0.0, min(0.75, tolerance_ratio))

    return {
        "min": round_money(max(total * (1 - tolerance_ratio), 0.0)),
        "max": round_money(total * (1 + tolerance_ratio)),
        "tolerance_ratio": round(tolerance_ratio, 3),
    }


def enrich_price_result_for_claims(
    price_result: Optional[dict],
    reference_prices: Optional[List[Dict]],
    detected_damages: List[str],
    affected_part: Optional[str],
) -> Optional[dict]:
    if price_result is None:
        return None

    enriched_result = dict(price_result)
    references = list(reference_prices or [])
    review_flags = build_review_flags(
        enriched_result,
        references,
        detected_damages,
        affected_part,
    )

    enriched_result["pricing_policy"] = {
        "version": PRICING_POLICY_VERSION,
        "source": PRICING_POLICY_PATH.name,
    }
    enriched_result["reference_quality"] = build_reference_quality(references)
    enriched_result["review_flags"] = review_flags
    enriched_result["pricing_confidence"] = build_pricing_confidence(
        enriched_result,
        review_flags,
    )
    enriched_result["estimate_range"] = build_estimate_range(
        enriched_result,
        review_flags,
    )

    return enriched_result


def humanize_family_label(family: str) -> str:
    return family.lower().replace("hood/bonnet", "bonnet")


def describe_scope(replacement_families: List[str], repair_families: List[str]) -> str:
    actions: List[str] = []
    if replacement_families:
        actions.append(
            "replace " + ", ".join(humanize_family_label(family) for family in replacement_families)
        )
    if repair_families:
        actions.append(
            "repair and repaint "
            + ", ".join(humanize_family_label(family) for family in repair_families)
        )
    if not actions:
        return "a limited repair scope"
    if len(actions) == 1:
        return actions[0]
    return f"{actions[0]}, then {actions[1]}"


class SparePartsLookup:
    def __init__(self):
        self.data: List[Dict] = []
        self.models: set = set()

    def load(self, csv_path: Path):
        self.data = []
        self.models = set()

        if not csv_path.exists():
            print(f"Spare parts CSV not found: {csv_path}")
            return

        with open(csv_path, newline="", encoding="utf-8") as file:
            reader = csv.DictReader(file)
            for row in reader:
                price_str = row.get("Price_LKR (Indicative)", "").strip()
                if not price_str:
                    continue

                try:
                    price = float(price_str)
                except ValueError:
                    continue

                part_name = row["Part_Name"].strip()
                self.data.append(
                    {
                        "brand": row["Brand"].strip().lower(),
                        "model": row["Model"].strip().lower(),
                        "year": int(row["Year"]),
                        "part": part_name,
                        "part_family": part_family(part_name),
                        "price": price,
                        "source": row.get("Source (Market Listing Category)", "").strip(),
                    }
                )
                self.models.add((row["Brand"].strip().lower(), row["Model"].strip().lower()))

        print(f"Loaded {len(self.data)} spare parts prices ({len(self.models)} model variants)")

    def is_supported_brand(self, brand: str) -> bool:
        return any(candidate_brand == brand.strip().lower() for candidate_brand, _ in self.models)

    def lookup(
        self,
        brand: str,
        model: str,
        year: int,
        damages: List[str],
        affected_part: Optional[str] = None,
    ) -> List[Dict]:
        brand_l = brand.strip().lower()
        model_l = model.strip().lower()
        relevant_families = build_relevant_part_families(damages, affected_part)
        if not relevant_families:
            return []

        exact_model_candidates = [
            row for row in self.data if row["brand"] == brand_l and row["model"] == model_l
        ]
        if exact_model_candidates:
            candidates = exact_model_candidates
            reference_match = "exact_model"
        else:
            candidates = [row for row in self.data if row["brand"] == brand_l]
            reference_match = "brand_only"
        if not candidates:
            return []

        results = []
        for family in relevant_families:
            family_rows = [row for row in candidates if row["part_family"] == family]
            if not family_rows:
                continue

            best = min(
                family_rows,
                key=lambda row: (abs(row["year"] - year), row["price"]),
            )
            results.append(
                {
                    "brand": best["brand"],
                    "model": best["model"],
                    "part": best["part"],
                    "part_family": best["part_family"],
                    "price_lkr": best["price"],
                    "reference_year": best["year"],
                    "year_gap": abs(best["year"] - year),
                    "reference_match": reference_match,
                    "source": best["source"],
                }
            )

        return results


class LocalPriceFallbackEngine:
    def __init__(self, model=None, scaler=None):
        self.model = model
        self.scaler = scaler
        self.ready = False
        self.encoders: Dict[str, Dict[str, int]] = {}

    def load(self, csv_path: Path):
        self.ready = False
        self.encoders = {}

        if self.model is None or self.scaler is None:
            return
        if not csv_path.exists():
            print(f"Price-model preprocessing CSV not found: {csv_path}")
            return

        rows = []
        with open(csv_path, newline="", encoding="utf-8") as file:
            reader = csv.DictReader(file)
            for row in reader:
                price_str = row.get("Price_LKR (Indicative)", "").strip()
                year_str = row.get("Year", "").strip()
                if not price_str or not year_str:
                    continue

                try:
                    price = float(price_str)
                    year = int(year_str)
                except ValueError:
                    continue

                rows.append(
                    {
                        "Brand": row.get("Brand", "").strip(),
                        "Model": row.get("Model", "").strip(),
                        "Year": year,
                        "Part_Name": row.get("Part_Name", "").strip(),
                        "Source (Market Listing Category)": row.get(
                            "Source (Market Listing Category)", ""
                        ).strip(),
                        "Price_LKR (Indicative)": price,
                    }
                )

        if not rows:
            print("No rows available to rebuild price-model preprocessing")
            return

        prices = sorted(row["Price_LKR (Indicative)"] for row in rows)
        q1 = self._percentile(prices, 0.25)
        q3 = self._percentile(prices, 0.75)
        iqr = q3 - q1
        lower_bound = q1 - 1.5 * iqr
        upper_bound = q3 + 1.5 * iqr
        filtered_rows = [
            row for row in rows if lower_bound <= row["Price_LKR (Indicative)"] <= upper_bound
        ] or rows

        for column in (
            "Brand",
            "Model",
            "Part_Name",
            "Source (Market Listing Category)",
        ):
            unique_values = sorted(
                {
                    str(row[column]).strip()
                    for row in filtered_rows
                    if str(row[column]).strip()
                }
            )
            self.encoders[column] = {
                value: index for index, value in enumerate(unique_values)
            }

        self.ready = True
        print("Random Forest fallback pricing ready")

    def estimate(
        self,
        vehicle_brand: str,
        vehicle_model: str,
        vehicle_year: int,
        detected_damages: List[str],
        reference_prices: List[Dict],
        affected_part: Optional[str] = None,
        reason: Optional[str] = None,
    ) -> Optional[dict]:
        if not self.ready or self.model is None or self.scaler is None:
            return None
        if not detected_damages:
            return build_no_damage_price_result()
        if not reference_prices:
            return None

        feature_rows = []
        matched_references = []

        for reference in reference_prices:
            source = reference.get("source", "").strip()
            part_name = reference.get("part", "").strip()
            if not source or not part_name:
                continue

            brand = str(reference.get("brand") or vehicle_brand).strip().lower()
            model = str(reference.get("model") or vehicle_model).strip().lower()

            try:
                feature_row = self._build_feature_row(
                    brand=brand,
                    model=model,
                    year=vehicle_year,
                    part_name=part_name,
                    source=source,
                )
            except KeyError as exc:
                print(f"Random Forest fallback skipped row: {exc}")
                continue

            feature_rows.append(feature_row)
            matched_references.append(reference)

        if not feature_rows:
            return None

        feature_matrix = np.asarray(feature_rows, dtype=np.float64)
        with warnings.catch_warnings():
            warnings.filterwarnings(
                "ignore",
                message="X does not have valid feature names, but StandardScaler was fitted with feature names",
                category=UserWarning,
            )
            scaled_matrix = self.scaler.transform(feature_matrix)

        predicted_prices = self.model.predict(scaled_matrix)
        family_costs: Dict[str, float] = {}
        for reference, predicted_price in zip(matched_references, predicted_prices):
            adjusted_price = max(float(predicted_price), 0.0) * PARTS_PRICE_INFLATION_FACTOR
            if adjusted_price <= 0:
                adjusted_price = (
                    max(float(reference.get("price_lkr", 0.0)), 0.0)
                    * PARTS_PRICE_INFLATION_FACTOR
                )

            family = str(reference.get("part_family") or part_family(reference["part"]))
            current_cost = family_costs.get(family)
            if current_cost is None or adjusted_price < current_cost:
                family_costs[family] = adjusted_price

        if not family_costs:
            return None

        damage_scope = build_damage_scope(
            detected_damages=detected_damages,
            affected_part=affected_part,
            family_costs=family_costs,
        )
        replacement_families = damage_scope.replacement_families
        repair_families = damage_scope.repair_families

        parts_cost = 0.0
        labor_cost = 0.0
        paint_costs: List[float] = []

        for family in replacement_families:
            replacement_cost = family_costs.get(family)
            if replacement_cost is None:
                continue

            parts_cost += replacement_cost

            replacement_paint = REPLACEMENT_PAINT_BY_FAMILY.get(family, 0.0)
            if replacement_paint:
                paint_costs.append(replacement_paint)

        for family in repair_families:
            reference_cost = family_costs.get(family)
            rule = REPAIR_RULES.get(family)
            if reference_cost is None or rule is None:
                continue

            material_cost = min(
                max(reference_cost * rule["ratio"], rule["min_parts"]),
                rule["max_parts"],
            )
            parts_cost += material_cost
            paint_costs.append(rule["paint"])

        if parts_cost <= 0 and labor_cost <= 0 and not paint_costs:
            return None

        paint_cost = combine_paint_costs(paint_costs)
        estimated_price = round(parts_cost + labor_cost + paint_cost, 2)
        if estimated_price <= 0:
            return None

        scope_summary = describe_scope(replacement_families, repair_families)
        return {
            "estimated_price": estimated_price,
            "breakdown": {
                "parts": round(parts_cost, 2),
                "labor": round(labor_cost, 2),
                "paint": paint_cost,
            },
            "resolved_affected_part": damage_scope.resolved_affected_part,
            "scope": {
                "replacement_families": replacement_families,
                "repair_families": repair_families,
                "reference_families": damage_scope.reference_families,
            },
            "explanation": (
                "Gemini pricing was unavailable, so the local fallback priced a focused repair scope: "
                f"{scope_summary}. Replacement items use market-based part prices, while dented or "
                f"scratched panels are treated as repair work instead of full replacement. "
                "Labor cost was excluded from this estimate."
                f"{summarize_fallback_reason(reason)}"
            ),
            "method": "price_model_fallback",
        }

    def _build_feature_row(
        self,
        brand: str,
        model: str,
        year: int,
        part_name: str,
        source: str,
    ) -> List[float]:
        return [
            float(self._encode_value("Brand", brand)),
            float(self._encode_value("Model", model)),
            float(year),
            float(self._encode_value("Part_Name", part_name)),
            float(self._encode_value("Source (Market Listing Category)", source)),
        ]

    def _encode_value(self, column: str, value: str) -> int:
        raw_value = str(value).strip()
        mapping = self.encoders.get(column, {})
        if raw_value in mapping:
            return mapping[raw_value]

        normalized = raw_value.lower()
        for known_value, encoded_value in mapping.items():
            if known_value.lower() == normalized:
                return encoded_value

        raise KeyError(f"Unknown {column} value: {raw_value}")

    def _percentile(self, values: List[float], quantile: float) -> float:
        if not values:
            return 0.0
        if len(values) == 1:
            return values[0]

        position = (len(values) - 1) * quantile
        lower_index = int(position)
        upper_index = min(lower_index + 1, len(values) - 1)
        weight = position - lower_index
        return (values[lower_index] * (1 - weight)) + (values[upper_index] * weight)
