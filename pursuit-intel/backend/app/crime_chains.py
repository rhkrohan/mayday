"""
crime_chains.py — Utilities for working with pre-computed crime chain data.
"""
import math
import logging
import numpy as np
import pandas as pd
from typing import Optional

logger = logging.getLogger(__name__)

DIRECTIONS = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
DIRECTION_BEARINGS = [0, 45, 90, 135, 180, 225, 270, 315]
GRID_CELL_DEG = 0.0045  # ~500m at Philly latitude
BLEND_RADIUS_KM = 3.0   # spatial interpolation search radius


def bearing_to_direction(bearing: float) -> str:
    """Convert a compass bearing (0-360) to 8-direction label."""
    bearing = bearing % 360
    idx = int((bearing + 22.5) / 45) % 8
    return DIRECTIONS[idx]


def haversine_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Straight-line distance in km between two lat/lng points."""
    R = 6371.0
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lng2 - lng1)
    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def compute_bearing(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Compute compass bearing from point 1 to point 2 (degrees, 0=North)."""
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dlambda = math.radians(lng2 - lng1)
    x = math.sin(dlambda) * math.cos(phi2)
    y = math.cos(phi1) * math.sin(phi2) - math.sin(phi1) * math.cos(phi2) * math.cos(dlambda)
    bearing = math.degrees(math.atan2(x, y))
    return (bearing + 360) % 360


def grid_key(lat: float, lng: float) -> str:
    """Round lat/lng to nearest grid cell center."""
    lat_cell = round(lat / GRID_CELL_DEG) * GRID_CELL_DEG
    lng_cell = round(lng / GRID_CELL_DEG) * GRID_CELL_DEG
    return f"{lat_cell:.4f}_{lng_cell:.4f}"


def find_nearest_profile_key(lat: float, lng: float, profiles: dict, max_km: float = 2.0) -> Optional[str]:
    """Find the nearest escape profile cell to a given lat/lng."""
    best_key = None
    best_dist = float("inf")
    for key, profile in profiles.items():
        clat = profile["center_lat"]
        clng = profile["center_lng"]
        d = haversine_km(lat, lng, clat, clng)
        if d < best_dist and d <= max_km:
            best_dist = d
            best_key = key
    return best_key


def _extract_probs(profile: dict, is_night: bool) -> dict:
    """Extract and normalize direction probabilities from a profile."""
    if is_night:
        probs = dict(profile.get("night_bearing_probabilities") or profile.get("bearing_probabilities", {}))
    else:
        probs = dict(profile.get("day_bearing_probabilities") or profile.get("bearing_probabilities", {}))

    # Ensure all 8 directions present with a small non-zero floor
    for d in DIRECTIONS:
        if d not in probs:
            probs[d] = 0.005

    # Normalize to sum to 1
    total = sum(probs.values())
    if total > 0:
        probs = {d: v / total for d, v in probs.items()}
    return probs


def get_escape_profile(lat: float, lng: float, profiles: dict, hour: int) -> dict:
    """
    Return direction probabilities for a given location using spatial interpolation.

    Strategy:
    1. Try exact grid cell — use directly if it has enough chains
    2. Find all profile cells within BLEND_RADIUS_KM
    3. Blend their distributions weighted by inverse-distance² × chain_count bonus
    4. Only return uniform distribution if truly no data found within the radius
    """
    is_night = not (6 <= hour < 20)

    # ── 1. Try exact cell ────────────────────────────────────────────────────
    key = grid_key(lat, lng)
    exact = profiles.get(key)
    if exact and exact.get("total_chains", 0) >= 5:
        probs = _extract_probs(exact, is_night)
        return {
            "probabilities": probs,
            "chain_count": exact.get("total_chains", 0),
            "sample_chains": exact.get("sample_chains", [])[:5],
            "avg_distance_km": exact.get("avg_distance_km", 1.0),
            "avg_speed_kmh": exact.get("avg_speed_kmh", 15.0),
            "interpolated": False,
        }

    # ── 2. Spatial interpolation: collect all cells within blend radius ──────
    cell_weights = []
    for k, profile in profiles.items():
        clat = profile.get("center_lat")
        clng = profile.get("center_lng")
        if clat is None or clng is None:
            continue
        dist = haversine_km(lat, lng, clat, clng)
        if dist > BLEND_RADIUS_KM:
            continue

        # Weight = inverse-distance² — closer cells dominate
        w = 1.0 / max(dist, 0.05) ** 2

        # Bonus for cells with more chains (more statistically reliable)
        chain_count = profile.get("total_chains", 0)
        w *= (1.0 + math.log1p(chain_count) / 6.0)

        cell_weights.append((profile, w, dist, chain_count))

    if not cell_weights:
        # Truly no data anywhere nearby — uniform fallback
        logger.debug(f"No profiles within {BLEND_RADIUS_KM}km of ({lat:.4f},{lng:.4f}) — using uniform")
        uniform = {d: 1.0 / 8 for d in DIRECTIONS}
        return {"probabilities": uniform, "chain_count": 0, "sample_chains": [], "interpolated": True}

    # ── 3. Blend probability distributions ──────────────────────────────────
    total_weight = sum(w for _, w, _, _ in cell_weights)
    blended = {d: 0.0 for d in DIRECTIONS}
    total_chains_weighted = 0
    sample_chains = []

    for profile, w, dist, chain_count in cell_weights:
        probs = _extract_probs(profile, is_night)
        norm_w = w / total_weight
        for d in DIRECTIONS:
            blended[d] += norm_w * probs.get(d, 1.0 / 8)
        total_chains_weighted += int(chain_count * norm_w)
        if not sample_chains and profile.get("sample_chains"):
            sample_chains = profile["sample_chains"][:3]

    # Normalize blended result
    total = sum(blended.values())
    if total > 0:
        blended = {d: v / total for d, v in blended.items()}

    closest_dist = min(d for _, _, d, _ in cell_weights)
    logger.debug(
        f"Interpolated from {len(cell_weights)} cells, closest {closest_dist:.2f}km, "
        f"weighted chains={total_chains_weighted}"
    )

    return {
        "probabilities": blended,
        "chain_count": total_chains_weighted,
        "sample_chains": sample_chains,
        "avg_distance_km": 1.0,
        "avg_speed_kmh": 15.0,
        "interpolated": len(cell_weights) > 1,
    }


def get_nearby_chains(lat: float, lng: float, chains_df: pd.DataFrame, radius_km: float = 1.0) -> pd.DataFrame:
    """Get historical crime chains that originated near the given point."""
    if chains_df.empty:
        return chains_df

    required = {"origin_lat", "origin_lng"}
    if not required.issubset(chains_df.columns):
        return chains_df.head(0)

    dists = chains_df.apply(
        lambda r: haversine_km(lat, lng, r["origin_lat"], r["origin_lng"]), axis=1
    )
    return chains_df[dists <= radius_km].copy()


def direction_cone_contains(point_lat: float, point_lng: float,
                             origin_lat: float, origin_lng: float,
                             direction: str) -> bool:
    """Return True if the point falls within the 45° cone of the given direction from origin."""
    bearing = compute_bearing(origin_lat, origin_lng, point_lat, point_lng)
    dir_bearing = DIRECTION_BEARINGS[DIRECTIONS.index(direction)]
    diff = abs((bearing - dir_bearing + 180) % 360 - 180)
    return diff <= 22.5
