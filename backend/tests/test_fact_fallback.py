import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MAIN_PY = ROOT / "app" / "main.py"
QUERIES_PY = ROOT / "app" / "queries.py"


def normalize(text: str) -> str:
    return " ".join(text.upper().split())


class FactFallbackSqlRegressionTests(unittest.TestCase):
    def setUp(self) -> None:
        self.queries = normalize(QUERIES_PY.read_text(encoding="utf-8"))

    def test_has_fact_by_street_name_sql(self):
        self.assertIn("FACT_BY_STREETNAME_SQL", self.queries)
        self.assertIn("WHERE KEY_TYPE = 'STREET_NAME'", self.queries)
        self.assertIn("LOWER(BTRIM(KEY_VALUE)) = :STREET_NAME", self.queries)


class FactFallbackWiringRegressionTests(unittest.TestCase):
    def setUp(self) -> None:
        self.main_source = normalize(MAIN_PY.read_text(encoding="utf-8"))

    def test_normalize_fact_street_name_exists(self):
        self.assertIn("DEF NORMALIZE_FACT_STREET_NAME(STREET_NAME: STR | NONE) -> STR | NONE:", self.main_source)

    def test_card_falls_back_to_fact_by_street_name(self):
        self.assertIn("FACT = FETCH_ONE(FACT_BY_STREETNAME_SQL, {\"STREET_NAME\": NORMALIZED_STREET})", self.main_source)


if __name__ == "__main__":
    unittest.main()
