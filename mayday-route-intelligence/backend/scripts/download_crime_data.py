"""
download_crime_data.py — Pull Philadelphia crime data from OpenDataPhilly Carto API.
Paginates by year. Saves to data/philly_crimes.csv.

Usage:
    python scripts/download_crime_data.py
"""
import sys
import time
import httpx
import pandas as pd
from pathlib import Path

DATA_DIR = Path(__file__).parent.parent / "data"
OUTPUT_PATH = DATA_DIR / "philly_crimes.csv"
BASE_URL = "https://phl.carto.com/api/v2/sql"

# Actual crime type names as they appear in the OpenDataPhilly database
CRIME_TYPES = [
    "Robbery Firearm", "Robbery No Firearm",
    "Theft from Vehicle", "Thefts", "Motor Vehicle Theft",
    "Aggravated Assault Firearm", "Aggravated Assault No Firearm",
    "Burglary Residential", "Burglary Non-Residential",
    "Other Assaults", "Narcotic / Drug Law Violations",
    "Vandalism/Criminal Mischief", "Weapon Violations",
    "Disorderly Conduct", "Receiving Stolen Property"
]

YEARS = list(range(2020, 2026))


def build_query(year: int) -> str:
    types_sql = ",".join(f"'{t}'" for t in CRIME_TYPES)
    # Single-line query — Carto rejects multi-line SQL
    return (
        f"SELECT dispatch_date,dispatch_time,point_y as lat,point_x as lng,"
        f"text_general_code,dc_dist,location_block,ucr_general "
        f"FROM incidents_part1_part2 "
        f"WHERE point_y IS NOT NULL AND point_x IS NOT NULL "
        f"AND dispatch_date>='{year}-01-01' AND dispatch_date<'{year + 1}-01-01' "
        f"AND text_general_code IN ({types_sql}) "
        f"ORDER BY dispatch_date,dispatch_time LIMIT 50000"
    )


def fetch_year(year: int, client: httpx.Client) -> pd.DataFrame:
    print(f"  Fetching {year}...", end=" ", flush=True)
    try:
        resp = client.get(BASE_URL, params={"q": build_query(year)}, timeout=120)
        resp.raise_for_status()
        data = resp.json()
        rows = data.get("rows", [])
        print(f"{len(rows):,} records")
        return pd.DataFrame(rows)
    except Exception as e:
        print(f"ERROR: {e}")
        return pd.DataFrame()


def main():
    DATA_DIR.mkdir(exist_ok=True)
    all_frames = []

    print("Downloading Philadelphia crime data from OpenDataPhilly...")
    print(f"Output: {OUTPUT_PATH}")
    print()

    with httpx.Client(follow_redirects=True) as client:
        for year in YEARS:
            df = fetch_year(year, client)
            if not df.empty:
                all_frames.append(df)
            time.sleep(0.5)

    if not all_frames:
        print("\nERROR: No data downloaded.")
        sys.exit(1)

    combined = pd.concat(all_frames, ignore_index=True)
    combined = combined.drop_duplicates()
    combined["lat"] = pd.to_numeric(combined["lat"], errors="coerce")
    combined["lng"] = pd.to_numeric(combined["lng"], errors="coerce")
    combined = combined.dropna(subset=["lat", "lng"])

    combined.to_csv(OUTPUT_PATH, index=False)
    print(f"\nSaved {len(combined):,} crime records to {OUTPUT_PATH}")
    print("\nCrime type breakdown:")
    for crime_type, count in combined["text_general_code"].value_counts().head(15).items():
        print(f"  {crime_type}: {count:,}")


if __name__ == "__main__":
    main()
