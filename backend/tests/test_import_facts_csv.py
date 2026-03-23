import importlib.util
import sys
import unittest
from pathlib import Path


SCRIPT_PATH = Path(__file__).resolve().parents[1] / "scripts" / "import_facts_csv.py"
SPEC = importlib.util.spec_from_file_location("import_facts_csv", SCRIPT_PATH)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC is not None and SPEC.loader is not None
sys.modules[SPEC.name] = MODULE
SPEC.loader.exec_module(MODULE)


class ImportFactsCsvTests(unittest.TestCase):
    def test_normalize_key_street_name_lowercases_and_squashes_spaces(self):
        key = MODULE.normalize_key({"key_type": "street_name", "key_value": "  North   7   Street  "})
        self.assertEqual(key, ("street_name", "north 7 street"))

    def test_normalize_key_street_code_keeps_value(self):
        key = MODULE.normalize_key({"key_type": "street_code", "key_value": "366530"})
        self.assertEqual(key, ("street_code", "366530"))

    def test_normalize_key_place_name_lowercases_and_squashes_spaces(self):
        key = MODULE.normalize_key({"key_type": "place_name", "key_value": "  Union   Square   Park  "})
        self.assertEqual(key, ("place_name", "union square park"))

    def test_row_to_params_rejects_missing_fact_text(self):
        params = MODULE.row_to_params({"key_type": "street_code", "key_value": "1", "fact_text": ""})
        self.assertIsNone(params)

    def test_parse_confidence_defaults_and_clamps(self):
        self.assertEqual(MODULE.parse_confidence(None), 0.5)
        self.assertEqual(MODULE.parse_confidence(""), 0.5)
        self.assertEqual(MODULE.parse_confidence("2.0"), 1.0)
        self.assertEqual(MODULE.parse_confidence("-1"), 0.0)

    def test_row_to_params_supports_structured_history_fields(self):
        params = MODULE.row_to_params(
            {
                "key_type": "street_name",
                "key_value": "Withers Street",
                "fact_text": "Withers Street is named for Reuben Withers.",
                "namesake": "Reuben Withers",
                "history_blurb": "Withers Street is named for Reuben Withers, a merchant tied to early Brooklyn ferries.",
                "image_url": "https://example.com/withers.jpg",
                "image_source_url": "https://example.com/source",
            }
        )
        self.assertEqual(params["namesake"], "Reuben Withers")
        self.assertEqual(params["history_blurb"], "Withers Street is named for Reuben Withers, a merchant tied to early Brooklyn ferries.")
        self.assertEqual(params["image_url"], "https://example.com/withers.jpg")
        self.assertEqual(params["image_source_url"], "https://example.com/source")


if __name__ == "__main__":
    unittest.main()
