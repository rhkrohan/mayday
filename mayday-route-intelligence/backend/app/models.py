from pydantic import BaseModel
from typing import Optional


class IncidentInput(BaseModel):
    lat: float
    lng: float
    crime_type: str  # "Robbery Firearm" | "Robbery No Weapon" | "Robbery Knife"
    time: str  # "HH:MM"


class SimulationInput(IncidentInput):
    elapsed_minutes: float  # 0.0 to 15.0


class EscapeCorridor(BaseModel):
    direction: str  # "N", "NE", "E", "SE", "S", "SW", "W", "NW"
    probability: float  # 0.0 to 1.0
    bearing: float  # degrees from true north
    historical_chain_count: int  # how many real crime chains support this direction


class EscapePoint(BaseModel):
    name: str
    type: str  # "subway" | "regional_rail" | "highway"
    line: Optional[str]  # "BSL", "MFL", "Regional", None
    lat: float
    lng: float
    distance_meters: float  # Real walking/driving distance along streets
    probability: float
    chain_references: int  # how many crime chains ended near this point


class InterceptionPoint(BaseModel):
    lat: float
    lng: float
    direction: str
    probability: float
    street_name: Optional[str]


class SearchRadius(BaseModel):
    foot_polygon: list[list[float]]  # [[lat, lng], ...] convex hull
    vehicle_polygon: list[list[float]]
    elapsed_minutes: float
    foot_radius_km: float
    vehicle_radius_km: float
    reachable_stations: list[str]
    reachable_highways: list[str]


class HeatmapPoint(BaseModel):
    lat: float
    lng: float
    intensity: float


class CrimeChainExample(BaseModel):
    origin_lat: float
    origin_lng: float
    dest_lat: float
    dest_lng: float
    bearing: float
    delta_minutes: float
    crime_b_type: str


class PredictionResult(BaseModel):
    corridors: list[EscapeCorridor]
    escape_points: list[EscapePoint]
    interceptions: list[InterceptionPoint]
    briefing: str
    risk_level: str  # "CRITICAL" | "HIGH" | "MODERATE"
    is_night: bool
    chain_count: int  # how many historical chains informed this prediction
    heatmap: list[HeatmapPoint]
    search_radius: Optional[SearchRadius]
    incident: IncidentInput
    sample_chains: list[CrimeChainExample]  # real examples for demo


class ValidationResult(BaseModel):
    predicted_corridors: list[EscapeCorridor]
    actual_direction: str
    actual_dest_lat: float
    actual_dest_lng: float
    match_top1: bool
    match_top3: bool
    confidence: float  # probability we assigned to the correct direction
