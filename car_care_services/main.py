import json
import math
import os
import re
from enum import Enum
from pathlib import Path
from typing import Any, Iterable, List, Optional
from urllib import error, parse, request

from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel


DEFAULT_LATITUDE = 6.9271
DEFAULT_LONGITUDE = 79.8612
DEFAULT_RADIUS_METERS = 20000
HTTP_TIMEOUT_SECONDS = 8
USER_AGENT = "car-care-services/2.2"
OVERPASS_ENDPOINTS = [
    "https://lz4.overpass-api.de/api/interpreter",
    "https://overpass-api.de/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
]
GENERIC_BUSINESS_NAMES = {
    "car wash",
    "car wash - car wash",
    "car wash - car spa",
    "car spa",
    "auto wash",
    "vehicle wash",
    "car service",
    "car service center",
    "service center",
    "vehicle service",
    "vehicle service center",
    "garage",
    "repair shop",
    "tire shop",
}
SERVICE_TYPE_ALIASES = {
    "basic wash": "Basic Wash",
    "premium wash": "Premium Wash",
    "interior cleaning": "Interior Cleaning",
    "oil change": "Oil Change",
    "engine check": "Engine Check",
    "tire shop": "Tire Shop",
    "tyre shop": "Tire Shop",
    "tire replacement": "Tire Shop",
    "tyre replacement": "Tire Shop",
}
MANIFEST_API_KEY_PATTERN = re.compile(
    r'android:name="com.google.android.geo.API_KEY"\s+android:value="([^"]+)"',
    re.DOTALL,
)


class Category(str, Enum):
    car_wash = "car_wash"
    service = "service"


class CarCareService(BaseModel):
    id: str
    name: str
    shop_name: Optional[str] = None
    address: str
    description: str
    rating: Optional[float] = None
    distance_km: float
    latitude: float
    longitude: float
    category: Category
    service_types: List[str]
    source: str


class ServiceListResponse(BaseModel):
    count: int
    services: List[CarCareService]


class NearestLocationResponse(BaseModel):
    count: int
    locations: List[CarCareService]


