#!/bin/bash
# Master Lab Reset - Remote trigger for CachyOS (10.0.0.50)
# Fix: Quoted EOF to prevent Fish/Bash syntax conflicts.

echo "=================================================="
echo "   REBUILDING BALANCED GAMING LAB..."
echo "=================================================="

# 1. CORE PROJECT SYNC
cd ~/Desktop/linux-multiseat-lab/infrastructure || exit 1

# 2. ANSIBLE EXECUTION
# Added --flush-cache to ensure Blackwell driver changes are immediate.
ansible-playbook -i inventory.ini setup.yml --ask-become-pass --flush-cache

echo "=================================================="
echo "   REBUILD COMPLETE. CHECK SAMSUNG TV."
echo "=================================================="
read -p "Press Enter to close..."

