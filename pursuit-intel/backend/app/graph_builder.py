"""
graph_builder.py — Load or build Philadelphia street network graphs.
Falls back to None (straight-line distances) if graphs unavailable.
"""
import logging
import time
from pathlib import Path

logger = logging.getLogger(__name__)


def load_graph(path: Path, network_type: str):
    """Load a saved OSMnx street graph, or return None if unavailable."""
    try:
        import osmnx as ox
    except ImportError:
        logger.error("osmnx not installed. Run: pip install osmnx==2.1.0")
        return None

    if not path.exists():
        logger.warning(
            f"Street graph not found at {path}. "
            f"Run: python scripts/download_street_network.py"
        )
        return None

    t0 = time.time()
    try:
        G = ox.load_graphml(path)
        elapsed = time.time() - t0
        logger.info(
            f"Loaded {network_type} graph: {len(G.nodes)} nodes, "
            f"{len(G.edges)} edges in {elapsed:.1f}s"
        )
        return G
    except Exception as e:
        logger.error(f"Failed to load {network_type} graph from {path}: {e}")
        return None


def load_walk_graph(path: Path):
    return load_graph(path, "walk")


def load_drive_graph(path: Path):
    return load_graph(path, "drive")
