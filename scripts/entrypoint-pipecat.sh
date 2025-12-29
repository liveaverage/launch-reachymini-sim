#!/bin/bash
# =============================================================================
# Reachy Mini Simulation + Pipecat Bot Container Entrypoint
# Purpose: Initialize environment and start supervisor
# =============================================================================
set -e

echo "=============================================="
echo "🤖 Reachy Mini Simulation + Pipecat Bot"
echo "=============================================="

# -----------------------------------------------------------------------------
# Environment Setup
# -----------------------------------------------------------------------------
export DISPLAY=${DISPLAY:-:1}
export RESOLUTION=${RESOLUTION:-1024x768}
export REACHY_SCENE=${REACHY_SCENE:-empty}
export NOVNC_PORT=${NOVNC_PORT:-6080}
export PIPECAT_PORT=${PIPECAT_PORT:-7880}
export NAT_PORT=${NAT_PORT:-8001}
export DASHBOARD_PORT=${DASHBOARD_PORT:-8000}
export JUPYTER_PORT=${JUPYTER_PORT:-8888}
export PYTHONUNBUFFERED=1

# WebRTC port range
export RTC_PORT_RANGE_MIN=${RTC_PORT_RANGE_MIN:-10000}
export RTC_PORT_RANGE_MAX=${RTC_PORT_RANGE_MAX:-20000}

# STUN/TURN servers for NAT traversal (critical for remote access)
export STUN_SERVERS=${STUN_SERVERS:-"stun:stun.l.google.com:19302,stun:stun1.l.google.com:19302"}
export TURN_SERVER=${TURN_SERVER:-""}
export TURN_USERNAME=${TURN_USERNAME:-""}
export TURN_PASSWORD=${TURN_PASSWORD:-""}

echo "📺 Display: ${DISPLAY}"
echo "📐 Resolution: ${RESOLUTION}"
echo "🎬 Scene: ${REACHY_SCENE}"
echo ""

# -----------------------------------------------------------------------------
# VNC Password Setup
# -----------------------------------------------------------------------------
echo "🔐 Setting up VNC password..."
mkdir -p /root/.vnc
# Use vncpasswd to create password file (simpler than x11vnc -storepasswd)
echo "reachy" | vncpasswd -f > /root/.vnc/passwd 2>/dev/null || \
    echo "Warning: vncpasswd not found, VNC will run without password"
chmod 600 /root/.vnc/passwd 2>/dev/null
if [ -f /root/.vnc/passwd ]; then
    echo "✅ VNC password configured"
else
    echo "⚠️  VNC password not set - continuing without password"
fi
echo ""

# -----------------------------------------------------------------------------
# Patch Dashboard JavaScript for WSS support (HTTPS compatibility)
# -----------------------------------------------------------------------------
if [ -f /patch-websocket.sh ]; then
    /patch-websocket.sh
fi
echo ""

# -----------------------------------------------------------------------------
# NVIDIA GPU Configuration
# -----------------------------------------------------------------------------
if command -v nvidia-smi &> /dev/null; then
    echo "🎮 NVIDIA GPU detected:"
    nvidia-smi --query-gpu=name,memory.total --format=csv,noheader
    export __GLX_VENDOR_LIBRARY_NAME=nvidia
    export VGL_DISPLAY=egl
else
    echo "⚠️  No NVIDIA GPU detected - simulation may be slow"
    export VGL_DISPLAY=:0
fi
echo ""

# -----------------------------------------------------------------------------
# VirtualGL Configuration
# -----------------------------------------------------------------------------
if [ -f /etc/opt/VirtualGL/vgl_xauth_key ]; then
    echo "🔧 Configuring VirtualGL..."
    vglserver_config -config +s +f -t
fi

# -----------------------------------------------------------------------------
# Create log directories
# -----------------------------------------------------------------------------
mkdir -p /var/log/supervisor /var/log/caddy

# -----------------------------------------------------------------------------
# API Key Configuration
# -----------------------------------------------------------------------------
echo "🔑 API Key Status:"

if [ -n "${NVIDIA_API_KEY}" ]; then
    echo "   ✅ NVIDIA_API_KEY configured (for NAT Nemotron models)"
else
    echo "   ❌ NVIDIA_API_KEY not set (NAT will not work)"
    echo "      Set via: -e NVIDIA_API_KEY=nvapi-..."
fi

if [ -n "${ELEVENLABS_API_KEY}" ]; then
    echo "   ✅ ELEVENLABS_API_KEY configured (for STT/TTS)"
