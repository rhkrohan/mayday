#!/bin/bash
# Mayday Escape Route Intelligence — Start Script

cd "$(dirname "$0")"

echo "========================================"
echo "  Mayday — Escape Route Intelligence"
echo "========================================"

# Find the right Python
PYTHON=""
for p in python3.11 python3.12 python3.13 python3; do
    if command -v $p &>/dev/null && $p -c "import uvicorn" 2>/dev/null; then
        PYTHON=$p
        break
    fi
done

if [ -z "$PYTHON" ]; then
    echo "Installing dependencies..."
    pip3 install -r backend/requirements.txt
    PYTHON=python3
fi

echo "Using: $($PYTHON --version)"

# Check for data files
if [ ! -f backend/data/philly_walk.graphml ]; then
    echo ""
    echo "Data files not found. Downloading..."
    cd backend
    $PYTHON scripts/download_street_network.py
    $PYTHON scripts/download_crime_data.py
    $PYTHON scripts/download_septa_stations.py
    $PYTHON scripts/build_crime_chains.py
    cd ..
    echo "Data download complete."
fi

# Start backend
echo ""
echo "Starting backend on http://localhost:8000..."
cd backend
$PYTHON -m uvicorn app.main:app --port 8000 &
BACKEND_PID=$!
cd ..

# Start frontend
echo "Starting frontend on http://localhost:5173..."
cd frontend
$PYTHON -m http.server 5173 &
FRONTEND_PID=$!
cd ..

echo ""
echo "========================================"
echo "  Backend:  http://localhost:8000"
echo "  Frontend: http://localhost:5173"
echo "========================================"
echo ""
echo "Press Ctrl+C to stop both servers."

# Clean shutdown
trap "kill $BACKEND_PID $FRONTEND_PID 2>/dev/null; exit" INT TERM
wait
