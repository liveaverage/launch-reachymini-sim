import base64
import hashlib
from pipecat.processors.frame_processor import FrameProcessor, FrameDirection
from pipecat.frames.frames import (
    AudioRawFrame, 
    Frame,
    BotStartedSpeakingFrame,
    BotStoppedSpeakingFrame,
    UserStartedSpeakingFrame
)
from .reachy_service import ReachyService
from loguru import logger as loguru_logger

class ReachyWobblerProcessor(FrameProcessor):
    def __init__(self):
        super().__init__()
        self.service = ReachyService.get_instance()
        # Attempt connection on initialization
        if not self.service.connected:
            loguru_logger.info("ReachyWobblerProcessor: Connecting to Reachy...")
            self.service.connect()
            if self.service.connected:
                loguru_logger.info("ReachyWobblerProcessor: Connected to Reachy successfully")
            else:
                loguru_logger.warning("ReachyWobblerProcessor: Failed to connect to Reachy")
        else:
            loguru_logger.info("ReachyWobblerProcessor: Reachy already connected")
        
        # Track bot speaking state
        self.bot_is_speaking = False
        # Track seen audio frames to avoid duplicates
        self.seen_audio_hashes = set()
        # Clear hash set periodically to prevent memory growth
        self.frame_count = 0
        self.hash_clear_interval = 1000
        # Track audio chunks fed
        self.chunks_fed = 0
    
    def reset_state(self):
        """Reset processor state (called on disconnect)."""
        self.bot_is_speaking = False
        self.seen_audio_hashes.clear()
        self.frame_count = 0

    async def process_frame(self, frame: Frame, direction: FrameDirection):
        await super().process_frame(frame, direction)
        
        # Track bot speaking state
        if isinstance(frame, BotStartedSpeakingFrame):
            self.bot_is_speaking = True
            self.seen_audio_hashes.clear()  # Clear hashes when new speech starts
            self.chunks_fed = 0
            loguru_logger.info("🗣️ Bot started speaking - wobbler armed")
            
        elif isinstance(frame, BotStoppedSpeakingFrame):
            self.bot_is_speaking = False
            loguru_logger.info(f"🤐 Bot stopped speaking - fed {self.chunks_fed} audio chunks")
            if self.service.connected:
                self.service.set_listening_pose()
            self.seen_audio_hashes.clear()
            
        elif isinstance(frame, UserStartedSpeakingFrame):
            self.bot_is_speaking = False
            if self.service.connected:
                self.service.set_listening_pose()
            self.seen_audio_hashes.clear()
        
        # Only feed audio if bot is actively speaking
        elif isinstance(frame, AudioRawFrame) and direction == FrameDirection.DOWNSTREAM:
            if self.bot_is_speaking and self.service.connected:
                # Create hash of audio data to detect duplicates
                audio_hash = hashlib.md5(frame.audio).hexdigest()
                
                if audio_hash not in self.seen_audio_hashes:
                    # Mark as seen
                    self.seen_audio_hashes.add(audio_hash)
                    
                    # Feed to wobbler
                    b64_audio = base64.b64encode(frame.audio).decode('utf-8')
                    self.service.feed_audio(b64_audio)
                    self.chunks_fed += 1
                    
                    # Log first few chunks
                    if self.chunks_fed <= 3:
                        loguru_logger.debug(f"🎵 Fed audio chunk #{self.chunks_fed} ({len(frame.audio)} bytes)")
                    
                    # Periodically clear hash set to prevent unbounded growth
                    self.frame_count += 1
                    if self.frame_count >= self.hash_clear_interval:
                        # Keep only the most recent hashes
                        if len(self.seen_audio_hashes) > 100:
                            self.seen_audio_hashes = set(list(self.seen_audio_hashes)[-100:])
                        self.frame_count = 0

        await self.push_frame(frame, direction)
