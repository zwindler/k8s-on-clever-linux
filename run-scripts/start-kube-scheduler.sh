#!/bin/bash

# Start kube-scheduler
set -e

sleep 10  # Ensure API server is ready before starting scheduler

echo "=== Starting kube-scheduler ==="

# Start kube-scheduler
echo "Starting kube-scheduler..."
exec bin/kube-scheduler --kubeconfig admin.conf