app = FastAPI(
    title="Car Care Services API",
    description="Live API for nearby car wash and maintenance services",
    version="2.2.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


def _parse_service_types(raw_value: Optional[str]) -> List[str]:
    if not raw_value:
        return []
    return _normalize_service_types(
        [item.strip() for item in raw_value.split(",") if item.strip()]
    )


def _normalize_service_type_label(value: str) -> str:
    normalized = value.strip().lower()
    if not normalized:
        return ""
    return SERVICE_TYPE_ALIASES.get(normalized, value.strip())


def _normalize_service_types(values: Iterable[str]) -> List[str]:
    normalized_values: List[str] = []
    for value in values:
        normalized = _normalize_service_type_label(value)
        if normalized and normalized not in normalized_values:
            normalized_values.append(normalized)
    return normalized_values


def _contains_any(text: str, terms: Iterable[str]) -> bool:
    return any(term in text for term in terms)


def _query_terms_for_service_types(
    category: Category,
    service_types: List[str],
) -> List[str]:
    normalized_service_types = _normalize_service_types(service_types)

    if not normalized_service_types:
        if category == Category.car_wash:
            return [
                "car wash",
                "car spa",
                "auto wash",
                "vehicle wash",
                "auto detailing",
            ]
        return [
            "car repair",
            "car service center",
            "vehicle workshop",
            "engine diagnostics",
            "oil change",
            "tire shop",
        ]

    mapped_terms: List[str] = []
    for service_type in normalized_service_types:
        if service_type == "Basic Wash":
            mapped_terms.extend(["car wash", "auto wash"])
        elif service_type == "Premium Wash":
            mapped_terms.extend(["auto detailing", "car detailing", "car spa"])
        elif service_type == "Interior Cleaning":
            mapped_terms.extend(
                ["car interior cleaning", "interior detailing", "car vacuum"]
            )
        elif service_type == "Oil Change":
            mapped_terms.extend(
                ["oil change", "engine oil", "lubrication service", "quick lube"]
            )
        elif service_type == "Engine Check":
            mapped_terms.extend(
                [
                    "engine repair",
                    "engine diagnostics",
                    "mechanic",
                    "car repair",
                    "vehicle workshop",
                ]
            )
        elif service_type == "Tire Shop":
            mapped_terms.extend(
                [
                    "tire shop",
                    "tyre shop",
                    "wheel alignment",
                    "wheel balancing",
                    "tire replacement",
                ]
            )
        else:
            mapped_terms.append(service_type)

    deduped_terms: List[str] = []
    for term in mapped_terms:
        if term not in deduped_terms:
            deduped_terms.append(term)
    return deduped_terms

def _build_text_query(
    category: Category,
    search: Optional[str],
    service_types: List[str],
) -> str:
    parts: List[str] = []
    if search and search.strip():
        parts.append(search.strip())
    parts.extend(_query_terms_for_service_types(category, service_types))
    parts.append("Colombo Sri Lanka")
    return " ".join(parts)


def _request_json(
    url: str,
    *,
    method: str = "GET",
    query_params: Optional[dict[str, Any]] = None,
    body: Optional[dict[str, Any]] = None,
    headers: Optional[dict[str, str]] = None,
) -> Any:
    if query_params:
        encoded_params = parse.urlencode(query_params)
        url = f"{url}?{encoded_params}"

    data = None
    request_headers = {
        "User-Agent": USER_AGENT,
        "Accept": "application/json",
    }
    if headers:
        request_headers.update(headers)

    if body is not None:
        data = json.dumps(body).encode("utf-8")
        request_headers.setdefault("Content-Type", "application/json")

    req = request.Request(url, data=data, headers=request_headers, method=method)
    with request.urlopen(req, timeout=HTTP_TIMEOUT_SECONDS) as response:
        return json.loads(response.read().decode("utf-8"))


def _post_form(url: str, payload: dict[str, str]) -> Any:
    data = parse.urlencode(payload).encode("utf-8")
    req = request.Request(
        url,
        data=data,
        headers={
            "User-Agent": USER_AGENT,
            "Accept": "application/json",
            "Content-Type": "application/x-www-form-urlencoded",
        },
        method="POST",
    )
    with request.urlopen(req, timeout=HTTP_TIMEOUT_SECONDS) as response:
        return json.loads(response.read().decode("utf-8"))


def _haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    radius_km = 6371.0
    d_lat = math.radians(lat2 - lat1)
    d_lon = math.radians(lon2 - lon1)
    a = (
        math.sin(d_lat / 2) ** 2
        + math.cos(math.radians(lat1))
        * math.cos(math.radians(lat2))
        * math.sin(d_lon / 2) ** 2
    )
    return radius_km * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def _infer_service_types(
    category: Category,
    text: str,
    selected_service_types: List[str],
) -> List[str]:
    normalized = text.lower()
    matches: List[str] = []
    normalized_selected_types = _normalize_service_types(selected_service_types)

    if category == Category.car_wash:
        is_wash_place = _contains_any(
            normalized,
            [
                "wash",
                "washing",
                "car wash",
                "auto wash",
                "car spa",
            ],
        )
        premium_match = _contains_any(
            normalized,
            ["detail", "detailing", "wax", "polish", "ceramic", "coating"],
        )
        interior_match = _contains_any(
            normalized,
            ["interior", "vacuum", "upholstery", "cabin", "seat cleaning"],
        )

        if is_wash_place:
            matches.append("Basic Wash")
        if premium_match:
            matches.append("Premium Wash")
        if interior_match:
            matches.append("Interior Cleaning")
    else:
        oil_match = _contains_any(
            normalized,
            [
                "oil",
                "engine oil",
                "lube",
                "lubrication",
                "oil filter",
                "quick lube",
            ],
        )
        engine_match = _contains_any(
            normalized,
            [
                "engine",
                "repair",
                "diagnostic",
                "mechanic",
                "garage",
                "workshop",
                "tune up",
                "tune-up",
                "service center",
                "service centre",
                "car repair",
                "auto repair",
            ],
        )
        tire_match = _contains_any(
            normalized,
            [
                "tire",
                "tyre",
                "wheel alignment",
                "wheel balancing",
                "wheel balance",
                "alloy wheel",
                "rim",
                "puncture",
            ],
        )

        if oil_match:
            matches.append("Oil Change")
        if engine_match:
            matches.append("Engine Check")
        if tire_match:
            matches.append("Tire Shop")

        if not matches and _contains_any(
            normalized,
            ["service", "motor", "auto care", "service center", "service centre"],
        ):
            matches.append("Engine Check")

    unique_matches: List[str] = []
    for match in matches:
        if match not in unique_matches:
            unique_matches.append(match)

    if category == Category.service and normalized_selected_types:
        return [
            service_type
            for service_type in unique_matches
            if service_type in normalized_selected_types
        ]

    return unique_matches

def _meaningful_place_types(place_types: Iterable[str]) -> List[str]:
    ignored = {
        "point_of_interest",
        "establishment",
        "store",
        "business",
        "food",
        "finance",
    }
    meaningful = []
    for place_type in place_types:
        if place_type in ignored:
            continue
        readable = place_type.replace("_", " ").title()
        if readable not in meaningful:
            meaningful.append(readable)
    return meaningful


def _describe_google_place(place_types: Iterable[str]) -> str:
    meaningful = _meaningful_place_types(place_types)
    if not meaningful:
        return ""
    return ", ".join(meaningful[:2])


def _matches_selected_service_types(
    inferred_types: List[str],
    selected_service_types: List[str],
) -> bool:
    normalized_selected_types = _normalize_service_types(selected_service_types)
    normalized_inferred_types = _normalize_service_types(inferred_types)

    if not normalized_selected_types:
        return True
    if not normalized_inferred_types:
        return False
    return any(item in normalized_inferred_types for item in normalized_selected_types)

def _manifest_google_maps_api_key() -> Optional[str]:
    manifest_path = (
        Path(__file__).resolve().parents[1]
        / "vehicle_app"
        / "android"
        / "app"
        / "src"
        / "main"
        / "AndroidManifest.xml"
    )
    try:
        manifest_text = manifest_path.read_text(encoding="utf-8")
    except OSError:
        return None

    match = MANIFEST_API_KEY_PATTERN.search(manifest_text)
    if not match:
        return None
    return match.group(1).strip() or None


def _google_places_api_key() -> Optional[str]:
    return (
        os.getenv("GOOGLE_PLACES_API_KEY")
        or os.getenv("GOOGLE_MAPS_API_KEY")
        or _manifest_google_maps_api_key()
    )


def _google_nearby_keywords(
    category: Category,
    search: Optional[str],
    service_types: List[str],
) -> List[str]:
    terms: List[str] = []
    if search and search.strip():
        terms.append(search.strip())

    normalized_service_types = _normalize_service_types(service_types)
    if not normalized_service_types:
        if category == Category.car_wash:
            terms.extend(["car wash", "car detailing", "car care", "auto detailing"])
        else:
            terms.extend(
                [
                    "car service",
                    "car repair",
                    "engine diagnostics",
                    "oil change",
                    "tire shop",
                ]
            )

    terms.extend(_query_terms_for_service_types(category, normalized_service_types))

    unique_terms: List[str] = []
    seen_terms = set()
    for term in terms:
        normalized = term.strip().lower()
        if not normalized or normalized in seen_terms:
            continue
        seen_terms.add(normalized)
        unique_terms.append(term.strip())
    return unique_terms[:8]

def _google_nearby_radius(category: Category) -> int:
    if category == Category.car_wash:
        return 12000
    return 16000


def _is_google_place_relevant(
    category: Category,
    name: str,
    address: str,
    place_types: List[str],
) -> bool:
    searchable_text = f"{name} {address}".lower()
    if any(term in searchable_text for term in ["academy", "training"]):
        return False

    if category == Category.car_wash:
        if "car_wash" in place_types:
            return True
        return any(
            term in searchable_text
            for term in ["wash", "detailing", "detail", "car care", "carepoint"]
        )

    if "car_repair" in place_types:
        return True
    return any(
        term in searchable_text
        for term in ["repair", "service", "oil", "tire", "tyre", "engine"]
    )


def _search_google_places(
    *,
    category: Category,
    latitude: float,
    longitude: float,
    search: Optional[str],
    service_types: List[str],
    limit: int,
) -> List[CarCareService]:
    api_key = _google_places_api_key()
    if not api_key:
        return []

    services: List[CarCareService] = []
    seen_ids = set()

    for keyword in _google_nearby_keywords(category, search, service_types):
        response = _request_json(
            "https://maps.googleapis.com/maps/api/place/nearbysearch/json",
            query_params={
                "location": f"{latitude},{longitude}",
                "rankby": "distance",
                "keyword": keyword,
                "key": api_key,
            },
        )

        status = str(response.get("status") or "")
        if status not in {"OK", "ZERO_RESULTS"}:
            continue

        for place in response.get("results", []):
            geometry = place.get("geometry") or {}
            location = geometry.get("location") or {}
            place_latitude = location.get("lat")
            place_longitude = location.get("lng")
            if place_latitude is None or place_longitude is None:
                continue

            name = str(place.get("name") or "").strip()
            if not name:
                continue

            place_id = str(place.get("place_id") or "")
            if place_id and place_id in seen_ids:
                continue
            if place_id:
                seen_ids.add(place_id)

            address = str(place.get("vicinity") or place.get("formatted_address") or "").strip()
            place_types = [str(item) for item in place.get("types", [])]
            if not _is_google_place_relevant(category, name, address, place_types):
                continue
            searchable_text = " ".join([name, address, *place_types])
            inferred_types = _infer_service_types(category, searchable_text, service_types)
            if not _matches_selected_service_types(inferred_types, service_types):
                continue

            services.append(
                CarCareService(
                    id=place_id or name.lower().replace(" ", "-"),
                    name=name,
                    shop_name=name if not _is_generic_business_name(name) else None,
                    address=address,
                    description=_describe_google_place(place_types),
                    rating=(place.get("rating") if isinstance(place.get("rating"), (int, float)) else None),
                    distance_km=_haversine_km(latitude, longitude, float(place_latitude), float(place_longitude)),
                    latitude=float(place_latitude),
                    longitude=float(place_longitude),
                    category=category,
                    service_types=inferred_types,
                    source="Google Maps",
                )
            )

        if len(services) >= max(limit, 10):
            break

    services.sort(key=lambda item: (item.distance_km, -(item.rating or 0)))
    return services[: max(limit, 10)]


def _build_address_from_tags(tags: dict[str, Any]) -> str:
    parts = [
        tags.get("addr:housenumber"),
        tags.get("addr:street"),
        tags.get("addr:suburb"),
        tags.get("addr:city") or tags.get("addr:place"),
        tags.get("addr:district"),
    ]
    address = ", ".join(str(part) for part in parts if part)
    if address:
        return address
    for field in ["addr:street", "addr:suburb", "addr:city", "addr:place", "addr:district"]:
        if tags.get(field):
            return str(tags[field])
    return "Colombo, Sri Lanka"


def _is_generic_business_name(value: str) -> bool:
    normalized = value.lower().strip(" .,-")
    if not normalized:
        return True
    if normalized in GENERIC_BUSINESS_NAMES:
        return True
    return (
        normalized.startswith("car wash - ")
        or normalized.startswith("service center - ")
        or normalized.startswith("car wash - car wash")
        or normalized.startswith("service center - service center")
    )


def _extract_locality_from_address(address: str) -> str:
    for part in [segment.strip() for segment in address.split(",") if segment.strip()]:
        if _is_generic_business_name(part):
            continue
        if part.lower() in {"colombo", "colombo 06", "sri lanka"}:
            continue
        return part
    return ""


def _smart_place_name(
    *,
    category: Category,
    tags: dict[str, Any],
    fallback_address: str,
) -> str:
    for field in ["name", "brand", "operator", "official_name", "alt_name"]:
        value = str(tags.get(field) or "").strip()
        if not value:
            continue
        if not _is_generic_business_name(value):
            return value
        if len(value.split()) > 2:
            return value

    locality = ""
    for field in ["addr:street", "addr:suburb", "addr:place", "addr:city", "addr:district"]:
        value = str(tags.get(field) or "").strip()
        if value and not _is_generic_business_name(value):
            locality = value
            break

    if not locality and fallback_address:
        locality = _extract_locality_from_address(fallback_address)

    prefix = "Car Wash" if category == Category.car_wash else "Service Center"
    if locality:
        return f"{prefix} - {locality}"
    return prefix


def _describe_osm_place(tags: dict[str, Any], category: Category) -> str:
    description_parts = []
    for field in ["amenity", "shop", "craft", "service"]:
        value = str(tags.get(field) or "").strip()
        if value:
            label = value.replace("_", " ").title()
            if label not in description_parts:
                description_parts.append(label)
    if description_parts:
        return ", ".join(description_parts[:2])
    return "Car Wash" if category == Category.car_wash else "Vehicle Service"


def _overpass_radius_meters(category: Category) -> int:
    # Use a large radius to capture all nearby places (like Google Maps does)
    if category == Category.car_wash:
        return 25000  # 25 km
    return 25000


def _build_overpass_query(category: Category, latitude: float, longitude: float) -> str:
    radius = _overpass_radius_meters(category)
    around = f"(around:{radius},{latitude},{longitude})"

    if category == Category.car_wash:
        # Use ONLY fast exact-tag selectors (regex selectors on name are too slow
        # and cause timeouts on Overpass). Named shops are found via Nominatim.
        selectors = [
            # Primary: standard car wash amenity tags
            'node["amenity"="car_wash"]',
            'way["amenity"="car_wash"]',
            'relation["amenity"="car_wash"]',
            # Car wash as a shop attribute
            'node["shop"="car_wash"]',
            'way["shop"="car_wash"]',
            # Car detailing shops
            'node["shop"="car_detailing"]',
            'way["shop"="car_detailing"]',
            # Any node tagged car_wash=yes (petrol stations etc.)
            'node["car_wash"="yes"]',
            'way["car_wash"="yes"]',
            # Laundry that may include vehicle wash (common in LK)
            'node["shop"="vehicle_inspection"]',
            'way["shop"="vehicle_inspection"]',
        ]
    else:
        selectors = [
            'node["shop"="car_repair"]',
            'way["shop"="car_repair"]',
            'relation["shop"="car_repair"]',
            'node["amenity"="car_repair"]',
            'way["amenity"="car_repair"]',
            'node["shop"="tyres"]',
            'way["shop"="tyres"]',
            'node["shop"="automotive"]',
            'way["shop"="automotive"]',
            'node["craft"="car_repair"]',
            'way["craft"="car_repair"]',
        ]

    lines = ["[out:json][timeout:20];", "("]
    for selector in selectors:
        lines.append(f"  {selector}{around};")
    lines.extend([");", "out center tags;"])
    return "\n".join(lines)


def _search_overpass_places(
    *,
    category: Category,
    latitude: float,
    longitude: float,
    search: Optional[str],
    service_types: List[str],
    limit: int,
) -> List[CarCareService]:
    query = _build_overpass_query(category, latitude, longitude)
    payload = None
    last_error: Optional[Exception] = None
    for endpoint in OVERPASS_ENDPOINTS:
        try:
            payload = _post_form(endpoint, {"data": query})
            break
        except Exception as exc:
            last_error = exc

    if payload is None:
        if last_error is not None:
            raise last_error
        return []

    normalized_search = (search or "").strip().lower()
    services: List[CarCareService] = []
    seen_keys = set()

    for element in payload.get("elements", []):
        tags = element.get("tags") or {}
        place_latitude = element.get("lat") or (element.get("center") or {}).get("lat")
        place_longitude = element.get("lon") or (element.get("center") or {}).get("lon")
        if place_latitude is None or place_longitude is None:
            continue

        fallback_address = _build_address_from_tags(tags)
        name = _smart_place_name(
            category=category,
            tags=tags,
            fallback_address=fallback_address,
        )
        searchable_text = " ".join(
            [
                name,
                fallback_address,
                str(tags.get("name") or ""),
                str(tags.get("brand") or ""),
                str(tags.get("operator") or ""),
                str(tags.get("amenity") or ""),
                str(tags.get("shop") or ""),
                str(tags.get("service") or ""),
            ]
        ).lower()
        if normalized_search and normalized_search not in searchable_text:
            continue

        inferred_types = _infer_service_types(category, searchable_text, service_types)
        if not _matches_selected_service_types(inferred_types, service_types):
            continue

        key = (
            name.lower(),
            round(float(place_latitude), 5),
            round(float(place_longitude), 5),
        )
        if key in seen_keys:
            continue
        seen_keys.add(key)

        # Extract the raw shop name from OSM tags for display
        raw_shop_name = (
            str(tags.get("name") or "").strip()
            or str(tags.get("brand") or "").strip()
            or str(tags.get("operator") or "").strip()
        )
        services.append(
            CarCareService(
                id=f"osm-{element.get('type', 'place')}-{element.get('id', len(services))}",
                name=name,
                shop_name=raw_shop_name if raw_shop_name and not _is_generic_business_name(raw_shop_name) else None,
                address=fallback_address,
                description=_describe_osm_place(tags, category),
                rating=None,
                distance_km=_haversine_km(latitude, longitude, float(place_latitude), float(place_longitude)),
                latitude=float(place_latitude),
                longitude=float(place_longitude),
                category=category,
                service_types=inferred_types,
                source="OpenStreetMap",
            )
        )

    services.sort(key=lambda item: (item.distance_km, -(item.rating or 0)))
    # Return ALL found services â€” caller decides how many to keep
    return services


def _search_nominatim_places(
    *,
    category: Category,
    latitude: float,
    longitude: float,
    search: Optional[str],
    service_types: List[str],
    limit: int,
) -> List[CarCareService]:
    """
    Search Nominatim using a large viewbox centred on the user's actual coordinates.
    Uses multiple search terms and collects all unique results.
    """
    desired_results = max(limit, 10)
    terms = _query_terms_for_service_types(category, service_types)
    if search and search.strip():
        terms = [f"{search.strip()} {term}" for term in terms]

    services: List[CarCareService] = []
    seen_ids = set()

    # Wide viewbox (~Â±0.35 deg â‰ˆ 39 km) \u2014 strict bounded so we NEVER get Jaffna etc.
    viewbox_margin = 0.35
    viewbox = (
        f"{longitude - viewbox_margin},{latitude + viewbox_margin},"
        f"{longitude + viewbox_margin},{latitude - viewbox_margin}"
    )

    # Build a combined list of queries:
    # 1. Free-text search terms (e.g. "car wash", "car spa", "auto detailing")
    # 2. Structured amenity/shop type searches that catch named places not in text search
    if category == Category.car_wash:
        structured_queries = [
            {"amenity": "car_wash"},
            {"shop": "car_detailing"},
            {"shop": "car_wash"},
        ]
    else:
        structured_queries = [
            {"shop": "car_repair"},
            {"amenity": "car_repair"},
            {"shop": "tyres"},
        ]

    all_query_params: List[dict] = []
    for term in terms:
        all_query_params.append({
            "format": "jsonv2",
            "q": term,
            "countrycodes": "lk",
            "limit": 30,
            "addressdetails": 1,
            "viewbox": viewbox,
            "bounded": 1,
        })
    for sq in structured_queries:
        params: dict = {
            "format": "jsonv2",
            "countrycodes": "lk",
            "limit": 50,
            "addressdetails": 1,
            "viewbox": viewbox,
            "bounded": 1,
        }
        params.update(sq)
        all_query_params.append(params)

    for query_params in all_query_params:
        try:
            results = _request_json(
                "https://nominatim.openstreetmap.org/search",
                query_params=query_params,
            )
        except Exception:
            continue

        if not isinstance(results, list):
            continue

        for place in results:
            osm_id = str(place.get("osm_id") or "")
            if not osm_id or osm_id in seen_ids:
                continue
            seen_ids.add(osm_id)

            try:
                place_latitude = float(place["lat"])
                place_longitude = float(place["lon"])
            except (KeyError, TypeError, ValueError):
                continue

            # Only include places within 25 km
            dist = _haversine_km(latitude, longitude, place_latitude, place_longitude)
            if dist > 25.0:
                continue

            display_name = str(place.get("display_name") or "").strip()
            raw_name = str(place.get("name") or "").strip()
            fallback_address = display_name or "Sri Lanka"
            tags = {
                "name": raw_name,
                "addr:street": _extract_locality_from_address(fallback_address),
            }
            name = _smart_place_name(
                category=category,
                tags=tags,
                fallback_address=fallback_address,
            )

            searchable_text = " ".join(
                [
                    name,
                    display_name,
                    raw_name,
                    str(place.get("type") or ""),
                    str(place.get("class") or ""),
                ]
            )
            inferred_types = _infer_service_types(category, searchable_text, service_types)
            if not _matches_selected_service_types(inferred_types, service_types):
                continue

            description_parts = [
                str(place.get("type") or "").replace("_", " ").title(),
                str(place.get("class") or "").replace("_", " ").title(),
            ]
            description = ", ".join(part for part in description_parts if part)

            services.append(
                CarCareService(
                    id=f"nominatim-{osm_id}",
                    name=name,
                    shop_name=raw_name if raw_name and not _is_generic_business_name(raw_name) else None,
                    address=fallback_address,
                    description=description,
                    rating=None,
                    distance_km=dist,
                    latitude=place_latitude,
                    longitude=place_longitude,
                    category=category,
                    service_types=inferred_types,
                    source="OpenStreetMap",
                )
            )

    services.sort(key=lambda item: (item.distance_km, -(item.rating or 0)))
    return services


def _sort_services(services: List[CarCareService]) -> List[CarCareService]:
    services.sort(key=lambda item: (item.distance_km, -(item.rating or 0)))
    return services


def _load_live_services(
    *,
    search: Optional[str],
    category: Category,
    service_types: List[str],
    latitude: Optional[float],
    longitude: Optional[float],
    min_rating: Optional[float],
    limit: int,
) -> List[CarCareService]:
    center_latitude = latitude if latitude is not None else DEFAULT_LATITUDE
    center_longitude = longitude if longitude is not None else DEFAULT_LONGITUDE
    desired_limit = max(limit, 10)

    provider_errors: List[str] = []
    aggregated_services: List[CarCareService] = []
    seen_keys: set = set()
    providers = [
        ("google", _search_google_places),
        ("overpass", _search_overpass_places),
        ("nominatim", _search_nominatim_places),
    ]

    # Run ALL providers and merge â€” never stop early
    for provider_name, provider in providers:
        try:
            services = provider(
                category=category,
                latitude=center_latitude,
                longitude=center_longitude,
                search=search,
                service_types=service_types,
                limit=desired_limit * 4,
            )
            if min_rating is not None:
                services = [
                    s for s in services
                    if s.rating is not None and s.rating >= min_rating
                ]
            for service in _sort_services(services):
                # Hard distance cap â€” never show anything > 30 km (prevents Jaffna etc.)
                if service.distance_km > 30.0:
                    continue
                # De-duplicate by coordinates (4 decimal places â‰ˆ 11 m)
                coord_key = (
                    round(service.latitude, 4),
                    round(service.longitude, 4),
                )
                if coord_key in seen_keys:
                    continue
                seen_keys.add(coord_key)
                aggregated_services.append(service)
        except error.HTTPError as exc:
            provider_errors.append(f"{provider_name}: HTTP {exc.code}")
        except Exception as exc:
            provider_errors.append(f"{provider_name}: {exc}")

    if aggregated_services:
        # Prefer places with a real shop name; fall back to all if not enough
        named = [
            s for s in aggregated_services
            if not _is_generic_business_name(s.name)
        ]
        pool = named if len(named) >= max(desired_limit // 2, 3) else aggregated_services
        return _sort_services(pool)[:desired_limit]

    if provider_errors:
        raise HTTPException(
            status_code=503,
            detail="Live location lookup failed: " + " | ".join(provider_errors),
        )

    return []


@app.get("/")
def root() -> dict:
    return {
        "service": "Car Care Services API",
        "status": "online",
        "docs": "/docs",
        "live_sources": ["Google Maps", "OpenStreetMap"],
        "endpoints": {
            "health": "/health",
            "services": "/services",
            "nearest": "/locations/nearest",
        },
    }


@app.get("/health")
def health() -> dict:
    return {
        "status": "healthy",
        "google_places_configured": bool(_google_places_api_key()),
        "default_center": {
            "latitude": DEFAULT_LATITUDE,
            "longitude": DEFAULT_LONGITUDE,
        },
    }


@app.get("/services", response_model=ServiceListResponse)
def list_services(
    search: Optional[str] = Query(default=None),
    category: Category = Query(default=Category.car_wash),
    service_types: Optional[str] = Query(default=None),
    latitude: Optional[float] = Query(default=None),
    longitude: Optional[float] = Query(default=None),
    min_rating: Optional[float] = Query(default=None, ge=0, le=5),
    limit: int = Query(default=10, ge=1, le=20),
) -> ServiceListResponse:
    services = _load_live_services(
        search=search,
        category=category,
        service_types=_parse_service_types(service_types),
        latitude=latitude,
        longitude=longitude,
        min_rating=min_rating,
        limit=limit,
    )
    return ServiceListResponse(count=len(services), services=services)


@app.get("/locations/nearest", response_model=NearestLocationResponse)
def nearest_locations(
    search: Optional[str] = Query(default=None),
    category: Category = Query(default=Category.car_wash),
    service_types: Optional[str] = Query(default=None),
    latitude: Optional[float] = Query(default=None),
    longitude: Optional[float] = Query(default=None),
    min_rating: Optional[float] = Query(default=None, ge=0, le=5),
    limit: int = Query(default=10, ge=1, le=20),
) -> NearestLocationResponse:
    services = _load_live_services(
        search=search,
        category=category,
        service_types=_parse_service_types(service_types),
        latitude=latitude,
        longitude=longitude,
        min_rating=min_rating,
        limit=max(limit, 10),
    )
    trimmed = services[:limit]
    return NearestLocationResponse(count=len(trimmed), locations=trimmed)











