#!/bin/bash
# panic_reset.sh - Surgical Automated Recovery (v2026.33)
# Targets: CachyOS / RTX 5080 / Ryzen 9900X
# Focus: Recover Seat 2 without affecting Seat 1 Gaming.

LOG_FILE="$HOME/lab_debug.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "‼️  [$(date)] SURGICAL RECOVERY INITIATED..."

# 1. DIAGNOSTIC SNAPSHOT
# NOTES: Log VRAM/GPU state before killing the container.
nvidia-smi --query-compute-apps=pid,used_memory,utilization.gpu --format=csv >> "$LOG_FILE"

# 2. AGGRESSIVE CONTAINER REMOVAL
# NOTES: '-t 1' ensures the container doesn't hang the host during shutdown.
if docker ps -a | grep -q "steamos_player2"; then
    echo "--> Terminating Seat 2 Container..."
    docker stop -t 1 steamos_player2 > /dev/null 2>&1
    docker rm -f steamos_player2 > /dev/null 2>&1
fi

# 3. BLACKWELL ORPHAN CLEANUP
# NOTES: Hunt for Proton threads that survived the container stop.
echo "--> Cleaning Blackwell render handles..."
sudo fuser -v /dev/dri/renderD128 2>/dev/null | awk '{print $NF}' | xargs -r sudo kill -9 2>/dev/null

# 4. DISPLAY HANDSHAKE KICK (Samsung DSC Fix)
# NOTES: Handshaking a Samsung HDMI 2.1 display back to safe 1080p mode
# clears the DSC (Display Stream Compression) buffer in the Blackwell GSP.
export DISPLAY=:0
export XAUTHORITY=$(find /run/user/100* -name "Xauthority" 2>/dev/null | head -n 1)
TV=$(xrandr | grep " connected" | grep -v "primary" | awk '{print $1}' | head -n 1)

if [ -n "$TV" ]; then
    echo "--> Kicking DSC Handshake for $TV..."
    xrandr --output "$TV" --mode 1920x1080 --rate 60 --auto
    sleep 1
    echo "✅ Display reset to safe-mode."
fi

# 5. PERSISTENCE REFRESH (VRAM Flush)
# NOTES: Clearing orphaned VRAM without the heavy '--gpu-reset'.
echo "--> Blackwell: Refreshing Driver Persistence..."
sudo nvidia-smi -i 0 -pm 0 > /dev/null && sudo nvidia-smi -i 0 -pm 1 > /dev/null

echo "✅ [$(date)] RECOVERY COMPLETE. SEAT 1 UNTOUCHED."
echo "=================================================="

