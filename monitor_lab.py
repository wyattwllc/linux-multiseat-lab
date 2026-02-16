import os
import subprocess
import time
import sys

# --- CONFIGURATION ---
TARGET_IP = "10.0.0.50"
USER = "null"
CONTAINER = "steamos_player2"
REFRESH_RATE = 2  # Seconds

# ANSI Colors for the "Cyberpunk" HUD
C_RED = "\033[91m"
C_GREEN = "\033[92m"
C_YELLOW = "\033[93m"
C_CYAN = "\033[96m"
C_RESET = "\033[0m"

def get_remote_telemetry():
    """
    Fetches all data in a single SSH hop to minimize handshake lag.
    """
    # COMMAND CHAIN:
    # 1. GPU: Util, MemUsed, MemTotal, Temp
    # 2. LOAD: System Load (1 min avg)
    # 3. DOCKER: Container Status
    # 4. INPUT: Check if the Controller Symlink exists (Hardware Check)
    cmd = (
        "nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu --format=csv,noheader,nounits && "
        "uptime | awk -F'load average:' '{ print $2 }' && "
        f"docker inspect -f '{{{{.State.Status}}}}' {CONTAINER} 2>/dev/null || echo 'OFFLINE' && "
        "[ -L /dev/input/seat2-controller ] && echo 'LINKED' || echo 'MISSING' && "
        f"docker logs --tail 3 {CONTAINER} 2>/dev/null"
    )

    try:
        # We use a timeout to prevent the UI from freezing if SSH hangs
        result = subprocess.check_output(
            ["ssh", "-o", "ConnectTimeout=3", "-o", "LogLevel=QUIET", f"{USER}@{TARGET_IP}", cmd], 
            stderr=subprocess.STDOUT, 
            timeout=5
        )
        return result.decode('utf-8').splitlines()
    except subprocess.TimeoutExpired:
        return ["TIMEOUT"]
    except Exception:
        return None

def clear_screen():
    # ANSI Escape to clear screen and move cursor to top-left (No flickering)
    sys.stdout.write("\033[2J\033[H")

def draw_hud():
    print(f"Connecting to Blackwell Lab ({TARGET_IP})...")
    
    while True:
        data = get_remote_telemetry()
        clear_screen()
        
        # --- HEADER ---
        print(f"{C_CYAN}=================================================={C_RESET}")
        print(f"{C_CYAN}   BLACKWELL MULTISEAT HUD  |  v2026.4   {C_RESET}")
        print(f"{C_CYAN}=================================================={C_RESET}")

        if not data or "TIMEOUT" in data:
            print(f"\n{C_RED}❌ CONNECTION LOST{C_RESET}")
            print(f"   Waiting for Host ({TARGET_IP})...")
            time.sleep(REFRESH_RATE)
            continue

        try:
            # --- 1. GPU TELEMETRY (The VRAM Watchdog) ---
            # Data[0]: "45, 12000, 16384, 65"
            gpu_stats = data[0].split(', ')
            if len(gpu_stats) == 4:
                util, used, total, temp = gpu_stats
                used_int = int(used)
                total_int = int(total)
                
                # Dynamic Status Color
                if used_int > (total_int * 0.9): # >90% VRAM
                    vram_color = C_RED + "!! CRITICAL !!"
                elif used_int > (total_int * 0.8): # >80% VRAM
                    vram_color = C_YELLOW + "[HIGH]"
                else:
                    vram_color = C_GREEN + "[OK]"

                print(f" [GPU] RTX 5080 Load: {util:>3}%  |  Temp: {temp}°C")
                print(f" [MEM] {used:>5} / {total} MB {vram_color}{C_RESET}")
                
                # Visual Bar for VRAM
                bar_len = 30
                filled = int((used_int / total_int) * bar_len)
                bar = "█" * filled + "░" * (bar_len - filled)
                print(f"       [{C_CYAN}{bar}{C_RESET}]")
            
            # --- 2. SYSTEM VITALS ---
            load = data[1].strip().split(',')[0] # Get 1 min avg
            print(f" [CPU] Load Avg: {load}")
            
            # --- 3. SEAT STATUS ---
            status = data[2].strip().upper()
            ctrl_link = data[3].strip()
            
            status_color = C_GREEN if "RUNNING" in status else C_RED
            link_color = C_GREEN if "LINKED" in ctrl_link else C_RED
            
            print(f" [BOX] Container: {status_color}{status}{C_RESET}")
            print(f" [INP] Controller: {link_color}{ctrl_link}{C_RESET}")

            # --- 4. LOG STREAM ---
            print(f"\n{C_CYAN}--- LIVE STEAM LOGS ---{C_RESET}")
            if len(data) > 4:
                for line in data[4:]:
                    print(f" > {line[:80]}") 
            else:
                print(" (No logs)")

        except (ValueError, IndexError):
            print(f"{C_YELLOW}⚠️  Telemetry Parsing Error (Host busy?){C_RESET}")

        time.sleep(REFRESH_RATE)

if __name__ == "__main__":
    try:
        draw_hud()
    except KeyboardInterrupt:
        print(f"\n{C_RED}Monitoring Terminated.{C_RESET}")