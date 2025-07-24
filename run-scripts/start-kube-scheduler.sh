#!/bin/bash

# Start kube-scheduler
set -e

sleep 10  # Ensure API server is ready before starting scheduler

echo "=== Starting kube-scheduler ==="

# Create logs directory if it doesn't exist
mkdir -p logs

# Start kube-scheduler
echo "Starting kube-scheduler..."
echo "Logs: logs/kube-scheduler.log"
exec bin/kube-scheduler --kubeconfig admin.conf \
>> logs/kube-scheduler.log 2>&1
