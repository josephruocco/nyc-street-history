import re
from fastapi import FastAPI, HTTPException

from .cache import SimpleTTLCache, encode_geohash
from .db import fetch_one, fetch_all
from .models import CardResponse, NearbyItem, Source
from .settings import settings
from .queries import (
    SNAP_STREET_SQL,
    NEIGHBORHOOD_SQL,
    NEARBY_POI_SQL,
    FACT_BY_STREETCODE_SQL,
    FACT_BY_STREETNAME_SQL,
    FACT_BY_PLACENAME_SQL,
    CROSS_STREET_SQL,
)

app = FastAPI(title="NYC Street History API")

NUMBERED_PAT = re.compile(r"^(E|W)\s*\d+|^\d+(st|nd|rd|th)\b", re.IGNORECASE)
ORDINAL_PAT = re.compile(r"^(\d+)(ST|ND|RD|TH)$", re.IGNORECASE)
CARD_CACHE_TTL_SECONDS = max(0, int(settings.card_cache_ttl_seconds))
CARD_CACHE_PRECISION = min(12, max(1, int(settings.card_cache_precision)))
CARD_CACHE = SimpleTTLCache()
POI_TOTAL_SQL = "SELECT COUNT(*)::int AS total FROM poi;"
POI_COUNTS_SQL = """
SELECT category, COUNT(*)::int AS n
FROM poi
GROUP BY category
ORDER BY category;
"""
FACT_TOTAL_SQL = "SELECT COUNT(*)::int AS total FROM fact;"
FACT_COUNTS_SQL = """
SELECT key_type, COUNT(*)::int AS n
FROM fact
GROUP BY key_type
ORDER BY key_type;
"""


def prettify_street_name(name: str | None) -> str | None:
    if not name:
        return name

    words = name.strip().split()
    out = []
    directional_map = {
        "N": "North",
        "S": "South",
        "E": "East",
        "W": "West",
        "NE": "Northeast",
        "NW": "Northwest",
        "SE": "Southeast",
        "SW": "Southwest",
    }

    for w in words:
        upper = w.upper()
        ordinal_match = ORDINAL_PAT.match(upper)

        if ordinal_match:
            out.append(f"{ordinal_match.group(1)}{ordinal_match.group(2).lower()}")
        elif upper in directional_map:
            out.append(directional_map[upper])
        elif upper in {"ST", "AVE", "AV", "RD", "DR", "PL", "CT", "BLVD", "PKWY", "TER", "LN", "WAY"}:
            out.append(upper.title())
        elif upper.isdigit():
            out.append(upper)
        else:
            out.append(upper.title())

    return " ".join(out)

def classify_mode(street_name: str | None) -> str:
    if not street_name:
        return "NEAR"
    if NUMBERED_PAT.search(street_name):
        return "NUMBERED_STREET"
    return "NAMED_STREET"


def normalize_fact_street_name(street_name: str | None) -> str | None:
    if not street_name:
        return None
    normalized = " ".join(street_name.strip().split()).lower()
    return normalized if normalized else None


def normalize_fact_place_name(place_name: str | None) -> str | None:
    if not place_name:
        return None
    normalized = " ".join(place_name.strip().split()).lower()
    return normalized if normalized else None


@app.get("/v1/card", response_model=CardResponse)
def card(lat: float, lon: float, acc: float = 25.0):
    cache_key = f"card:{encode_geohash(lat, lon, precision=CARD_CACHE_PRECISION)}"
    cached = CARD_CACHE.get(cache_key)
    if cached is not None:
        return CardResponse(**cached)

    radius_m = max(40, min(int(acc * 2.0), 120))

    street = fetch_one(SNAP_STREET_SQL, {"lat": lat, "lon": lon, "radius_m": radius_m})
    if not street:
        raise HTTPException(status_code=404, detail="No street segment found nearby")
    cross = fetch_one(CROSS_STREET_SQL, {"segment_id": street["id"], "lat": lat, "lon": lon})

    neighborhood = fetch_one(NEIGHBORHOOD_SQL, {"lat": lat, "lon": lon})
    nearby = fetch_all(NEARBY_POI_SQL, {"lat": lat, "lon": lon, "radius_m": 800, "limit_n": 6})

    mode = classify_mode(street.get("primary_name"))
    did_you_know = None
    sources: list[Source] = []

    if mode == "NAMED_STREET":
        fact = None

        if street.get("street_code"):
            fact = fetch_one(FACT_BY_STREETCODE_SQL, {"street_code": street["street_code"]})

        if not fact:
            normalized_street = normalize_fact_street_name(prettify_street_name(street.get("primary_name")))
            if normalized_street:
                fact = fetch_one(FACT_BY_STREETNAME_SQL, {"street_name": normalized_street})

        if fact:
            did_you_know = fact["fact_text"]
            sources.append(Source(label=fact.get("source_label") or "source", url=fact.get("source_url")))

    if not did_you_know:
        for item in nearby:
            if item.get("category") not in {"park", "landmark"}:
                continue
            if item.get("distance_m") is not None and item["distance_m"] > 300:
                continue
            normalized_place = normalize_fact_place_name(item.get("name"))
            if not normalized_place:
                continue
            fact = fetch_one(FACT_BY_PLACENAME_SQL, {"place_name": normalized_place})
            if not fact:
                continue
            did_you_know = fact["fact_text"]
            sources.append(Source(label=fact.get("source_label") or "source", url=fact.get("source_url")))
            break

    if not did_you_know and neighborhood:
        did_you_know = f"You’re in {neighborhood['name']}. Check nearby landmarks for context."

    response = CardResponse(
        canonical_street=prettify_street_name(street.get("primary_name")),
        cross_street=prettify_street_name(cross.get("primary_name")) if cross else None,
        borough=street.get("borough"),
        neighborhood=neighborhood["name"] if neighborhood else None,
        mode=mode,
        did_you_know=did_you_know,
        nearby=[NearbyItem(**n) for n in nearby],
        sources=sources,
    )
    if CARD_CACHE_TTL_SECONDS > 0:
        if hasattr(response, "model_dump"):
            CARD_CACHE.set(cache_key, response.model_dump(), ttl_seconds=CARD_CACHE_TTL_SECONDS)
        else:
            CARD_CACHE.set(cache_key, response.dict(), ttl_seconds=CARD_CACHE_TTL_SECONDS)
    return response

@app.get("/health")
def health():
    return {"ok": True}


@app.get("/health/poi")
def health_poi():
    total_row = fetch_one(POI_TOTAL_SQL, {}) or {"total": 0}
    category_rows = fetch_all(POI_COUNTS_SQL, {})
    by_category = {row["category"]: row["n"] for row in category_rows}
    return {"ok": True, "poi": {"total": total_row["total"], "by_category": by_category}}


@app.get("/health/facts")
def health_facts():
    total_row = fetch_one(FACT_TOTAL_SQL, {}) or {"total": 0}
    key_type_rows = fetch_all(FACT_COUNTS_SQL, {})
    by_key_type = {row["key_type"]: row["n"] for row in key_type_rows}
    return {"ok": True, "facts": {"total": total_row["total"], "by_key_type": by_key_type}}
