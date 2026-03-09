#!/usr/bin/env python3
"""Fetch a starter NYC POI bundle from Socrata and write normalized GeoJSON.

This script fetches a practical first-pass POI bundle for the app categories:
- park
- landmark
- transit
- food

Then use backend/scripts/import_poi_geojson.py to load into PostGIS.
"""

from __future__ import annotations

import argparse
import json
import os
from dataclasses import dataclass
from pathlib import Path
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen


BASE_URL = "https://data.cityofnewyork.us/resource"


@dataclass(frozen=True)
class SourceConfig:
    dataset_id: str
    category: str
    label: str
    name_fields: tuple[str, ...]
    rank_score: float
    base_url: str = BASE_URL
    where: str | None = None
    dedupe_field: str | None = None


DEFAULT_SOURCES: tuple[SourceConfig, ...] = (
    # NYC Parks properties (updated Jan 2026 in NYC Open Data metadata)
    SourceConfig(
        dataset_id="enfh-gkve",
        category="park",
        label="nyc_parks_properties",
        name_fields=("propertyname", "name", "park_name"),
        rank_score=1.4,
    ),
    # LPC landmarks (updated Feb 2026 in NYC Open Data metadata)
    SourceConfig(
        dataset_id="7mgd-s57w",
        category="landmark",
        label="lpc_landmarks",
        name_fields=("name", "lp_name", "building_name", "address"),
        rank_score=1.6,
    ),
    # Subway stations
    SourceConfig(
        dataset_id="39hk-dx4f",
        category="transit",
        label="subway_stations",
        name_fields=("name", "station_name"),
        rank_score=1.5,
        base_url="https://data.ny.gov/resource",
    ),
    # Restaurant inspection records (dedupe by CAMIS)
    SourceConfig(
        dataset_id="43nn-pn8j",
        category="food",
        label="dohmh_restaurants",
        name_fields=("dba", "restaurantname", "name"),
        rank_score=1.1,
        where="grade in ('A','B','C')",
        dedupe_field="camis",
    ),
)


def _safe_float(value: Any) -> float | None:
    if value is None:
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _point_from_location_obj(value: Any) -> tuple[float, float] | None:
    if not isinstance(value, dict):
        return None

    # Socrata "location" object may include latitude/longitude strings.
    lat = _safe_float(value.get("latitude"))
    lon = _safe_float(value.get("longitude"))
    if lat is not None and lon is not None:
        return lat, lon

    # GeoJSON-style object may include coordinates [lon, lat].
    coords = value.get("coordinates")
    if isinstance(coords, list) and len(coords) >= 2:
        lon = _safe_float(coords[0])
        lat = _safe_float(coords[1])
        if lat is not None and lon is not None:
            return lat, lon

    return None


def _flatten_points(geom_type: str, coords: Any) -> list[tuple[float, float]]:
    points: list[tuple[float, float]] = []

    if isinstance(coords, list) and len(coords) >= 2:
        lon = _safe_float(coords[0])
        lat = _safe_float(coords[1])
        if lat is not None and lon is not None:
            points.append((lat, lon))
            return points

    if isinstance(coords, list):
        for item in coords:
            points.extend(_flatten_points(geom_type, item))

    return points


def _point_from_geojson_obj(value: Any) -> tuple[float, float] | None:
    if not isinstance(value, dict):
        return None

    geom_type = value.get("type")
    coords = value.get("coordinates")
    if not isinstance(geom_type, str) or coords is None:
        return None

    pts = _flatten_points(geom_type, coords)
    if not pts:
        return None

    # Use simple centroid/average for polygon or multipolygon features.
    lat = sum(p[0] for p in pts) / len(pts)
    lon = sum(p[1] for p in pts) / len(pts)
    return lat, lon


def extract_lat_lon(row: dict[str, Any]) -> tuple[float, float] | None:
    for lat_key, lon_key in (
        ("latitude", "longitude"),
        ("lat", "lon"),
        ("lat", "lng"),
        ("y", "x"),
    ):
        lat = _safe_float(row.get(lat_key))
        lon = _safe_float(row.get(lon_key))
        if lat is not None and lon is not None:
            if -90 <= lat <= 90 and -180 <= lon <= 180:
                return lat, lon

    for key in ("location", "point", "georeference", "the_geom"):
        pt = _point_from_location_obj(row.get(key))
        if pt is None:
            pt = _point_from_geojson_obj(row.get(key))
        if pt is not None:
            lat, lon = pt
            if -90 <= lat <= 90 and -180 <= lon <= 180:
                return lat, lon

    return None


