# syntax=docker/dockerfile:1
################################################################################
# Reachy Mini Simulation Container
# - VirtualGL + Xvfb + x11vnc + noVNC for GPU-accelerated remote desktop
# - reachy-mini SDK with MuJoCo simulation
# - Jupyter Lab for interactive development
# - Dashboard and conversation app support
################################################################################

FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04

LABEL org.opencontainers.image.source="https://github.com/liveaverage/brev-launch-reachymini-sim"
LABEL org.opencontainers.image.description="Reachy Mini simulation with noVNC"
LABEL org.opencontainers.image.licenses="Apache-2.0"

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Python and display configuration
ENV PYTHON_VERSION=3.12
ENV DISPLAY=:1
ENV VGL_DISPLAY=egl
ENV RESOLUTION=1024x768

# Application ports
ENV NOVNC_PORT=6080
ENV DASHBOARD_PORT=8000
ENV JUPYTER_PORT=8888
ENV CONVERSATION_PORT=7860

# Reachy Mini configuration (overridable at runtime)
ENV REACHY_SCENE=empty
ENV OPENAI_API_KEY=""

# ============================================================================
# System Dependencies
# ============================================================================
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Core utilities
    ca-certificates \
    curl \
    wget \
    git \
    gnupg2 \
    software-properties-common \
    # Build essentials for Python packages
    build-essential \
    pkg-config \
    # X11 and virtual framebuffer
    xvfb \
    x11-utils \
    x11-xserver-utils \
    xauth \
    dbus-x11 \
    # Window manager (lightweight)
    openbox \
    # VNC server for Xvfb
    x11vnc \
    # Mesa for EGL/OpenGL
    libgl1-mesa-glx \
    libgl1-mesa-dri \
    libegl1-mesa \
    libgles2-mesa \
    libglvnd0 \
    libglvnd-dev \
    # Audio (for conversation app)
    pulseaudio \
    libportaudio2 \
    portaudio19-dev \
    # Network utilities
    net-tools \
    procps \
    && rm -rf /var/lib/apt/lists/*

# ============================================================================
# Python 3.12 via deadsnakes PPA
# Note: distutils was removed in Python 3.12, not needed
# ============================================================================
RUN add-apt-repository ppa:deadsnakes/ppa -y \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        python${PYTHON_VERSION} \
        python${PYTHON_VERSION}-venv \
        python${PYTHON_VERSION}-dev \
    && rm -rf /var/lib/apt/lists/*

# Set Python 3.12 as default
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python${PYTHON_VERSION} 1 \
    && update-alternatives --install /usr/bin/python python /usr/bin/python${PYTHON_VERSION} 1

# Install pip
RUN curl -sS https://bootstrap.pypa.io/get-pip.py | python${PYTHON_VERSION}

# Install supervisor via pip (apt version uses asynchat, removed in Python 3.12)
RUN pip install --no-cache-dir supervisor

# ============================================================================
# VirtualGL (GPU-accelerated OpenGL) - Optional, for enhanced performance
# ============================================================================
ARG VIRTUALGL_VERSION=3.1.1
RUN curl -fsSL -o /tmp/virtualgl.deb \
    "https://github.com/VirtualGL/virtualgl/releases/download/${VIRTUALGL_VERSION}/virtualgl_${VIRTUALGL_VERSION}_amd64.deb" \
    && apt-get update \
    && dpkg -i /tmp/virtualgl.deb || (apt-get install -fy && dpkg -i /tmp/virtualgl.deb) \
    && rm /tmp/virtualgl.deb \
    && rm -rf /var/lib/apt/lists/* \
    || echo "VirtualGL installation failed - continuing without it"

# Add VirtualGL to PATH if installed
ENV PATH="/opt/VirtualGL/bin:${PATH}"

# ============================================================================
# noVNC (web-based VNC client)
# ============================================================================
ARG NOVNC_VERSION=1.4.0
ARG WEBSOCKIFY_VERSION=0.11.0

RUN mkdir -p /opt/noVNC \
    && curl -fsSL "https://github.com/novnc/noVNC/archive/refs/tags/v${NOVNC_VERSION}.tar.gz" \
        | tar -xz -C /opt/noVNC --strip-components=1 \
    && ln -s /opt/noVNC/vnc.html /opt/noVNC/index.html

RUN pip install --no-cache-dir websockify==${WEBSOCKIFY_VERSION}

# ============================================================================
# Caddy (reverse proxy with automatic TLS for conversation app)
# ============================================================================
RUN curl -fsSL "https://caddyserver.com/api/download?os=linux&arch=amd64" -o /usr/local/bin/caddy \
    && chmod +x /usr/local/bin/caddy

# ============================================================================
# Reachy Mini SDK with MuJoCo
# ============================================================================
RUN pip install --no-cache-dir \
    "reachy-mini[mujoco]" \
    jupyterlab \
    ipywidgets \
    matplotlib \
    opencv-python-headless \
    numpy

# ============================================================================
# Reachy Mini Conversation App (Gradio-based voice assistant)
# https://github.com/pollen-robotics/reachy_mini_conversation_app
# ============================================================================
RUN pip install --no-cache-dir \
    "reachy-mini-conversation-app @ git+https://github.com/pollen-robotics/reachy_mini_conversation_app.git"

# ============================================================================
# Configuration Files
# ============================================================================

# Supervisor configuration (create directory for pip-installed supervisor)
RUN mkdir -p /etc/supervisor/conf.d /var/log/supervisor
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Caddy configuration for TLS reverse proxy
COPY config/Caddyfile /etc/caddy/Caddyfile

# Generate self-signed certificate for Caddy
RUN openssl req -x509 -newkey rsa:2048 -nodes \
    -keyout /etc/caddy/key.pem -out /etc/caddy/cert.pem \
    -days 365 -subj '/CN=reachy-mini' \
    && chmod 644 /etc/caddy/cert.pem /etc/caddy/key.pem

# Entrypoint and helper scripts
COPY scripts/entrypoint.sh /entrypoint.sh
COPY scripts/patch-websocket.sh /patch-websocket.sh
COPY scripts/conversation-app-wrapper.py /conversation-app-wrapper.py
RUN chmod +x /entrypoint.sh /patch-websocket.sh /conversation-app-wrapper.py

# Openbox configuration for minimal window manager
RUN mkdir -p /root/.config/openbox
COPY config/openbox-rc.xml /root/.config/openbox/rc.xml

# Jupyter configuration (no token for demo ease)
RUN mkdir -p /root/.jupyter
COPY config/jupyter_config.py /root/.jupyter/jupyter_lab_config.py

# Create workspace for user notebooks/code
RUN mkdir -p /workspace
WORKDIR /workspace

# Clone example notebooks from reachy_mini repo
RUN git clone --depth 1 https://github.com/pollen-robotics/reachy_mini.git /opt/reachy_mini_repo \
    && cp -r /opt/reachy_mini_repo/examples /workspace/examples \
    && rm -rf /opt/reachy_mini_repo

# ============================================================================
# Ports
# ============================================================================
EXPOSE 6080 8000 7860 8888

# ============================================================================
# Entrypoint
# ============================================================================
ENTRYPOINT ["/entrypoint.sh"]

