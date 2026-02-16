#!/bin/bash
# master_reset_seat2.sh - Hardware-Aware Emergency Recovery
# Targets: CachyOS / RTX 5080 / Samsung TV
# Run from: MintOS Control Node

TARGET_IP="10.0.0.50"
TARGET_USER="null"

echo "=================================================="
echo "   EMERGENCY RESET: SEAT 2 RECOVERY"
echo "=================================================="

# 1. HARDWARE ALIGNMENT CHECK
# NOTES: Before resetting, we verify if a driver crash or BIOS shift 
# has moved our GPU or Network interface.
echo "[1/4] Re-verifying Hardware Alignment..."
ssh -t $TARGET_USER@$TARGET_IP "bash ~/Desktop/linux-multiseat-lab/scripts/verify_hardware.sh"
if [ $? -ne 0 ]; then
    echo "❌ RESET ABORTED: Hardware mismatch detected. Update configs first."
    exit 1
fi

# 2. REMOTE CLEANUP & HANDSHAKE
echo "[2/4] Clearing X11 Locks & GPU Handshake..."
ssh -t $TARGET_USER@$TARGET_IP -- /bin/bash << 'EOF'
    export DISPLAY=:0
    # NOTES: Clear 'stale' lock files that prevent XWayland/X11 from restarting
    sudo rm -f /tmp/.X11-unix/X0 /tmp/.X0-lock
    
    # NOTES: Force GPU Persistence and wake the Samsung TV
    sudo nvidia-smi -pm 1 > /dev/null
    xset dpms force on
    
    TV=$(xrandr | grep " connected" | grep -v "primary" | awk '{print $1}' | head -n 1)
    if [ -n "$TV" ]; then
        xrandr --output "$TV" --off && sleep 1
        xrandr --output "$TV" --auto
        echo "✅ Samsung TV Handshake Reset."
    fi
EOF

# 3. CONTAINER PURGE
echo "[3/4] Purging Container & CDI Cache..."
ssh -t $TARGET_USER@$TARGET_IP "cd ~/Desktop/linux-multiseat-lab && sudo docker-compose down --volumes --remove-orphans"

# 4. FRESH TRIGGER
echo "[4/4] Re-triggering Launch Sequence..."
bash scripts/launch_seat2.sh

echo "=================================================="
echo "   RESET COMPLETE | Check Samsung TV for Steam"
echo "=================================================="

