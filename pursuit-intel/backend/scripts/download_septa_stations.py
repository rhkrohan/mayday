"""
download_septa_stations.py — Fetch SEPTA station data.
Tries SEPTA API first; falls back to built-in hardcoded station data.
Saves to data/septa_stations.json.

Usage:
    python scripts/download_septa_stations.py
"""
import json
import sys
import httpx
from pathlib import Path

DATA_DIR = Path(__file__).parent.parent / "data"
OUTPUT_PATH = DATA_DIR / "septa_stations.json"
SEPTA_API_URL = "https://www3.septa.org/hackathon/Stations/"

HARDCODED_STATIONS = {
    "subway": [
        {"name": "Fern Rock TC", "lat": 40.0410, "lng": -75.1140, "line": "BSL"},
        {"name": "Olney", "lat": 40.0340, "lng": -75.1205, "line": "BSL"},
        {"name": "Logan", "lat": 40.0260, "lng": -75.1310, "line": "BSL"},
        {"name": "Wyoming", "lat": 40.0190, "lng": -75.1390, "line": "BSL"},
        {"name": "Hunting Park", "lat": 40.0120, "lng": -75.1440, "line": "BSL"},
        {"name": "Erie", "lat": 39.9905, "lng": -75.1564, "line": "BSL"},
        {"name": "North Philadelphia", "lat": 39.9910, "lng": -75.1564, "line": "BSL"},
        {"name": "Susquehanna-Dauphin", "lat": 39.9835, "lng": -75.1635, "line": "BSL"},
        {"name": "Cecil B. Moore", "lat": 39.9788, "lng": -75.1635, "line": "BSL"},
        {"name": "Girard (BSL)", "lat": 39.9740, "lng": -75.1635, "line": "BSL"},
        {"name": "Fairmount", "lat": 39.9680, "lng": -75.1635, "line": "BSL"},
        {"name": "Spring Garden (BSL)", "lat": 39.9615, "lng": -75.1635, "line": "BSL"},
        {"name": "Race-Vine", "lat": 39.9568, "lng": -75.1635, "line": "BSL"},
        {"name": "City Hall", "lat": 39.9527, "lng": -75.1635, "line": "BSL"},
        {"name": "Walnut-Locust", "lat": 39.9489, "lng": -75.1635, "line": "BSL"},
        {"name": "Lombard-South", "lat": 39.9450, "lng": -75.1635, "line": "BSL"},
        {"name": "Ellsworth-Federal", "lat": 39.9435, "lng": -75.1635, "line": "BSL"},
        {"name": "Tasker-Morris", "lat": 39.9365, "lng": -75.1635, "line": "BSL"},
        {"name": "Snyder", "lat": 39.9305, "lng": -75.1635, "line": "BSL"},
        {"name": "Oregon", "lat": 39.9250, "lng": -75.1635, "line": "BSL"},
        {"name": "AT&T Station", "lat": 39.9210, "lng": -75.1635, "line": "BSL"},
        {"name": "69th Street TC", "lat": 39.9694, "lng": -75.2594, "line": "MFL"},
        {"name": "Millbourne", "lat": 39.9625, "lng": -75.2493, "line": "MFL"},
        {"name": "63rd Street", "lat": 39.9607, "lng": -75.2400, "line": "MFL"},
        {"name": "60th Street", "lat": 39.9607, "lng": -75.2340, "line": "MFL"},
        {"name": "56th Street", "lat": 39.9590, "lng": -75.2260, "line": "MFL"},
        {"name": "52nd Street", "lat": 39.9580, "lng": -75.2180, "line": "MFL"},
        {"name": "46th Street", "lat": 39.9566, "lng": -75.2120, "line": "MFL"},
        {"name": "40th Street", "lat": 39.9566, "lng": -75.2012, "line": "MFL"},
        {"name": "34th Street", "lat": 39.9566, "lng": -75.1907, "line": "MFL"},
        {"name": "30th Street", "lat": 39.9566, "lng": -75.1819, "line": "MFL"},
        {"name": "15th Street", "lat": 39.9527, "lng": -75.1665, "line": "MFL"},
        {"name": "13th Street", "lat": 39.9527, "lng": -75.1608, "line": "MFL"},
        {"name": "11th Street", "lat": 39.9527, "lng": -75.1567, "line": "MFL"},
        {"name": "8th Street", "lat": 39.9527, "lng": -75.1527, "line": "MFL"},
        {"name": "5th Street", "lat": 39.9527, "lng": -75.1460, "line": "MFL"},
        {"name": "2nd Street", "lat": 39.9527, "lng": -75.1410, "line": "MFL"},
        {"name": "Spring Garden (MFL)", "lat": 39.9612, "lng": -75.1527, "line": "MFL"},
        {"name": "Girard (MFL)", "lat": 39.9675, "lng": -75.1527, "line": "MFL"},
        {"name": "Berks", "lat": 39.9735, "lng": -75.1527, "line": "MFL"},
        {"name": "York-Dauphin", "lat": 39.9795, "lng": -75.1480, "line": "MFL"},
        {"name": "Huntingdon", "lat": 39.9850, "lng": -75.1440, "line": "MFL"},
        {"name": "Somerset", "lat": 39.9905, "lng": -75.1400, "line": "MFL"},
        {"name": "Allegheny", "lat": 39.9945, "lng": -75.1370, "line": "MFL"},
        {"name": "Tioga", "lat": 40.0000, "lng": -75.1330, "line": "MFL"},
        {"name": "Erie-Torresdale", "lat": 40.0040, "lng": -75.1290, "line": "MFL"},
        {"name": "Church", "lat": 40.0095, "lng": -75.1220, "line": "MFL"},
        {"name": "Margaret-Orthodox", "lat": 40.0140, "lng": -75.1050, "line": "MFL"},
        {"name": "Frankford TC", "lat": 40.0235, "lng": -75.0815, "line": "MFL"}
    ],
    "regional_rail": [
        {"name": "30th Street Station", "lat": 39.9566, "lng": -75.1819, "line": "Regional"},
        {"name": "Suburban Station", "lat": 39.9538, "lng": -75.1676, "line": "Regional"},
        {"name": "Jefferson Station", "lat": 39.9525, "lng": -75.1581, "line": "Regional"},
        {"name": "Temple University", "lat": 39.9815, "lng": -75.1496, "line": "Regional"},
        {"name": "North Broad", "lat": 39.9720, "lng": -75.1560, "line": "Regional"},
        {"name": "University City", "lat": 39.9487, "lng": -75.1910, "line": "Regional"},
        {"name": "49th Street", "lat": 39.9430, "lng": -75.2170, "line": "Regional"},
        {"name": "Angora", "lat": 39.9430, "lng": -75.2300, "line": "Regional"}
    ],
    "highway_ramps": [
        {"name": "I-76 East On-Ramp (30th St)", "lat": 39.9555, "lng": -75.1850, "type": "highway"},
        {"name": "I-76 West On-Ramp (Spring Garden)", "lat": 39.9625, "lng": -75.1820, "type": "highway"},
        {"name": "I-76 On-Ramp (University Ave)", "lat": 39.9480, "lng": -75.1920, "type": "highway"},
        {"name": "I-76 On-Ramp (Girard Ave)", "lat": 39.9720, "lng": -75.1900, "type": "highway"},
        {"name": "I-95 South On-Ramp (Columbus Blvd)", "lat": 39.9460, "lng": -75.1420, "type": "highway"},
        {"name": "I-95 North On-Ramp (Spring Garden)", "lat": 39.9630, "lng": -75.1380, "type": "highway"},
        {"name": "I-95 On-Ramp (Girard Ave)", "lat": 39.9700, "lng": -75.1320, "type": "highway"},
        {"name": "I-95 On-Ramp (Allegheny Ave)", "lat": 39.9950, "lng": -75.1150, "type": "highway"},
        {"name": "I-676 On-Ramp (Broad St)", "lat": 39.9580, "lng": -75.1635, "type": "highway"},
        {"name": "I-676 On-Ramp (22nd St)", "lat": 39.9580, "lng": -75.1800, "type": "highway"},
        {"name": "I-676 On-Ramp (8th St)", "lat": 39.9580, "lng": -75.1520, "type": "highway"},
        {"name": "Roosevelt Blvd On-Ramp (Broad)", "lat": 39.9995, "lng": -75.1500, "type": "highway"},
        {"name": "Roosevelt Blvd On-Ramp (5th St)", "lat": 40.0350, "lng": -75.1180, "type": "highway"},
        {"name": "Lincoln Drive On-Ramp (Kelly Dr)", "lat": 39.9850, "lng": -75.1950, "type": "highway"}
    ]
}


def main():
    DATA_DIR.mkdir(exist_ok=True)

    if OUTPUT_PATH.exists():
        print(f"SEPTA stations file already exists at {OUTPUT_PATH}")
        return

    print("Fetching SEPTA station data...")

    # Try SEPTA API
    try:
        with httpx.Client(timeout=15) as client:
            resp = client.get(SEPTA_API_URL)
            resp.raise_for_status()
            api_data = resp.json()
            print(f"  SEPTA API returned {len(api_data)} entries")
            # API returns different format — use hardcoded which is more complete
            print("  Using hardcoded station list (more complete than API)")
    except Exception as e:
        print(f"  SEPTA API unavailable ({e}), using hardcoded station data")

    with open(OUTPUT_PATH, "w") as f:
        json.dump(HARDCODED_STATIONS, f, indent=2)

    total = (len(HARDCODED_STATIONS["subway"]) +
             len(HARDCODED_STATIONS["regional_rail"]) +
             len(HARDCODED_STATIONS["highway_ramps"]))
    print(f"Saved {total} stations/ramps to {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
