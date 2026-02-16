#!/bin/bash
# map_hardware.sh - Hardware Slot Locking for Seat 2
# Targets: PS5 Controller (DualSense) on CachyOS

if [[ $EUID -ne 0 ]]; then
   echo "❌ This script must be run as root (sudo)."
   exit 1
fi

RULE_FILE="/etc/udev/rules.d/99-seat2-slots.rules"

echo "--- [1/2] PS5 CONTROLLER SLOT DISCOVERY ---"
echo "1. Unplug the Seat 2 PS5 Controller."
read -p "2. Press Enter once it is unplugged..."

echo "3. 🚀 PLUG IT IN NOW..."
# NOTES: We monitor 'usb' to catch the physical port binding
udevadm monitor -u -s usb | grep --line-buffered "bind" | while read -r line; do
    DEVPATH=$(echo "$line" | awk '{print $NF}")
    KERNEL_ID=$(basename "$DEVPATH")
    
    if [[ "$KERNEL_ID" =~ ^[0-9]+-[0-9]+(\.[0-9]+)*$ ]]; then
        echo "✅ DETECTED PHYSICAL PORT: $KERNEL_ID"
        
        # NOTES: 
        # 1. SYMLINK creates /dev/input/seat2-controller for Docker.
        # 2. LIBINPUT_IGNORE_DEVICE prevents the PS5 touchpad from moving the Host cursor.
        RULE="SUBSYSTEMS==\"usb\", KERNELS==\"$KERNEL_ID\", ENV{ID_SEAT}=\"seat2\", ENV{LIBINPUT_IGNORE_DEVICE}=\"1\", SYMLINK+=\"input/seat2-controller\""
        
        # CLEANUP: Remove any existing rules for THIS KERNEL_ID to prevent duplicates
        sed -i "/$KERNEL_ID/d" "$RULE_FILE" 2>/dev/null
        
        echo "$RULE" >> "$RULE_FILE"
        
        echo "✅ SUCCESS: Physical port $KERNEL_ID is locked to Seat 2."
        echo "Reloading udev rules..."
        udevadm control --reload-rules && udevadm trigger
        
        pkill -P $$ udevadm 
        break
    fi
done

echo "--- [2/2] CONTAINER RE-SYNC ---"
# NOTES: Docker devices are 'static' at launch. We must force-recreate to bind the node.
read -p "Force-restart Seat 2 now to map the new controller? (y/n): " RESTART
if [[ "$RESTART" == "y" ]]; then
    cd ~/Desktop/linux-multiseat-lab
    # NOTES: -E carries your XAuthority into the restart sequence
    sudo -E docker-compose up -d --force-recreate
fi

