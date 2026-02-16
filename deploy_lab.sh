#!/bin/bash
# deploy_lab.sh - Master Reset & Deployment for Linux Multiseat Lab
# Author: wyattwllc@gmail.com
set -e

# --- CONFIGURATION ---
TARGET_IP="10.0.0.50"
USER="null"
PROJECT_DIR="/home/$USER/linux-multiseat-lab"

echo "=================================================="
echo "   LINUX MULTISEAT LAB - INFRASTRUCTURE RESET"
echo "=================================================="

# 1. PRE-FLIGHT: Get Real Network Interface from Host
# We need this for Macvlan to work. If we guess 'eth0', it will fail.
echo "Detecting Network Interface on $TARGET_IP..."
# Try to fetch interface. If SSH requires password, this might prompt.
NET_IFACE=$(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 $USER@$TARGET_IP "ip route | grep default | awk '{print \$5}'" 2>/dev/null || echo "eth0")

if [ "$NET_IFACE" == "eth0" ]; then
    echo "WARNING: Could not auto-detect interface (or it really is eth0)."
    echo "Using default: eth0"
else
    echo "SUCCESS: Detected Interface '$NET_IFACE'"
fi

# 2. Create Directory Structure
mkdir -p infrastructure
mkdir -p scripts

# 3. Generate Inventory (Explicit Newlines for Safety)
printf "[gaming_hosts]\n%s ansible_user=%s\n" "$TARGET_IP" "$USER" > infrastructure/inventory.ini

# 4. Generate ansible.cfg (For SSH Stability)
cat > ansible.cfg <<EOF
[DEFAULTS]
inventory = infrastructure/inventory.ini
host_key_checking = False
interpreter_python = /usr/bin/python3
nocows = 1

[ssh_connection]
ssh_args = -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
pipelining = True
EOF

# 5. Generate The Master Playbook
cat > infrastructure/setup.yml <<EOF
---
- name: Linux Multiseat Lab - Master Provisioning
  hosts: gaming_hosts
  become: true
  vars:
    target_user: "$USER"
    project_path: "$PROJECT_DIR"
    # Injected from the script auto-detection
    host_interface: "$NET_IFACE"

  tasks:
    # --- 1. CONNECTIVITY & DRIVERS ---
    - name: Install Critical Drivers & Tools
      community.general.pacman:
        name: 
          - nvidia-dkms
          - nvidia-utils
          - nvidia-container-toolkit
          - lib32-nvidia-utils
          - bluez
          - bluez-utils
          - docker
          - docker-compose
          - xorg-xrandr
          - xorg-xhost
          - inetutils
          - git
        state: present
        update_cache: yes

    - name: Configure NVIDIA Container Runtime
      command: nvidia-ctk runtime configure --runtime=docker
      changed_when: false

    - name: Enable Promiscuous Mode on {{ host_interface }} (For Macvlan)
      command: "ip link set {{ host_interface }} promisc on"
      ignore_errors: true

    # --- 2. PERMISSIONS ---
    - name: Allow '$USER' to run Docker without Password
      copy:
        dest: /etc/sudoers.d/docker-nopasswd
        content: "$USER ALL=(ALL) NOPASSWD: /usr/bin/docker-compose, /usr/bin/docker"
        mode: '0440'

    - name: Enable Auto-Login (Bypass SDDM)
      copy:
        dest: /etc/sddm.conf.d/autologin.conf
        content: |
          [Autologin]
          User=$USER
          Session=plasma
          Relogin=false
    
    - name: Ensure SDDM Config Dir Exists
      file:
        path: /etc/sddm.conf.d
        state: directory
        owner: root
        group: root
        mode: '0755'

    # --- 3. INPUT SLOT SYSTEM ---
    - name: Create Input Slot Rules File
      file:
        path: /etc/udev/rules.d/99-seat2-slots.rules
        state: touch
        mode: '0644'

    - name: Disable PS5 Touchpad Mouse (Ghost Cursor Fix)
      copy:
        dest: /etc/udev/rules.d/98-ps5-nomouse.rules
        content: |
          ATTRS{name}=="Sony Interactive Entertainment DualSense Wireless Controller Touchpad", ENV{LIBINPUT_IGNORE_DEVICE}="1"

    # --- 4. PROJECT FILES ---
    - name: Create Project Directories
      file:
        path: "{{ item }}"
        state: directory
        owner: "$USER"
        group: "$USER"
        mode: '0775'
      loop:
        - "{{ project_path }}"
        - "{{ project_path }}/infrastructure"
        - "{{ project_path }}/scripts"
        - "/home/$USER/seat2_library/steamapps"
        - "/home/$USER/seat2_library/compatdata"
        - "/home/$USER/Games/Manual-Entries"

  post_tasks:
    - name: Finalize Hardware Hooks
      shell: |
        dkms autoinstall || true
        mkinitcpio -P
        systemctl enable --now docker
        systemctl restart docker
        udevadm control --reload-rules && udevadm trigger
