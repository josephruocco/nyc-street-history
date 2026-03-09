import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MAIN_PY = ROOT / "app" / "main.py"


def normalize(text: str) -> str:
    return " ".join(text.upper().split())


class HealthFactsEndpointRegressionTests(unittest.TestCase):
    def setUp(self) -> None:
        self.source = normalize(MAIN_PY.read_text(encoding="utf-8"))

    def test_health_facts_route_exists(self):
        self.assertIn('@APP.GET("/HEALTH/FACTS")', self.source)

    def test_health_facts_queries_total_and_key_type_counts(self):
        self.assertIn('FACT_TOTAL_SQL = "SELECT COUNT(*)::INT AS TOTAL FROM FACT;"', self.source)
        self.assertIn('SELECT KEY_TYPE, COUNT(*)::INT AS N FROM FACT GROUP BY KEY_TYPE ORDER BY KEY_TYPE;', self.source)

    def test_health_facts_response_contains_total_and_by_key_type(self):
        self.assertIn('RETURN {"OK": TRUE, "FACTS": {"TOTAL": TOTAL_ROW["TOTAL"], "BY_KEY_TYPE": BY_KEY_TYPE}}', self.source)


if __name__ == "__main__":
    unittest.main()
