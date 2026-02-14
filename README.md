# Linux Multiseat Lab: Single-GPU Resource Orchestration

Instructions for setting up a dual-user Linux workstation environment powered by a single NVIDIA GPU. It utilizes containerized workloads and Infrastructure-as-Code (IaC) to provide a functional gaming experience for a second user without the overhead of full virtualization. (SSH for additional configuring is still possible however)

## 🏗️ Architecture & Tech Stack

- **Host OS:** [CachyOS](https://cachyos.org/) (Arch-based) for optimized kernel performance and NVIDIA drivers.
- **Automation:** [Ansible](https://www.ansible.com/) for idempotent hardware provisioning and container deployment.
- **Containerization:** [Docker](https://www.docker.com/) via the **Wolf (Games on Whales)** project to isolate the secondary seat.
- **Streaming Protocol:** [Moonlight/Sunshine](https://moonlight-stream.org/) for low-latency internal loopback streaming.

## 🛠️ Key Technical Challenges Addressed

### 1. Single-GPU Resource Contention
Unlike traditional multi-seat setups requiring two physical GPUs, this project utilizes a "Soft Multiseat" approach. By sharing the Vulkan/OpenGL driver stack across the host and a privileged Docker container, we achieve near-native performance (approx. 95-98% efficiency) while dynamically sharing VRAM.

### 2. Infrastructure as Code (IaC)
To ensure reproducibility, the entire environment is deployed via Ansible playbooks. This eliminates manual configuration errors in:
- NVIDIA Container Toolkit registration.
- Udev rule assignments for per-seat input isolation.
- Persistent volume mapping for shared Steam libraries.

### 3. Input & Focus Management
Solving the "Single Focus" limitation of SDL/Wayland by utilizing separate seat assignments and forcing gamepad IDs within the Moonlight stream, ensuring Player 1's inputs never "bleed" into Player 2's session.

## 🚀 Deployment

### Prerequisites
- A control node (Linux/Unix) with Ansible installed.
- A target node running CachyOS with an NVIDIA GPU.

### Usage
1. Update the `infrastructure/inventory.ini` with your target IP.
2. Run the deployment playbook:
   ```bash
   ansible-playbook -i infrastructure/inventory.ini infrastructure/setup.yml --ask-become-pass

## 📝 Project Roadmap & Task Status

### Phase 1: Infrastructure (In Progress)
- [x] Initial Repository Architecture and Git Configuration
- [x] Ansible Playbook: Basic System Provisioning
- [x] Ansible Playbook: NVIDIA Container Toolkit Integration
- [x] SSH Handshake & Remote Control Configuration (Mint to CachyOS)

### Phase 2: Runtime Configuration
- [ ] Implement Wolf (Games on Whales) Docker Compose
- [ ] Configure Moonlight/Sunshine Loopback Stream
- [ ] Map Per-Seat Input Devices (Controller Isolation)

### Phase 3: Optimization & Tooling
- [ ] Develop Python-based Dynamic Input Binder
- [ ] VRAM Allocation Testing & Performance Benchmarking
- [ ] Automated Backup Strategy (BTRFS Snapshots)
