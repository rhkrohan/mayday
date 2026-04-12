"""
briefing.py — AI tactical briefing generator with OpenAI tool calling.
GPT-4o can query live crime data before generating the briefing.
"""
import os
import json
import math
import logging
import pandas as pd
from .models import PredictionResult

logger = logging.getLogger(__name__)

OPENAI_MODEL = "gpt-4o"


# ─── Tool implementations (query against real DataFrames) ─────────────────────

def _haversine_km(lat1, lng1, lat2, lng2):
    R = 6371.0
    dlat = math.radians(lat2 - lat1)
    dlng = math.radians(lng2 - lng1)
    a = math.sin(dlat / 2) ** 2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlng / 2) ** 2
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def _query_crimes_nearby(crime_df: pd.DataFrame, lat: float, lng: float,
                          radius_km: float = 0.75, time_str: str = None) -> dict:
    """Find crimes within radius, optionally filtered to ±2hrs of incident time."""
    if crime_df is None or crime_df.empty:
        return {"error": "No crime data available"}

    df = crime_df.copy()

    # Derive hour column if not already present
    if "hour" not in df.columns and "dispatch_time" in df.columns:
        try:
            df["hour"] = pd.to_datetime(df["dispatch_time"], errors="coerce").dt.hour
        except Exception:
            pass

    # Time-of-day filter: if time provided, filter to same ±2 hour window
    if time_str and "hour" in df.columns:
        try:
            inc_hour = int(time_str.split(":")[0])
            df = df[abs(df["hour"] - inc_hour) <= 2]
        except Exception:
            pass

    # Distance filter
    df["dist_km"] = df.apply(
        lambda r: _haversine_km(lat, lng, r["lat"], r["lng"]), axis=1
    )
    nearby = df[df["dist_km"] <= radius_km].sort_values("dist_km")

    if nearby.empty:
        return {"count": 0, "message": f"No crimes found within {radius_km}km", "crimes": []}

    crimes_list = []
    for _, row in nearby.head(10).iterrows():
        crimes_list.append({
            "type": str(row.get("text_general_code", "Unknown")),
            "dist_m": round(row["dist_km"] * 1000),
            "hour": int(row.get("hour", -1)) if "hour" in row else None,
        })

    type_counts = nearby["text_general_code"].value_counts().head(5).to_dict() if "text_general_code" in nearby.columns else {}

    return {
        "count": len(nearby),
        "radius_km": radius_km,
        "top_crime_types": {str(k): int(v) for k, v in type_counts.items()},
        "nearest_crimes": crimes_list,
    }


def _bearing_to_direction(bearing: float) -> str:
    dirs = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
    return dirs[int((bearing + 22.5) / 45) % 8]


def _get_corridor_chains(crime_chains: pd.DataFrame, lat: float, lng: float,
                          direction: str, top_n: int = 5) -> dict:
    """Get real chain examples supporting a specific escape direction from this location."""
    if crime_chains is None or crime_chains.empty:
        return {"error": "No crime chain data available"}

    df = crime_chains.copy()
    df["dist_km"] = df.apply(
        lambda r: _haversine_km(lat, lng, r["origin_lat"], r["origin_lng"]), axis=1
    )
    nearby = df[df["dist_km"] <= 1.5]

    # Derive direction from bearing column (chains don't store direction directly)
    if "direction" in nearby.columns:
        direction_chains = nearby[nearby["direction"] == direction]
    elif "bearing" in nearby.columns:
        nearby = nearby.copy()
        nearby["_dir"] = nearby["bearing"].apply(_bearing_to_direction)
        direction_chains = nearby[nearby["_dir"] == direction]
    else:
        direction_chains = pd.DataFrame()

    chains_list = []
    for _, row in direction_chains.head(top_n).iterrows():
        chains_list.append({
            "dest_crime": str(row.get("dest_crime_type", row.get("crime_b_type", "Unknown"))),
            "delta_minutes": round(float(row.get("delta_minutes", 0)), 1),
            "dist_km": round(float(row["dist_km"]), 2),
        })

    return {
        "direction": direction,
        "chains_in_area": len(nearby),
        "chains_matching_direction": len(direction_chains),
        "examples": chains_list,
    }


