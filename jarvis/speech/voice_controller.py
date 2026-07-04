"""
Voice controller module for JARVIS.

Uses SpeechRecognition for listening and pyttsx3 for offline TTS.
All commands are processed in German.
"""

import logging
import threading
from typing import Callable, Optional

import pyttsx3

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Command definitions (German)
# ---------------------------------------------------------------------------
COMMANDS = {
    "öffne youtube":   "youtube",
    "öffne google":    "google",
    "öffne chrome":    "chrome",
    "öffne discord":   "discord",
    "öffne spotify":   "spotify",
    "öffne notepad":   "notepad",
    "öffne editor":    "notepad",
    "beende jarvis":   "shutdown",
}

# ---------------------------------------------------------------------------
# TTS engine singleton (pyttsx3)
# ---------------------------------------------------------------------------
_tts_lock = threading.Lock()
_tts_engine: Optional[pyttsx3.Engine] = None


def _get_tts_engine() -> pyttsx3.Engine:
    """Lazy-initialised pyttsx3 engine (thread-safe)."""
    global _tts_engine
    if _tts_engine is None:
        with _tts_lock:
            if _tts_engine is None:
                _tts_engine = pyttsx3.init()
                # Set German voice if available
                voices = _tts_engine.getProperty("voices")
                for v in voices:
                    if "german" in v.name.lower() or "de" in v.id.lower():
                        _tts_engine.setProperty("voice", v.id)
                        break
                _tts_engine.setProperty("rate", 175)
                _tts_engine.setProperty("volume", 0.9)
    return _tts_engine


# ---------------------------------------------------------------------------
# Voice controller
# ---------------------------------------------------------------------------
class VoiceController:
    """Handles speech recognition and text-to-speech in German."""

    def __init__(self) -> None:
        self._recognizer = None
        self._mic = None

        self._listening = False
        self._thread: Optional[threading.Thread] = None
        self._on_shutdown: Optional[Callable] = None

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------
    @property
    def is_listening(self) -> bool:
        return self._listening

    def set_on_shutdown(self, callback: Callable) -> None:
        """Register a callback to invoke when 'Beende Jarvis' is spoken."""
        self._on_shutdown = callback

    def start_listening(self) -> None:
        """Start voice recognition in a background thread."""
        if self._listening:
            logger.warning("Voice controller already listening.")
            return
        self._listening = True
        self._thread = threading.Thread(target=self._listen_loop, daemon=True)
        self._thread.start()
        self.speak("Sprachsteuerung aktiviert.")
        logger.info("Voice controller started.")

    def stop_listening(self) -> None:
        """Stop the voice recognition loop."""
        self._listening = False
        logger.info("Voice controller stopped.")

    def speak(self, text: str, lang: str = "de") -> None:
        """Convert text to speech using pyttsx3 (non-blocking)."""
        def _play() -> None:
            try:
                engine = _get_tts_engine()
                engine.say(text)
                engine.runAndWait()
            except Exception as exc:
                logger.debug("TTS playback skipped: %s", exc)

        threading.Thread(target=_play, daemon=True).start()

    # ------------------------------------------------------------------
    # Internal
    # ------------------------------------------------------------------
    def _ensure_recognizer(self):
        if self._recognizer is None:
            import speech_recognition as sr
            self._recognizer = sr.Recognizer()
            self._recognizer.energy_threshold = 300
            self._recognizer.pause_threshold = 0.8
            self._recognizer.dynamic_energy_threshold = True
        if self._mic is None:
            import speech_recognition as sr
            try:
                self._mic = sr.Microphone()
                # Calibrate for ambient noise
                with self._mic as source:
                    self._recognizer.adjust_for_ambient_noise(source, duration=0.5)
                logger.info("Microphone calibrated.")
            except Exception as exc:
                logger.warning("No microphone available: %s", exc)
                self._mic = None

    def _listen_loop(self) -> None:
        """Background loop: listen → recognise → execute."""
        self._ensure_recognizer()

        if self._mic is None:
            logger.error("No microphone – voice control unavailable.")
            self._listening = False
            return

        while self._listening:
            try:
                with self._mic as source:
                    logger.debug("Listening …")
                    audio = self._recognizer.listen(source, timeout=2, phrase_time_limit=5)
                logger.debug("Processing audio …")

                try:
                    text = self._recognizer.recognize_google(audio, language="de-DE")
                except Exception:
                    # Unintelligible – continue listening
                    continue

                text_lower = text.lower().strip()
                logger.info("Erkannt: %s", text_lower)

                # Match against known commands
                matched = self._match_command(text_lower)
                if matched is not None:
                    self._execute_command(matched, text_lower)

            except Exception as exc:
                # Timeout / no speech detected – keep looping
                logger.debug("Listen cycle: %s", exc)

        logger.info("Listen loop ended.")

    def _match_command(self, text: str) -> Optional[str]:
        """Find the best matching command key or return None."""
        for phrase, action in COMMANDS.items():
            if phrase in text:
                return action
        return None

    def _execute_command(self, action: str, raw_text: str) -> None:
        """Perform the action associated with a recognised command."""
        logger.info("Befehl erkannt: %s → %s", raw_text, action)

        if action == "shutdown":
            self.speak("JARVIS wird beendet.")
            self._listening = False
            if self._on_shutdown:
                self._on_shutdown()
            return

        # App-Start via automation.apps
        from jarvis.automation.apps import (
            open_youtube,
            open_google,
            open_chrome,
            open_discord,
            open_spotify,
            open_notepad,
        )

        app_actions = {
            "youtube": (open_youtube, "Öffne YouTube."),
            "google":  (open_google, "Öffne Google."),
            "chrome":  (open_chrome, "Starte Chrome."),
            "discord": (open_discord, "Öffne Discord."),
            "spotify": (open_spotify, "Öffne Spotify."),
            "notepad": (open_notepad, "Öffne Editor."),
        }

        if action in app_actions:
            func, reply = app_actions[action]
            self.speak(reply)
            func()
        else:
            self.speak("Befehl ausgeführt.")
