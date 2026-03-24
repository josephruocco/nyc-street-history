#!/usr/bin/env python3
"""
Fetch Wikipedia summaries for neighborhood-guide streets not yet in facts_seed.csv,
then append new rows.

Usage (from repo root):
    python backend/scripts/enrich_guide_streets.py           # write to CSV
    python backend/scripts/enrich_guide_streets.py --dry-run # preview only
"""
from __future__ import annotations

import argparse
import csv
import json
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
FACTS_CSV = REPO_ROOT / "backend" / "data" / "facts_seed.csv"

# ─────────────────────────────────────────────────────────────────────────────
# Every street/place listed in NeighborhoodGuideStore that may be missing
# from facts_seed.csv.  Format: (normalized_key, display_name, wikipedia_title, namesake_hint)
# ─────────────────────────────────────────────────────────────────────────────
GUIDE_ENTRIES: list[tuple[str, str, str, str | None]] = [
    # Manhattan – Chinatown
    ("doyers street",        "Doyers Street",        "Doyers_Street",                         None),
    ("bayard street",        "Bayard Street",        "Bayard_Street_(Manhattan)",              "Nicholas Bayard"),
    # Manhattan – SoHo
    ("greene street",        "Greene Street",        "Greene_Street_(Manhattan)",              "Nathanael Greene"),
    ("wooster street",       "Wooster Street",       "Wooster_Street",                         "David Wooster"),
    ("broome street",        "Broome Street",        "Broome_Street",                          "John Broome"),
    ("spring street",        "Spring Street",        "Spring_Street_(Manhattan)",              None),
    ("prince street",        "Prince Street",        "Prince_Street_(Manhattan)",              None),
    # Manhattan – Tribeca
    ("reade street",         "Reade Street",         "Reade_Street",                           "Joseph Reade"),
    ("duane street",         "Duane Street",         "Duane_Street",                           "James Duane"),
    ("worth street",         "Worth Street",         "Worth_Street_(Manhattan)",               "William Jenkins Worth"),
    ("hudson street",        "Hudson Street",        "Hudson_Street_(Manhattan)",              None),
    ("greenwich street",     "Greenwich Street",     "Greenwich_Street_(Manhattan)",           None),
    ("west broadway",        "West Broadway",        "West_Broadway_(Manhattan)",              None),
    # Manhattan – Civic Center
    ("centre street",        "Centre Street",        "Centre_Street_(Manhattan)",              None),
    ("park row",             "Park Row",             "Park_Row_(Manhattan)",                   None),
    # Manhattan – Financial District
    ("broad street",         "Broad Street",         "Broad_Street_(Manhattan)",               None),
    ("stone street",         "Stone Street",         "Stone_Street_(Manhattan)",               None),
    # Manhattan – Greenwich Village
    ("macdougal street",     "MacDougal Street",     "MacDougal_Street",                       "Alexander McDougall"),
    ("christopher street",   "Christopher Street",   "Christopher_Street_(Manhattan)",         None),
    ("waverly place",        "Waverly Place",        "Waverly_Place_(Manhattan)",              None),
    # Brooklyn – Downtown Brooklyn
    ("court street",         "Court Street",         "Court_Street_(Brooklyn)",                None),
    ("smith street",         "Smith Street",         "Smith_Street_(Brooklyn)",                None),
    ("atlantic avenue",      "Atlantic Avenue",      "Atlantic_Avenue_(New_York_City)",        None),
    # Brooklyn – Brooklyn Heights
    ("montague street",      "Montague Street",      "Montague_Street_(Brooklyn)",             "Lady Mary Wortley Montagu"),
    ("joralemon street",     "Joralemon Street",     "Joralemon_Street",                       "Teunis Joralemon"),
    ("pierrepont street",    "Pierrepont Street",    "Pierrepont_Street",                      "Hezekiah Beers Pierrepont"),
    ("hicks street",         "Hicks Street",         "Hicks_Street_(Brooklyn)",                None),
    ("henry street",         "Henry Street",         "Henry_Street_(Brooklyn)",                None),
    # Brooklyn – DUMBO
    ("washington street",    "Washington Street",    "Washington_Street_(DUMBO,_Brooklyn)",    "George Washington"),
    ("front street",         "Front Street",         "Front_Street_(Brooklyn)",                None),
    ("water street",         "Water Street",         "Water_Street_(Brooklyn,_New_York)",      None),
    # Brooklyn – Boerum Hill
    ("hoyt street",          "Hoyt Street",          "Hoyt_Street_(Brooklyn)",                 None),
    ("bond street",          "Bond Street",          "Bond_Street_(Brooklyn)",                 None),
    ("wyckoff street",       "Wyckoff Street",       "Wyckoff_Street",                         None),
    # Brooklyn – Bushwick
    ("knickerbocker avenue", "Knickerbocker Avenue", "Knickerbocker_Avenue",                   None),
    ("flushing avenue",      "Flushing Avenue",      "Flushing_Avenue",                        None),
    ("bushwick avenue",      "Bushwick Avenue",      "Bushwick_Avenue",                        None),
]

