import re
from fastapi import FastAPI, HTTPException

from .db import fetch_one, fetch_all
from .models import CardResponse, NearbyItem, Source
from .queries import (
    SNAP_STREET_SQL,
    NEIGHBORHOOD_SQL,
    NEARBY_POI_SQL,
    FACT_BY_STREETCODE_SQL,
    CROSS_STREET_SQL,
)

app = FastAPI(title="NYC Street History API")

NUMBERED_PAT = re.compile(r"^(E|W)\s*\d+|^\d+(st|nd|rd|th)\b", re.IGNORECASE)
ORDINAL_PAT = re.compile(r"^(\d+)(ST|ND|RD|TH)$", re.IGNORECASE)


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

@app.get("/v1/card", response_model=CardResponse)
def card(lat: float, lon: float, acc: float = 25.0):
    radius_m = max(40, min(int(acc * 2.0), 120))

    street = fetch_one(SNAP_STREET_SQL, {"lat": lat, "lon": lon, "radius_m": radius_m})
    if not street:
        raise HTTPException(status_code=404, detail="No street segment found nearby")
    cross = fetch_one(CROSS_STREET_SQL, {"segment_id": street["id"]})

    neighborhood = fetch_one(NEIGHBORHOOD_SQL, {"lat": lat, "lon": lon})
    nearby = fetch_all(NEARBY_POI_SQL, {"lat": lat, "lon": lon, "radius_m": 800, "limit_n": 6})

    mode = classify_mode(street.get("primary_name"))
    did_you_know = None
    sources: list[Source] = []

    if mode == "NAMED_STREET" and street.get("street_code"):
        fact = fetch_one(FACT_BY_STREETCODE_SQL, {"street_code": street["street_code"]})
        if fact:
            did_you_know = fact["fact_text"]
            sources.append(Source(label=fact.get("source_label") or "source", url=fact.get("source_url")))

    if not did_you_know and neighborhood:
        did_you_know = f"You’re in {neighborhood['name']}. Check nearby landmarks for context."

    return CardResponse(
        canonical_street=prettify_street_name(street.get("primary_name")),
        cross_street=prettify_street_name(cross.get("primary_name")) if cross else None,
        borough=street.get("borough"),
        neighborhood=neighborhood["name"] if neighborhood else None,
        mode=mode,
        did_you_know=did_you_know,
        nearby=[NearbyItem(**n) for n in nearby],
        sources=sources,
    )

@app.get("/health")
def health():
    return {"ok": True}
