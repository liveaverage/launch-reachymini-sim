<h1 align="center">🤖 Reachy Mini Simulation Launcher</h1>

<p align="center">
  <strong>One-click deployment of Pollen Robotics' Reachy Mini robot simulation</strong>
</p>

<p align="center">
  <a href="https://github.com/pollen-robotics/reachy_mini"><img src="https://img.shields.io/badge/Robot-Reachy%20Mini-00d4aa?style=for-the-badge&logo=probot&logoColor=white" alt="Reachy Mini"/></a>
  <a href="https://docs.docker.com/"><img src="https://img.shields.io/badge/Docker-Required-2496ED?style=for-the-badge&logo=docker&logoColor=white" alt="Docker"/></a>
  <a href="https://developer.nvidia.com/cuda-toolkit"><img src="https://img.shields.io/badge/NVIDIA-GPU%20Required-76B900?style=for-the-badge&logo=nvidia&logoColor=white" alt="NVIDIA GPU"/></a>
  <a href="https://mujoco.org/"><img src="https://img.shields.io/badge/Physics-MuJoCo-FF6B35?style=for-the-badge" alt="MuJoCo"/></a>
</p>

---

## 🚀 Deploy Instantly with Brev

<p align="center">
  <em>Skip the setup—launch a fully configured Reachy Mini simulation environment in seconds</em>
</p>

<table align="center">
<thead>
<tr>
<th align="center">GPU</th>
<th align="center">VRAM</th>
<th align="center">Best For</th>
<th align="center">Deploy</th>
</tr>
</thead>
<tbody>
<tr>
<td align="center"><strong>🔵 NVIDIA L40S</strong></td>
<td align="center">48 GB</td>
<td align="center">Heavy Simulation & AI Apps</td>
<td align="center"><a href="https://brev.nvidia.com/launchable/deploy?launchableID=env-XXXXX"><img src="https://brev-assets.s3.us-west-1.amazonaws.com/nv-lb-dark.svg" alt="Deploy on Brev" height="40"/></a></td>
</tr>
</tbody>
</table>

<p align="center">
  <sub>☝️ Click deploy to launch on <a href="https://brev.nvidia.com">Brev</a> — GPU cloud for AI developers</sub>
</p>

---

<p align="center">
  <a href="#-quick-start">Quick Start</a> •
  <a href="#-features">Features</a> •
  <a href="#-architecture">Architecture</a> •
  <a href="#%EF%B8%8F-configuration">Configuration</a> •
  <a href="#-sdk-examples">SDK Examples</a> •
  <a href="#-troubleshooting">Troubleshooting</a>
</p>

---

## ✨ Features

<table>
<tr>
<td width="50%">

### 🖥️ Web-Based VNC
Access the full 3D MuJoCo simulation through your browser via TurboVNC + noVNC. GPU-accelerated with VirtualGL for smooth remote rendering.

### 📊 Dashboard
Built-in Reachy Mini dashboard for robot status, controls, and real-time monitoring at port 8000.

### 🗣️ Conversation App
Voice assistant powered by OpenAI's realtime API. Talk to Reachy Mini through your browser's microphone via the Gradio web UI at port 7860.

</td>
<td width="50%">

### ⚡ GPU Accelerated
Full NVIDIA GPU passthrough with VirtualGL for real-time physics simulation in MuJoCo.

### 🐍 Jupyter Lab
Pre-configured Python 3.12 environment with Reachy Mini SDK for rapid prototyping.

</td>
</tr>
</table>

---

## 📋 Prerequisites

| Requirement | Details |
|:------------|:--------|
| **OS** | Ubuntu 22.04+ / Debian-based Linux |
| **GPU** | NVIDIA GPU with drivers installed |
| **Verification** | `nvidia-smi` should display GPU info |
| **Network** | Internet access for Docker image (~3-5GB) |
| **Privileges** | `sudo` access required |