FIELDNAMES = [
    "key_type", "key_value", "fact_text", "namesake", "history_blurb",
    "image_url", "image_source_url", "source_label", "source_url", "confidence",
]


def load_existing_keys(path: Path) -> set[str]:
    if not path.exists():
        return set()
    with path.open(newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        return {row["key_value"].strip().lower() for row in reader}


def fetch_summary(title: str) -> dict | None:
    encoded = urllib.parse.quote(title, safe="_()")
    url = f"https://en.wikipedia.org/api/rest_v1/page/summary/{encoded}"
    req = urllib.request.Request(
        url,
        headers={"User-Agent": "nyc-street-history/1.0 (github.com/josephruocco/nyc-street-history)"},
    )
    try:
        with urllib.request.urlopen(req, timeout=12) as resp:
            if resp.status != 200:
                return None
            return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        if e.code != 404:
            print(f"  HTTP {e.code} for {title}", file=sys.stderr)
        return None
    except Exception as e:
        print(f"  Error for {title}: {e}", file=sys.stderr)
        return None


def trim_extract(text: str, max_sentences: int = 2) -> str:
    text = re.sub(r"\s+", " ", text).strip()
    # Remove coordinate blurbs: "(40°42′N 74°00′W / ...)"
    text = re.sub(r"\s*\([^)]*°[^)]*\)\s*", " ", text).strip()
    sentences = re.split(r"(?<=[.!?])\s+", text)
    return " ".join(sentences[:max_sentences]).strip()


def build_row(
    key: str,
    data: dict,
    namesake_hint: str | None,
) -> dict:
    extract = data.get("extract", "")
    blurb = trim_extract(extract, max_sentences=2) if extract else ""

    thumb = (data.get("thumbnail") or {})
    image_url = thumb.get("source", "")
    wiki_url = ((data.get("content_urls") or {}).get("desktop") or {}).get("page", "")

    namesake = namesake_hint or ""
    if not namesake and blurb:
        m = re.search(r"\bnamed (?:for|after)\s+([A-Z][a-zA-Z .'-]+?)(?:[,;.])", blurb)
        if m:
            namesake = m.group(1).strip()

    return {
        "key_type": "street_name",
        "key_value": key,
        "fact_text": blurb,
        "namesake": namesake,
        "history_blurb": blurb,
        "image_url": image_url,
        "image_source_url": wiki_url,
        "source_label": "Wikipedia",
        "source_url": wiki_url,
        "confidence": "0.75",
    }


def main(dry_run: bool = False) -> None:
    existing = load_existing_keys(FACTS_CSV)
    print(f"Existing facts: {len(existing)} entries in {FACTS_CSV.name}")
    print()

    new_rows: list[dict] = []
    skipped: list[str] = []

    for key, display_name, wiki_title, namesake_hint in GUIDE_ENTRIES:
        if key in existing:
            skipped.append(display_name)
            continue

        print(f"  {display_name} ...", end=" ", flush=True)
        data = fetch_summary(wiki_title)
        time.sleep(0.35)  # polite rate limit

        if data and data.get("extract"):
            new_rows.append(build_row(key, data, namesake_hint))
            print("✓")
        else:
            # Try plain display name as fallback title
            fallback_title = display_name.replace(" ", "_")
            data2 = fetch_summary(fallback_title)
            time.sleep(0.35)
            if data2 and data2.get("extract"):
                new_rows.append(build_row(key, data2, namesake_hint))
                print("✓ (fallback)")
            else:
                print("✗  no Wikipedia article found")

    print()
    print(f"Already covered:  {len(skipped)}")
    print(f"New entries found: {len(new_rows)}")

    if not new_rows:
        print("Nothing new to write.")
        return

    if dry_run:
        print("\n─── DRY RUN preview ───")
        for row in new_rows:
            preview = (row["history_blurb"] or "")[:90]
            print(f"  [{row['key_value']}]  {preview}…")
        return

    with FACTS_CSV.open("a", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDNAMES)
        for row in new_rows:
            writer.writerow(row)

    print(f"\nAppended {len(new_rows)} rows → {FACTS_CSV}")
    print("Re-run import_facts_csv.py to load them into the database.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Enrich facts_seed.csv with Wikipedia summaries for guide streets"
    )
    parser.add_argument("--dry-run", action="store_true", help="Preview without writing")
    args = parser.parse_args()
    main(dry_run=args.dry_run)
