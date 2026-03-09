from __future__ import annotations

from threading import Lock
from time import monotonic
from typing import Any


_BASE32 = "0123456789bcdefghjkmnpqrstuvwxyz"


def encode_geohash(lat: float, lon: float, precision: int = 6) -> str:
    """Encode WGS84 coordinates into a geohash string."""
    if precision <= 0:
        raise ValueError("precision must be > 0")

    lat_interval = [-90.0, 90.0]
    lon_interval = [-180.0, 180.0]

    geohash: list[str] = []
    bit = 0
    ch = 0
    even = True
    bits = [16, 8, 4, 2, 1]

    while len(geohash) < precision:
        if even:
            mid = (lon_interval[0] + lon_interval[1]) / 2.0
            if lon >= mid:
                ch |= bits[bit]
                lon_interval[0] = mid
            else:
                lon_interval[1] = mid
        else:
            mid = (lat_interval[0] + lat_interval[1]) / 2.0
            if lat >= mid:
                ch |= bits[bit]
                lat_interval[0] = mid
            else:
                lat_interval[1] = mid

        even = not even
        if bit < 4:
            bit += 1
        else:
            geohash.append(_BASE32[ch])
            bit = 0
            ch = 0

    return "".join(geohash)


class SimpleTTLCache:
    def __init__(self) -> None:
        self._lock = Lock()
        self._data: dict[str, tuple[float, Any]] = {}

    def get(self, key: str, *, now: float | None = None) -> Any | None:
        ts = monotonic() if now is None else now
        with self._lock:
            item = self._data.get(key)
            if item is None:
                return None
            expires_at, value = item
            if expires_at <= ts:
                del self._data[key]
                return None
            return value

    def set(self, key: str, value: Any, *, ttl_seconds: int, now: float | None = None) -> None:
        if ttl_seconds <= 0:
            return
        ts = monotonic() if now is None else now
        with self._lock:
            self._data[key] = (ts + ttl_seconds, value)

    def clear(self) -> None:
        with self._lock:
            self._data.clear()
