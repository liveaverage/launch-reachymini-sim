#!/usr/bin/env python3
"""
Standalone WebRTC server with proper ICE configuration for remote access.
Bypasses pipecat runner to configure STUN servers correctly.
"""

import os
import asyncio
from pathlib import Path

from dotenv import load_dotenv
from loguru import logger
from fastapi import FastAPI
from fastapi.responses import HTMLResponse, FileResponse
from fastapi.staticfiles import StaticFiles
from aiortc.rtcconfiguration import RTCIceServer

from pipecat.transports.smallwebrtc.request_handler import SmallWebRTCRequestHandler
from pipecat.transports.smallwebrtc.transport import SmallWebRTCTransport
from pipecat.transports.base_transport import TransportParams
from pipecat.audio.vad.silero import SileroVADAnalyzer
from pipecat.audio.vad.vad_analyzer import VADParams

# Import our bot logic
from main import run_bot

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
    
    logger.info(f"✅ ICE servers configured: {len(ice_servers)} servers")
    for server in ice_servers:
        logger.info(f"  - {server.urls}")
    
    return ice_servers


async def bot_runner(transport: SmallWebRTCTransport):
    """Wrapper to run bot with minimal runner args."""
    from pipecat.runner.types import SmallWebRTCRunnerArguments
    
    runner_args = SmallWebRTCRunnerArguments(
        webrtc_connection=transport._connection,
        handle_sigint=False,
        pipeline_idle_timeout_secs=0,  # No timeout
    )
    
    await run_bot(transport, runner_args)


async def start_server():
    """Start FastAPI server with WebRTC handler."""
    from fastapi import Request
    
    app = FastAPI()
    
    # Build ICE configuration
    ice_servers = build_ice_servers()
    
    # Create request handler with ICE servers
    request_handler = SmallWebRTCRequestHandler(
        ice_servers=ice_servers,
    )
    
    # Create transport params
    params = TransportParams(
        audio_in_enabled=True,
        audio_out_enabled=True,
        video_in_enabled=True,
        vad_analyzer=SileroVADAnalyzer(params=VADParams(stop_secs=0.2)),
    )
    
    # Manually create routes (no mount_fastapi_routes in 0.0.98)
    @app.post("/start")
    async def start(request: Request):
        """Start a new WebRTC session."""
        return await request_handler.handle_web_request(request, bot_runner, params)
    
    @app.post("/sessions/{pc_id}/api/offer")
    async def offer(pc_id: str, request: Request):
        """Handle WebRTC offer."""
        return await request_handler.handle_web_request(request, bot_runner, params)
    
    @app.post("/sessions/{pc_id}/api/patch")
    async def patch(pc_id: str, request: Request):
        """Handle ICE candidate patch."""
        return await request_handler.handle_patch_request(request)
    
    # Serve static client
    client_dir = Path(__file__).parent / "client"
    if client_dir.exists():
        app.mount("/client", StaticFiles(directory=str(client_dir), html=True), name="client")
        
        @app.get("/")
        async def root():
            return HTMLResponse("""
                <html><head><title>Reachy Pipecat Bot</title></head>
                <body style="font-family: sans-serif; margin: 40px;">
                    <h1>🤖 Reachy Mini + Pipecat WebRTC</h1>
                    <p><a href="/client">Open WebRTC Client</a></p>
                </body></html>
            """)
    
    # Start server
    import uvicorn
    config = uvicorn.Config(
        app=app,
        host="0.0.0.0",
        port=7880,
        log_level="info",
    )
    server = uvicorn.Server(config)
    
    logger.info("🚀 Starting WebRTC server on http://0.0.0.0:7880")
    logger.info("   Caddy will proxy this to HTTPS on port 7860")
    await server.serve()


if __name__ == "__main__":
    asyncio.run(start_server())

