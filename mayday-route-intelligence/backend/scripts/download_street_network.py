"""
download_street_network.py — Download Philadelphia street network from OpenStreetMap.
Saves walk and drive graphs as .graphml files (~50-100MB each).
Takes 2-5 minutes per network type. Requires internet connection (one-time only).

Usage:
    python scripts/download_street_network.py
"""
import sys
import time
from pathlib import Path

DATA_DIR = Path(__file__).parent.parent / "data"
WALK_PATH = DATA_DIR / "philly_walk.graphml"
DRIVE_PATH = DATA_DIR / "philly_drive.graphml"


def download_network(network_type: str, output_path: Path):
    try:
        import osmnx as ox
    except ImportError:
        print("ERROR: osmnx not installed. Run: pip install osmnx==2.1.0")
        sys.exit(1)

    if output_path.exists():
        print(f"  {output_path.name} already exists, skipping download.")
        return

    print(f"  Downloading {network_type} network from OpenStreetMap...")
    print("  (This may take 2-5 minutes — downloading and processing Philly street data)")
    t0 = time.time()
    try:
        G = ox.graph_from_place("Philadelphia, Pennsylvania, USA", network_type=network_type)
        ox.save_graphml(G, filepath=output_path)
        elapsed = time.time() - t0
        print(f"  Saved: {len(G.nodes):,} nodes, {len(G.edges):,} edges in {elapsed:.0f}s")
        print(f"  File: {output_path} ({output_path.stat().st_size / 1024 / 1024:.1f} MB)")
    except Exception as e:
        print(f"  ERROR: {e}")
        raise


def main():
    DATA_DIR.mkdir(exist_ok=True)
    print("Downloading Philadelphia street networks...")
    print()

    print("1/2 Walking network:")
    download_network("walk", WALK_PATH)
    print()

    print("2/2 Driving network:")
    download_network("drive", DRIVE_PATH)
    print()

    print("Street network download complete!")
    print("These files are used for shortest-path routing and isochrone computation.")


if __name__ == "__main__":
    main()
