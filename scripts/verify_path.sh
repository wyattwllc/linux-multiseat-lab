#!/bin/bash
# verify_paths.sh - Hardware Discovery & Proton Sweep (v2026.31)
# Targets: CachyOS / RTX 5080 / Ryzen 9900X
# Logic: Dynamic PCI mapping, CCD isolation, and Proton Version Sweeping.

# 1. LOGGING & TRACE
# NOTES: 'exec' captures all script output into our central lab_debug.log.
# tee ensures you see the output in your MintOS terminal via SSH.
LOG_FILE="$HOME/lab_debug.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "--- [HARDWARE & PROTON DISCOVERY: $(date)] ---"

# 2. BLACKWELL PCI BUS DISCOVERY (The Cold-Boot Fix)
# NOTES: We target Slot 1 (0000:01:00.0). Even if the iGPU is enabled or 
# disabled in BIOS, the PCI address of the 5080 remains constant.
GPU_BY_PATH="/dev/dri/by-path/pci-0000:01:00.0-card"

if [ -e "$GPU_BY_PATH" ]; then
    # readlink resolves the symlink to the actual device (e.g., /dev/dri/card1)
    REAL_DEVICE=$(readlink -f "$GPU_BY_PATH")
    echo "✅ GPU: Blackwell RTX 5080 confirmed at $REAL_DEVICE."
    export RENDER_DEVICE="$REAL_DEVICE"
else
    echo "⚠️  GPU: Slot 1 check failed. Scanning all NVidia Bus IDs..."
    # FALLBACK: Find the first Nvidia card that IS NOT the AMD iGPU (Vendor 1002)
    # This is critical for Blackwell architecture detection on Arch/CachyOS.
    FALLBACK_GPU=$(ls -l /dev/dri/by-path/ | grep -v "1002" | grep "card" | head -n 1 | awk '{print $NF}' | sed 's/.*\///')
    if [ -n "$FALLBACK_GPU" ]; then
        export RENDER_DEVICE="/dev/dri/$FALLBACK_GPU"
        echo "✅ GPU: Fallback discovery mapped $RENDER_DEVICE."
    else
        echo "❌ FATAL: No Nvidia Blackwell GPU detected. Check power/seating."
        exit 1
    fi
fi

# 3. CPU ISOLATION (9900X CCD Split)
# NOTES: We isolate Seat 2 to Cores 6-11 (CCD1) to prevent Seat 1 (CCD0) stutter.
# Dynamic check: If lscpu sees >1 NODE, it applies isolation; otherwise, it uses all cores.
NUM_CCDS=$(lscpu -p=NODE,CORE | grep -v "#" | awk -F, '{print $1}' | sort -u | wc -l)
if [ "$NUM_CCDS" -gt 1 ]; then
    # Ryzen 9 Dual-CCD Logic: Pin to the second CCD and its SMT threads.
    export CPU_CORES="6-11,18-23"
    echo "✅ CPU: Ryzen 9 (Dual CCD) detected. Using CCD1: $CPU_CORES"
else
    # Fallback for single-CCD or Intel testing (upper half of threads)
    export CPU_CORES="0-$(($(nproc)-1))"
    echo "ℹ️  CPU: Single CCD detected. Using global pool."
fi

# 4. PROTON VERSION SWEEP (3rd Party Game Logic)
# NOTES: Scans for GE-Proton/Experimental on the host and symlinks them to Seat 2.
# This allows Seat 2 to "see" every Proton version Seat 1 has installed.
echo "--> Sweeping for Proton Versions..."
S2_TOOLS="$HOME/seat2_steam_home/compatibilitytools.d"
mkdir -p "$S2_TOOLS"
SEARCH_PATHS=(
    "$HOME/.local/share/Steam/compatibilitytools.d"
    "$HOME/.steam/root/compatibilitytools.d"
)

for path in "${SEARCH_PATHS[@]}"; do
    if [ -d "$path" ]; then
        find "$path" -maxdepth 1 -type d -name "*Proton*" | while read -r v_dir; do
            v_name=$(basename "$v_dir")
            if [ ! -L "$S2_TOOLS/$v_name" ]; then
                ln -s "$v_dir" "$S2_TOOLS/$v_name"
                echo "✅ PROTON: Linked $v_name to Seat 2 tools directory."
            fi
        done
    fi
done

# 5. PATH & OVERLAY PREP (Persistence Fix)
# NOTES: We pre-create 'compatdata' and 'shadercache' on the host. 
# This ensures the Seat 2 Overlay Strategy works and saves persist independently.
PATHS=(
    "$HOME/seat2_library"                      # Shared Steam Data (Install folder)
    "$HOME/seat2_steam_home/compatdata"        # Private Seat 2 Proton Prefixes (Saves)
    "$HOME/seat2_steam_home/shadercache"       # Private Seat 2 Shaders (Performance)
    "$HOME/Games/Manual-Entries"               # Shared 3rd Party Games
)

for p in "${PATHS[@]}"; do
    if [ ! -d "$p" ]; then
        echo "🛠️  Auto-Heal: Creating missing path $p"
        mkdir -p "$p"
    fi
    # Force ownership to 'null' user (UID 1000) so container can write.
    sudo chown -R $USER:$USER "$p"
done

# 6. ENVIRONMENT EXPORT
# NOTES: Saves variables to a temp file so launch_seat2.sh can ingest them.
{
    echo "export RENDER_DEVICE=$RENDER_DEVICE"
    echo "export CPU_CORES=$CPU_CORES"
} > /tmp/seat2_env.sh

echo "✅ DISCOVERY: Success. Environment variables exported to /tmp/seat2_env.sh"
echo "--- [END DISCOVERY] ---"

