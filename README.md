# nyc-street-history

Scaffold for an NYC “where am I + did you know?” street/nearby card app.

## Quick start
```bash
cd infra
docker compose up --build#!/usr/bin/env bash
set -euo pipefail

# Creates the NYC street-history project scaffold + starter files.
# Usage:
#   chmod +x init_project.sh
#   ./init_project.sh nyc-street-history
#
# If you omit the argument, it creates ./nyc-street-history

ROOT="${1:-nyc-street-history}"

echo "Creating project at: $ROOT"

# Folders
mkdir -p "$ROOT"/{backend/app,backend/app/sql,infra,ios}

# -------------------------
# infra/docker-compose.yml
# -------------------------
cat > "$ROOT/infra/docker-compose.yml" <<'YAML'
services:
  db:
    image: postgis/postgis:16-3.4
    environment:
      POSTGRES_DB: streetdb
      POSTGRES_USER: streetuser
      POSTGRES_PASSWORD: streetpass
    ports:
      - "5432:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data

  api:
    build:
      context: ../backend
    environment:
      DATABASE_URL: postgresql+psycopg://streetuser:streetpass@db:5432/streetdb
    ports:
      - "8000:8000"
    depends_on:
      - db

volumes:
  pgdata:
YAML

# -------------------------
# backend/requirements.txt
# -------------------------
cat > "$ROOT/backend/requirements.txt" <<'REQ'
fastapi==0.115.8
uvicorn[standard]==0.30.6
pydantic-settings==2.6.1
sqlalchemy==2.0.36
psycopg==3.2.3
REQ

# -------------------------
# backend/Dockerfile
# -------------------------
cat > "$ROOT/backend/Dockerfile" <<'DOCKER'
FROM python:3.12-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
  && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
DOCKER

# -------------------------
# backend/app/__init__.py
# -------------------------
cat > "$ROOT/backend/app/__init__.py" <<'PY'
# package marker
PY

# -------------------------
# backend/app/settings.py
# -------------------------
cat > "$ROOT/backend/app/settings.py" <<'PY'
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str

    class Config:
        env_prefix = ""
        case_sensitive = False


settings = Settings()
PY

# -------------------------
# backend/app/db.py
# -------------------------
cat > "$ROOT/backend/app/db.py" <<'PY'
from sqlalchemy import create_engine, text
from sqlalchemy.engine import Engine

from .settings import settings

engine: Engine = create_engine(settings.database_url, pool_pre_ping=True)


def fetch_one(sql: str, params: dict):
    with engine.connect() as conn:
        row = conn.execute(text(sql), params).mappings().first()
        return dict(row) if row else None


def fetch_all(sql: str, params: dict):
    with engine.connect() as conn:
        rows = conn.execute(text(sql), params).mappings().all()
        return [dict(r) for r in rows]
PY

# -------------------------
# backend/app/models.py
# -------------------------
cat > "$ROOT/backend/app/models.py" <<'PY'
from pydantic import BaseModel
from typing import List, Optional


class Source(BaseModel):
    label: str
    url: Optional[str] = None


class NearbyItem(BaseModel):
    name: str
    category: str
    distance_m: int


class CardResponse(BaseModel):
    canonical_street: Optional[str] = None
    cross_street: Optional[str] = None
    borough: Optional[str] = None
    neighborhood: Optional[str] = None
    mode: str  # NAMED_STREET | NUMBERED_STREET | NEAR
    did_you_know: Optional[str] = None
    nearby: List[NearbyItem] = []
    sources: List[Source] = []
PY

# -------------------------
# backend/app/queries.py
# -------------------------
cat > "$ROOT/backend/app/queries.py" <<'PY'
SNAP_STREET_SQL = """
WITH p AS (
  SELECT ST_SetSRID(ST_MakePoint(:lon, :lat), 4326) AS pt
)
SELECT
  id,
  street_code,
  primary_name,
  borough,
  ROUND(ST_Distance(geom::geography, p.pt::geography))::int AS dist_m
FROM street_segment, p
WHERE ST_DWithin(geom::geography, p.pt::geography, :radius_m)
ORDER BY ST_Distance(geom::geography, p.pt::geography)
LIMIT 1;
"""

NEIGHBORHOOD_SQL = """
SELECT name
FROM neighborhood
WHERE ST_Contains(geom, ST_SetSRID(ST_MakePoint(:lon, :lat), 4326))
LIMIT 1;
"""

NEARBY_POI_SQL = """
WITH p AS (
  SELECT ST_SetSRID(ST_MakePoint(:lon, :lat), 4326)::geography AS g
)
SELECT
  name,
  category,
  ROUND(ST_Distance(geom::geography, p.g))::int AS distance_m
FROM poi, p
WHERE ST_DWithin(geom::geography, p.g, :radius_m)
ORDER BY (rank_score * 1000.0) - ST_Distance(geom::geography, p.g) DESC
LIMIT :limit_n;
"""

FACT_BY_STREETCODE_SQL = """
SELECT fact_text, source_label, source_url, confidence
FROM fact
WHERE key_type = 'street_code' AND key_value = :street_code
ORDER BY confidence DESC, updated_at DESC
LIMIT 1;
"""
PY

# -------------------------
# backend/app/main.py
# -------------------------
cat > "$ROOT/backend/app/main.py" <<'PY'
import re
from fastapi import FastAPI, HTTPException

from .db import fetch_one, fetch_all
from .models import CardResponse, NearbyItem, Source
from .queries import SNAP_STREET_SQL, NEIGHBORHOOD_SQL, NEARBY_POI_SQL, FACT_BY_STREETCODE_SQL

app = FastAPI(title="NYC Street History API")

NUMBERED_PAT = re.compile(r"^(E|W)\s*\d+|^\d+(st|nd|rd|th)\b", re.IGNORECASE)

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
        canonical_street=street.get("primary_name"),
        cross_street=None,
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
PY

# -------------------------
# backend/app/sql/init.sql
# -------------------------
cat > "$ROOT/backend/app/sql/init.sql" <<'SQL'
CREATE EXTENSION IF NOT EXISTS postgis;

CREATE TABLE IF NOT EXISTS street_segment (
  id BIGSERIAL PRIMARY KEY,
  street_code TEXT,
  primary_name TEXT,
  borough TEXT,
  geom geometry(LineString, 4326)
);

CREATE INDEX IF NOT EXISTS idx_street_segment_geom
  ON street_segment USING gist (geom);

CREATE TABLE IF NOT EXISTS neighborhood (
  id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  geom geometry(MultiPolygon, 4326)
);

CREATE INDEX IF NOT EXISTS idx_neighborhood_geom
  ON neighborhood USING gist (geom);

CREATE TABLE IF NOT EXISTS poi (
  id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  category TEXT NOT NULL,
  rank_score REAL NOT NULL DEFAULT 1.0,
  geom geometry(Point, 4326)
);

CREATE INDEX IF NOT EXISTS idx_poi_geom
  ON poi USING gist (geom);

CREATE TABLE IF NOT EXISTS fact (
  id BIGSERIAL PRIMARY KEY,
  key_type TEXT NOT NULL,
  key_value TEXT NOT NULL,
  fact_text TEXT NOT NULL,
  source_label TEXT,
  source_url TEXT,
  confidence REAL NOT NULL DEFAULT 0.5,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fact_key
  ON fact (key_type, key_value);
SQL

# -------------------------
# Root README + .gitignore (handy)
# -------------------------
cat > "$ROOT/README.md" <<'MD'
# nyc-street-history

Scaffold for an NYC “where am I + did you know?” street/nearby card app.

## Quick start
```bash
cd infra
docker compose up --build
