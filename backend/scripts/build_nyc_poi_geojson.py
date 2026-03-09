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
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen


BASE_URL = "https://data.cityofnewyork.us/resource"
POINT_WKT_RE = re.compile(r"POINT\s*\(\s*(-?\d+(?:\.\d+)?)\s+(-?\d+(?:\.\d+)?)\s*\)", re.IGNORECASE)


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


def _normalize_lat_lon(lat: float | None, lon: float | None) -> tuple[float, float] | None:
    if lat is None or lon is None:
        return None
    if -90 <= lat <= 90 and -180 <= lon <= 180:
        return lat, lon
    return None


def _point_from_wkt(value: Any) -> tuple[float, float] | None:
    if not isinstance(value, str):
        return None
    match = POINT_WKT_RE.search(value)
    if not match:
        return None
    lon = _safe_float(match.group(1))
    lat = _safe_float(match.group(2))
    return _normalize_lat_lon(lat, lon)


def _point_from_lat_lon_map(value: Any) -> tuple[float, float] | None:
    if not isinstance(value, dict):
        return None

    lat_keys = ("latitude", "lat", "y", "y_coordinate", "ycoord")
    lon_keys = ("longitude", "lon", "lng", "x", "x_coordinate", "xcoord")
    for lat_key in lat_keys:
        for lon_key in lon_keys:
            lat = _safe_float(value.get(lat_key))
            lon = _safe_float(value.get(lon_key))
            pt = _normalize_lat_lon(lat, lon)
            if pt is not None:
                return pt
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


def _find_point_recursive(value: Any) -> tuple[float, float] | None:
    # Direct pattern checks first
    for extractor in (_point_from_location_obj, _point_from_lat_lon_map, _point_from_geojson_obj, _point_from_wkt):
        pt = extractor(value)
        if pt is not None:
            return pt

    # Walk containers for nested coordinate objects.
    if isinstance(value, dict):
        for nested in value.values():
            pt = _find_point_recursive(nested)
            if pt is not None:
                return pt
    elif isinstance(value, list):
        for nested in value:
            pt = _find_point_recursive(nested)
            if pt is not None:
                return pt
    return None


def extract_lat_lon(row: dict[str, Any], source: SourceConfig) -> tuple[float, float] | None:
    for lat_key, lon_key in (
        ("latitude", "longitude"),
        ("lat", "lon"),
        ("lat", "lng"),
        ("y", "x"),
        ("y_coordinate", "x_coordinate"),
        ("ycoord", "xcoord"),
    ):
        lat = _safe_float(row.get(lat_key))
        lon = _safe_float(row.get(lon_key))
        pt = _normalize_lat_lon(lat, lon)
        if pt is not None:
            return pt

    # Check commonly geocoded fields first.
    for key in ("location", "point", "georeference", "the_geom", "geocoded_column", "shape"):
        pt = _find_point_recursive(row.get(key))
        if pt is not None:
            return pt

    # Last resort: deep walk across all values.
    for value in row.values():
        pt = _find_point_recursive(value)
        if pt is not None:
            return pt

    return None


def _clean_text(value: Any) -> str | None:
    if value is None:
        return None
    text = str(value).strip()
    return text if text else None


def pick_name(row: dict[str, Any], candidates: tuple[str, ...]) -> str | None:
    for field in candidates:
        text = _clean_text(row.get(field))
        if text:
            return text

    # Common schema variants across NYC/NYS Socrata datasets.
    for field in (
        "site_name",
        "park_name",
        "landmark_name",
        "station",
        "station_name",
        "name",
        "title",
        "dba",
        "facility_name",
    ):
        text = _clean_text(row.get(field))
        if text:
            return text

    # Last resort: any field containing "name" or "title".
    for key, value in row.items():
        lowered = key.lower()
        if "name" in lowered or "title" in lowered:
            text = _clean_text(value)
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
        total_rows = len(rows)
        missing_name = 0
        missing_coords = 0
        kept = 0

        for row in rows:
            name = pick_name(row, source.name_fields)
            if not name:
                missing_name += 1
                continue

            coords = extract_lat_lon(row, source)
            if coords is None:
                missing_coords += 1
                continue
            lat, lon = coords

            key = dedupe_key(source.category, name, lat, lon, source, row)
            if key in seen:
                continue
            seen.add(key)
            kept += 1

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
        print(
            f"[info] source={source.label} dataset={source.dataset_id} "
            f"rows={total_rows} kept={kept} missing_name={missing_name} missing_coords={missing_coords}"
        )
        if rows and kept == 0 and missing_name == total_rows:
            sample = rows[0]
            keys = sorted(sample.keys())
            name_like_keys = [k for k in keys if "name" in k.lower() or "title" in k.lower()]
            print(f"[debug] source={source.label} keys={keys[:40]}")
            print(f"[debug] source={source.label} name_like_keys={name_like_keys}")
            sample_text_fields = []
            for k, v in sample.items():
                if isinstance(v, str):
                    t = v.strip()
                    if t:
                        sample_text_fields.append((k, t[:80]))
                if len(sample_text_fields) >= 10:
                    break
            print(f"[debug] source={source.label} sample_text_fields={sample_text_fields}")

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