else
    echo "   ❌ ELEVENLABS_API_KEY not set (voice will not work)"
    echo "      Set via: -e ELEVENLABS_API_KEY=sk_..."
fi
echo ""

# -----------------------------------------------------------------------------
# Get Public IP for WebRTC
# -----------------------------------------------------------------------------
PUBLIC_IP=$(curl -s --connect-timeout 3 icanhazip.com 2>/dev/null || echo "")
INTERNAL_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")

if [ -n "${PUBLIC_IP}" ]; then
    HOST_IP="${PUBLIC_IP}"
    echo "🌐 Public IP: ${PUBLIC_IP}"
else
    HOST_IP="${INTERNAL_IP}"
    echo "🏠 Internal IP: ${INTERNAL_IP} (no public IP detected)"
fi

# Export for WebRTC libraries to advertise correct external IP
export EXTERNAL_IP="${HOST_IP}"
export RTC_EXTERNAL_IP="${HOST_IP}"

# Write .env file for Pipecat bot
cat > /app/bot/.env << EOF
NVIDIA_API_KEY=${NVIDIA_API_KEY}
ELEVENLABS_API_KEY=${ELEVENLABS_API_KEY}
RTC_EXTERNAL_IP=${HOST_IP}
RTC_PORT_RANGE_MIN=${RTC_PORT_RANGE_MIN}
RTC_PORT_RANGE_MAX=${RTC_PORT_RANGE_MAX}
STUN_SERVERS=${STUN_SERVERS}
TURN_SERVER=${TURN_SERVER}
TURN_USERNAME=${TURN_USERNAME}
TURN_PASSWORD=${TURN_PASSWORD}
EOF

# Write .env file for NAT
cat > /app/nat/.env << EOF
NVIDIA_API_KEY=${NVIDIA_API_KEY}
EOF

echo ""
echo "=============================================="
echo "🚀 Services Starting (ALL via HTTPS)"
echo "=============================================="
echo ""
echo "📺 noVNC (3D Simulation):    https://${HOST_IP}:6090/vnc.html"
echo "🗣️  Pipecat Bot (WebRTC):    https://${HOST_IP}:7860"
echo "📊 Dashboard:                https://${HOST_IP}:8443"
echo "🧠 NAT API:                  https://${HOST_IP}:8002/docs"
echo "📓 Jupyter Lab:              https://${HOST_IP}:8889"
echo ""
echo "⚠️  Accept self-signed certificate warning in browser for each service"
echo ""
echo "=============================================="
echo "🌐 WebRTC Configuration for Remote Access"
echo "=============================================="
echo ""
echo "External IP advertised: ${HOST_IP}"
echo "STUN servers: ${STUN_SERVERS}"
if [ -n "${TURN_SERVER}" ]; then
    echo "TURN server: ${TURN_SERVER} (relay enabled)"
else
    echo "TURN server: Not configured (may fail behind strict firewalls)"
fi
echo ""
echo "TCP Ports (must be open - ALL HTTPS via Caddy):"
echo "   • 6090  - noVNC (3D simulation)"
echo "   • 7860  - Pipecat WebRTC signaling"
echo "   • 8002  - NAT API"
echo "   • 8443  - Dashboard"
echo "   • 8889  - Jupyter Lab"
echo ""
echo "UDP Ports (must be open for voice/video):"
echo "   • ${RTC_PORT_RANGE_MIN}-${RTC_PORT_RANGE_MAX} - WebRTC RTP/RTCP media"
echo ""
echo "⚠️  Remote Access Checklist:"
echo "   1. Firewall allows UDP ${RTC_PORT_RANGE_MIN}-${RTC_PORT_RANGE_MAX}"
echo "   2. Cloud security group allows inbound UDP range"
echo "   3. If behind NAT: public IP detected correctly (${HOST_IP})"
echo "   4. If corporate network: configure TURN server"
echo ""
echo "💡 Tips:"
echo "   - Wait ~40 seconds for all services to fully load"
echo "   - Accept self-signed certificate warning in browser"
echo "   - Grant microphone/camera permissions when prompted"
echo "   - If audio fails: check UDP ports are truly open"
echo ""
echo "=============================================="

# -----------------------------------------------------------------------------
# Start Supervisor (manages all services)
# -----------------------------------------------------------------------------
exec supervisord -n -c /etc/supervisor/conf.d/supervisord.conf