def _get_area_crime_profile(crime_df: pd.DataFrame, lat: float, lng: float,
                             radius_km: float = 0.5) -> dict:
    """Get high-level crime profile for the neighborhood around the incident."""
    if crime_df is None or crime_df.empty:
        return {"error": "No crime data available"}

    df = crime_df.copy()
    df["dist_km"] = df.apply(
        lambda r: _haversine_km(lat, lng, r["lat"], r["lng"]), axis=1
    )
    nearby = df[df["dist_km"] <= radius_km]

    if nearby.empty:
        return {"count": 0, "message": f"No crime data within {radius_km}km"}

    night_pct = 0
    if "hour" in nearby.columns:
        night_crimes = nearby[(nearby["hour"] >= 20) | (nearby["hour"] <= 5)]
        night_pct = round(len(night_crimes) / max(len(nearby), 1) * 100, 1)

    top_types = {}
    if "text_general_code" in nearby.columns:
        top_types = {str(k): int(v) for k, v in nearby["text_general_code"].value_counts().head(5).items()}

    return {
        "total_crimes_in_area": len(nearby),
        "radius_km": radius_km,
        "night_crime_pct": night_pct,
        "top_crime_types": top_types,
    }


# ─── OpenAI tool schemas ──────────────────────────────────────────────────────

TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "query_crimes_nearby",
            "description": "Query historical crime records near a location, optionally filtered to a time window. Use this to understand the crime environment around the incident.",
            "parameters": {
                "type": "object",
                "properties": {
                    "radius_km": {"type": "number", "description": "Search radius in km (default 0.75)"},
                    "time_str": {"type": "string", "description": "Time filter as HH:MM — finds crimes in ±2hr window"},
                },
                "required": [],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_corridor_chains",
            "description": "Get real historical crime chain examples for a specific escape direction from the incident location. Use this to understand why the model ranked a direction highly.",
            "parameters": {
                "type": "object",
                "properties": {
                    "direction": {
                        "type": "string",
                        "enum": ["N", "NE", "E", "SE", "S", "SW", "W", "NW"],
                        "description": "Escape direction to query",
                    },
                },
                "required": ["direction"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_area_crime_profile",
            "description": "Get overall crime statistics for the neighborhood — total incidents, day vs night breakdown, top crime types.",
            "parameters": {
                "type": "object",
                "properties": {
                    "radius_km": {"type": "number", "description": "Area radius in km (default 0.5)"},
                },
                "required": [],
            },
        },
    },
]


# ─── Main entry point ─────────────────────────────────────────────────────────

