#!/bin/bash
# launch_seat2.sh - Interactive Multiseat Launcher (v2026.4)
# Features: PS5 Touchpad Isolation, Interactive Device Wizard, Docker ENV Integration
# Usage: ./launch_seat2.sh [--setup]

# --- CONFIGURATION ---
TARGET_IP="10.0.0.50"
TARGET_USER="null"
PROJECT_DIR="$HOME/Desktop/linux-multiseat-lab"
ENV_FILE="$PROJECT_DIR/.env"

# --- REMOTE EXECUTION BLOCK ---
ssh -t $TARGET_USER@$TARGET_IP "/bin/bash" << 'EOF'
    # Force immediate exit on error
    set -e

    # ==============================================================================
    # MODULE 1: THE PERIPHERAL WIZARD
    # ==============================================================================
    PROJECT_DIR="$HOME/Desktop/linux-multiseat-lab"
    ENV_FILE="$PROJECT_DIR/.env"
    
    # Helper: Select a device from xinput list
    select_xinput_device() {
        echo "--------------------------------------------------"
        echo "Select the $1 for Seat 2 (Enter number):"
        # We grep for 'slave' to avoid selecting Virtual Core pointers
        # We format it to show ID and Name clearly.
        mapfile -t DEVICES < <(xinput list --name-only | grep -v "Virtual core" | grep -v "XTEST" | sort)
        
        select ITEM in "${DEVICES[@]}" "SKIP (No device)"; do
            if [[ "$ITEM" == "SKIP (No device)" ]]; then
                echo "NONE"
                return
            elif [[ -n "$ITEM" ]]; then
                echo "$ITEM"
                return
            else
                echo "Invalid selection."
            fi
        done
    }

    # Helper: Select a dev node for Docker (harder, using /dev/input/by-id)
    select_dev_node() {
        echo "--------------------------------------------------"
        echo "Select the /dev/input node for $1 (Docker Passthrough):"
        echo "NOTE: Choose the event-mouse or event-kbd entry matching your device."
        
        mapfile -t NODES < <(ls /dev/input/by-id/usb-*-event*)
        
        select NODE in "${NODES[@]}" "SKIP"; do
            if [[ "$NODE" == "SKIP" ]]; then
                echo "/dev/null"
                return
            elif [[ -n "$NODE" ]]; then
                echo "$NODE"
                return
            fi
        done
    }

    # RUN WIZARD IF REQUESTED OR MISSING ENV
    # We check if .env exists or if the user passed a "setup" flag (simulated here for simplicity)
    if [ ! -f "$ENV_FILE" ] || [ "$1" == "--setup" ]; then
        echo "=================================================="
        echo "   SEAT 2 SETUP WIZARD"
        echo "=================================================="
        echo "Creating new configuration file..."

        # 1. MOUSE SETUP
        MOUSE_NAME=$(select_xinput_device "MOUSE")
        if [ "$MOUSE_NAME" != "NONE" ]; then
            MOUSE_DEV=$(select_dev_node "MOUSE")
        else
            MOUSE_DEV="/dev/null"
        fi

        # 2. KEYBOARD SETUP
        KB_NAME=$(select_xinput_device "KEYBOARD")
        if [ "$KB_NAME" != "NONE" ]; then
            KB_DEV=$(select_dev_node "KEYBOARD")
        else
            KB_DEV="/dev/null"
        fi

        # Write to .env
        echo "SEAT2_MOUSE_NAME=\"$MOUSE_NAME\"" > "$ENV_FILE"
        echo "SEAT2_MOUSE_DEV=\"$MOUSE_DEV\"" >> "$ENV_FILE"
        echo "SEAT2_KB_NAME=\"$KB_NAME\"" >> "$ENV_FILE"
        echo "SEAT2_KB_DEV=\"$KB_DEV\"" >> "$ENV_FILE"
        
        echo "✅ Configuration saved to $ENV_FILE"
        echo "--------------------------------------------------"
    fi

    # Load the configuration
    source "$ENV_FILE"

    # ==============================================================================
    # MODULE 2: AUTOMATIC CONTROLLER ISOLATION (PS5 FIX)
    # ==============================================================================
    # PS5 Controllers have a touchpad that X11 thinks is a mouse.
    # We must float it, or Player 2 will hijack your cursor.
    echo "--> Scanning for PS5 Controllers..."
    
    # Grep for Sony Touchpad specifically
    PS5_TOUCH_ID=$(xinput list --id-only "Sony Interactive Entertainment Wireless Controller Touchpad" 2>/dev/null || echo "")
    
    if [ -n "$PS5_TOUCH_ID" ]; then
        echo "   Found PS5 Touchpad (ID: $PS5_TOUCH_ID). Isolating..."
        xinput float "$PS5_TOUCH_ID" && echo "✅ PS5 Touchpad Severed."
    else
        echo "   No PS5 Touchpad active (or already floated)."
    fi

    # ==============================================================================
    # MODULE 3: PERIPHERAL ISOLATION (MOUSE/KB)
    # ==============================================================================
    if [ "$SEAT2_MOUSE_NAME" != "NONE" ]; then
        echo "--> Isolating Mouse: $SEAT2_MOUSE_NAME"
        xinput float "$(xinput list --id-only "$SEAT2_MOUSE_NAME")" 2>/dev/null || echo "⚠️  Could not float mouse (already floated?)"
    fi

    if [ "$SEAT2_KB_NAME" != "NONE" ]; then
        echo "--> Isolating Keyboard: $SEAT2_KB_NAME"
        # Keyboards are tricky. Often floating the "slave keyboard" is enough.
        xinput float "$(xinput list --id-only "$SEAT2_KB_NAME")" 2>/dev/null || echo "⚠️  Could not float keyboard."
    fi

    # ==============================================================================
    # MODULE 4: DISPLAY & LAUNCH
    # ==============================================================================
    
    # (Existing Logic for Samsung TV detection...)
    TV_OUTPUT=$(xrandr | grep " connected" | grep -v "primary" | awk '{print $1}' | head -n 1)
    if [ -z "$TV_OUTPUT" ]; then
        RESOLVED_INDEX=0
    else
        # Calculate Index
        RESOLVED_INDEX=1
        # Force 120Hz (Optional, uncomment if needed)
        # xrandr --output "$TV_OUTPUT" --mode 2560x1440 --rate 120 --right-of primary --auto
    fi

    echo "--> Launching Container..."
    cd "$PROJECT_DIR"
    
    # We pass the env vars to docker-compose automatically via the .env file we just sourced/created
    sudo -E SDL_VIDEO_FULLSCREEN_DISPLAY=$RESOLVED_INDEX \
            taskset -c 6-11,18-23 \
            docker-compose up -d --build --force-recreate

    echo "=================================================="
    echo "   SEAT 2 LIVE - PS5 MODE"
    echo "=================================================="
EOF