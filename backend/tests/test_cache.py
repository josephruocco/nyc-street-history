import unittest

from app.cache import SimpleTTLCache, encode_geohash


class GeohashTests(unittest.TestCase):
    def test_encode_geohash_known_reference_value(self):
        # Canonical reference from common geohash examples.
        self.assertEqual(encode_geohash(42.6, -5.6, precision=5), "ezs42")

    def test_encode_geohash_precision_length(self):
        value = encode_geohash(40.718, -73.958, precision=6)
        self.assertEqual(len(value), 6)

    def test_encode_geohash_invalid_precision(self):
        with self.assertRaises(ValueError):
            encode_geohash(40.718, -73.958, precision=0)


class SimpleTTLCacheTests(unittest.TestCase):
    def test_set_get_before_expiry(self):
        cache = SimpleTTLCache()
        cache.set("k", {"v": 1}, ttl_seconds=30, now=100.0)
        self.assertEqual(cache.get("k", now=120.0), {"v": 1})

    def test_get_after_expiry_returns_none(self):
        cache = SimpleTTLCache()
        cache.set("k", "value", ttl_seconds=10, now=100.0)
        self.assertIsNone(cache.get("k", now=110.0))

    def test_non_positive_ttl_is_ignored(self):
        cache = SimpleTTLCache()
        cache.set("k", "value", ttl_seconds=0, now=100.0)
        self.assertIsNone(cache.get("k", now=100.0))


if __name__ == "__main__":
    unittest.main()
