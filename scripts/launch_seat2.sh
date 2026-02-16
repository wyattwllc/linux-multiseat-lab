#!/bin/bash
# launch_seat2.sh - Surgical Audit Build (v2026.27)
# Targets: CachyOS / RTX 5080 / Ryzen 9900X
# Features: Integrated Universal Display Auditor & Sidecar Stats

TARGET_IP="10.0.0.50"
TARGET_USER="null"
TARGET_HZ="240" # Set your target refresh rate here

echo "=================================================="
echo "   SEAT 2 LAUNCHER: BLACKWELL / RYZEN 9900X"
echo "=================================================="

# 1. TRIGGER SIDECAR STATS (MintOS HUD)
x-terminal-emulator --title="LAB STATS: 9900X CCD ISOLATION" -e "ssh -t $TARGET_USER@$TARGET_IP 'bash scripts/lab_stats.sh'" &

# 2. REMOTE AUDIT & DEPLOYMENT
ssh -t $TARGET_USER@$TARGET_IP -- /bin/bash << EOF
    # 1. INITIALIZE LOGGING
    LOG_FILE="\$HOME/lab_debug.log"
    exec > >(tee -a "\$LOG_FILE") 2>&1
    
    echo "--- [LAUNCH SEQUENCE: \$(date)] ---"

    # 2. UNIVERSAL DISPLAY AUDIT (The Gatekeeper)
    # NOTES: We call the auditor with our TARGET_HZ.
    echo "--> Auditing Display Profile ($TARGET_HZ Hz)..."
    if [ -f "\$HOME/Desktop/linux-multiseat-lab/scripts/verify_display_profile.sh" ]; then
        bash "\$HOME/Desktop/linux-multiseat-lab/scripts/verify_display_profile.sh" $TARGET_HZ || {
            echo "❌ FATAL: Display Audit Failed. Check TV settings or HDMI 2.1 cable."
            exit 1
        }
    fi

    # 3. GENERAL DIAGNOSTICS & SENTINEL CHECK
    echo "--> Verifying Hardware Mapping & Sentinel..."
    if [ -f "\$HOME/Desktop/linux-multiseat-lab/scripts/verify_paths.sh" ]; then
        source "\$HOME/Desktop/linux-multiseat-lab/scripts/verify_paths.sh"
    fi
    systemctl is-active --quiet lab_monitor.timer && echo "✅ Sentinel: Active."

    # 4. SAMSUNG 240Hz HANDSHAKE (The DSC Kick)
    export DISPLAY=:0
    export XAUTHORITY=\$(find /run/user/100* -name "Xauthority" 2>/dev/null | head -n 1)
    
    TV=\$(xrandr | grep " connected" | grep -v "primary" | awk '{print \$1}' | head -n 1)
    PRIMARY=\$(xrandr | grep " primary" | awk '{print \$1}')

    if [ -n "\$TV" ]; then
        echo "--> Handshaking \$TV at $TARGET_HZ Hz..."
        xrandr --output "\$TV" --off && sleep 1
        xrandr --output "\$TV" --mode 2560x1440 --rate $TARGET_HZ --right-of "\$PRIMARY" --auto
        
        RESOLVED_INDEX=\$(xrandr --listactivemonitors | grep "\$TV" | awk '{print \$1}' | sed 's/://')
        echo "✅ Handshake: Target $TARGET_HZ Hz (SDL_INDEX=\$RESOLVED_INDEX)"
    fi

    # 5. CONTAINER DEPLOYMENT
    cd "\$HOME/Desktop/linux-multiseat-lab" || exit 1
    sudo -E RENDER_DEVICE=\$RENDER_DEVICE \
         CPU_CORES=\$CPU_CORES \
         RESOLVED_INDEX=\$RESOLVED_INDEX \
         XAUTHORITY=\$XAUTHORITY \
         docker-compose up -d --build --force-recreate

    # 6. POST-LAUNCH HEALTH
    sleep 5
    bash scripts/lab_doctor.sh

    echo "=================================================="
    echo "   SEAT 2 LIVE | MONITOR HUD FOR CCD STUTTER"
    echo "=================================================="
EOF

