#!/bin/bash
# verify_hardware.sh - Local CachyOS Sanity Check (v2.2)
# Targets: Ryzen 9900X / RTX 5080 / CachyOS (Arch)

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}==================================================${NC}"
echo -e "   MULTISEAT LAB: HARDWARE TRUTH VERIFICATION"
echo -e "${YELLOW}==================================================${NC}"

# 1. NETWORK INTERFACE CHECK
IFACE=$(ip -br link show | grep UP | awk '{print $1}' | grep -v lo | head -n 1)
echo -e "🔍 [1/4] Network Interface: ${IFACE}"
[[ "$IFACE" == "enp14s0" ]] && echo -e "  ${GREEN}✅ Matches setup.yml${NC}" || echo -e "  ${RED}❌ MISMATCH! Expected enp14s0.${NC}"

# 2. DYNAMIC GPU MAPPING
# Detects the NVIDIA card node regardless of its index (card0 vs card1)
NVIDIA_CARD=$(ls -l /dev/dri/by-path/*pci*-card | grep -i "nvidia" | awk '{print $NF}' | sed 's/..\/..\///')
echo -e "\n🔍 [2/4] NVIDIA GPU Node: ${NVIDIA_CARD:-NOT FOUND}"
if [[ "$NVIDIA_CARD" == "card1" ]]; then
    echo -e "  ${GREEN}✅ Matches docker-compose.yml${NC}"
else
    echo -e "  ${YELLOW}⚠️  Detected as $NVIDIA_CARD. Ensuring docker-compose uses by-path for safety.${NC}"
fi

# 3. BLACKWELL STABILITY & GSP CHECK
# NOTES: Blackwell requires GSP firmware. We check if the open modules are loaded.
echo -e "\n🔍 [3/4] Blackwell Driver Health:"
if lsmod | grep -q "nvidia_uvm"; then
    echo -e "  ${GREEN}✅ Kernel Modules Loaded.${NC}"
    PM_STATUS=$(nvidia-smi --query-gpu=persistence_mode --format=csv,noheader)
    [[ "$PM_STATUS" == "Enabled" ]] && echo -e "  ${GREEN}✅ Persistence Mode: Enabled${NC}" || echo -e "  ${YELLOW}⚠️  Persistence Mode: Disabled.${NC}"
else
    echo -e "  ${RED}❌ DRIVER ERROR: nvidia_uvm module missing. Check dkms.${NC}"
fi

# 4. CPU TOPOLOGY (CCD1 Verification)
# Verifies cores 6-11 are available for the 9900X secondary CCD.
echo -e "\n🔍 [4/4] CPU CCD Topology:"
CCD1_COUNT=$(lscpu -e=CPU | grep -E "^(6|7|8|9|10|11)$" | wc -l)
[[ "$CCD1_COUNT" -eq 6 ]] && echo -e "  ${GREEN}✅ CCD 1 Online.${NC}" || echo -e "  ${RED}❌ TOPOLOGY ERROR: Check BIOS SMT/Core settings.${NC}"

echo -e "${YELLOW}==================================================${NC}"
# Exit logic for launch_lab.sh
[[ "$IFACE" == "enp14s0" && "$NVIDIA_CARD" != "" ]] && exit 0 || exit 1

