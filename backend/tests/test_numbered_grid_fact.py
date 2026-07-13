import os
import re
import unittest

os.environ.setdefault("DATABASE_URL", "postgresql://test")

from app.main import classify_mode, GRID_FACTS, GRID_FACT_DEFAULT  # noqa: E402


class ClassifyModeTests(unittest.TestCase):
    def test_numbered_streets_detected(self):
        for name in ["West 25 Street", "5 Avenue", "E 14 St", "21 Street",
                     "Avenue C", "North 6 Street", "83 Avenue"]:
            self.assertEqual(classify_mode(name), "NUMBERED_STREET", name)

    def test_named_streets_detected(self):
        for name in ["Broadway", "Fort Hamilton Parkway", "Bedford Avenue",
                     "Crescent Street"]:
            self.assertEqual(classify_mode(name), "NAMED_STREET", name)


class GridFactTests(unittest.TestCase):
    def test_all_boroughs_covered(self):
        self.assertEqual(
            set(GRID_FACTS), {"manhattan", "bronx", "queens", "brooklyn"}
        )

    def test_manhattan_credits_1811_plan(self):
        namesake, blurb = GRID_FACTS["manhattan"]
        self.assertIn("1811", namesake)
        self.assertIn("Commissioners", blurb)

    def test_style_rules(self):
        # no em dashes, no stylistic hyphens in served text
        for namesake, blurb in list(GRID_FACTS.values()) + [GRID_FACT_DEFAULT]:
            for text in (namesake, blurb):
                self.assertNotIn("—", text)
                self.assertNotIn("--", text)
                for token in re.findall(r"\S+-\S+", text):
                    self.assertRegex(token, r"^[A-Z]", f"stylistic hyphen: {token}")


if __name__ == "__main__":
    unittest.main()
