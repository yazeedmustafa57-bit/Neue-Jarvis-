import sqlite3
import logging
from pathlib import Path
from typing import Optional, Any
from jarvis.config.settings import Settings

logger = logging.getLogger(__name__)


class DatabaseManager:
    """Manages SQLite database connections and schema."""

    def __init__(self, db_path: Optional[Path] = None) -> None:
        self.db_path = db_path or Settings.DB_PATH
        self._connection: Optional[sqlite3.Connection] = None

    # ------------------------------------------------------------------
    # Connection management
    # ------------------------------------------------------------------
    @property
    def connection(self) -> sqlite3.Connection:
        if self._connection is None:
            self._connection = sqlite3.connect(str(self.db_path))
            self._connection.row_factory = sqlite3.Row
            self._connection.execute("PRAGMA journal_mode=WAL;")
            self._connection.execute("PRAGMA foreign_keys=ON;")
        return self._connection

    def close(self) -> None:
        if self._connection is not None:
            self._connection.close()
            self._connection = None
            logger.info("Database connection closed.")

    # ------------------------------------------------------------------
    # Schema
    # ------------------------------------------------------------------
    def initialize(self) -> None:
        """Create all required tables."""
        logger.info("Initializing database schema …")
        self.connection.executescript("""
            CREATE TABLE IF NOT EXISTS tasks (
                id          INTEGER PRIMARY KEY AUTOINCREMENT,
                title       TEXT    NOT NULL,
                description TEXT    DEFAULT '',
                status      TEXT    DEFAULT 'pending',
                created_at  TEXT    DEFAULT (datetime('now')),
                updated_at  TEXT    DEFAULT (datetime('now'))
            );

            CREATE TABLE IF NOT EXISTS logs (
                id          INTEGER PRIMARY KEY AUTOINCREMENT,
                level       TEXT    NOT NULL DEFAULT 'INFO',
                message     TEXT    NOT NULL,
                timestamp   TEXT    DEFAULT (datetime('now'))
            );

            CREATE TABLE IF NOT EXISTS settings (
                key         TEXT PRIMARY KEY,
                value       TEXT NOT NULL
            );
        """)
        self.connection.commit()
        logger.info("Database schema ready.")

    # ------------------------------------------------------------------
    # CRUD helpers – tasks
    # ------------------------------------------------------------------
    def add_task(self, title: str, description: str = "") -> int:
        cur = self.connection.execute(
            "INSERT INTO tasks (title, description) VALUES (?, ?)",
            (title, description),
        )
        self.connection.commit()
        logger.info("Task %d created: %s", cur.lastrowid, title)
        return cur.lastrowid

    def get_task(self, task_id: int) -> Optional[dict]:
        row = self.connection.execute(
            "SELECT * FROM tasks WHERE id = ?", (task_id,)
        ).fetchone()
        return dict(row) if row else None

    def get_all_tasks(self) -> list[dict]:
        rows = self.connection.execute(
            "SELECT * FROM tasks ORDER BY created_at DESC"
        ).fetchall()
        return [dict(r) for r in rows]

    def update_task_status(self, task_id: int, status: str) -> bool:
        cur = self.connection.execute(
            "UPDATE tasks SET status = ?, updated_at = datetime('now') WHERE id = ?",
            (status, task_id),
        )
        self.connection.commit()
        return cur.rowcount > 0

    def delete_task(self, task_id: int) -> bool:
        cur = self.connection.execute(
            "DELETE FROM tasks WHERE id = ?", (task_id,)
        )
        self.connection.commit()
        return cur.rowcount > 0
