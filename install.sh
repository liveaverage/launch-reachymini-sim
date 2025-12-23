#!/bin/bash
# =============================================================================
# Reachy Mini Simulation - One-Click Installer
# Purpose: Clone repo, setup Docker/NVIDIA, launch simulation
# Usage: bash <(curl -sL https://raw.githubusercontent.com/liveaverage/brev-launch-reachymini-sim/main/install.sh)
# =============================================================================
set -e

REPO_URL="https://github.com/liveaverage/brev-launch-reachymini-sim.git"
CLONE_DIR="/tmp/reachy_mini_automation"

echo "=============================================="
echo "🤖 Reachy Mini Simulation Installer"
echo "=============================================="
echo ""

# -----------------------------------------------------------------------------
# Clone or update repository
# -----------------------------------------------------------------------------
echo "📦 Cloning Reachy Mini Automation Repo..."
echo "📁 Target directory: ${CLONE_DIR}"

if [ -d "${CLONE_DIR}" ]; then
    echo ">>> Directory exists. Pulling latest changes..."
    cd "${CLONE_DIR}"
    git pull
else
    git clone "${REPO_URL}" "${CLONE_DIR}"
    cd "${CLONE_DIR}"
fi

# -----------------------------------------------------------------------------
# Enter scripts directory
# -----------------------------------------------------------------------------
if [ -d "scripts" ]; then
    cd scripts
else
    echo "❌ Error: 'scripts' directory not found in repository."
    exit 1
fi

# -----------------------------------------------------------------------------
# Make scripts executable
# -----------------------------------------------------------------------------
chmod +x setup_env.sh start_reachy.sh

# -----------------------------------------------------------------------------
# Run host setup (Docker + NVIDIA Container Toolkit)
# -----------------------------------------------------------------------------
echo ""
echo "🛠️  Running Host Setup..."
sudo ./setup_env.sh

# -----------------------------------------------------------------------------
# Launch simulation
# -----------------------------------------------------------------------------
echo ""
echo "🚀 Launching Reachy Mini Simulation..."

# Check if user is already in docker group
if groups $USER | grep &>/dev/null "\bdocker\b"; then
    ./start_reachy.sh
else
    # Force execution with 'docker' group permissions immediately
    echo "🔄 Applying docker permissions..."
    sg docker -c "./start_reachy.sh"
fi
