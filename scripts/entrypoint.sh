#!/bin/bash
# =============================================================================
# Reachy Mini Simulation Container Entrypoint
# Purpose: Initialize environment and start supervisor
# =============================================================================
set -e

echo "=============================================="
echo "🤖 Reachy Mini Simulation Container"
echo "=============================================="

# -----------------------------------------------------------------------------
# Environment Setup
# -----------------------------------------------------------------------------
export DISPLAY=${DISPLAY:-:1}
export RESOLUTION=${RESOLUTION:-1920x1080}
export REACHY_SCENE=${REACHY_SCENE:-empty}
export NOVNC_PORT=${NOVNC_PORT:-6080}
export DASHBOARD_PORT=${DASHBOARD_PORT:-8000}
export JUPYTER_PORT=${JUPYTER_PORT:-8888}

echo "📺 Display: ${DISPLAY}"
echo "📐 Resolution: ${RESOLUTION}"
echo "🎬 Scene: ${REACHY_SCENE}"
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
# VirtualGL Configuration for EGL (headless GPU rendering)
# -----------------------------------------------------------------------------
if [ -f /etc/opt/VirtualGL/vgl_xauth_key ]; then
    echo "🔧 Configuring VirtualGL..."
    vglserver_config -config +s +f -t
fi

# -----------------------------------------------------------------------------
# Create log directory
# -----------------------------------------------------------------------------
mkdir -p /var/log/supervisor

# -----------------------------------------------------------------------------
# OpenAI API Key (for conversation app)
# -----------------------------------------------------------------------------
if [ -n "${OPENAI_API_KEY}" ]; then
    echo "🔑 OpenAI API key configured"
else
    echo "ℹ️  OpenAI API key not set (conversation app will not work)"
    echo "   Set via: -e OPENAI_API_KEY=sk-..."
fi
echo ""

# -----------------------------------------------------------------------------
# Print Access Information
# -----------------------------------------------------------------------------
HOST_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")

echo "=============================================="
echo "🚀 Services Starting..."
echo "=============================================="
echo ""
echo "📺 noVNC (3D Simulation): http://${HOST_IP}:${NOVNC_PORT}/vnc.html"
echo "📊 Dashboard:             http://${HOST_IP}:${DASHBOARD_PORT}"
echo "📓 Jupyter Lab:           http://${HOST_IP}:${JUPYTER_PORT}"
echo ""
echo "💡 Tips:"
echo "   - Wait ~15 seconds for MuJoCo simulation to fully load"
echo "   - Use Full Color mode in noVNC settings for best quality"
echo "   - Resize browser to match ${RESOLUTION} for best experience"
echo ""
echo "=============================================="

# -----------------------------------------------------------------------------
# Start Supervisor (manages all services)
# Using pip-installed supervisor (Python 3.12 compatible)
# -----------------------------------------------------------------------------
exec supervisord -n -c /etc/supervisor/conf.d/supervisord.conf

