import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
QUERIES_PY = ROOT / "app" / "queries.py"


def normalize(text: str) -> str:
    return " ".join(text.upper().split())


class NearbyPoiSqlRegressionTests(unittest.TestCase):
    def setUp(self) -> None:
        self.sql = normalize(QUERIES_PY.read_text(encoding="utf-8"))

    def test_maps_supported_categories(self):
        self.assertIn("THEN 'PARK'", self.sql)
        self.assertIn("THEN 'LANDMARK'", self.sql)
        self.assertIn("THEN 'TRANSIT'", self.sql)
        self.assertIn("THEN 'FOOD'", self.sql)

    def test_filters_unknown_categories(self):
        self.assertIn("WHERE CATEGORY IS NOT NULL", self.sql)

    def test_uses_per_category_rank_for_balanced_results(self):
        self.assertIn("ROW_NUMBER() OVER ( PARTITION BY CATEGORY ORDER BY SCORE DESC ) AS CATEGORY_RANK", self.sql)
        self.assertIn("ORDER BY CATEGORY_RANK, CATEGORY_PRIORITY, SCORE DESC", self.sql)

    def test_boosts_nearby_civic_places_over_generic_results(self):
        self.assertIn("WHEN CATEGORY IN ('LANDMARK', 'PARK') AND DIST_M <= 250 THEN 2500", self.sql)
        self.assertIn("WHEN CATEGORY = 'TRANSIT' AND DIST_M <= 150 THEN 800", self.sql)
        self.assertIn("WHEN CATEGORY = 'FOOD' AND DIST_M <= 60 THEN 350", self.sql)


if __name__ == "__main__":
    unittest.main()
