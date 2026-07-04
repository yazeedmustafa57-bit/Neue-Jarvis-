"""
Reminder database module.

Uses its own SQLite file: database/reminders.db
"""

import sqlite3
import logging
from pathlib import Path
from typing import Optional
from jarvis.config.settings import Settings

logger = logging.getLogger(__name__)


class ReminderDB:
    """Manages reminders in a dedicated SQLite database."""

    def __init__(self, db_path: Optional[Path] = None) -> None:
        self.db_path = db_path or Settings.BASE_DIR / "database" / "reminders.db"
        self._connection: Optional[sqlite3.Connection] = None

    # ------------------------------------------------------------------
    # Connection
    # ------------------------------------------------------------------
    @property
    def connection(self) -> sqlite3.Connection:
        if self._connection is None:
            self.db_path.parent.mkdir(parents=True, exist_ok=True)
            self._connection = sqlite3.connect(str(self.db_path))
            self._connection.row_factory = sqlite3.Row
            self._connection.execute("PRAGMA journal_mode=WAL;")
        return self._connection

    def close(self) -> None:
        if self._connection is not None:
            self._connection.close()
            self._connection = None
            logger.info("Reminder database closed.")

    # ------------------------------------------------------------------
    # Schema
    # ------------------------------------------------------------------
    def initialize(self) -> None:
        """Create the reminders table."""
        logger.info("Initialising reminder database …")
        self.connection.executescript("""
            CREATE TABLE IF NOT EXISTS reminders (
                id          INTEGER PRIMARY KEY AUTOINCREMENT,
                title       TEXT    NOT NULL,
                description TEXT    DEFAULT '',
                due_date    TEXT    DEFAULT '',
                is_done     INTEGER DEFAULT 0,
                created_at  TEXT    DEFAULT (datetime('now'))
            );
        """)
        self.connection.commit()
        logger.info("Reminder database ready.")

    # ------------------------------------------------------------------
    # CRUD
    # ------------------------------------------------------------------
    def add_reminder(self, title: str, description: str = "",
                     due_date: str = "") -> int:
        """
        Add a new reminder.

        Parameters
        ----------
        title : str       – required
        description : str – optional (default '')
        due_date : str    – optional date string, e.g. '2026-07-10' (default '')

        Returns
        -------
        int – the new row id
        """
        cur = self.connection.execute(
            "INSERT INTO reminders (title, description, due_date) VALUES (?, ?, ?)",
            (title, description, due_date),
        )
        self.connection.commit()
        logger.info("Reminder %d created: %s", cur.lastrowid, title)
        return cur.lastrowid

    def list_reminders(self, include_done: bool = False) -> list[dict]:
        """
        Return all reminders, newest first.

        Parameters
        ----------
        include_done : bool – if False (default) only pending reminders are returned.

        Returns
        -------
        list[dict]
        """
        if include_done:
            rows = self.connection.execute(
                "SELECT * FROM reminders ORDER BY is_done ASC, created_at DESC"
            ).fetchall()
        else:
            rows = self.connection.execute(
                "SELECT * FROM reminders WHERE is_done = 0 ORDER BY created_at DESC"
            ).fetchall()
        return [dict(r) for r in rows]

    def get_reminder(self, reminder_id: int) -> Optional[dict]:
        row = self.connection.execute(
            "SELECT * FROM reminders WHERE id = ?", (reminder_id,)
        ).fetchone()
        return dict(row) if row else None

    def delete_reminder(self, reminder_id: int) -> bool:
        cur = self.connection.execute(
            "DELETE FROM reminders WHERE id = ?", (reminder_id,)
        )
        self.connection.commit()
        return cur.rowcount > 0

    def mark_done(self, reminder_id: int) -> bool:
        cur = self.connection.execute(
            "UPDATE reminders SET is_done = 1 WHERE id = ?",
            (reminder_id,),
        )
        self.connection.commit()
        return cur.rowcount > 0