> [!IMPORTANT]
> The scripts assume NVIDIA drivers are already installed. If `nvidia-smi` fails, [install NVIDIA drivers](https://docs.nvidia.com/cuda/cuda-installation-guide-linux/) first.

---

## 🚀 Quick Start

```bash
# Clone and run - that's it!
git clone https://github.com/liveaverage/brev-launch-reachymini-sim.git
cd brev-launch-reachymini-sim
./install.sh
```

Or one-liner:

```bash
bash <(curl -sL https://raw.githubusercontent.com/liveaverage/brev-launch-reachymini-sim/main/install.sh)
```

After a few minutes, access your simulation:

<table>
<tr>
<th>🖥️ 3D Simulator</th>
<th>🗣️ Conversation App</th>
<th>📊 Dashboard</th>
<th>📓 Jupyter Lab</th>
</tr>
<tr>
<td align="center">

**http://localhost:6080/vnc.html**

MuJoCo simulation via<br/>noVNC web interface

</td>
<td align="center">

**http://localhost:7860**

Voice assistant via<br/>browser microphone

</td>
<td align="center">

**http://localhost:8000**

Reachy Mini dashboard<br/>& controls

</td>
<td align="center">

**http://localhost:8888**

Python notebooks for<br/>SDK development

</td>
</tr>
</table>

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         install.sh                                  │
│                    (Entry Point Script)                             │
└──────────────────────────┬──────────────────────────────────────────┘
                           │
           ┌───────────────┴───────────────┐
           ▼                               ▼
┌──────────────────────┐       ┌──────────────────────┐
│   setup_env.sh       │       │   start_reachy.sh    │
│  ─────────────────   │       │  ─────────────────   │
│  • Install Docker    │       │  • Pull Docker image │
│  • NVIDIA Toolkit    │       │  • Configure GPU     │
│  • User permissions  │       │  • Expose ports      │
└──────────────────────┘       └──────────┬───────────┘
                                          │
                                          ▼
                ┌─────────────────────────────────────────┐
                │  ghcr.io/liveaverage/reachy-mini-sim    │
                │  ───────────────────────────────────────│
                │                                         │
                │   ┌──────────────┐  ┌──────────────┐   │
                │   │   Xvfb +     │  │   MuJoCo     │   │
                │   │  TurboVNC    │  │  Simulation  │   │
                │   └──────────────┘  └──────────────┘   │
                │                                         │
                │   ┌──────────────┐  ┌──────────────┐   │
                │   │   noVNC      │  │   Jupyter    │   │
                │   │  (Web VNC)   │  │     Lab      │   │
                │   └──────────────┘  └──────────────┘   │
                │                                         │
                │   ┌──────────────┐  ┌──────────────┐   │
                │   │  Dashboard   │  │ Conversation │   │
                │   │  (Port 8000) │  │ App (:7860)  │   │
                │   └──────────────┘  └──────────────┘   │
                │                                         │
                │    :6080    :7860    :8000    :8888    │
                └─────────────────────────────────────────┘
```

### Container Stack

| Component | Purpose |
|:----------|:--------|
| **Xvfb** | Virtual framebuffer for headless display |
| **VirtualGL** | GPU-accelerated OpenGL rendering |
| **TurboVNC** | Optimized VNC server for GPU apps |
| **noVNC** | Web-based VNC client (websocket) |
| **MuJoCo** | Physics simulation engine |
| **Conversation App** | Voice assistant with Gradio web UI |
| **Supervisor** | Process manager for all services |

### Docker Container Configuration

| Setting | Value | Purpose |
|:--------|:------|:--------|
| **Image** | `ghcr.io/liveaverage/reachy-mini-sim:latest` | Pre-built simulation image |
| **Container** | `reachy_mini_sim` | Easy identification |
| **Restart** | `unless-stopped` | Auto-recovery on failure |
| **Shared Memory** | `2GB` | Physics simulation buffer |
| **GPU** | `--gpus all` | Full GPU passthrough |

---

## ⚙️ Configuration

### Environment Variables

Set these when launching the container:

```bash
# Scene configuration (default: empty)
export REACHY_SCENE=empty      # Just the robot
export REACHY_SCENE=minimal    # Robot + table + objects

# Display resolution
export RESOLUTION=1920x1080    # Default
export RESOLUTION=2560x1440    # Higher resolution

# OpenAI API key (for conversation app)
export OPENAI_API_KEY=sk-...
```

### Launch with Custom Settings

```bash
REACHY_SCENE=minimal OPENAI_API_KEY=sk-xxx ./scripts/start_reachy.sh
```

### Port Configuration

Default ports in `scripts/start_reachy.sh`:

```bash
-p 6080:6080 \   # 🖥️  noVNC web interface
-p 7860:7860 \   # 🗣️  Conversation App (Gradio)
-p 8000:8000 \   # 📊 Dashboard
-p 8888:8888     # 📓 Jupyter Lab
```

### Scene Options

| Scene | Description |
|:------|:------------|
| `empty` | Just Reachy Mini robot (default) |
| `minimal` | Robot + table + manipulation objects |

---

## 🐍 SDK Examples

### Connect to the Simulation

```python
from reachy_mini import ReachyMini
from reachy_mini.utils import create_head_pose

# Connect to the simulated robot
with ReachyMini() as mini:
    print(f"Connected: {mini.is_connected}")
```

### Move the Robot Head

```python
from reachy_mini import ReachyMini
from reachy_mini.utils import create_head_pose

with ReachyMini() as mini:
    # Look up and tilt head
    mini.goto_target(
        head=create_head_pose(z=10, roll=15, degrees=True, mm=True),
        duration=1.0
    )
```

### Animate Antennas

```python
from reachy_mini import ReachyMini
import time

with ReachyMini() as mini:
    # Wave antennas
    for _ in range(3):
        mini.antennas.set_positions([30, -30])
        time.sleep(0.3)
        mini.antennas.set_positions([-30, 30])
        time.sleep(0.3)
    mini.antennas.set_positions([0, 0])
```

> 📚 **Full SDK Documentation:** [github.com/pollen-robotics/reachy_mini](https://github.com/pollen-robotics/reachy_mini)

---

## 🤖 Conversation App

The [Reachy Mini Conversation App](https://github.com/pollen-robotics/reachy_mini_conversation_app) is bundled and starts automatically. It provides a voice assistant powered by OpenAI's realtime API.

### Requirements

- **OpenAI API Key**: Required for the conversation app to function
- **Browser Microphone**: Grant microphone access when prompted in the Gradio UI

### Quick Start

```bash
# Launch with OpenAI API key
OPENAI_API_KEY=sk-your-key-here ./scripts/start_reachy.sh

# Access the conversation app at:
# http://localhost:7860
```

### How It Works

1. Open the Gradio web UI at port 7860
2. Allow browser microphone access when prompted
3. Speak to Reachy Mini through your browser
4. Watch the robot respond in the noVNC simulation view

> **Note**: The conversation app runs in audio-only mode (`--no-camera`) since remote simulation doesn't have access to a physical camera. Future versions may support client webcam passthrough.

### Checking Logs

```bash
# View conversation app logs
docker exec -it reachy_mini_sim cat /var/log/supervisor/conversation-app.log

# View error logs
docker exec -it reachy_mini_sim cat /var/log/supervisor/conversation-app_err.log
```

---

## 🔧 Container Management

```bash
# Check container status
docker ps -a | grep reachy_mini_sim

# View live logs
docker logs -f reachy_mini_sim

# Stop the simulation
docker stop reachy_mini_sim

# Restart the simulation
docker start reachy_mini_sim

# Full restart (remove and relaunch)
docker rm -f reachy_mini_sim
./scripts/start_reachy.sh

# Shell into container
docker exec -it reachy_mini_sim bash
```

---

## 🔥 Troubleshooting

<details>
<summary><strong>❌ Docker permission denied</strong></summary>

```bash
# Option 1: Log out and back in (recommended after first install)
logout

# Option 2: Force group reload (install.sh does this automatically)
sg docker -c "./scripts/start_reachy.sh"
```

</details>

<details>
<summary><strong>❌ GPU not detected in container</strong></summary>

```bash
# Verify host GPU works
nvidia-smi

# Test NVIDIA Container Toolkit
docker run --rm --gpus all nvidia/cuda:12.0-base nvidia-smi

# Reconfigure if needed
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

</details>

<details>
<summary><strong>❌ Container exits immediately</strong></summary>

```bash
# Check logs for error details
docker logs reachy_mini_sim

# Common causes:
# • Insufficient shared memory → increase --shm-size
# • GPU memory exhausted → close other GPU applications
# • Port already in use → change port mappings
```

</details>

<details>
<summary><strong>❌ VNC page loads but shows nothing</strong></summary>

- Wait 15-30 seconds for MuJoCo simulation to initialize
- Verify container is running: `docker ps | grep reachy_mini_sim`
- Check logs: `docker logs reachy_mini_sim`
- Try refreshing the noVNC page

</details>

<details>
<summary><strong>❌ Simulation is laggy/slow</strong></summary>

In noVNC settings (gear icon):
- Set **Quality** to 6-9 for better visuals
- Enable **Compression** for remote connections
- Try **Local Scaling: Remote Resizing** mode

For faster connections:
- Use wired ethernet instead of WiFi
- Reduce `RESOLUTION` environment variable

</details>

<details>
<summary><strong>🌐 Remote access setup</strong></summary>

```bash
# Get host IP
hostname -I | awk '{print $1}'

# Access remotely:
# http://<HOST_IP>:6080/vnc.html  (noVNC)
# http://<HOST_IP>:7860           (Conversation App)
# http://<HOST_IP>:8000           (Dashboard)
# http://<HOST_IP>:8888           (Jupyter Lab)

# Open firewall ports
sudo ufw allow 6080/tcp
sudo ufw allow 7860/tcp
sudo ufw allow 8000/tcp
sudo ufw allow 8888/tcp
```

</details>

---

## 📁 File Reference

| File | Purpose |
|:-----|:--------|
| `install.sh` | 🚀 Entry point—runs setup + launches simulation |
| `Dockerfile` | 🐳 Container image definition |
| `scripts/setup_env.sh` | 🔧 Installs Docker + NVIDIA Container Toolkit |
| `scripts/start_reachy.sh` | 🤖 Pulls and launches container |
| `scripts/entrypoint.sh` | 🎬 Container startup script |
| `config/supervisord.conf` | ⚙️ Process manager configuration |
| `config/jupyter_config.py` | 📓 Jupyter Lab settings |
| `.github/workflows/build-image.yml` | 🏗️ CI/CD for image builds |

---

## 📦 Dependencies

**Installed automatically:**
- Docker Engine via [get.docker.com](https://get.docker.com)
- NVIDIA Container Toolkit

**Required on host:**
- NVIDIA GPU drivers
- `curl`, `sudo`, `git`

**Docker image includes:**
- Python 3.12 + reachy-mini SDK
- MuJoCo physics engine
- VirtualGL + TurboVNC + noVNC
- Conversation App (Gradio-based voice assistant)
- Jupyter Lab

---

## 🔗 References

<table>
<tr>
<td align="center">
<a href="https://github.com/pollen-robotics/reachy_mini">
<img src="https://img.shields.io/badge/GitHub-reachy__mini-181717?style=flat-square&logo=github" alt="GitHub"/>
</a>
<br/><sub>Reachy Mini SDK</sub>
</td>
<td align="center">
<a href="https://huggingface.co/reachy-mini">
<img src="https://img.shields.io/badge/🤗%20Hugging%20Face-Apps-yellow?style=flat-square" alt="HuggingFace"/>
</a>
<br/><sub>Reachy Mini Apps</sub>
</td>
<td align="center">
<a href="https://mujoco.org/">
<img src="https://img.shields.io/badge/MuJoCo-Physics-FF6B35?style=flat-square" alt="MuJoCo"/>
</a>
<br/><sub>Physics Engine</sub>
</td>
<td align="center">
<a href="https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/">
<img src="https://img.shields.io/badge/NVIDIA-Container%20Toolkit-76B900?style=flat-square&logo=nvidia" alt="NVIDIA"/>
</a>
<br/><sub>GPU Runtime</sub>
</td>
</tr>
</table>

---

<p align="center">
  <sub>Based on <a href="https://github.com/pollen-robotics/reachy_mini">Pollen Robotics Reachy Mini</a> • Apache 2.0 License</sub>
</p>
