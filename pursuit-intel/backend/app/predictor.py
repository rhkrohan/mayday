"""
predictor.py — Core escape route prediction engine.
Uses crime chain analysis as the primary signal, supplemented by
street graph distances and crime density KDE.
"""
import math
import logging
import time
import numpy as np
import pandas as pd
from typing import Optional

from .models import (
    EscapeCorridor, EscapePoint, InterceptionPoint, SearchRadius,
    HeatmapPoint, PredictionResult, CrimeChainExample, IncidentInput
)
from .crime_chains import (
    DIRECTIONS, DIRECTION_BEARINGS, haversine_km, compute_bearing,
    bearing_to_direction, direction_cone_contains, get_escape_profile, get_nearby_chains
)

logger = logging.getLogger(__name__)

CRIME_CHAIN_WEIGHT = 0.55
INFRASTRUCTURE_WEIGHT = 0.30
KDE_WEIGHT = 0.15

FOOT_SPEED_KMH = 5.0
VEHICLE_SPEED_KMH = 30.0


class EscapeRoutePredictor:
    def __init__(self, G_walk, G_drive, escape_profiles: dict,
                 stations: dict, crime_df: pd.DataFrame, crime_chains: pd.DataFrame):
        self.G_walk = G_walk
        self.G_drive = G_drive
        self.escape_profiles = escape_profiles
        self.stations = stations
        self.crime_df = crime_df
        self.crime_chains = crime_chains
        self.kde = None
        self._risk_critical = 0.35  # calibrated at startup
        self._risk_high = 0.25
        self._fit_kde()
        self._calibrate_risk_thresholds()

    def _calibrate_risk_thresholds(self):
        """Set risk thresholds from actual escape profile distribution (data-driven)."""
        if not self.escape_profiles:
            return
        top_probs = []
        for profile in self.escape_profiles.values():
            probs = profile.get("bearing_probabilities", {})
            if probs:
                top_probs.append(max(probs.values()))
        if len(top_probs) < 10:
            return
        top_probs.sort()
        n = len(top_probs)
        self._risk_critical = top_probs[int(n * 0.75)]
        self._risk_high = top_probs[int(n * 0.50)]
        logger.info(
            f"Risk thresholds calibrated from {n} profiles — "
            f"CRITICAL≥{self._risk_critical:.3f}, HIGH≥{self._risk_high:.3f}"
        )

    def _fit_kde(self):
        try:
            from sklearn.neighbors import KernelDensity
            if self.crime_df.empty:
                return
            robbery_df = self.crime_df[
                self.crime_df["text_general_code"].str.contains("Robbery", na=False)
            ][["lat", "lng"]].dropna()
            if len(robbery_df) < 10:
                return
            coords = robbery_df.values.astype(float)
            self.kde = KernelDensity(bandwidth=0.003, metric="haversine")
            self.kde.fit(np.radians(coords))
            logger.info(f"KDE fitted on {len(coords)} robbery locations")
        except Exception as e:
            logger.warning(f"KDE fit failed: {e}")

    def _graph_distance(self, G, lat1: float, lng1: float, lat2: float, lng2: float) -> float:
        """Return shortest-path distance in meters, falling back to straight-line."""
        if G is None:
            return haversine_km(lat1, lng1, lat2, lng2) * 1000
        try:
            import osmnx as ox
            import networkx as nx
            src = ox.nearest_nodes(G, lng1, lat1)
            dst = ox.nearest_nodes(G, lng2, lat2)
            return nx.shortest_path_length(G, src, dst, weight="length")
        except Exception:
            return haversine_km(lat1, lng1, lat2, lng2) * 1000

    def _get_all_escape_points(self) -> list[dict]:
        points = []
        for st in self.stations.get("subway", []):
            points.append({**st, "type": "subway", "line": st.get("line", "")})
        for st in self.stations.get("regional_rail", []):
            points.append({**st, "type": "regional_rail", "line": st.get("line", "Regional")})
        for ramp in self.stations.get("highway_ramps", []):
            points.append({**ramp, "type": "highway", "line": None})
        return points

    def _infrastructure_scores(self, lat: float, lng: float,
                                hour: int, crime_type: str, is_night: bool) -> dict[str, float]:
        """
        For each of 8 directions, score how much attractive escape infrastructure
        lies in that cone within 5km.
        """
        scores = {d: 0.0 for d in DIRECTIONS}
        all_points = self._get_all_escape_points()

        for pt in all_points:
            dist_km = haversine_km(lat, lng, pt["lat"], pt["lng"])
            if dist_km > 5.0:
                continue

            # Weight by type
            weight = 1.0
            if pt["type"] == "subway":
                weight = 1.8 if is_night else 1.2
                # MFL penalty for late night / early morning
                if pt.get("line") == "MFL" and (hour >= 1 and hour <= 5):
                    weight *= 0.3
            elif pt["type"] == "highway":
                weight = 1.5 if "Firearm" in crime_type else 1.0
            elif pt["type"] == "regional_rail":
                weight = 1.2

            direction = bearing_to_direction(compute_bearing(lat, lng, pt["lat"], pt["lng"]))
            scores[direction] += weight / max(dist_km, 0.1)

        # Normalize
        total = sum(scores.values()) or 1.0
        return {d: v / total for d, v in scores.items()}

    def _kde_scores(self, lat: float, lng: float) -> dict[str, float]:
        """Score each direction by average crime density 500-2000m out."""
        scores = {d: 0.0 for d in DIRECTIONS}
        if self.kde is None:
            return {d: 1.0 / 8 for d in DIRECTIONS}

        try:
            sample_dist_km = 1.0
            for i, (direction, bearing) in enumerate(zip(DIRECTIONS, DIRECTION_BEARINGS)):
                bearing_rad = math.radians(bearing)
                # Offset ~1km in this direction
                dlat = (sample_dist_km / 111.0) * math.cos(bearing_rad)
                dlng = (sample_dist_km / (111.0 * math.cos(math.radians(lat)))) * math.sin(bearing_rad)
                pt = np.radians([[lat + dlat, lng + dlng]])
                score = float(np.exp(self.kde.score_samples(pt)[0]))
                scores[direction] = max(score, 0.0)

            total = sum(scores.values()) or 1.0
            return {d: v / total for d, v in scores.items()}
        except Exception as e:
            logger.warning(f"KDE scoring failed: {e}")
            return {d: 1.0 / 8 for d in DIRECTIONS}

    def _combine_scores(self, chain_probs: dict, infra_scores: dict, kde_scores: dict) -> dict[str, float]:
        combined = {}
        for d in DIRECTIONS:
            combined[d] = (
                CRIME_CHAIN_WEIGHT * chain_probs.get(d, 1.0 / 8) +
                INFRASTRUCTURE_WEIGHT * infra_scores.get(d, 1.0 / 8) +
                KDE_WEIGHT * kde_scores.get(d, 1.0 / 8)
            )
        total = sum(combined.values()) or 1.0
        return {d: v / total for d, v in combined.items()}

    def _rank_escape_points(self, lat: float, lng: float,
                             corridor_probs: dict, is_night: bool, crime_type: str,
                             nearby_chains: pd.DataFrame) -> list[EscapePoint]:
        all_pts = self._get_all_escape_points()
        candidates = []

        # Phase 1: fast haversine pre-filter + score — NO graph routing yet
        for pt in all_pts:
            dist_km = haversine_km(lat, lng, pt["lat"], pt["lng"])
            if dist_km > 5.0:
                continue

            direction = bearing_to_direction(compute_bearing(lat, lng, pt["lat"], pt["lng"]))
            corridor_prob = corridor_probs.get(direction, 0.0)

            # Count chain references using haversine (fast)
            chain_refs = 0
            if not nearby_chains.empty and "dest_lat" in nearby_chains.columns:
                dists = nearby_chains.apply(
                    lambda r: haversine_km(pt["lat"], pt["lng"], r["dest_lat"], r["dest_lng"]), axis=1
                )
                chain_refs = int((dists < 0.5).sum())

            score = corridor_prob * (1.0 / max(dist_km, 0.1)) + chain_refs * 0.05
            candidates.append({
                "pt": pt,
                "dist_km": dist_km,
                "dist_m": dist_km * 1000.0,  # haversine estimate initially
                "direction": direction,
                "corridor_prob": corridor_prob,
                "chain_refs": chain_refs,
                "score": score,
            })

        # Sort by score, take top 10 only
        candidates.sort(key=lambda x: x["score"], reverse=True)
        top = candidates[:10]

        # Phase 2: refine distances with graph routing for top 10 only
        for c in top:
            pt = c["pt"]
            try:
                if pt["type"] == "highway":
                    c["dist_m"] = self._graph_distance(self.G_drive, lat, lng, pt["lat"], pt["lng"])
                else:
                    c["dist_m"] = self._graph_distance(self.G_walk, lat, lng, pt["lat"], pt["lng"])
            except Exception:
                pass  # keep haversine estimate

        results = []
        for c in top:
            results.append(EscapePoint(
                name=c["pt"]["name"],
                type=c["pt"]["type"],
                line=c["pt"].get("line"),
                lat=c["pt"]["lat"],
                lng=c["pt"]["lng"],
                distance_meters=round(c["dist_m"]),
                probability=min(c["corridor_prob"] + 0.05 * c["chain_refs"], 1.0),
                chain_references=c["chain_refs"]
            ))

        results.sort(key=lambda x: x.probability, reverse=True)
        return results

    def _compute_interceptions(self, lat: float, lng: float,
                                corridors: list[EscapeCorridor],
                                escape_points: list[EscapePoint]) -> list[InterceptionPoint]:
        interceptions = []
        seen_dirs = set()

        top_corridors = sorted(corridors, key=lambda c: c.probability, reverse=True)[:3]
        for corridor in top_corridors:
            if corridor.direction in seen_dirs:
                continue
            seen_dirs.add(corridor.direction)

            # Find closest escape point in this direction
            pts_in_dir = [
                ep for ep in escape_points
                if direction_cone_contains(ep.lat, ep.lng, lat, lng, corridor.direction)
            ]

            if pts_in_dir:
                target = pts_in_dir[0]  # already sorted by score
                # Place interception at 60% of the way from incident to target
                interp_lat = lat + 0.6 * (target.lat - lat)
                interp_lng = lng + 0.6 * (target.lng - lng)
                street_name = None
                if self.G_walk is not None:
                    try:
                        import osmnx as ox
                        node = ox.nearest_nodes(self.G_walk, interp_lng, interp_lat)
                        node_data = self.G_walk.nodes[node]
                        # Try to find a street name from adjacent edges
                        edges = list(self.G_walk.edges(node, data=True))
                        if edges:
                            street_name = edges[0][2].get("name")
                            if isinstance(street_name, list):
                                street_name = street_name[0]
                    except Exception:
                        pass
            else:
                # Project 1.5km in this direction
                bearing_rad = math.radians(corridor.bearing)
                dlat = (1.5 / 111.0) * math.cos(bearing_rad)
                dlng = (1.5 / (111.0 * math.cos(math.radians(lat)))) * math.sin(bearing_rad)
                interp_lat = lat + dlat
                interp_lng = lng + dlng
                street_name = None

            interceptions.append(InterceptionPoint(
                lat=round(interp_lat, 5),
                lng=round(interp_lng, 5),
                direction=corridor.direction,
                probability=corridor.probability,
                street_name=street_name
            ))

        return interceptions

    def _compute_search_radius(self, lat: float, lng: float, elapsed_minutes: float) -> SearchRadius:
        from shapely.geometry import MultiPoint
        from shapely.ops import unary_union

        foot_dist_m = (elapsed_minutes / 60.0) * FOOT_SPEED_KMH * 1000.0
        vehicle_dist_m = (elapsed_minutes / 60.0) * VEHICLE_SPEED_KMH * 1000.0

        foot_polygon = self._isochrone_polygon(self.G_walk, lat, lng, foot_dist_m)
        vehicle_polygon = self._isochrone_polygon(self.G_drive, lat, lng, vehicle_dist_m)

        # Find reachable stations
        foot_km = foot_dist_m / 1000.0
        vehicle_km = vehicle_dist_m / 1000.0

        reachable_stations = []
        reachable_highways = []
        all_pts = self._get_all_escape_points()
        for pt in all_pts:
            d = haversine_km(lat, lng, pt["lat"], pt["lng"])
            if pt["type"] == "highway":
                if d <= vehicle_km:
                    reachable_highways.append(pt["name"])
            else:
                if d <= foot_km:
                    reachable_stations.append(pt["name"])
                elif d <= vehicle_km:
                    reachable_stations.append(f"{pt['name']} (vehicle)")

        return SearchRadius(
            foot_polygon=foot_polygon,
            vehicle_polygon=vehicle_polygon,
            elapsed_minutes=elapsed_minutes,
            foot_radius_km=round(foot_km, 2),
            vehicle_radius_km=round(vehicle_km, 2),
            reachable_stations=reachable_stations[:8],
            reachable_highways=reachable_highways[:6]
        )

    def _isochrone_polygon(self, G, lat: float, lng: float, radius_m: float) -> list[list[float]]:
        """Compute convex hull of reachable nodes within radius_m meters."""
        if G is None:
            # Approximate circle with 12 points
            return self._approx_circle(lat, lng, radius_m / 1000.0)

        try:
            import osmnx as ox
            import networkx as nx
            from shapely.geometry import MultiPoint

            source = ox.nearest_nodes(G, lng, lat)
            subgraph = nx.ego_graph(G, source, radius=radius_m, distance="length")
            node_lats = [G.nodes[n]["y"] for n in subgraph.nodes]
            node_lngs = [G.nodes[n]["x"] for n in subgraph.nodes]
            if len(node_lats) < 3:
                return self._approx_circle(lat, lng, radius_m / 1000.0)

            hull = MultiPoint(list(zip(node_lngs, node_lats))).convex_hull
            if hull.geom_type == "Polygon":
                coords = list(hull.exterior.coords)
                return [[c[1], c[0]] for c in coords]
            return self._approx_circle(lat, lng, radius_m / 1000.0)
        except Exception as e:
            logger.warning(f"Isochrone computation failed: {e}")
            return self._approx_circle(lat, lng, radius_m / 1000.0)

    def _approx_circle(self, lat: float, lng: float, radius_km: float, n: int = 16) -> list[list[float]]:
        points = []
        for i in range(n):
            bearing = (360.0 / n) * i
            bearing_rad = math.radians(bearing)
            dlat = (radius_km / 111.0) * math.cos(bearing_rad)
            dlng = (radius_km / (111.0 * math.cos(math.radians(lat)))) * math.sin(bearing_rad)
            points.append([round(lat + dlat, 5), round(lng + dlng, 5)])
        points.append(points[0])  # close polygon
        return points

    def _heatmap(self, lat: float, lng: float, grid_size: int = 20) -> list[HeatmapPoint]:
        """Generate a crime density heatmap grid around the incident."""
        if self.kde is None or self.crime_df.empty:
            return []
        try:
            span = 0.05  # ~5km
            lats = np.linspace(lat - span, lat + span, grid_size)
            lngs = np.linspace(lng - span, lng + span, grid_size)
            grid_lat, grid_lng = np.meshgrid(lats, lngs)
            pts = np.c_[grid_lat.ravel(), grid_lng.ravel()]
            scores = np.exp(self.kde.score_samples(np.radians(pts)))
            max_score = scores.max() or 1.0
            result = []
            for (plat, plng), score in zip(pts, scores):
                intensity = float(score / max_score)
                if intensity > 0.05:
                    result.append(HeatmapPoint(lat=round(plat, 5), lng=round(plng, 5), intensity=round(intensity, 3)))
            return result
        except Exception as e:
            logger.warning(f"Heatmap generation failed: {e}")
            return []

    def predict(self, lat: float, lng: float, crime_type: str, time_str: str,
                elapsed_minutes: float = 0.0) -> PredictionResult:
        hour = int(time_str.split(":")[0]) if ":" in time_str else 22
        is_night = hour >= 20 or hour < 6

        # 1. Historical escape profile from crime chain analysis
        profile = get_escape_profile(lat, lng, self.escape_profiles, hour)
        chain_probs = profile["probabilities"]
        chain_count = profile["chain_count"]
        sample_chains_raw = profile.get("sample_chains", [])

        # 2. Infrastructure-weighted scores
        infra_scores = self._infrastructure_scores(lat, lng, hour, crime_type, is_night)

        # 3. KDE crime density scores
        kde_scores = self._kde_scores(lat, lng)

        # 4. Combine
        final_probs = self._combine_scores(chain_probs, infra_scores, kde_scores)

        # 5. Build corridor objects
        nearby_chains = get_nearby_chains(lat, lng, self.crime_chains, radius_km=1.5)

        # Count chains per direction
        chain_counts_by_dir = {d: 0 for d in DIRECTIONS}
        if not nearby_chains.empty and "bearing" in nearby_chains.columns:
            for _, row in nearby_chains.iterrows():
                d = bearing_to_direction(float(row["bearing"]))
                chain_counts_by_dir[d] += 1

        corridors = []
        for direction, bearing in zip(DIRECTIONS, DIRECTION_BEARINGS):
            corridors.append(EscapeCorridor(
                direction=direction,
                probability=round(final_probs[direction], 4),
                bearing=float(bearing),
                historical_chain_count=chain_counts_by_dir[direction]
            ))
        corridors.sort(key=lambda c: c.probability, reverse=True)

        # 6. Rank escape points
        escape_points = self._rank_escape_points(lat, lng, final_probs, is_night, crime_type, nearby_chains)

        # 7. Interceptions
        interceptions = self._compute_interceptions(lat, lng, corridors, escape_points)

        # 8. Search radius
        search_radius = None
        if elapsed_minutes > 0:
            search_radius = self._compute_search_radius(lat, lng, elapsed_minutes)

        # 9. Heatmap
        heatmap = self._heatmap(lat, lng)

        # 10. Sample chains
        sample_chains = []
        for sc in sample_chains_raw[:5]:
            try:
                sample_chains.append(CrimeChainExample(
                    origin_lat=float(sc["origin"][0]),
                    origin_lng=float(sc["origin"][1]),
                    dest_lat=float(sc["dest"][0]),
                    dest_lng=float(sc["dest"][1]),
                    bearing=float(sc.get("bearing", 0)),
                    delta_minutes=float(sc.get("delta_minutes", 15)),
                    crime_b_type=str(sc.get("crime_b_type", "Unknown"))
                ))
            except Exception:
                pass

        # If no sample chains from profile, take from nearby_chains df
        if not sample_chains and not nearby_chains.empty:
            for _, row in nearby_chains.head(5).iterrows():
                try:
                    sample_chains.append(CrimeChainExample(
                        origin_lat=float(row["origin_lat"]),
                        origin_lng=float(row["origin_lng"]),
                        dest_lat=float(row["dest_lat"]),
                        dest_lng=float(row["dest_lng"]),
                        bearing=float(row.get("bearing", 0)),
                        delta_minutes=float(row.get("delta_minutes", 15)),
                        crime_b_type=str(row.get("dest_crime_type", "Unknown"))
                    ))
                except Exception:
                    pass

        # Risk level — thresholds calibrated from actual escape profile distribution
        top_prob = corridors[0].probability if corridors else 0
        if top_prob >= self._risk_critical:
            risk_level = "CRITICAL"
        elif top_prob >= self._risk_high:
            risk_level = "HIGH"
        else:
            risk_level = "MODERATE"
        # Firearm escalates only if already HIGH or borderline
        if "Firearm" in crime_type and risk_level == "MODERATE":
            risk_level = "HIGH"

        incident = IncidentInput(lat=lat, lng=lng, crime_type=crime_type, time=time_str)

        return PredictionResult(
            corridors=corridors,
            escape_points=escape_points,
            interceptions=interceptions,
            briefing="",  # filled by briefing.py
            risk_level=risk_level,
            is_night=is_night,
            chain_count=chain_count,
            heatmap=heatmap,
            search_radius=search_radius,
            incident=incident,
            sample_chains=sample_chains
        )

    def validate(self, chain_id: Optional[int] = None):
        """Run prediction on a known crime chain and compare to actual outcome."""
        from .models import ValidationResult

        if self.crime_chains.empty:
            raise ValueError("No crime chain data available for validation")

        df = self.crime_chains.copy()
        if chain_id is not None and chain_id < len(df):
            row = df.iloc[chain_id]
        else:
            row = df.sample(1).iloc[0]

        origin_lat = float(row["origin_lat"])
        origin_lng = float(row["origin_lng"])
        dest_lat = float(row["dest_lat"])
        dest_lng = float(row["dest_lng"])
        actual_bearing = float(row.get("bearing", compute_bearing(origin_lat, origin_lng, dest_lat, dest_lng)))
        actual_direction = bearing_to_direction(actual_bearing)
        crime_type = str(row.get("origin_crime_type", "Robbery No Weapon"))
        origin_time = str(row.get("origin_time", "22:00"))
        if ":" not in origin_time:
            origin_time = "22:00"

        # Run prediction without Crime B info
        result = self.predict(origin_lat, origin_lng, crime_type, origin_time)

        # Find the confidence we assigned to the actual direction
        dir_probs = {c.direction: c.probability for c in result.corridors}
        confidence = dir_probs.get(actual_direction, 0.0)

        top1 = result.corridors[0].direction if result.corridors else ""
        top3 = [c.direction for c in result.corridors[:3]]

        return ValidationResult(
            predicted_corridors=result.corridors,
            actual_direction=actual_direction,
            actual_dest_lat=dest_lat,
            actual_dest_lng=dest_lng,
            match_top1=(top1 == actual_direction),
            match_top3=(actual_direction in top3),
            confidence=round(confidence, 4)
        )

