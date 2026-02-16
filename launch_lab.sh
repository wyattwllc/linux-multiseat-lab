#!/bin/bash
# launch_lab.sh - Master Controller (HUD-Integrated v2.5)
# Targets: CachyOS / RTX 5080 (Blackwell) / Ryzen 9900X
# Purpose: Orchestrates boot verification, state sync, and live telemetry.

TARGET_IP="10.0.0.50"
TARGET_USER="null"
LOG_PATH="/home/$TARGET_USER/lab_debug.log"

echo "=================================================="
echo "   LINUX MULTISEAT LAB: MASTER LAUNCHER (v2.5)"
echo "=================================================="

# 0. CONNECTIVITY CHECK (The "Is CachyOS Awake?" Gate)
# NOTES: Uses a persistent ping to wait for the CachyOS network stack.
echo "[0/5] Checking CachyOS Availability..."
while ! ping -c 1 -W 1 "$TARGET_IP" &> /dev/null; do
    echo "⚠️  CachyOS (10.0.0.50) is OFFLINE. Waiting for boot..."
    sleep 5
done
echo "✅ Host detected. Waiting for SSH & X11 readiness..."

# 0.5 X11 READINESS HANDSHAKE (The "Is Desktop Ready?" Gate)
# NOTES: We must wait for the X11 socket. If we launch too early, the 
# 240Hz handshake will fail because the display server isn't initialized.
until ssh -o ConnectTimeout=5 $TARGET_USER@$TARGET_IP "[[ -S /tmp/.X11-unix/X0 ]]" 2>/dev/null; do
    echo "⏳ Waiting for X11 Session (Ensure Auto-Login on CachyOS)..."
    sleep 5
done
echo "✅ X11 Session Detected. Initiating Hardware Audit..."

# 1. REMOTE DIRECTORY & HARDWARE AUDIT
# NOTES: Hardens script permissions and performs a cold-boot hardware scan.
echo "[1/5] Auditing Remote Paths & Blackwell Hardware..."
ssh -o ConnectTimeout=10 -t $TARGET_USER@$TARGET_IP "/bin/bash" << 'EOF'
    # 1.1 Permission Guard
    [ -d ~/Desktop/linux-multiseat-lab/scripts ] && chmod +x ~/Desktop/linux-multiseat-lab/scripts/*.sh
    
    # 1.2 Hardware & Proton Discovery
    # Sources verify_paths.sh to map the 5080 by PCI-path and split 9900X CCDs.
    bash ~/Desktop/linux-multiseat-lab/scripts/verify_paths.sh || exit 1
    
    # 1.3 Blackwell Bus Verification
    echo "--> Verifying Blackwell RTX 5080 Bus ID..."
    DGPU_BUS=$(lspci -nnD | grep -E "VGA|3D" | grep -vE "8086|1002" | awk '{print $1}' | head -n 1)
    if [ -z "$DGPU_BUS" ]; then echo "❌ ERROR: RTX 5080 missing!"; exit 1; fi
    echo "✅ dGPU confirmed at $DGPU_BUS."
EOF

if [ $? -ne 0 ]; then
    echo "❌ ERROR: Remote audit failed. Halting startup."
    exit 1
fi

# 2. LOG INITIALIZATION (Background Stream)
# NOTES: Streams host kernel/driver logs to a background pipe.
ssh $TARGET_USER@$TARGET_IP "touch $LOG_PATH"
ssh -f $TARGET_USER@$TARGET_IP "tail -F $LOG_PATH" & 
LOG_PID=$!

# 3. PUSH CONFIGURATIONS (Ansible State Sync)
# NOTES: Enforces the Sentinel (Auto-Healer) and Blackwell CDI Spec.
echo "[3/5] Synchronizing Lab State via Ansible..."
ansible-playbook infrastructure/setup.yml

# 4. TRIGGER SEAT 2 (Display & Container)
# NOTES: Executes the DSC Handshake (240Hz) and starts the Seat 2 container.
echo "[4/5] Triggering Seat 2 Handshake & Container..."
bash scripts/launch_seat2.sh

# 5. MASTER DASHBOARD (Live Telemetry)
# NOTES: Instead of a tail, we launch the Python Dashboard.
# This stays active until you press Ctrl+C to end the session.
echo "[5/5] Launching Master Telemetry Dashboard..."
python3 scripts/lab_monitor.py

# --- CLEANUP ---
echo "=================================================="
echo "   DASHBOARD CLOSED | Cleaning up background logs..."
kill $LOG_PID 2>/dev/null
echo "   LAB DISCONNECTED."
echo "=================================================="

trap "kill $LOG_PID 2>/dev/null; exit" INT

