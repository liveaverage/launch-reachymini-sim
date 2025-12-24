#!/usr/bin/env python3
"""
Wrapper to run conversation app with no_media backend for headless simulation.

The upstream conversation app hardcodes media_backend="default" which tries to
initialize camera. For headless simulation, we override to use "no_media".

Per reachy_mini SDK docs, media_backend options:
  - "no_media": No audio/camera - for motor control demos or simulations
  - "gstreamer": For wireless Reachy Mini
  - "webrtc": For wireless/web-based communication
  - "default": Full audio + camera (requires hardware)
"""
import sys


def patch_reachy_mini_for_no_media():
    """Patch ReachyMini to use no_media backend."""
    import reachy_mini.reachy_mini as rm

    original_init = rm.ReachyMini.__init__

    def patched_init(self, *args, **kwargs):
        # Override media_backend to no_media for headless operation
        kwargs["media_backend"] = "no_media"
        return original_init(self, *args, **kwargs)

    rm.ReachyMini.__init__ = patched_init
    print("✓ Using no_media backend for headless simulation")


def main():
    # Apply patch when --no-camera is specified
    if "--no-camera" in sys.argv:
        patch_reachy_mini_for_no_media()

    # Import and run the conversation app
    from reachy_mini_conversation_app.main import main as app_main

    sys.exit(app_main())


if __name__ == "__main__":
    main()
