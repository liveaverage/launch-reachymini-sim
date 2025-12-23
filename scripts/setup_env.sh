#!/bin/bash
set -e # Exit on error

echo ">>> 🛠️  Starting Lightweight Host Setup..."

# 1. Install Docker (Official Convenience Script)
if ! command -v docker &> /dev/null; then
    echo ">>> 🐳 Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    rm get-docker.sh
    # Add current user to docker group so you don't need 'sudo' for docker commands
    sudo usermod -aG docker $USER
    echo ">>> ✅ Docker installed."
else
    echo ">>> ⚡ Docker is already installed."
fi

# 2. Install NVIDIA Container Toolkit (The Bridge to your GPU)
if ! dpkg -l | grep -q nvidia-container-toolkit; then
    echo ">>> 🎮 Installing NVIDIA Container Toolkit..."
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
    && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
      sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#' | \
      sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
    
    sudo apt-get update
    sudo apt-get install -y nvidia-container-toolkit
    
    # Configure Docker to use NVIDIA runtime
    sudo nvidia-ctk runtime configure --runtime=docker
    sudo systemctl restart docker
    echo ">>> ✅ NVIDIA Toolkit configured."
else
    echo ">>> ⚡ NVIDIA Toolkit is already installed."
fi

echo "################################################################"
echo ">>> Setup Complete!"
echo ">>> ⚠️  IMPORTANT: Please LOG OUT and LOG BACK IN to apply Docker permissions."
echo "################################################################"