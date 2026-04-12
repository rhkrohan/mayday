"""
build_crime_chains.py — Extract real criminal movement patterns from Philadelphia crime data.

For each robbery (Crime A), finds any crime that happened 5-45 minutes later within 3km.
These sequential pairs represent actual criminal escape vectors.

Output:
  data/crime_chains.csv    — all crime chain pairs with bearing/speed/distance
  data/escape_profiles.json — per-grid-cell directional escape probabilities

Usage:
    python scripts/build_crime_chains.py
"""
import json
import math
import sys
import time
import logging
from pathlib import Path

import numpy as np
import pandas as pd

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s")
logger = logging.getLogger(__name__)

DATA_DIR = Path(__file__).parent.parent / "data"
INPUT_PATH = DATA_DIR / "philly_crimes.csv"
CHAINS_OUTPUT = DATA_DIR / "crime_chains.csv"
PROFILES_OUTPUT = DATA_DIR / "escape_profiles.json"

ROBBERY_TYPES = {"Robbery Firearm", "Robbery No Firearm"}
MIN_DELTA_MINUTES = 5
MAX_DELTA_MINUTES = 45
MAX_DISTANCE_KM = 3.0
MAX_SPEED_KMH = 60.0
MIN_CHAINS_FOR_PROFILE = 5
GRID_CELL_DEG = 0.0045  # ~500m

DIRECTIONS = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
DIRECTION_BEARINGS = [0, 45, 90, 135, 180, 225, 270, 315]

# Philadelphia police district adjacency map
ADJACENT_DISTRICTS = {
    "1": ["3", "6", "9"],
    "2": ["5", "8", "25"],
    "3": ["1", "6", "9", "17"],
    "5": ["2", "8", "14", "18"],
    "6": ["1", "3", "9", "17", "22"],
    "7": ["8", "14", "19"],
    "8": ["2", "5", "7", "14", "25"],
    "9": ["1", "3", "17", "22", "26"],
    "12": ["16", "19", "24"],
    "14": ["5", "7", "8", "18", "19"],
    "15": ["24", "25", "35"],
    "16": ["12", "19", "24", "26"],
    "17": ["3", "6", "9", "22", "26"],
    "18": ["5", "14", "19"],
    "19": ["7", "12", "14", "16", "18"],
    "22": ["6", "9", "17", "26"],
    "24": ["12", "15", "16", "25", "35"],
    "25": ["2", "8", "15", "24", "35"],
    "26": ["9", "16", "17", "22"],
    "35": ["15", "24", "25"],
    "39": ["14", "19"],
}


def haversine_km(lat1, lng1, lat2, lng2):
    R = 6371.0
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lng2 - lng1)
    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def compute_bearing(lat1, lng1, lat2, lng2):
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dlambda = math.radians(lng2 - lng1)
    x = math.sin(dlambda) * math.cos(phi2)
    y = math.cos(phi1) * math.sin(phi2) - math.sin(phi1) * math.cos(phi2) * math.cos(dlambda)
    return (math.degrees(math.atan2(x, y)) + 360) % 360


def bearing_to_direction(bearing):
    idx = int((bearing + 22.5) / 45) % 8
    return DIRECTIONS[idx]


def grid_key(lat, lng):
    lat_cell = round(lat / GRID_CELL_DEG) * GRID_CELL_DEG
    lng_cell = round(lng / GRID_CELL_DEG) * GRID_CELL_DEG
    return f"{lat_cell:.4f}_{lng_cell:.4f}"


def districts_adjacent(d1, d2):
    d1, d2 = str(d1), str(d2)
    if d1 == d2:
        return True
    return d2 in ADJACENT_DISTRICTS.get(d1, [])


