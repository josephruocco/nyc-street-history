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