def generate_briefing(prediction: PredictionResult, incident_lat: float,
                      incident_lng: float, crime_type: str, time_str: str,
                      crime_df: pd.DataFrame = None,
                      crime_chains: pd.DataFrame = None) -> str:
    api_key = os.getenv("OPENAI_API_KEY", "")

    top_corridor = prediction.corridors[0] if prediction.corridors else None
    nearest_transit = prediction.escape_points[0] if prediction.escape_points else None

    if not api_key or api_key.startswith("sk-proj-xxx"):
        return _template_briefing(prediction, crime_type, time_str,
                                  top_corridor, nearest_transit)

    try:
        from openai import OpenAI
        client = OpenAI(api_key=api_key)

        escape_points_text = "\n".join([
            f"- {ep.name} ({ep.type}, {ep.line}): {ep.distance_meters:.0f}m, {ep.probability:.0%}"
            for ep in prediction.escape_points[:6]
        ])
        corridors_text = "\n".join([
            f"- {c.direction}: {c.probability:.0%} ({c.historical_chain_count} chains)"
            for c in prediction.corridors[:5]
        ])
        interceptions_text = "\n".join([
            f"- Unit {i+1}: {ip.direction} corridor — "
            + (f"{ip.street_name}" if ip.street_name else f"({ip.lat:.4f}, {ip.lng:.4f})")
            + f" ({ip.probability:.0%} probability)"
            for i, ip in enumerate(prediction.interceptions)
        ])

        system_prompt = (
            "You are a tactical AI assistant for Philadelphia Police dispatch. "
            "You write concise, direct, radio-tone briefings for responding officers. "
            "You know Philadelphia's streets, neighborhoods, and SEPTA system. "
            "You have tools to query the actual historical crime database — use them to verify "
            "and enrich the briefing with specific data before writing it. "
            "Never use pleasantries. Dispatch tone only."
        )

        user_prompt = f"""INCIDENT: {crime_type} at ({incident_lat:.4f}, {incident_lng:.4f}) at {time_str}
RISK LEVEL: {prediction.risk_level} | {"NIGHT" if prediction.is_night else "DAY"} | {prediction.chain_count} chains analyzed

TOP ESCAPE CORRIDORS:
{corridors_text}

ESCAPE INFRASTRUCTURE:
{escape_points_text}

INTERCEPTION POINTS:
{interceptions_text}

Query the crime database to verify the top corridor and get specific supporting data, then write a 5-7 sentence tactical briefing. Include:
1. Primary escape direction with specific chain data to back it up
2. Which SEPTA stations to lock down (name the line)
3. Exact unit positions
4. Time-critical deadlines
No filler. Dispatch tone only."""

        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ]

        # Tool call loop — allow up to 3 tool calls before forcing a final answer
        for _ in range(3):
            response = client.chat.completions.create(
                model=OPENAI_MODEL,
                max_tokens=600,
                temperature=0.2,
                tools=TOOLS,
                tool_choice="auto",
                messages=messages,
            )

            msg = response.choices[0].message
            messages.append(msg)

            if not msg.tool_calls:
                break  # Final answer ready

            # Execute each tool call
            for tc in msg.tool_calls:
                fn = tc.function.name
                args = json.loads(tc.function.arguments)
                logger.info(f"Briefing tool call: {fn}({args})")

                if fn == "query_crimes_nearby":
                    result = _query_crimes_nearby(
                        crime_df, incident_lat, incident_lng,
                        radius_km=args.get("radius_km", 0.75),
                        time_str=args.get("time_str", time_str),
                    )
                elif fn == "get_corridor_chains":
                    result = _get_corridor_chains(
                        crime_chains, incident_lat, incident_lng,
                        direction=args["direction"],
                    )
                elif fn == "get_area_crime_profile":
                    result = _get_area_crime_profile(
                        crime_df, incident_lat, incident_lng,
                        radius_km=args.get("radius_km", 0.5),
                    )
                else:
                    result = {"error": f"Unknown tool: {fn}"}

                messages.append({
                    "role": "tool",
                    "tool_call_id": tc.id,
                    "content": json.dumps(result),
                })

        # Extract final text — last assistant message without tool calls
        for m in reversed(messages):
            if hasattr(m, "content") and m.content and not getattr(m, "tool_calls", None):
                return m.content.strip()
            if isinstance(m, dict) and m.get("role") == "assistant" and m.get("content"):
                return m["content"].strip()

        return _template_briefing(prediction, crime_type, time_str, top_corridor, nearest_transit)

    except Exception as e:
        logger.warning(f"OpenAI API call failed: {e}. Using template briefing.")
        return _template_briefing(prediction, crime_type, time_str,
                                  top_corridor, nearest_transit)


def _template_briefing(prediction: PredictionResult, crime_type: str, time_str: str,
                        top_corridor, nearest_transit) -> str:
    lines = [f"ALERT: {crime_type} reported at {time_str}."]
    if top_corridor:
        lines.append(
            f"Primary escape vector is {top_corridor.direction} "
            f"({top_corridor.probability:.0%} probability, {top_corridor.historical_chain_count} historical chains)."
        )
    if nearest_transit:
        line_info = f" ({nearest_transit.line})" if nearest_transit.line else ""
        lines.append(
            f"Nearest transit escape: {nearest_transit.name}{line_info} — "
            f"{nearest_transit.distance_meters:.0f}m from incident. Lock down immediately."
        )
    if prediction.interceptions:
        pts = ", ".join([
            f"Unit {i+1} to ({ip.lat:.4f},{ip.lng:.4f}) [{ip.direction}]"
            for i, ip in enumerate(prediction.interceptions[:3])
        ])
        lines.append(f"Deploy: {pts}.")
    lines.append(f"Threat level: {prediction.risk_level}.")
    if prediction.is_night:
        lines.append("Night conditions: BSL runs 24/7 owl service — secure all platform exits.")
    else:
        lines.append("Daytime: high pedestrian traffic. Check SEPTA cameras at nearest station.")
    return " ".join(lines)
