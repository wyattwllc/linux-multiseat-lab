#!/bin/bash
# skeleton_key.sh - Master Environment Prep & Hardware Linker (v2026.5)
# Function: Prepares X11, Forces 120Hz, and Links Input Devices for Docker.

# --- [1/4] X11 AUTHENTICATION HUNT ---
echo "--- [1/4] X11 AUTHENTICATION HUNT ---"
export DISPLAY=:0

# Improved Find: Sorts by modification time to grab the active session, not a stale one.
XAUTH_PATH=$(find /run/user/$(id -u) -name "Xauthority" -printf "%T@ %p\n" 2>/dev/null | sort -n | tail -1 | awk '{print $2}')

if [ -n "$XAUTH_PATH" ]; then
    export XAUTHORITY="$XAUTH_PATH"
    # Grant access to local non-network connections (vital for Docker)
    xhost +local:$(whoami) > /dev/null
    xhost +local:root > /dev/null
    echo "✅ VALID KEY ACQUIRED: $XAUTH_PATH"
else
    echo "❌ ERROR: No active XAuthority found. Is the Host Desktop logged in?"
    exit 1
fi

# --- [2/4] SAMSUNG TV HANDSHAKE (2K/120Hz) ---
echo "--- [2/4] SAMSUNG TV HANDSHAKE (1440p/120Hz) ---"
# We aggressively grep for common TV names or just the second connected port.
TV_OUTPUT=$(xrandr | grep " connected" | grep -v "primary" | awk '{print $1}' | head -n 1)

if [ -n "$TV_OUTPUT" ]; then
    echo "   Detected Display on: $TV_OUTPUT"
    # We toggle it OFF then ON to force a new HDMI handshake (fixes "No Signal" on deep sleep)
    xrandr --output "$TV_OUTPUT" --off
    sleep 1
    # Force 120Hz Mode. If this fails, it falls back to --auto
    xrandr --output "$TV_OUTPUT" --mode 2560x1440 --rate 120 --right-of $(xrandr | grep " primary" | awk '{print $1}') --auto || echo "⚠️  120Hz Request Failed, using Auto."
    xset dpms force on
    echo "✅ Display Output Stabilized."
else
    echo "⚠️  No Secondary Display Found. Seat 2 will run Headless or on Primary."
fi

# --- [3/4] INPUT DEVICE SYMLINKING (The Docker Fix) ---
echo "--- [3/4] CONTROLLER DISCOVERY ---"
# Docker expects /dev/input/seat2-controller. We must create it dynamically.

# 1. Find the PS5 Controller (Sony Interactive Entertainment)
# We look in /dev/input/by-id/ for a matching event device.
PS5_DEV=$(find /dev/input/by-id/ -name "*Sony*Wireless*Controller*-event-joystick" | head -n 1)

if [ -z "$PS5_DEV" ]; then
    # Fallback: Look for generic "Wireless Controller" if Sony name is masked
    PS5_DEV=$(find /dev/input/by-id/ -name "*Wireless_Controller*-event-joystick" | head -n 1)
fi

if [ -n "$PS5_DEV" ]; then
    echo "✅ Found PS5 Controller at: $PS5_DEV"
    # We create a symlink that Docker can rely on.
    # NOTE: sudo is required to modify /dev/input
    sudo ln -sf "$PS5_DEV" /dev/input/seat2-controller
    echo "   Symlink Created: /dev/input/seat2-controller -> $PS5_DEV"
else
    echo "⚠️  PS5 Controller NOT DETECTED."
    echo "   Docker may fail if it expects 'seat2-controller'."
    # EMERGENCY FALLBACK: Point to a safe dummy path so Docker doesn't crash on boot?
    # Uncomment if you want the container to start even without a controller:
    # sudo ln -sf /dev/input/mice /dev/input/seat2-controller
fi

# --- [4/4] CDI & CONTAINER LAUNCH ---
echo "--- [4/4] SEAT 2 COLD BOOT ---"
# Ensure NVIDIA Persistence Mode is ON (Prevents slow startup)
sudo nvidia-smi -pm 1 > /dev/null
# Regenerate the CDI spec to ensure the 5080 is visible
sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml > /dev/null

PROJECT_DIR="/home/null/Desktop/linux-multiseat-lab"
if [ -d "$PROJECT_DIR" ]; then
    cd "$PROJECT_DIR"
    echo "   Restarting Container..."
    
    # We pass -E to preserve the XAUTHORITY env var we exported earlier.
    sudo -E docker-compose down --remove-orphans
    
    # We purposely do NOT use 'launch_seat2.sh' here. 
    # skeleton_key.sh is a "Hard Reset" tool, so we invoke docker-compose directly.
    # Note: This skips the "Wizard" logic from launch_seat2.sh unless you source .env
    if [ -f ".env" ]; then
        source .env
    fi
    
    sudo -E docker-compose up -d --build --force-recreate
    echo "✅ Seat 2 Launch Sequence Initiated."
else
    echo "❌ ERROR: Project Directory not found at $PROJECT_DIR"
    exit 1
fi