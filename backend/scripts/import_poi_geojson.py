#!/usr/bin/env python3
"""Import POIs from a GeoJSON FeatureCollection into the poi table.

Usage:
  DATABASE_URL=postgresql://... python3 backend/scripts/import_poi_geojson.py path/to/pois.geojson
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

import psycopg


INSERT_SQL = """
INSERT INTO poi (name, category, rank_score, geom)
VALUES (
  %(name)s,
  %(category)s,
  %(rank_score)s,
  ST_SetSRID(ST_MakePoint(%(lon)s, %(lat)s), 4326)
);
"""


def normalize_category(raw: str) -> str | None:
    value = (raw or "").strip().lower()
    if value in {"park", "playground", "garden"}:
        return "park"
    if value in {"landmark", "historic", "museum", "monument"}:
        return "landmark"
    if value in {"transit", "subway", "bus", "train", "ferry"}:
        return "transit"
    if value in {"food", "restaurant", "cafe", "bar", "bakery"}:
        return "food"
    return None


def feature_to_row(feature: dict) -> dict | None:
    props = feature.get("properties") or {}
    geom = feature.get("geometry") or {}

    if geom.get("type") != "Point":
        return None

    coords = geom.get("coordinates") or []
    if len(coords) < 2:
        return None

    lon = float(coords[0])
    lat = float(coords[1])
    if not (-180 <= lon <= 180 and -90 <= lat <= 90):
        return None

    name = (props.get("name") or "").strip()
    if not name:
        return None

    category = normalize_category(str(props.get("category") or ""))
    if category is None:
        return None

    rank_score = props.get("rank_score", 1.0)
    try:
        rank_score = float(rank_score)
    except (TypeError, ValueError):
        rank_score = 1.0

    return {
        "name": name,
        "category": category,
        "rank_score": rank_score,
        "lon": lon,
        "lat": lat,
    }


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: import_poi_geojson.py path/to/pois.geojson", file=sys.stderr)
        return 2

    db_url = os.getenv("DATABASE_URL")
    if not db_url:
        print("DATABASE_URL is required", file=sys.stderr)
        return 2
    # Accept SQLAlchemy-style URL used by the API config.
    if db_url.startswith("postgresql+psycopg://"):
        db_url = db_url.replace("postgresql+psycopg://", "postgresql://", 1)

    geojson_path = Path(sys.argv[1])
    payload = json.loads(geojson_path.read_text(encoding="utf-8"))

    if payload.get("type") != "FeatureCollection":
        print("GeoJSON must be a FeatureCollection", file=sys.stderr)
        return 2

    features = payload.get("features") or []
    rows = []
    skipped = 0
    for feature in features:
        row = feature_to_row(feature)
        if row is None:
            skipped += 1
            continue
        rows.append(row)

    with psycopg.connect(db_url) as conn:
        with conn.cursor() as cur:
            cur.execute("TRUNCATE TABLE poi;")
            if rows:
                cur.executemany(INSERT_SQL, rows)
        conn.commit()

    print(f"Imported {len(rows)} POIs, skipped {skipped} features")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
