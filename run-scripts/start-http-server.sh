#!/bin/bash

# Start HTTP server (for Clever Cloud health checks)
set -e

echo "=== Starting HTTP server ==="

# Start HTTP server on port 8080
echo "Starting HTTP server on port 8080..."
echo "HTTP server available at: http://0.0.0.0:8080"
exec python3 -m http.server 8080 --bind 0.0.0.0 --directory public
