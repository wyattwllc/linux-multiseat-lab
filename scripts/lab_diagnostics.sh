#!/bin/bash
# lab_diagnostic.sh - Automated Multi-Seat Integrity Audit (v2026.31)
# Targets: CachyOS / RTX 5080 / Ryzen 9900X / Samsung 240Hz
# Logic: Checks VRAM, GSP Firmware, CDI, and DSC Handshakes.

LOG_FILE="$HOME/lab_debug.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=================================================="
echo "   LAB DIAGNOSTIC AUTO-SCAN: [$(date)]"
echo "=================================================="

# 1. SEAT 1 ACTIVITY SENSE
# NOTES: Checks if Seat 1 is gaming. If so, we skip intrusive tests.
S1_LOAD=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits | head -n 1)
if [ "$S1_LOAD" -gt 10 ]; then
    echo "ℹ️  SENSE: Seat 1 is active (Load: ${S1_LOAD}%). Using Passive Scan."
    MODE="PASSIVE"
else
    MODE="ACTIVE"
fi

# 2. BLACKWELL GSP & CDI AUDIT
echo "[1/4] Auditing Blackwell Driver & CDI..."
if ! lsmod | grep -q "nvidia_uvm"; then
    echo "❌ FAIL: nvidia_uvm not loaded. DLSS 3.5 will fail."
    [ "$MODE" == "ACTIVE" ] && sudo modprobe nvidia_uvm
fi

# CDI check for Blackwell resource sharing
if ! nvidia-ctk cdi list | grep -q "://nvidia.com"; then
    echo "❌ FAIL: CDI Spec missing or corrupted."
    [ "$MODE" == "ACTIVE" ] && sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml
fi

# 3. CCD ISOLATION VERIFIER (Ryzen 9900X)
echo "[2/4] Verifying 9900X CCD Isolation..."
S2_PID=$(pgrep -f "steamos_player2" | head -n 1)
if [ -n "$S2_PID" ]; then
    AFFINITY=$(taskset -cp "$S2_PID" | awk '{print $NF}')
    if [[ "$AFFINITY" =~ [0-5] ]] || [[ "$AFFINITY" =~ (12|13|14|15|16|17) ]]; then
        echo "❌ FAIL: Seat 2 Core Leak (Affinity: $AFFINITY)."
    else
        echo "✅ PASS: Seat 2 isolated to CCD1."
    fi
else
    echo "ℹ️  SKIP: Seat 2 container not running."
fi

# 4. SAMSUNG 240Hz DSC HANDSHAKE
echo "[3/4] Testing Samsung Display Handshake..."
export DISPLAY=:0
export XAUTHORITY=$(find /run/user/100* -name "Xauthority" 2>/dev/null | head -n 1)
TV_RAW=$(xrandr | grep " connected" | grep -v "primary")
if [[ "$TV_RAW" == *"0x0"* ]]; then
    echo "❌ FAIL: Display Handshake Stalled (0x0 Detection)."
else
    echo "✅ PASS: Display Handshake active."
fi

# 5. VRAM LEAK & FRAGMENTATION
echo "[4/4] Checking Blackwell VRAM..."
VRAM_TOTAL=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits)
VRAM_USED=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits)
USAGE_PERC=$(( 100 * VRAM_USED / VRAM_TOTAL ))

if [ "$USAGE_PERC" -gt 85 ]; then
    echo "⚠️  WARN: VRAM usage high (${USAGE_PERC}%). Fragmented?"
else
    echo "✅ PASS: VRAM healthy."
fi

echo "=================================================="