def pick_name(row: dict[str, Any], candidates: tuple[str, ...]) -> str | None:
    for field in candidates:
        value = row.get(field)
        if value is not None:
            text = str(value).strip()
            if text:
                return text
    return None


def fetch_rows(
    dataset_id: str,
    *,
    base_url: str,
    where: str | None,
    app_token: str | None,
    limit: int | None,
) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    offset = 0
    page_size = 50000

    while True:
        query: dict[str, Any] = {
            "$limit": page_size,
            "$offset": offset,
        }
        if where:
            query["$where"] = where

        url = f"{base_url}/{dataset_id}.json?{urlencode(query)}"
        headers = {"Accept": "application/json"}
        if app_token:
            headers["X-App-Token"] = app_token

        req = Request(url, headers=headers)
        try:
            with urlopen(req, timeout=60) as resp:
                rows = json.loads(resp.read().decode("utf-8"))
        except HTTPError as exc:
            raise RuntimeError(f"HTTP {exc.code} for dataset {dataset_id} URL {url}") from exc
        except URLError as exc:
            raise RuntimeError(f"Network error for dataset {dataset_id} URL {url}: {exc.reason}") from exc

        if not rows:
            break

        out.extend(rows)
        if limit is not None and len(out) >= limit:
            return out[:limit]

        if len(rows) < page_size:
            break
        offset += page_size

    return out


def dedupe_key(category: str, name: str, lat: float, lon: float, source: SourceConfig, row: dict[str, Any]) -> str:
    if source.dedupe_field:
        value = str(row.get(source.dedupe_field) or "").strip()
        if value:
            return f"{category}:{source.dedupe_field}:{value}"

    # round to avoid near-identical duplicates from source precision drift
    return f"{category}:{name.lower()}:{round(lat, 5)}:{round(lon, 5)}"


def build_features(*, sources: tuple[SourceConfig, ...], app_token: str | None, limit_per_source: int | None) -> dict[str, Any]:
    features: list[dict[str, Any]] = []
    seen: set[str] = set()
    loaded_sources = 0

    for source in sources:
        try:
            rows = fetch_rows(
                source.dataset_id,
                base_url=source.base_url,
                where=source.where,
                app_token=app_token,
                limit=limit_per_source,
            )
        except RuntimeError as exc:
            print(f"[warn] skipped source={source.label} dataset={source.dataset_id}: {exc}")
            continue

        loaded_sources += 1
        for row in rows:
            name = pick_name(row, source.name_fields)
            if not name:
                continue

            coords = extract_lat_lon(row)
            if coords is None:
                continue
            lat, lon = coords

            key = dedupe_key(source.category, name, lat, lon, source, row)
            if key in seen:
                continue
            seen.add(key)

            features.append(
                {
                    "type": "Feature",
                    "geometry": {"type": "Point", "coordinates": [lon, lat]},
                    "properties": {
                        "name": name,
                        "category": source.category,
                        "rank_score": source.rank_score,
                        "source": source.label,
                        "source_dataset": source.dataset_id,
                    },
                }
            )

    print(f"[info] loaded {loaded_sources}/{len(sources)} sources")
    return {"type": "FeatureCollection", "features": features}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build normalized NYC POI GeoJSON")
    parser.add_argument(
        "--output",
        default="backend/data/pois.geojson",
        help="Output GeoJSON path",
    )
    parser.add_argument(
        "--limit-per-source",
        type=int,
        default=None,
        help="Optional max rows fetched per source (for quick test runs)",
    )
    parser.add_argument(
        "--categories",
        default="park,landmark,transit,food",
        help="Comma-separated categories to include",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    categories = {c.strip().lower() for c in args.categories.split(",") if c.strip()}
    selected = tuple(s for s in DEFAULT_SOURCES if s.category in categories)

    if not selected:
        raise SystemExit("No valid categories selected")

    app_token = os.getenv("NYC_OPEN_DATA_APP_TOKEN")
    bundle = build_features(sources=selected, app_token=app_token, limit_per_source=args.limit_per_source)

    out_path = Path(args.output)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(bundle), encoding="utf-8")

    print(f"Wrote {len(bundle['features'])} features to {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
