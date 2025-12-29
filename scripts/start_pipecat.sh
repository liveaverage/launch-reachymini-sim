#!/bin/bash
# =============================================================================
# Reachy Mini Simulation + Pipecat Bot Launcher
# Purpose: Pull and run the Reachy Mini simulation with Pipecat WebRTC bot
# =============================================================================

# Configuration
# Image: Override with REACHY_IMAGE env var or use default from GHCR
IMAGE_NAME="${REACHY_IMAGE:-ghcr.io/liveaverage/reachy-mini-pipecat:latest}"
CONTAINER_NAME="${CONTAINER_NAME:-reachy_pipecat}"

# Default scene (empty = just robot, minimal = table + objects)
REACHY_SCENE="${REACHY_SCENE:-empty}"

# Display resolution
RESOLUTION="${RESOLUTION:-1920x1080}"

# API keys (required)
NVIDIA_API_KEY="${NVIDIA_API_KEY:-}"
ELEVENLABS_API_KEY="${ELEVENLABS_API_KEY:-}"

# WebRTC port range
RTC_PORT_RANGE_MIN="${RTC_PORT_RANGE_MIN:-10000}"
RTC_PORT_RANGE_MAX="${RTC_PORT_RANGE_MAX:-20000}"

# STUN/TURN servers (for remote access through NAT)
STUN_SERVERS="${STUN_SERVERS:-stun:stun.l.google.com:19302,stun:stun1.l.google.com:19302}"
TURN_SERVER="${TURN_SERVER:-}"
TURN_USERNAME="${TURN_USERNAME:-}"
TURN_PASSWORD="${TURN_PASSWORD:-}"

echo "=============================================="
echo "🤖 Reachy Mini + Pipecat Bot Launcher"
echo "=============================================="
echo ""
echo "📦 Image: ${IMAGE_NAME}"
echo "🎬 Scene: ${REACHY_SCENE}"
echo "📐 Resolution: ${RESOLUTION}"
echo ""

# -----------------------------------------------------------------------------
# Check required API keys
# -----------------------------------------------------------------------------
MISSING_KEYS=0
if [ -z "${NVIDIA_API_KEY}" ]; then
    echo "❌ NVIDIA_API_KEY not set"
    echo "   Get one at: https://build.nvidia.com/"
    MISSING_KEYS=1
fi

if [ -z "${ELEVENLABS_API_KEY}" ]; then
    echo "❌ ELEVENLABS_API_KEY not set"
    echo "   Get one at: https://elevenlabs.io/"
    MISSING_KEYS=1
fi

if [ $MISSING_KEYS -eq 1 ]; then
    echo ""
    echo "⚠️  Please set required API keys:"
    echo "   export NVIDIA_API_KEY=nvapi-..."
    echo "   export ELEVENLABS_API_KEY=sk_..."
    echo ""
    exit 1
fi

echo "🔑 API keys configured"
echo ""

# -----------------------------------------------------------------------------
# Stop existing container if running
# -----------------------------------------------------------------------------
if [ "$(docker ps -aq -f name=${CONTAINER_NAME})" ]; then
    echo "🛑 Stopping existing container..."
    docker rm -f ${CONTAINER_NAME} > /dev/null 2>&1
fi

# -----------------------------------------------------------------------------
# Pull latest image
# -----------------------------------------------------------------------------
echo "📥 Pulling latest image..."
docker pull ${IMAGE_NAME}

# -----------------------------------------------------------------------------
# Build docker run command
# Uses --network=host for WebRTC compatibility (avoids NAT traversal issues)
# =============================================================================
DOCKER_CMD="docker run -d \
    --name ${CONTAINER_NAME} \
    --restart unless-stopped \
    --gpus all \
    --shm-size=2gb \
    --network=host \
    -e NVIDIA_DRIVER_CAPABILITIES=all \
    -e NVIDIA_VISIBLE_DEVICES=all \
    -e REACHY_SCENE=${REACHY_SCENE} \
    -e RESOLUTION=${RESOLUTION} \
    -e NVIDIA_API_KEY=${NVIDIA_API_KEY} \
    -e ELEVENLABS_API_KEY=${ELEVENLABS_API_KEY} \
    -e RTC_PORT_RANGE_MIN=${RTC_PORT_RANGE_MIN} \
    -e RTC_PORT_RANGE_MAX=${RTC_PORT_RANGE_MAX} \
    -e STUN_SERVERS=${STUN_SERVERS} \
    -e TURN_SERVER=${TURN_SERVER} \
    -e TURN_USERNAME=${TURN_USERNAME} \
    -e TURN_PASSWORD=${TURN_PASSWORD} \
    ${IMAGE_NAME}"