EOF

# 6. Generate Hardware Mapping Script
cat > scripts/map_hardware.sh <<'EOF'
#!/bin/bash
# map_hardware.sh - Run on CachyOS to lock USB ports to Seat 2
echo "--- INPUT SLOT MAPPING ---"
echo "We will identify the USB port for the PS5 Controller."
echo "Please UNPLUG the controller now."
read -p "Press Enter when unplugged..."

echo "Waiting for you to PLUG IT IN..."
udevadm monitor -u -s usb | grep --line-buffered "bind" | while read -r line; do
    DEVPATH=$(echo "$line" | awk '{print $NF}')
    KERNEL_ID=$(basename "$DEVPATH")
    if [[ "$KERNEL_ID" =~ ^[0-9]+-[0-9]+(\.[0-9]+)*$ ]]; then
        echo "DETECTED PORT: $KERNEL_ID"
        echo "SUBSYSTEM==\"input\", KERNELS==\"$KERNEL_ID\", ENV{ID_SEAT}=\"seat-steam\", SYMLINK+=\"input/seat2-controller\"" > /etc/udev/rules.d/99-seat2-slots.rules
        echo "SUCCESS: Port $KERNEL_ID is now 'seat2-controller'"
        pkill -P $$ udevadm
        break
    fi
done
udevadm control --reload-rules && udevadm trigger
EOF

# 7. Generate Dockerfile (Steam Fixes)
cat > Dockerfile <<EOF
FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN dpkg --add-architecture i386 && apt-get update && \
    apt-get install -y steam mesa-utils libgl1 libglx-mesa0 \
    libgl1:i386 libglx-mesa0:i386 libgl1-mesa-dri libgl1-mesa-dri:i386 \
    libvulkan1 libvulkan1:i386 sudo pulseaudio libpulse0 libpulse0:i386 \
    python3 libnss3 libxcomposite1 libxrandr2 libxtst6 libxss1 \
    curl wget file iproute2 && \
    rm -rf /var/lib/apt/lists/*
RUN userdel -r ubuntu || true
RUN groupadd -f input && groupadd -f render && \
    useradd -m -u 1000 -G video,audio,input,render gamer && \
    echo "gamer ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
USER gamer
ENV DISPLAY=:0
ENTRYPOINT ["/usr/games/steam"]
EOF

# 8. Generate Docker Compose (Auto-detected Network)
# Note: We inject the NET_IFACE we found at the start!
cat > docker-compose.yml <<EOF
services:
  steam-seat:
    build: .
    container_name: steamos_player2
    privileged: true
    networks:
      seat2_net:
        ipv4_address: 10.0.0.51
    cpuset: "6-11,18-23"
    environment:
      - DISPLAY=:0
      - SDL_VIDEO_FULLSCREEN_DISPLAY=1
      - PULSE_SERVER=unix:/run/user/1000/pulse/native
      - STEAM_EXTRA_COMPAT_TOOLS_PATHS=/home/gamer/Games
    volumes:
      - /tmp/.X11-unix:/tmp/.X11-unix:rw
      - /run/user/1000:/run/user/1000:ro
      - /home/$USER/seat2_library:/home/gamer/.local/share/Steam/steamapps
      - /home/$USER/.local/share/Steam/steamapps/common:/home/gamer/.local/share/Steam/steamapps/common:rw
      - /dev/dri:/dev/dri
    devices:
      - /dev/input/seat2-controller:/dev/input/event0
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu, graphics, display]

networks:
  seat2_net:
    driver: macvlan
    driver_opts:
      parent: $NET_IFACE
    ipam:
      config:
        - subnet: 10.0.0.0/24
          gateway: 10.0.0.1
EOF

echo "Files generated successfully."

# --- EXECUTION ---
echo "Running Ansible Playbook..."
# FIX: Explicitly passing inventory path to avoid detection failure
ansible-playbook -i infrastructure/inventory.ini infrastructure/setup.yml --ask-become-pass
