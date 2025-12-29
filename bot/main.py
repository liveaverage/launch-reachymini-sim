#
# Copyright (c) 2024–2025, Daily
#
# SPDX-License-Identifier: BSD 2-Clause License
#
# Adapted for containerized Reachy Mini simulation with NeMo Agent Toolkit

import os

from dotenv import load_dotenv
from loguru import logger

from pipecat.audio.vad.silero import SileroVADAnalyzer
from pipecat.audio.vad.vad_analyzer import VADParams
from pipecat.frames.frames import LLMRunFrame
from pipecat.pipeline.pipeline import Pipeline
from pipecat.pipeline.runner import PipelineRunner
from pipecat.pipeline.task import PipelineParams, PipelineTask
from pipecat.processors.aggregators.llm_context import LLMContext
from pipecat.processors.aggregators.llm_response_universal import LLMContextAggregatorPair
from pipecat.runner.types import RunnerArguments
from pipecat.runner.utils import (
    create_transport,
    get_transport_client_id,
    maybe_capture_participant_camera,
)
from pipecat.services.elevenlabs.stt import ElevenLabsSTTService
from pipecat.services.elevenlabs.tts import ElevenLabsHttpTTSService
from pipecat.transports.base_transport import BaseTransport, TransportParams
from pipecat.transports.daily.transport import DailyParams
import aiohttp

from nat_vision_llm import NATVisionLLMService
from services.reachy_service import ReachyService
from services.processor import ReachyWobblerProcessor


load_dotenv(override=True)

# NAT server URL - in container, runs locally
NAT_BASE_URL = os.getenv("NAT_BASE_URL", "http://localhost:8001/v1")

# WebRTC configuration for remote access
RTC_EXTERNAL_IP = os.getenv("RTC_EXTERNAL_IP", "")
RTC_PORT_RANGE_MIN = int(os.getenv("RTC_PORT_RANGE_MIN", "10000"))
RTC_PORT_RANGE_MAX = int(os.getenv("RTC_PORT_RANGE_MAX", "20000"))

# STUN/TURN servers for NAT traversal
# STUN: Free, discovers public IP/port (works for most cases)
# TURN: Paid relay, required when direct connection blocked (corporate firewalls)
STUN_SERVERS = os.getenv("STUN_SERVERS", "stun:stun.l.google.com:19302,stun:stun1.l.google.com:19302").split(",")
TURN_SERVER = os.getenv("TURN_SERVER", "")  # Format: turn:host:port
TURN_USERNAME = os.getenv("TURN_USERNAME", "")
TURN_PASSWORD = os.getenv("TURN_PASSWORD", "")


def build_ice_servers():
    """Build ICE server configuration for WebRTC NAT traversal."""
    ice_servers = []
    
    # Add STUN servers (free, public)
    for stun in STUN_SERVERS:
        if stun.strip():
            ice_servers.append({"urls": stun.strip()})
    
    # Add TURN server if configured (requires credentials)
    if TURN_SERVER and TURN_USERNAME and TURN_PASSWORD:
        ice_servers.append({
            "urls": TURN_SERVER,
            "username": TURN_USERNAME,
            "credential": TURN_PASSWORD,
        })
        logger.info(f"TURN server configured: {TURN_SERVER}")
    
    logger.info(f"ICE servers configured: {len(ice_servers)} servers")
    return ice_servers


def get_webrtc_params():
    """Build WebRTC transport parameters with ICE configuration."""
    params = TransportParams(
        audio_in_enabled=True,
        audio_out_enabled=True,
        video_in_enabled=True,
        vad_analyzer=SileroVADAnalyzer(params=VADParams(stop_secs=0.2)),
    )
    
    # Log external IP configuration
    if RTC_EXTERNAL_IP:
        logger.info(f"WebRTC external IP: {RTC_EXTERNAL_IP}")
    else:
        logger.warning("RTC_EXTERNAL_IP not set - remote clients may have connection issues")
    
    logger.info(f"WebRTC port range: {RTC_PORT_RANGE_MIN}-{RTC_PORT_RANGE_MAX}")
    
    return params


