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

    def test_prioritizes_categories_before_score_distance(self):
        self.assertIn("ORDER BY CASE CATEGORY WHEN 'LANDMARK' THEN 1 WHEN 'PARK' THEN 2 WHEN 'TRANSIT' THEN 3 WHEN 'FOOD' THEN 4 ELSE 5 END", self.sql)
        self.assertIn("(RANK_SCORE * 1000.0) - DIST_M DESC", self.sql)


if __name__ == "__main__":
    unittest.main()
