#!/bin/bash

# Start kube-scheduler
set -e

echo "=== Starting kube-scheduler ==="

# Start kube-scheduler
echo "Starting kube-scheduler..."
exec bin/kube-scheduler --kubeconfig admin.conf
