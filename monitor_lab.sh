#!/bin/bash
# Lab Log Monitor for: null
# Resilient Auto-Reconnect for CachyOS (10.0.0.50)

REMOTE_HOST="null@10.0.0.50"
CONTAINER_NAME="steamos_seat1"
ANSIBLE_LOG="./ansible_execution.log"

echo "=================================================="
echo "   STARTING RESILIENT MULTI-SEAT MONITOR..."
echo "   (Press Ctrl+C to stop all monitoring)"
echo "=================================================="

# 1. Start Local Ansible Log Tailer (in background)
touch "$ANSIBLE_LOG"
tail -f "$ANSIBLE_LOG" | grep -E "TASK|PLAY|FATAL|RECAP" --line-buffered &

# 2. Infinite Loop for Remote Container Logs
echo "[SYSTEM] Waiting for CachyOS and Seat 1 container..."

while true; do
    # Check if host is reachable
    if ping -c 1 -W 1 10.0.0.50 > /dev/null 2>&1; then
        # Attempt to stream Docker logs via SSH
        # -t forces a TTY for better signal handling
        ssh -t "$REMOTE_HOST" "docker logs -f $CONTAINER_NAME 2>&1"
        
        echo "[WARN] Connection lost or container stopped. Retrying in 3s..."
    else
        echo "[INFO] CachyOS (10.0.0.50) is offline/rebooting. Waiting..."
    fi
    sleep 3
done

# Cleanup background processes on exit
trap "kill 0" EXIT

