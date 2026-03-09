import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
QUERIES_PY = ROOT / "app" / "queries.py"
MAIN_PY = ROOT / "app" / "main.py"


def normalize_sql(text: str) -> str:
    return " ".join(text.upper().split())


class CrossStreetSqlRegressionTests(unittest.TestCase):
    def test_cross_street_sql_excludes_same_name(self):
        sql = normalize_sql(QUERIES_PY.read_text(encoding="utf-8"))
        self.assertIn(
            "UPPER(BTRIM(S.PRIMARY_NAME)) <> UPPER(BTRIM(M.PRIMARY_NAME))",
            sql,
        )

    def test_cross_street_sql_ranks_by_intersection_proximity(self):
        sql = normalize_sql(QUERIES_PY.read_text(encoding="utf-8"))
        self.assertIn(
            "ORDER BY ST_DISTANCE(IX_POINT::GEOGRAPHY, USER_PT::GEOGRAPHY), ID",
            sql,
        )

    def test_cross_street_sql_uses_segment_intersection(self):
        sql = normalize_sql(QUERIES_PY.read_text(encoding="utf-8"))
        self.assertIn("ST_INTERSECTS(S.GEOM, M.GEOM)", sql)


class CardWiringRegressionTests(unittest.TestCase):
    def test_card_passes_lat_lon_to_cross_street_query(self):
        source = normalize_sql(MAIN_PY.read_text(encoding="utf-8"))
        self.assertIn(
            'CROSS = FETCH_ONE(CROSS_STREET_SQL, {"SEGMENT_ID": STREET["ID"], "LAT": LAT, "LON": LON})',
            source,
        )


if __name__ == "__main__":
    unittest.main()