# Transport parameters for different connection types
transport_params = {
    "daily": lambda: DailyParams(
        audio_in_enabled=True,
        audio_out_enabled=True,
        video_in_enabled=True,
        vad_analyzer=SileroVADAnalyzer(params=VADParams(stop_secs=0.2)),
    ),
    "webrtc": get_webrtc_params,
}


async def run_bot(transport: BaseTransport, runner_args: RunnerArguments):
    logger.info("Starting Pipecat bot with NAT backend")

    # Get Reachy service singleton and ensure fresh state
    from services.reachy_service import ReachyService
    reachy_service = ReachyService.get_instance()
    
    # Reset wobbler state for new session
    if reachy_service.wobbler:
        reachy_service.wobbler.reset()
        logger.info("Reset Reachy wobbler for new session")

    async with aiohttp.ClientSession() as session:

        stt = ElevenLabsSTTService(
            api_key=os.getenv("ELEVENLABS_API_KEY"),
            aiohttp_session=session,
        )

        tts = ElevenLabsHttpTTSService(
            api_key=os.getenv("ELEVENLABS_API_KEY", ""),
            voice_id="JBFqnCBsd6RMkjVDRZzb",
            aiohttp_session=session,
        )

        llm = NATVisionLLMService(
            api_key=os.getenv("NVIDIA_API_KEY"),
            base_url=NAT_BASE_URL,
        )

        messages = [
            {
                "role": "system",
                "content": """You are Reachy Mini, a friendly desktop robot assistant powered by NVIDIA Nemotron.
You can see through your camera and hear through the microphone. 
Your responses are spoken aloud, so keep them conversational and avoid special characters.
You can describe what you see, answer questions, and have natural conversations.
Be helpful, curious, and express your robot personality!""",
            },
        ]

        context = LLMContext(messages)
        context_aggregator = LLMContextAggregatorPair(context)

        pipeline = Pipeline(
            [
                transport.input(),  # Transport user input
                stt,  # STT
                context_aggregator.user(),  # User responses
                llm,  # LLM (via NAT router)
                tts,  # TTS
                ReachyWobblerProcessor(),  # Robot head movement
                transport.output(),  # Transport bot output
                context_aggregator.assistant(),  # Assistant spoken responses
            ]
        )

        task = PipelineTask(
            pipeline,
            params=PipelineParams(
                enable_metrics=True,
                enable_usage_metrics=True,
            ),
            idle_timeout_secs=runner_args.pipeline_idle_timeout_secs,
        )

        @transport.event_handler("on_client_connected")
        async def on_client_connected(transport, client):
            logger.info("Client connected")

            await maybe_capture_participant_camera(transport, client)

            client_id = get_transport_client_id(transport, client)
            
            # Set the user_id for automatic image fetching
            llm.set_user_id(client_id)

            # Greet the user
            messages.append(
                {
                    "role": "system",
                    "content": "A user just connected. Greet them warmly and let them know you can see and hear them!",
                }
            )
            await task.queue_frames([LLMRunFrame()])

        @transport.event_handler("on_client_disconnected")
        async def on_client_disconnected(transport, client):
            logger.info("Client disconnected")
            
            # Reset wobbler state for next session
            if reachy_service.wobbler:
                reachy_service.wobbler.reset()
                logger.info("Reset Reachy wobbler on disconnect")
            
            # Set back to listening pose
            reachy_service.set_listening_pose()
            
            await task.cancel()

        runner = PipelineRunner(handle_sigint=runner_args.handle_sigint)

        await runner.run(task)


async def bot(runner_args: RunnerArguments):
    """Main bot entry point compatible with Pipecat Cloud."""
    transport = await create_transport(runner_args, transport_params)
    await run_bot(transport, runner_args)


if __name__ == "__main__":
    from pipecat.runner.run import main

    main()

