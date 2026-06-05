#!/bin/bash
# run_libero.sh - Automate running the LIBERO evaluation benchmark.

# Exit immediately if a command exits with a non-zero status
set -e

# Configs
CONFIG="pi05_libero"
CHECKPOINT_DIR="checkpoints/pi05_libero"

echo "========================================================="
echo "Starting PyTorch Policy Server for $CONFIG..."
echo "========================================================="

# Start policy server in background and redirect logs
uv run scripts/serve_policy.py policy:checkpoint --policy.config "$CONFIG" --policy.dir "$CHECKPOINT_DIR" > policy_server.log 2>&1 &
SERVER_PID=$!

# Ensure server is stopped when the script exits
cleanup() {
    echo ""
    echo "========================================================="
    echo "Stopping policy server (PID: $SERVER_PID)..."
    echo "========================================================="
    kill "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
}
trap cleanup EXIT

# Wait for server to start listening on port 8000
echo "Waiting for the policy server to start listening on port 8000..."
max_attempts=120
attempt=1
while ! (echo > /dev/tcp/127.0.0.1/8000) >/dev/null 2>&1; do
    if [ $attempt -gt $max_attempts ]; then
        echo "Error: Policy server failed to start within $max_attempts seconds."
        echo "See policy_server.log for details."
        exit 1
    fi
    sleep 1
    attempt=$((attempt + 1))
done

echo "Policy server is online and listening!"
echo ""
echo "========================================================="
echo "Starting LIBERO Evaluation Client..."
echo "========================================================="

# Set up environment for the simulation client
echo "Activating LIBERO virtual environment..."
source examples/libero/.venv/bin/activate
export PYTHONPATH=$PYTHONPATH:$PWD/third_party/libero

# Run the simulation client
MUJOCO_GL=glx python examples/libero/main.py

echo ""
echo "Evaluation finished successfully."
