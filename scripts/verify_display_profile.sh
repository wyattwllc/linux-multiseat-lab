#!/bin/bash
# verify_display_profile.sh - Universal Display Capability Auditor (v2026.33)
# Purpose: Verifies HDMI 2.1 Bandwidth (240Hz), VRR, and 10-bit Color.
# Usage: ./verify_display_profile.sh [TARGET_HZ]

# --- CONFIGURATION ---
TARGET_HZ="${1:-240}" 
LOG_FILE="$HOME/display_audit.log"

exec > >(tee -a "$LOG_FILE") 2>&1

echo "=================================================="
echo "   DISPLAY PROFILE AUDITOR | TARGET: ${TARGET_HZ}Hz"
echo "   DATE: $(date)"
echo "=================================================="

# 1. ENVIRONMENT PREP
# NOTES: Vital for SSH-triggered launches.
if [ -z "$DISPLAY" ]; then export DISPLAY=:0; fi
if [ -z "$XAUTHORITY" ]; then
    XAUTH_GUESS=$(find /run/user/100* -name "Xauthority" 2>/dev/null | head -n 1)
    [ -n "$XAUTH_GUESS" ] && export XAUTHORITY="$XAUTH_GUESS"
fi

# 2. BRAND-AWARE DETECTION
# NOTES: Identifies terminology for Samsung (Input Signal Plus) vs LG vs Sony.
RAW_EDID=$(xrandr --verbose)
if echo "$RAW_EDID" | grep -qi "Samsung"; then
    BRAND="Samsung"; TERM_BW="Input Signal Plus"; TERM_GM="Game Mode"
elif echo "$RAW_EDID" | grep -qi "LG Electronics"; then
    BRAND="LG"; TERM_BW="HDMI Ultra HD Deep Color"; TERM_GM="Game Optimizer"
else
    BRAND="Generic"; TERM_BW="HDMI 2.1 Enhanced"; TERM_GM="VRR/Game Mode"
fi

# Locate secondary/target display (excluding the primary monitor)
TARGET_PORT=$(xrandr | grep " connected" | grep -v "primary" | awk '{print $1}' | head -n 1)
[ -z "$TARGET_PORT" ] && TARGET_PORT=$(xrandr | grep " connected" | awk '{print $1}' | head -n 1)

if [ -z "$TARGET_PORT" ]; then
    echo "❌ FATAL: No display detected on the connection bus."
    exit 1
fi
echo "ℹ️  Targeting $BRAND on Port $TARGET_PORT"

# 3. BANDWIDTH AUDIT (HDMI 2.1)
# NOTES: Blackwell requires the TV to expose the 240Hz mode in the EDID.
echo "[1/3] Checking Bandwidth..."
if xrandr --prop | grep -A 50 "$TARGET_PORT" | grep -q "${TARGET_HZ}."; then
    echo "✅ PASS: ${TARGET_HZ}Hz Mode Available."
else
    echo "❌ FAIL: ${TARGET_HZ}Hz mode MISSING from EDID."
    echo "   ---> FIX ($BRAND): Enable '$TERM_BW' in TV settings."
    STATUS_FAIL=1
fi

# 4. VRR / ADAPTIVE SYNC
echo "[2/3] Checking VRR/G-Sync..."
if xrandr --prop | grep -A 50 "$TARGET_PORT" | grep -iE "vrr_capable|g-sync" | grep -q "1"; then
    echo "✅ PASS: VRR/G-Sync Signaling Active."
else
    echo "⚠️  WARN: VRR Inactive. Check '$TERM_GM' on TV."
fi

# 5. COLOR DEPTH (Nvidia Blackwell Specific)
echo "[3/3] Checking Color Depth..."
if command -v nvidia-settings &> /dev/null; then
    # Nvidia reports 30-bit for 10-bit color depth.
    DEPTH=$(nvidia-settings -q CurrentMetaMode -t 2>/dev/null | grep -o "depth=[0-9]*" | cut -d= -f2 | head -n 1)
    if [ -n "$DEPTH" ] && [ "$DEPTH" -ge 30 ]; then
        echo "✅ PASS: Deep Color Active ($DEPTH-bit)."
    else
        echo "ℹ️  INFO: Standard 8-bit color detected."
    fi
fi

echo "=================================================="
[ "$STATUS_FAIL" == "1" ] && exit 1 || exit 0

