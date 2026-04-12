"""
main.py — FastAPI application entry point.
Loads all data on startup, exposes prediction endpoints.
"""
import logging
import os
import time
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware

from .config import config
from .models import (
    IncidentInput, SimulationInput, PredictionResult,
    ValidationResult, HeatmapPoint
)
from .data_loader import (
    load_septa_stations, load_crime_data, load_crime_chains, load_escape_profiles
)
from .graph_builder import load_walk_graph, load_drive_graph
from .predictor import EscapeRoutePredictor
from .briefing import generate_briefing

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s"
)
logger = logging.getLogger(__name__)

# Global predictor instance
predictor: EscapeRoutePredictor | None = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    global predictor
    logger.info("=" * 60)
    logger.info("MAYDAY ESCAPE ROUTE INTELLIGENCE — startup sequence")
    logger.info("=" * 60)

    t_total = time.time()

    # Load street graphs
    logger.info("Loading walk street graph...")
    t0 = time.time()
    G_walk = load_walk_graph(config.STREET_GRAPH_WALK_PATH)
    logger.info(f"Walk graph loaded in {time.time() - t0:.1f}s")

    logger.info("Loading drive street graph...")
    t0 = time.time()
    G_drive = load_drive_graph(config.STREET_GRAPH_DRIVE_PATH)
    logger.info(f"Drive graph loaded in {time.time() - t0:.1f}s")

    # Load all other data
    logger.info("Loading SEPTA stations...")
    stations = load_septa_stations(config.SEPTA_STATIONS_PATH)

    logger.info("Loading crime data...")
    crime_df = load_crime_data(config.CRIME_DATA_PATH)

    logger.info("Loading crime chains...")
    crime_chains = load_crime_chains(config.CRIME_CHAINS_PATH)

    logger.info("Loading escape profiles...")
    escape_profiles = load_escape_profiles(config.ESCAPE_PROFILES_PATH)

    # Build predictor
    logger.info("Initializing prediction engine...")
    t0 = time.time()
    predictor = EscapeRoutePredictor(
        G_walk=G_walk,
        G_drive=G_drive,
        escape_profiles=escape_profiles,
        stations=stations,
        crime_df=crime_df,
        crime_chains=crime_chains
    )
    logger.info(f"Prediction engine ready in {time.time() - t0:.1f}s")

    openai_key = os.getenv("OPENAI_API_KEY", "")
    openai_status = "configured (gpt-4o)" if (openai_key and not openai_key.startswith("sk-proj-xxx")) else "not configured (template fallback active)"
    logger.info(f"OpenAI API: {openai_status}")
    logger.info(f"Total startup time: {time.time() - t_total:.1f}s")
    logger.info("=" * 60)

    yield

    logger.info("Shutting down Mayday Route Intelligence...")


app = FastAPI(
    title="Mayday Escape Route Intelligence API",
    description="AI-powered escape route prediction engine for Philadelphia — Codefest 2026",
    version="2.0.0",
    lifespan=lifespan
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=config.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


def require_predictor():
    if predictor is None:
        raise HTTPException(status_code=503, detail="Prediction engine not initialized. Check server logs.")
    return predictor


@app.get("/api/health")
async def health():
    p = predictor
    graph_nodes = 0
    if p and p.G_walk:
        try:
            graph_nodes = len(p.G_walk.nodes)
        except Exception:
            pass
    crime_records = len(p.crime_df) if p and not p.crime_df.empty else 0
    chain_count = len(p.crime_chains) if p and not p.crime_chains.empty else 0
    profiles_loaded = len(p.escape_profiles) if p else 0

    return {
        "status": "ok" if p else "initializing",
        "graph_nodes": graph_nodes,
        "crime_records": crime_records,
        "chain_count": chain_count,
        "profiles_loaded": profiles_loaded,
        "openai_configured": bool(
            os.getenv("OPENAI_API_KEY") and not os.getenv("OPENAI_API_KEY", "").startswith("sk-proj-xxx")
        )
    }


@app.post("/api/predict", response_model=PredictionResult)
async def predict(incident: IncidentInput):
    p = require_predictor()
    try:
        result = p.predict(
            lat=incident.lat,
            lng=incident.lng,
            crime_type=incident.crime_type,
            time_str=incident.time,
            elapsed_minutes=0.0
        )
        # Generate AI briefing with live crime data access
        result.briefing = generate_briefing(
            result, incident.lat, incident.lng, incident.crime_type, incident.time,
            crime_df=p.crime_df, crime_chains=p.crime_chains
        )
        return result
    except Exception as e:
        logger.exception(f"Prediction failed: {e}")
        raise HTTPException(status_code=500, detail=f"Prediction failed: {str(e)}")


@app.post("/api/simulate", response_model=PredictionResult)
async def simulate(sim_input: SimulationInput):
    p = require_predictor()
    try:
        result = p.predict(
            lat=sim_input.lat,
            lng=sim_input.lng,
            crime_type=sim_input.crime_type,
            time_str=sim_input.time,
            elapsed_minutes=sim_input.elapsed_minutes
        )
        result.briefing = generate_briefing(
            result, sim_input.lat, sim_input.lng, sim_input.crime_type, sim_input.time,
            crime_df=p.crime_df, crime_chains=p.crime_chains
        )
        return result
    except Exception as e:
        logger.exception(f"Simulation failed: {e}")
        raise HTTPException(status_code=500, detail=f"Simulation failed: {str(e)}")


@app.get("/api/heatmap", response_model=list[HeatmapPoint])
async def heatmap(
    lat_min: float = Query(39.85),
    lat_max: float = Query(40.10),
    lng_min: float = Query(-75.28),
    lng_max: float = Query(-74.95)
):
    p = require_predictor()
    center_lat = (lat_min + lat_max) / 2
    center_lng = (lng_min + lng_max) / 2
    return p._heatmap(center_lat, center_lng, grid_size=25)


@app.get("/api/stations")
async def stations():
    p = require_predictor()
    return p.stations


@app.get("/api/validate/random", response_model=ValidationResult)
async def validate_random():
    p = require_predictor()
    try:
        return p.validate(chain_id=None)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        logger.exception(f"Validation failed: {e}")
        raise HTTPException(status_code=500, detail=f"Validation failed: {str(e)}")


@app.get("/api/validate/{chain_id}", response_model=ValidationResult)
async def validate_by_id(chain_id: int):
    p = require_predictor()
    try:
        return p.validate(chain_id=chain_id)
    except Exception as e:
        logger.exception(f"Validation failed: {e}")
        raise HTTPException(status_code=500, detail=f"Validation failed: {str(e)}")


@app.get("/api/chains/nearby")
async def chains_nearby(
    lat: float = Query(...),
    lng: float = Query(...),
    radius_km: float = Query(1.0)
):
    p = require_predictor()
    from .crime_chains import get_nearby_chains
    nearby = get_nearby_chains(lat, lng, p.crime_chains, radius_km=radius_km)
    if nearby.empty:
        return []
    records = nearby.head(20).to_dict(orient="records")
    return records
