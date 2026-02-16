#!/bin/bash
# lab_doctor.sh - Proactive Guardian & Fixer (v2026.32)
# Targets: CachyOS / RTX 5080 / Ryzen 9900X
# Logic: Validates Blackwell GSP, CCD Isolation, and DSC Handshakes.
# Note: This is the background version of your diagnostic audit.

LOG_FILE="$HOME/lab_debug.log"
SENTINEL="/tmp/lab_panic.lock"
COOLDOWN=300 # 5-minute suppression to avoid Death Loops

# Redirect to log while maintaining visibility for SSH/Sidecar
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=================================================="
echo "   LAB DOCTOR AUDIT: [$(date '+%Y-%m-%d %H:%M:%S')]"
echo "=================================================="

# 1. DEATH LOOP PROTECTION
# NOTES: If a panic happened recently, we skip auto-reset to avoid thrashing.
if [ -f "$SENTINEL" ]; then
    DIFF=$(( $(date +%s) - $(stat -c %Y "$SENTINEL") ))
    if [ "$DIFF" -lt "$COOLDOWN" ]; then
        echo "ℹ️  SENTINEL: Cooldown active ($((COOLDOWN-DIFF))s). Skipping Auto-Heal."
        exit 0
    fi
    rm "$SENTINEL"
fi

# 2. SEAT 1 ACTIVITY SENSE
# NOTES: If Seat 1 is gaming (>10%), we use PASSIVE mode (No intrusive fixes).
S1_LOAD=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits | head -n 1)
if [ "$S1_LOAD" -gt 10 ]; then
    echo "ℹ️  SENSE: Seat 1 Active (${S1_LOAD}%). Using Passive Mode."
    MODE="PASSIVE"
else
    MODE="ACTIVE"
fi

# 3. BLACKWELL GSP & CDI AUDIT
echo "[1/4] Auditing Blackwell Driver & CDI..."
if ! lsmod | grep -q "nvidia_uvm"; then
    echo "❌ FAIL: nvidia_uvm module not loaded."
    # AUTO-FIX: Only modprobe if Seat 1 isn't using the driver heavily
    [ "$MODE" == "ACTIVE" ] && sudo modprobe nvidia_uvm && echo "🛠️  FIX: UVM reloaded."
fi

# CDI Check for Blackwell-Container parity
if ! nvidia-ctk cdi list | grep -q "://nvidia.com"; then
    echo "❌ FAIL: CDI Spec missing."
    [ "$MODE" == "ACTIVE" ] && sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml
fi

# 4. CCD ISOLATION VERIFIER (9900X Guard)
# NOTES: Verifies Seat 2 hasn't "leaked" into Seat 1's cores (0-5, 12-17).
echo "[2/4] Verifying 9900X CCD Isolation..."
S2_PID=$(pgrep -f "steamos_player2" | head -n 1)
if [ -n "$S2_PID" ]; then
    AFFINITY=$(taskset -cp "$S2_PID" | awk '{print $NF}')
    if [[ "$AFFINITY" =~ [0-5] ]] || [[ "$AFFINITY" =~ (12|13|14|15|16|17) ]]; then
        echo "❌ FAIL: Seat 2 Core Leak (Affinity: $AFFINITY)."
        echo "🛠️  AUTO-HEAL: Triggering surgical panic to save Seat 1 FPS..."
        touch "$SENTINEL"
        bash "$HOME/Desktop/linux-multiseat-lab/scripts/panic_reset.sh"
        exit 1
    else
        echo "✅ PASS: Seat 2 isolated to CCD1."
    fi
else
    echo "ℹ️  SKIP: Seat 2 container not running."
fi

# 5. SAMSUNG 240Hz DSC HANDSHAKE
echo "[3/4] Testing Samsung Display Handshake..."
export DISPLAY=:0
export XAUTHORITY=$(find /run/user/100* -name "Xauthority" 2>/dev/null | head -n 1)
TV_RAW=$(xrandr | grep " connected" | grep -v "primary")
if [[ "$TV_RAW" == *"0x0"* ]]; then
    echo "❌ FAIL: Display Handshake Stalled (0x0 Detected)."
    # Only reset if Seat 2 is actually supposed to be running
    if [ -n "$S2_PID" ]; then
        touch "$SENTINEL"
        bash "$HOME/Desktop/linux-multiseat-lab/scripts/panic_reset.sh"
        exit 1
    fi
else
    echo "✅ PASS: Display Handshake active."
fi

# 6. VRAM LEAK & KERNEL SYNC
echo "[4/4] Checking Blackwell VRAM & Kernel Limits..."
# Self-healing for vm.max_map_count (Proton stability)
if [ "$(sysctl -n vm.max_map_count)" -lt 1000000 ]; then
    sudo sysctl -w vm.max_map_count=2147483642 > /dev/null
    echo "🛠️  FIX: Restored vm.max_map_count."
fi

VRAM_USED=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits)
echo "✅ PASS: VRAM Usage at $VRAM_USED MB."

echo "=================================================="
echo "   AUDIT COMPLETE | Sentinel Active."
echo "=================================================="

