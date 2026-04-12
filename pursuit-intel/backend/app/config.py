import os
from pathlib import Path
from dotenv import load_dotenv

load_dotenv()

class Config:
    ANTHROPIC_API_KEY: str = os.getenv("ANTHROPIC_API_KEY", "")
    OPENDATA_PHILLY_URL: str = os.getenv("OPENDATA_PHILLY_URL", "https://phl.carto.com/api/v2/sql")
    SEPTA_API_URL: str = os.getenv("SEPTA_API_URL", "https://www3.septa.org/hackathon")
    HOST: str = os.getenv("HOST", "0.0.0.0")
    PORT: int = int(os.getenv("PORT", "8000"))
    CORS_ORIGINS: list[str] = os.getenv(
        "CORS_ORIGINS", "http://localhost:5173,http://localhost:3000"
    ).split(",")

    DATA_DIR: Path = Path(os.getenv("DATA_DIR", "./data"))
    STREET_GRAPH_WALK_PATH: Path = Path(os.getenv("STREET_GRAPH_WALK_PATH", "./data/philly_walk.graphml"))
    STREET_GRAPH_DRIVE_PATH: Path = Path(os.getenv("STREET_GRAPH_DRIVE_PATH", "./data/philly_drive.graphml"))
    CRIME_DATA_PATH: Path = Path(os.getenv("CRIME_DATA_PATH", "./data/philly_crimes.csv"))
    CRIME_CHAINS_PATH: Path = Path(os.getenv("CRIME_CHAINS_PATH", "./data/crime_chains.csv"))
    ESCAPE_PROFILES_PATH: Path = Path(os.getenv("ESCAPE_PROFILES_PATH", "./data/escape_profiles.json"))
    SEPTA_STATIONS_PATH: Path = Path(os.getenv("SEPTA_STATIONS_PATH", "./data/septa_stations.json"))


config = Config()
