#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR"

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

OUT_PATH="backend/data/pois.geojson"
CATEGORIES="${1:-park,transit,food}"

python3 backend/scripts/build_nyc_poi_geojson.py \
  --categories "$CATEGORIES" \
  --output "$OUT_PATH"

python3 backend/scripts/import_poi_geojson.py "$OUT_PATH"

python3 - <<'PY'
import os
import psycopg

url = os.environ.get("DATABASE_URL")
if not url:
    raise SystemExit("DATABASE_URL is required (set in .env or environment)")
if url.startswith("postgresql+psycopg://"):
    url = url.replace("postgresql+psycopg://", "postgresql://", 1)

with psycopg.connect(url) as conn:
    with conn.cursor() as cur:
        cur.execute("SELECT COUNT(*) FROM poi")
        total = cur.fetchone()[0]
        cur.execute("SELECT category, COUNT(*) FROM poi GROUP BY category ORDER BY category")
        rows = cur.fetchall()

print(f"[verify] poi total={total}")
for category, n in rows:
    print(f"[verify] {category}={n}")
PY
