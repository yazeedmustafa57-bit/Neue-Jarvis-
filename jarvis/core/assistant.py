import logging
from typing import Optional, Callable
from jarvis.database import DatabaseManager
from jarvis.database.reminders import ReminderDB
from jarvis.automation import AutomationEngine
from jarvis.config.settings import Settings
from jarvis.speech import VoiceController
from jarvis.core.ai import ask_ai

logger = logging.getLogger(__name__)


class Assistant:
    """Core JARVIS assistant – orchestrates all subsystems."""

    def __init__(self) -> None:
        self.db = DatabaseManager()
        self.reminders = ReminderDB()
        self.automation = AutomationEngine()
        self.voice = VoiceController()
        self._initialized = False

    # ------------------------------------------------------------------
    # Lifecycle
    # ------------------------------------------------------------------
    def initialize(self) -> None:
        """Bootstrap the assistant (database schema, config dirs, …)."""
        if self._initialized:
            return
        Settings.ensure_dirs()
        self.db.initialize()
        self.reminders.initialize()
        self._initialized = True
        logger.info("JARVIS core initialised.")

    def shutdown(self) -> None:
        """Gracefully shut down all subsystems."""
        self.voice.stop_listening()
        self.db.close()
        self.reminders.close()
        self.automation.shutdown()
        logger.info("JARVIS core shut down.")

    # ------------------------------------------------------------------
    # AI
    # ------------------------------------------------------------------
    def ask_ai(self, prompt: str) -> str:
        self._require_initialized()
        return ask_ai(prompt)

    # ------------------------------------------------------------------
    # Voice control
    # ------------------------------------------------------------------
    def start_voice_control(self, on_shutdown: Optional[Callable] = None) -> None:
        if on_shutdown:
            self.voice.set_on_shutdown(on_shutdown)
        self.voice.start_listening()

    def stop_voice_control(self) -> None:
        self.voice.stop_listening()

    def speak(self, text: str) -> None:
        self.voice.speak(text)

    @property
    def is_voice_active(self) -> bool:
        return self.voice.is_listening

    # ------------------------------------------------------------------
    # Tasks
    # ------------------------------------------------------------------
    def create_task(self, title: str, description: str = "") -> int:
        self._require_initialized()
        return self.db.add_task(title, description)

    def list_tasks(self) -> list[dict]:
        self._require_initialized()
        return self.db.get_all_tasks()

    def complete_task(self, task_id: int) -> bool:
        self._require_initialized()
        return self.db.update_task_status(task_id, "completed")

    # ------------------------------------------------------------------
    # Reminders
    # ------------------------------------------------------------------
    def add_reminder(self, title: str, description: str = "",
                     due_date: str = "") -> int:
        self._require_initialized()
        return self.reminders.add_reminder(title, description, due_date)

    def list_reminders(self, include_done: bool = False) -> list[dict]:
        self._require_initialized()
        return self.reminders.list_reminders(include_done)

    def delete_reminder(self, reminder_id: int) -> bool:
        self._require_initialized()
        return self.reminders.delete_reminder(reminder_id)

    def mark_reminder_done(self, reminder_id: int) -> bool:
        self._require_initialized()
        return self.reminders.mark_done(reminder_id)

    # ------------------------------------------------------------------
    # Automation
    # ------------------------------------------------------------------
    def execute_command(self, command: str) -> str:
        self._require_initialized()
        return self.automation.run(command)

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------
    def _require_initialized(self) -> None:
        if not self._initialized:
            raise RuntimeError("Assistant not initialised – call .initialize() first")
