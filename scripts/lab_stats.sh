#!/bin/bash
# lab_stats.sh - Multi-Seat Performance HUD (v2026.36)
# Targets: CachyOS / RTX 5080 (Blackwell) / Ryzen 9900X (Zen 5)
# Purpose: Real-time visual verification of CCD isolation and GPU load.
# Logic: Zero-overhead polling using mpstat and nvidia-smi with VRAM Alerts.

# NOTES: 
# 1. This script is triggered by 'launch_seat2.sh' as a sidecar terminal on MintOS.
# 2. CCD0 (Cores 0-5, 12-17) is the protected zone for Seat 1.
# 3. CCD1 (Cores 6-11, 18-23) is the isolated zone for Seat 2.
# 4. VRAM Alert: Flashes Red if usage > 14500MB to warn of Seat 1 starvation.

# Color definitions for scannability
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
FLASH_RED='\033[0;31;5m' # ANSI Blink/Flash
NC='\033[0m' # No Color

# Uses 'watch' for a stable 1-second refresh rate without terminal flicker.
# The '-c' flag ensures ANSI colors are interpreted correctly.
watch -t -c -n 1 "
    echo -e '${BLUE}==================================================${NC}'
    echo -e '   ${BLUE}9900X MULTISEAT HUD: CCD0 (S1) vs CCD1 (S2)${NC}'
    echo -e '${BLUE}==================================================${NC}'
    
    # 1. CCD0 (Seat 1) AUDIT
    # NOTES: Monitored to ensure zero intrusion. Load should reflect Seat 1 gaming.
    echo -e '${GREEN}--- [CCD0: SEAT 1 (Cores 0-5, 12-17)] ---${NC}'
    mpstat -P 0,1,2,3,4,5,12,13,14,15,16,17 1 1 | tail -n 1 | \
    awk '{printf \"  CPU Load: %.2f%% | System Wait: %.2f%%\\n\", 100-\$12, \$6}'
    
    echo ''
    
    # 2. CCD1 (Seat 2) AUDIT
    # NOTES: Monitors Seat 2 performance. If Load is high but FPS is low, check System Wait.
    echo -e '${YELLOW}--- [CCD1: SEAT 2 (Cores 6-11, 18-23)] ---${NC}'
    mpstat -P 6,7,8,9,10,11,18,19,20,21,22,23 1 1 | tail -n 1 | \
    awk '{printf \"  CPU Load: %.2f%% | System Wait: %.2f%%\\n\", 100-\$12, \$6}'
    
    echo -e '${BLUE}==================================================${NC}'
    
    # 3. BLACKWELL RTX 5080 STATUS & VRAM ALERTS
    # NOTES: Fetches Power, Load, Temp, and VRAM.
    # Logic: If VRAM > 14500MB, the HUD color shifts to flashing red.
    echo -e '${RED}--- [RTX 5080 BLACKWELL STATUS] ---${NC}'
    
    VRAM_DATA=\$(nvidia-smi --query-gpu=power.draw,utilization.gpu,temperature.gpu,memory.used,memory.total --format=csv,noheader,nounits)
    
    echo \"\$VRAM_DATA\" | awk -F', ' -v red='${RED}' -v flash='${FLASH_RED}' -v nc='${NC}' '{
        vram_used = \$4;
        color = red;
        if (vram_used > 14500) color = flash;
        printf \"  Power: %sW | Load: %s%% | Temp: %s°C\\n\", \$1, \$2, \$3;
        printf \"  VRAM Status: %s%s/%s MB%s\\n\", color, \$4, \$5, nc;
    }'
    
    echo -e '${BLUE}==================================================${NC}'
    
    # 4. SENTINEL & CONTAINER STATUS
    echo -n '  Sentinel Timer: '
    systemctl is-active lab_monitor.timer
    echo -n '  Seat 2 Container: '
    docker ps --format \"{{.Status}}\" --filter name=steamos_player2
    echo -e '${BLUE}==================================================${NC}'
"

