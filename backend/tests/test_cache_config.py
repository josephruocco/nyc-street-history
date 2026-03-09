import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MAIN_PY = ROOT / "app" / "main.py"
SETTINGS_PY = ROOT / "app" / "settings.py"


def normalize(text: str) -> str:
    return " ".join(text.upper().split())


class CacheConfigRegressionTests(unittest.TestCase):
    def setUp(self) -> None:
        self.main_source = normalize(MAIN_PY.read_text(encoding="utf-8"))
        self.settings_source = normalize(SETTINGS_PY.read_text(encoding="utf-8"))

    def test_settings_exposes_cache_fields(self):
        self.assertIn("CARD_CACHE_TTL_SECONDS: INT = 45", self.settings_source)
        self.assertIn("CARD_CACHE_PRECISION: INT = 6", self.settings_source)

    def test_main_reads_cache_from_settings(self):
        self.assertIn("CARD_CACHE_TTL_SECONDS = MAX(0, INT(SETTINGS.CARD_CACHE_TTL_SECONDS))", self.main_source)
        self.assertIn("CARD_CACHE_PRECISION = MIN(12, MAX(1, INT(SETTINGS.CARD_CACHE_PRECISION)))", self.main_source)

    def test_main_skips_cache_write_when_ttl_zero(self):
        self.assertIn("IF CARD_CACHE_TTL_SECONDS > 0:", self.main_source)


if __name__ == "__main__":
    unittest.main()
