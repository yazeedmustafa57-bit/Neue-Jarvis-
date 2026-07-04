"""
Application launchers for JARVIS.

Windows-kompatible Funktionen zum Öffnen von Anwendungen und Webseiten.
"""

import logging
import subprocess
import webbrowser
import shutil
from typing import Optional

logger = logging.getLogger(__name__)


def _find_executable(name: str) -> Optional[str]:
    """Search PATH for an executable, return full path or None."""
    path = shutil.which(name)
    if path:
        logger.debug("Found %s at %s", name, path)
    return path


def _launch(path_or_url: str) -> bool:
    """Try to open a file/URL via the OS default handler."""
    try:
        webbrowser.open(path_or_url)
        return True
    except Exception as exc:
        logger.warning("Failed to open %s: %s", path_or_url, exc)
        return False


def _run_exe(exe: str, *args: str) -> bool:
    """Launch an executable with optional arguments."""
    full = _find_executable(exe)
    if full:
        try:
            subprocess.Popen(
                [full, *args],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            return True
        except Exception as exc:
            logger.warning("Failed to launch %s: %s", exe, exc)
            return False
    return False


# ------------------------------------------------------------------
# Public API
# ------------------------------------------------------------------

def open_youtube() -> str:
    """Öffne YouTube im Standard-Browser."""
    url = "https://www.youtube.com"
    _launch(url)
    logger.info("YouTube geöffnet")
    return "YouTube geöffnet."


def open_google() -> str:
    """Öffne Google im Standard-Browser."""
    url = "https://www.google.com"
    _launch(url)
    logger.info("Google geöffnet")
    return "Google geöffnet."


def open_chrome() -> str:
    """Starte Google Chrome (via PATH oder Fallback-Browser)."""
    launched = (
        _run_exe("google-chrome")
        or _run_exe("google-chrome-stable")
        or _run_exe("chromium-browser")
        or _run_exe("chromium")
        or _run_exe("chrome")          # Windows: chrome
        or _run_exe("msedge")          # Fallback Edge
    )
    if launched:
        logger.info("Chrome gestartet")
        return "Chrome gestartet."
    # Letzter Fallback: Webseite im Standardbrowser
    _launch("https://www.google.com")
    logger.info("Chrome nicht gefunden – Google im Standardbrowser geöffnet")
    return "Chrome nicht gefunden. Google im Standardbrowser geöffnet."


def open_discord() -> str:
    """Öffne Discord (Desktop-App bevorzugt, sonst Web)."""
    # Windows: Discord Desktop
    if _run_exe("discord"):
        logger.info("Discord Desktop gestartet")
        return "Discord geöffnet."
    # Fallback: Web-Version
    _launch("https://discord.com/app")
    logger.info("Discord Web geöffnet")
    return "Discord Web geöffnet."


def open_spotify() -> str:
    """Öffne Spotify (Desktop-App bevorzugt, sonst Web)."""
    # Windows / Linux
    if _run_exe("spotify"):
        logger.info("Spotify Desktop gestartet")
        return "Spotify geöffnet."
    # Fallback: Web-Version
    _launch("https://open.spotify.com")
    logger.info("Spotify Web geöffnet")
    return "Spotify Web geöffnet."


def open_notepad() -> str:
    """Öffne Windows Editor (notepad.exe)."""
    # Windows
    if _run_exe("notepad"):
        logger.info("Notepad geöffnet")
        return "Notepad geöffnet."
    # Linux-Fallback: Texteditor
    for exe in ("gedit", "kate", "mousepad", "nano"):
        if _run_exe(exe):
            logger.info("%s geöffnet", exe)
            return f"{exe} geöffnet."
    logger.warning("Kein Texteditor gefunden")
    return "Kein Texteditor gefunden."