def load_and_prepare(path: Path) -> pd.DataFrame:
    logger.info(f"Loading crime data from {path}...")
    df = pd.read_csv(path)
    logger.info(f"  Loaded {len(df):,} records")

    # Parse datetime
    df["dispatch_date"] = pd.to_datetime(df["dispatch_date"], errors="coerce")
    df["dispatch_time"] = df["dispatch_time"].astype(str).str.strip()
    df["datetime"] = pd.to_datetime(
        df["dispatch_date"].dt.strftime("%Y-%m-%d") + " " + df["dispatch_time"],
        errors="coerce"
    )
    df = df.dropna(subset=["datetime", "lat", "lng"])
    df["lat"] = pd.to_numeric(df["lat"], errors="coerce")
    df["lng"] = pd.to_numeric(df["lng"], errors="coerce")
    df["dc_dist"] = df["dc_dist"].astype(str).str.strip()
    df = df.dropna(subset=["lat", "lng"])

    # Filter to valid Philly bounds
    df = df[(df["lat"] > 39.85) & (df["lat"] < 40.15) &
            (df["lng"] > -75.35) & (df["lng"] < -74.90)]

    df = df.sort_values("datetime").reset_index(drop=True)
    logger.info(f"  After cleaning: {len(df):,} records")
    return df


def extract_chains(df: pd.DataFrame) -> pd.DataFrame:
    logger.info("Extracting crime chains...")

    robberies = df[df["text_general_code"].isin(ROBBERY_TYPES)].copy()
    logger.info(f"  {len(robberies):,} robbery incidents (Crime A candidates)")

    chains = []
    total = len(robberies)

    for i, (_, crime_a) in enumerate(robberies.iterrows()):
        if i % 500 == 0:
            logger.info(f"  Processing {i:,}/{total:,} robberies...")

        a_lat = float(crime_a["lat"])
        a_lng = float(crime_a["lng"])
        a_dt = crime_a["datetime"]
        a_dist = crime_a["dc_dist"]

        # Candidate window: 5-45 minutes after Crime A
        t_min = a_dt + pd.Timedelta(minutes=MIN_DELTA_MINUTES)
        t_max = a_dt + pd.Timedelta(minutes=MAX_DELTA_MINUTES)

        candidates = df[(df["datetime"] >= t_min) & (df["datetime"] <= t_max)]

        for _, crime_b in candidates.iterrows():
            b_lat = float(crime_b["lat"])
            b_lng = float(crime_b["lng"])
            b_dist = crime_b["dc_dist"]

            # District check
            if not districts_adjacent(a_dist, b_dist):
                continue

            # Distance check
            dist_km = haversine_km(a_lat, a_lng, b_lat, b_lng)
            if dist_km > MAX_DISTANCE_KM or dist_km < 0.05:
                continue

            delta_minutes = (crime_b["datetime"] - a_dt).total_seconds() / 60.0
            implied_speed = dist_km / (delta_minutes / 60.0)

            if implied_speed > MAX_SPEED_KMH:
                continue

            bearing = compute_bearing(a_lat, a_lng, b_lat, b_lng)

            chains.append({
                "origin_lat": round(a_lat, 6),
                "origin_lng": round(a_lng, 6),
                "origin_district": a_dist,
                "origin_crime_type": crime_a["text_general_code"],
                "origin_time": a_dt.strftime("%H:%M"),
                "dest_lat": round(b_lat, 6),
                "dest_lng": round(b_lng, 6),
                "dest_crime_type": crime_b["text_general_code"],
                "bearing": round(bearing, 1),
                "distance_km": round(dist_km, 3),
                "delta_minutes": round(delta_minutes, 1),
                "implied_speed_kmh": round(implied_speed, 1),
                "hour_of_day": a_dt.hour,
                "day_of_week": a_dt.weekday(),
            })

    logger.info(f"  Found {len(chains):,} crime chain pairs")
    return pd.DataFrame(chains)


