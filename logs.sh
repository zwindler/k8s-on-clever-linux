#!/bin/bash

# Script to monitor Kubernetes component logs
set -e

echo "=== Kubernetes Component Logs ==="
echo ""

# Check if logs directory exists
if [[ ! -d "logs" ]]; then
    echo "No logs directory found. Start the cluster first with: mise run run"
    exit 1
fi

# Function to show log status
show_log_status() {
    local component=$1
    local logfile="logs/${component}.log"
    
    if [[ -f "$logfile" ]]; then
        local size=$(du -h "$logfile" | cut -f1)
        local lines=$(wc -l < "$logfile")
        echo "📄 $component: $size ($lines lines)"
    else
        echo "❌ $component: No log file found"
    fi
}

# Show all log files status
echo "📊 Log files status:"
show_log_status "etcd"
show_log_status "kube-apiserver"
show_log_status "kube-controller-manager"
show_log_status "kube-scheduler"

echo ""
echo "🔍 Available commands:"
echo "  ./logs.sh tail <component>     - Follow logs for a component"
echo "  ./logs.sh grep <pattern>       - Search across all logs"
echo "  ./logs.sh errors               - Show recent errors from all components"
echo "  ./logs.sh clean                - Clean old log files"
echo ""

# Handle command line arguments
case "${1:-}" in
    "tail")
        if [[ -z "${2:-}" ]]; then
            echo "Usage: ./logs.sh tail <component>"
            echo "Components: etcd, kube-apiserver, kube-controller-manager, kube-scheduler"
            exit 1
        fi
        
        logfile="logs/${2}.log"
        if [[ -f "$logfile" ]]; then
            echo "Following $logfile (Press Ctrl+C to stop)..."
            tail -f "$logfile"
        else
            echo "Log file not found: $logfile"
            exit 1
        fi
        ;;
        
    "grep")
        if [[ -z "${2:-}" ]]; then
            echo "Usage: ./logs.sh grep <pattern>"
            exit 1
        fi
        
        echo "Searching for '$2' in all logs..."
        grep -n "$2" logs/*.log 2>/dev/null || echo "No matches found"
        ;;
        
    "errors")
        echo "Recent errors from all components:"
        echo ""
        for logfile in logs/*.log; do
            if [[ -f "$logfile" ]]; then
                component=$(basename "$logfile" .log)
                echo "=== $component ==="
                grep -i "error\|failed\|fatal" "$logfile" | tail -5 || echo "No recent errors"
                echo ""
            fi
        done
        ;;
        
    "clean")
        echo "Cleaning old log files..."
        rm -f logs/*.log
        echo "✓ Log files cleaned"
        ;;
        
    *)
        if [[ -n "${1:-}" ]]; then
            echo "Unknown command: $1"
            exit 1
        fi
        ;;
esac
