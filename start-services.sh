#!/bin/bash

# Start additional services (HTTP server, etc.)
set -e

echo "=== Starting additional services ==="

# Start HTTP server on port 8080
echo "Starting HTTP server on port 8080..."
python3 -m http.server 8080 --bind 0.0.0.0 &

HTTP_SERVER_PID=$!
echo "HTTP server started with PID: $HTTP_SERVER_PID"

echo "✓ Additional services started"
echo "HTTP server available at: http://0.0.0.0:8080"
