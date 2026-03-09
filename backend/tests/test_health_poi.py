import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MAIN_PY = ROOT / "app" / "main.py"


def normalize(text: str) -> str:
    return " ".join(text.upper().split())


class HealthPoiEndpointRegressionTests(unittest.TestCase):
    def setUp(self) -> None:
        self.source = normalize(MAIN_PY.read_text(encoding="utf-8"))

    def test_health_poi_route_exists(self):
        self.assertIn('@APP.GET("/HEALTH/POI")', self.source)

    def test_health_poi_queries_total_and_category_counts(self):
        self.assertIn('POI_TOTAL_SQL = "SELECT COUNT(*)::INT AS TOTAL FROM POI;"', self.source)
        self.assertIn('SELECT CATEGORY, COUNT(*)::INT AS N FROM POI GROUP BY CATEGORY ORDER BY CATEGORY;', self.source)

    def test_health_poi_response_contains_total_and_by_category(self):
        self.assertIn('RETURN {"OK": TRUE, "POI": {"TOTAL": TOTAL_ROW["TOTAL"], "BY_CATEGORY": BY_CATEGORY}}', self.source)


if __name__ == "__main__":
    unittest.main()
