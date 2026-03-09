import importlib.util
import sys
import unittest
from pathlib import Path
from unittest.mock import patch


SCRIPT_PATH = Path(__file__).resolve().parents[1] / "scripts" / "build_nyc_poi_geojson.py"
SPEC = importlib.util.spec_from_file_location("build_nyc_poi_geojson", SCRIPT_PATH)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC is not None and SPEC.loader is not None
sys.modules[SPEC.name] = MODULE
SPEC.loader.exec_module(MODULE)


class BuildNycPoiHelpersTests(unittest.TestCase):
    def test_extract_lat_lon_from_direct_fields(self):
        row = {"latitude": "40.7128", "longitude": "-74.0060"}
        self.assertEqual(MODULE.extract_lat_lon(row), (40.7128, -74.006))

    def test_extract_lat_lon_from_location_object(self):
        row = {"location": {"latitude": "40.7", "longitude": "-73.9"}}
        self.assertEqual(MODULE.extract_lat_lon(row), (40.7, -73.9))

    def test_extract_lat_lon_from_geojson_polygon(self):
        row = {
            "the_geom": {
                "type": "Polygon",
                "coordinates": [[[-74.0, 40.7], [-73.9, 40.7], [-73.9, 40.8], [-74.0, 40.8], [-74.0, 40.7]]],
            }
        }
        lat, lon = MODULE.extract_lat_lon(row)
        self.assertTrue(40.7 <= lat <= 40.8)
        self.assertTrue(-74.0 <= lon <= -73.9)

    def test_pick_name_prefers_first_non_empty_candidate(self):
        row = {"name": "", "station_name": "Bedford Ave"}
        self.assertEqual(MODULE.pick_name(row, ("name", "station_name")), "Bedford Ave")

    def test_dedupe_key_uses_dedupe_field_when_present(self):
        source = MODULE.SourceConfig(
            dataset_id="x",
            category="food",
            label="test",
            name_fields=("name",),
            rank_score=1.0,
            dedupe_field="camis",
        )
        row = {"camis": "12345"}
        key = MODULE.dedupe_key("food", "Cafe", 40.7, -73.9, source, row)
        self.assertEqual(key, "food:camis:12345")

    def test_build_features_skips_failed_source(self):
        good = MODULE.SourceConfig(
            dataset_id="good-id",
            category="park",
            label="good_source",
            name_fields=("name",),
            rank_score=1.0,
        )
        bad = MODULE.SourceConfig(
            dataset_id="bad-id",
            category="food",
            label="bad_source",
            name_fields=("name",),
            rank_score=1.0,
        )

        def fake_fetch_rows(dataset_id, **kwargs):
            if dataset_id == "bad-id":
                raise RuntimeError("HTTP 404")
            return [{"name": "Prospect Park", "latitude": "40.66", "longitude": "-73.97"}]

        with patch.object(MODULE, "fetch_rows", side_effect=fake_fetch_rows):
            bundle = MODULE.build_features(sources=(good, bad), app_token=None, limit_per_source=None)

        self.assertEqual(bundle["type"], "FeatureCollection")
        self.assertEqual(len(bundle["features"]), 1)
        props = bundle["features"][0]["properties"]
        self.assertEqual(props["name"], "Prospect Park")
        self.assertEqual(props["category"], "park")


if __name__ == "__main__":
    unittest.main()
