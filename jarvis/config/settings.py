import os
from pathlib import Path


class Settings:
    """Central configuration for the JARVIS application."""

    APP_NAME = "JARVIS"
    APP_VERSION = "1.0.0"
    BASE_DIR = Path(__file__).resolve().parent.parent
    LOG_DIR = BASE_DIR / "logs"
    DB_PATH = BASE_DIR / "database" / "jarvis.db"

    # GUI defaults
    WINDOW_TITLE = f"{APP_NAME} v{APP_VERSION}"
    WINDOW_WIDTH = 1024
    WINDOW_HEIGHT = 768

    # Automation
    MAX_RETRIES = 3
    COMMAND_TIMEOUT = 30  # seconds

    @classmethod
    def ensure_dirs(cls) -> None:
        """Create required directories if they don't exist."""
        cls.LOG_DIR.mkdir(parents=True, exist_ok=True)
        cls.BASE_DIR.joinpath("database").mkdir(parents=True, exist_ok=True)
