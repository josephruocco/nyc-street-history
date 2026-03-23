from pydantic import BaseModel
from typing import List, Optional


class Source(BaseModel):
    label: str
    url: Optional[str] = None


class NearbyItem(BaseModel):
    name: str
    category: str
    distance_m: int


class HistoryEntry(BaseModel):
    namesake: Optional[str] = None
    blurb: Optional[str] = None
    image_url: Optional[str] = None
    image_source_url: Optional[str] = None
    source: Optional[Source] = None


class CardResponse(BaseModel):
    canonical_street: Optional[str] = None
    cross_street: Optional[str] = None
    borough: Optional[str] = None
    neighborhood: Optional[str] = None
    mode: str  # NAMED_STREET | NUMBERED_STREET | NEAR
    history: Optional[HistoryEntry] = None
    namesake: Optional[str] = None
    history_blurb: Optional[str] = None
    image_url: Optional[str] = None
    image_source_url: Optional[str] = None
    did_you_know: Optional[str] = None
    nearby: List[NearbyItem] = []
    sources: List[Source] = []