# -----------------------------------------------------------------------------
# Run the container
# -----------------------------------------------------------------------------
echo ""
echo "🚀 Starting container..."
eval ${DOCKER_CMD}

# -----------------------------------------------------------------------------
# Wait for services to initialize
# -----------------------------------------------------------------------------
echo ""
echo "⏳ Waiting for services to start..."
sleep 5

# Check if container is running
if [ "$(docker ps -q -f name=${CONTAINER_NAME})" ]; then
    # Get public IP for remote access
    PUBLIC_IP=$(curl -s --connect-timeout 3 icanhazip.com 2>/dev/null || echo "")
    HOST_IP=${PUBLIC_IP:-$(hostname -I | awk '{print $1}')}
    
    echo ""
    echo "=============================================="
    echo "✅ Reachy Mini + Pipecat Bot Running!"
    echo "=============================================="
    echo ""
    echo "🖥️  3D Simulation (noVNC):    http://${HOST_IP}:6080/vnc.html"
    echo "🗣️  Pipecat Bot (WebRTC):     https://${HOST_IP}:7860  ← HTTPS required!"
    echo "🧠 NAT API (Swagger):         http://${HOST_IP}:8001/docs"
    echo "📊 Dashboard:                 http://${HOST_IP}:8000"
    echo "📓 Jupyter Lab:               http://${HOST_IP}:8888"
    echo ""
    echo "=============================================="
    echo "🌐 Required Ports (ensure firewall allows):"
    echo "=============================================="
    echo ""
    echo "TCP:"
    echo "   • 6080  - noVNC web interface"
    echo "   • 7860  - Pipecat WebRTC signaling (HTTPS)"
    echo "   • 8000  - Reachy Dashboard"
    echo "   • 8001  - NAT API"
    echo "   • 8888  - Jupyter Lab"
    echo ""
    echo "UDP (for voice/video):"
    echo "   • ${RTC_PORT_RANGE_MIN}-${RTC_PORT_RANGE_MAX} - WebRTC RTP/RTCP media"
    echo ""
    echo "💡 Tips:"
    echo "   - Wait ~40 seconds for all services to fully load"
    echo "   - Accept the self-signed certificate warning in browser"
    echo "   - Allow microphone/camera access when prompted"
    echo "   - View logs: docker logs -f ${CONTAINER_NAME}"
    echo "   - Debug: docker exec ${CONTAINER_NAME} tail -f /var/log/supervisor/*.log"
    echo "   - Stop: docker stop ${CONTAINER_NAME}"
    echo ""
    echo "=============================================="
    echo "🔧 Remote Access Troubleshooting"
    echo "=============================================="
    echo ""
    echo "If remote clients can't connect (signaling works but no audio/video):"
    echo ""
    echo "1. Check UDP ports are open on cloud firewall/security group:"
    echo "   - AWS: Edit Security Group, add UDP 10000-20000 inbound"
    echo "   - GCP: VPC firewall rule, allow UDP 10000-20000"
    echo "   - Azure: NSG rule, allow UDP 10000-20000"
    echo ""
    echo "2. For corporate networks (strict firewalls), add a TURN server:"
    echo "   export TURN_SERVER=turn:your-turn-server:3478"
    echo "   export TURN_USERNAME=user"
    echo "   export TURN_PASSWORD=password"
    echo ""
    echo "   Free TURN options:"
    echo "   - Metered.ca (free tier available)"
    echo "   - Twilio (pay-as-you-go)"
    echo "   - Self-host coturn"
    echo ""
    echo "⚠️  Using --network=host: all ports exposed directly on host"
    echo ""
    echo "=============================================="
else
    echo ""
    echo "❌ Container failed to start!"
    echo "   Check logs: docker logs ${CONTAINER_NAME}"
    exit 1
fi

