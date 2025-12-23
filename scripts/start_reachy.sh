#!/bin/bash
# =============================================================================
# Reachy Mini Simulation Launcher
# Purpose: Pull and run the Reachy Mini simulation container
# =============================================================================

# Configuration
IMAGE_NAME="${REACHY_IMAGE:-ghcr.io/liveaverage/reachy-mini-sim:latest}"
CONTAINER_NAME="reachy_mini_sim"

# Default scene (empty = just robot, minimal = table + objects)
REACHY_SCENE="${REACHY_SCENE:-empty}"

# Display resolution
RESOLUTION="${RESOLUTION:-1920x1080}"

# OpenAI API key (optional, for conversation app)
OPENAI_API_KEY="${OPENAI_API_KEY:-}"

echo "=============================================="
echo "🤖 Reachy Mini Simulation Launcher"
echo "=============================================="
echo ""
echo "📦 Image: ${IMAGE_NAME}"
echo "🎬 Scene: ${REACHY_SCENE}"
echo "📐 Resolution: ${RESOLUTION}"
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
# -----------------------------------------------------------------------------
DOCKER_CMD="docker run -d \
    --name ${CONTAINER_NAME} \
    --restart unless-stopped \
    --gpus all \
    --shm-size=2gb \
    -p 6080:6080 \
    -p 8000:8000 \
    -p 8888:8888 \
    -e NVIDIA_DRIVER_CAPABILITIES=all \
    -e NVIDIA_VISIBLE_DEVICES=all \
    -e REACHY_SCENE=${REACHY_SCENE} \
    -e RESOLUTION=${RESOLUTION}"

# Add OpenAI API key if provided
if [ -n "${OPENAI_API_KEY}" ]; then
    DOCKER_CMD="${DOCKER_CMD} -e OPENAI_API_KEY=${OPENAI_API_KEY}"
    echo "🔑 OpenAI API key configured"
fi

# Add image name
DOCKER_CMD="${DOCKER_CMD} ${IMAGE_NAME}"

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
    HOST_IP=$(hostname -I | awk '{print $1}')
    
    echo ""
    echo "=============================================="
    echo "✅ Reachy Mini Simulation Running!"
    echo "=============================================="
    echo ""
    echo "📺 3D Simulation (noVNC): http://${HOST_IP}:6080/vnc.html"
    echo "📊 Dashboard:             http://${HOST_IP}:8000"
    echo "📓 Jupyter Lab:           http://${HOST_IP}:8888"
    echo ""
    echo "💡 Tips:"
    echo "   - Wait ~15 seconds for MuJoCo simulation to fully load"
    echo "   - View logs: docker logs -f ${CONTAINER_NAME}"
    echo "   - Stop: docker stop ${CONTAINER_NAME}"
    echo ""
    echo "=============================================="
else
    echo ""
    echo "❌ Container failed to start!"
    echo "   Check logs: docker logs ${CONTAINER_NAME}"
    exit 1
fi