def build_escape_profiles(chains_df: pd.DataFrame) -> dict:
    logger.info("Building escape profiles by grid cell...")

    if chains_df.empty:
        logger.warning("No chains — returning empty profiles")
        return {}

    profiles = {}

    # Group by grid cell of the ORIGIN
    chains_df["grid_key"] = chains_df.apply(
        lambda r: grid_key(r["origin_lat"], r["origin_lng"]), axis=1
    )

    for cell_key, group in chains_df.groupby("grid_key"):
        if len(group) < MIN_CHAINS_FOR_PROFILE:
            continue

        # Parse grid cell center
        lat_str, lng_str = cell_key.split("_")
        center_lat = float(lat_str)
        center_lng = float(lng_str)

        # Bearing histogram (8 directions)
        def bearing_hist(subset):
            counts = {d: 0 for d in DIRECTIONS}
            for bearing in subset["bearing"]:
                d = bearing_to_direction(float(bearing))
                counts[d] += 1
            total = sum(counts.values())
            if total == 0:
                return {d: 1.0 / 8 for d in DIRECTIONS}
            return {d: round(v / total, 4) for d, v in counts.items()}

        all_probs = bearing_hist(group)

        day_group = group[group["hour_of_day"].between(6, 19)]
        night_group = group[~group["hour_of_day"].between(6, 19)]

        day_probs = bearing_hist(day_group) if len(day_group) >= 3 else all_probs
        night_probs = bearing_hist(night_group) if len(night_group) >= 3 else all_probs

        # Top escape points (by direction and dest_crime_type)
        top_dirs = sorted(all_probs.items(), key=lambda x: x[1], reverse=True)[:3]
        top_escape = [{"direction": d, "count": int(all_probs[d] * len(group))} for d, _ in top_dirs]

        # Chain count by hour
        hour_counts = [0] * 24
        for h in group["hour_of_day"]:
            hour_counts[int(h)] += 1

        # Sample chains (up to 5, preferring highest-bearing-probability direction)
        sample_rows = group.sample(min(5, len(group)), random_state=42)
        sample_chains = []
        for _, row in sample_rows.iterrows():
            sample_chains.append({
                "origin": [row["origin_lat"], row["origin_lng"]],
                "dest": [row["dest_lat"], row["dest_lng"]],
                "bearing": row["bearing"],
                "delta_minutes": row["delta_minutes"],
                "crime_b_type": row["dest_crime_type"],
                "time": row["origin_time"]
            })

        profiles[cell_key] = {
            "center_lat": center_lat,
            "center_lng": center_lng,
            "total_chains": len(group),
            "bearing_probabilities": all_probs,
            "day_bearing_probabilities": day_probs,
            "night_bearing_probabilities": night_probs,
            "avg_distance_km": round(float(group["distance_km"].mean()), 3),
            "avg_speed_kmh": round(float(group["implied_speed_kmh"].mean()), 1),
            "top_escape_points": top_escape,
            "chain_count_by_hour": hour_counts,
            "sample_chains": sample_chains
        }

    logger.info(f"  Built {len(profiles)} grid cell escape profiles")
    return profiles


def main():
    if not INPUT_PATH.exists():
        logger.error(f"Crime data not found at {INPUT_PATH}")
        logger.error("Run: python scripts/download_crime_data.py")
        sys.exit(1)

    t0 = time.time()
    df = load_and_prepare(INPUT_PATH)

    chains_df = extract_chains(df)

    if chains_df.empty:
        logger.warning("No crime chains extracted. Check your crime data.")
    else:
        chains_df.to_csv(CHAINS_OUTPUT, index=False)
        logger.info(f"Saved {len(chains_df):,} chains to {CHAINS_OUTPUT}")

    profiles = build_escape_profiles(chains_df)
    with open(PROFILES_OUTPUT, "w") as f:
        json.dump(profiles, f, indent=2)
    logger.info(f"Saved {len(profiles)} escape profiles to {PROFILES_OUTPUT}")

    elapsed = time.time() - t0
    logger.info(f"Done in {elapsed:.1f}s")
    logger.info("")
    logger.info("Summary:")
    logger.info(f"  Crime chain pairs: {len(chains_df):,}")
    logger.info(f"  Grid cells with profiles: {len(profiles)}")
    if not chains_df.empty:
        logger.info(f"  Avg escape distance: {chains_df['distance_km'].mean():.2f} km")
        logger.info(f"  Most common escape direction: {chains_df['bearing'].apply(bearing_to_direction).value_counts().index[0]}")


if __name__ == "__main__":
    main()
