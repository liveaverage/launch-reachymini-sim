#!/usr/bin/env python3
"""
Monkey-patch pipecat to inject ICE servers before runner starts.
This preserves the full pipecat web client/dashboard.
"""

import os
from dotenv import load_dotenv
from loguru import logger
from aiortc.rtcconfiguration import RTCIceServer

load_dotenv(override=True)

# ICE Server Configuration
STUN_SERVERS = os.getenv("STUN_SERVERS", "stun:stun.l.google.com:19302,stun:stun1.l.google.com:19302").split(",")
TURN_SERVER = os.getenv("TURN_SERVER", "")
TURN_USERNAME = os.getenv("TURN_USERNAME", "")
TURN_PASSWORD = os.getenv("TURN_PASSWORD", "")

def build_ice_servers():
    """Build ICE server list for aiortc."""
    ice_servers = []
    
    # Add STUN servers
    for stun in STUN_SERVERS:
        if stun.strip():
            ice_servers.append(RTCIceServer(urls=stun.strip()))
    
    # Add TURN server if configured
    if TURN_SERVER and TURN_USERNAME and TURN_PASSWORD:
        ice_servers.append(RTCIceServer(
            urls=TURN_SERVER,
            username=TURN_USERNAME,
            credential=TURN_PASSWORD
        ))
        logger.info(f"TURN server configured: {TURN_SERVER}")
    
    logger.info(f"✅ ICE servers configured for remote access: {len(ice_servers)} servers")
    for server in ice_servers:
        logger.info(f"  - {server.urls}")
    
    return ice_servers


# Monkey-patch SmallWebRTCConnection to always use our ICE servers
from pipecat.transports.smallwebrtc.connection import SmallWebRTCConnection

_original_init = SmallWebRTCConnection.__init__

def patched_init(self, ice_servers=None, connection_timeout_secs=60):
    """Patched __init__ that injects our ICE servers."""
    our_ice_servers = build_ice_servers()
    logger.info(f"🔧 Injecting {len(our_ice_servers)} ICE servers into SmallWebRTCConnection")
    _original_init(self, ice_servers=our_ice_servers, connection_timeout_secs=connection_timeout_secs)

SmallWebRTCConnection.__init__ = patched_init

logger.info("✅ Monkey-patch applied! Runner will use configured ICE servers.")

# Now import and run the normal pipecat runner
if __name__ == "__main__":
    from pipecat.runner.run import main
    logger.info("🚀 Starting pipecat runner with ICE server injection...")
    main()


