#!/usr/bin/env python3
"""
JARVIS – Just A Rather Very Intelligent System
Futuristic personal automation assistant.

Usage:
    python3 -m jarvis.main          # from project root
    python3 jarvis/main.py          # from project root
    cd jarvis && python3 main.py    # from within jarvis/
"""

import sys
import signal
import logging
from pathlib import Path

# ── Ensure the project root is on sys.path ──────────────────────────
# This allows running as either `python3 jarvis/main.py` or
# `python3 -m jarvis.main` from the project root directory.
_PROJECT_ROOT = Path(__file__).resolve().parent.parent
if str(_PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(_PROJECT_ROOT))

from PyQt6.QtWidgets import QApplication

from jarvis.config.settings import Settings
from jarvis.core import Assistant
from jarvis.gui import MainWindow

logger = logging.getLogger(__name__)


def configure_logging() -> None:
    """Set up logging to both file and console."""
    Settings.ensure_dirs()
    log_file = Settings.LOG_DIR / "jarvis.log"

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
        handlers=[
            logging.FileHandler(str(log_file), encoding="utf-8"),
            logging.StreamHandler(sys.stdout),
        ],
    )


def main() -> None:
    """JARVIS entry point – initialises everything and starts the GUI."""
    configure_logging()
    logger.info("=" * 50)
    logger.info("JARVIS v%s starting …", Settings.APP_VERSION)
    logger.info("=" * 50)

    # ── Qt application ────────────────────────────────────────────────
    app = QApplication(sys.argv)
    app.setApplicationName(Settings.APP_NAME)
    app.setApplicationVersion(Settings.APP_VERSION)

    # ── Window size (futuristic UI) ───────────────────────────────────
    Settings.WINDOW_WIDTH = 1200
    Settings.WINDOW_HEIGHT = 800

    # ── Graceful shutdown on Ctrl+C / SIGINT ──────────────────────────
    assistant_ref = [None]  # mutable holder for the signal handler

    def handle_signal(signum, frame) -> None:
        """Shut down cleanly on SIGINT/SIGTERM."""
        logger.info("Received signal %d, shutting down …", signum)
        if assistant_ref[0] is not None:
            assistant_ref[0].shutdown()
        app.quit()

    signal.signal(signal.SIGINT, handle_signal)

    # ── Core assistant ────────────────────────────────────────────────
    try:
        assistant = Assistant()
        assistant.initialize()
        assistant_ref[0] = assistant
        logger.info("Core assistant initialised.")
    except Exception as exc:
        logger.exception("Failed to initialise assistant")
        print(f"\n❌  JARVIS initialisation failed: {exc}", file=sys.stderr)
        sys.exit(1)

    # ── Main window ───────────────────────────────────────────────────
    try:
        window = MainWindow(assistant)
        window.show()
        logger.info("GUI window displayed.")
    except Exception as exc:
        logger.exception("Failed to create main window")
        assistant.shutdown()
        print(f"\n❌  GUI creation failed: {exc}", file=sys.stderr)
        sys.exit(1)

    # ── Event loop ────────────────────────────────────────────────────
    try:
        exit_code = app.exec()
        logger.info("JARVIS exited with code %d", exit_code)
        sys.exit(exit_code)
    except KeyboardInterrupt:
        logger.info("Keyboard interrupt received.")
        assistant.shutdown()
        sys.exit(0)
    except Exception as exc:
        logger.exception("Unexpected error in event loop")
        assistant.shutdown()
        sys.exit(1)


if __name__ == "__main__":
    main()
