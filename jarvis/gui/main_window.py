import logging
import math
from typing import Optional

from PyQt6.QtCore import Qt, QTimer
from PyQt6.QtGui import QColor, QPainter, QPen, QTextCursor
from PyQt6.QtWidgets import (
    QAbstractItemView,
    QHBoxLayout,
    QLabel,
    QListWidget,
    QListWidgetItem,
    QMainWindow,
    QMessageBox,
    QPushButton,
    QSizePolicy,
    QTabWidget,
    QTextEdit,
    QVBoxLayout,
    QWidget,
)

from jarvis.core import Assistant
from jarvis.config.settings import Settings
# Try OpenGL-accelerated brain; fall back to 2D CPU version
try:
    from jarvis.gui.gl_brain_widget import GLBrainWidget
    _HAS_OPENGL = True
except Exception:
    _HAS_OPENGL = False

from jarvis.gui.brain_widget import BrainWidget

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Neon panel base
# ---------------------------------------------------------------------------
class NeonPanel(QWidget):
    """A semi‑transparent panel with a pulsing orange‑red neon border."""

    def __init__(self, title: str, parent: QWidget = None) -> None:
        super().__init__(parent)
        self._title = title
        self._pulse = 0.0
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground)
        self.setStyleSheet("background: transparent;")

        self.inner = QWidget(self)
        self.inner.setStyleSheet("""
            QWidget#neonInner {
                background: rgba(8, 2, 12, 200);
                border: none;
            }
            QLabel {
                color: #ff8c1a;
                font-family: 'Courier New';
                font-size: 13px;
                font-weight: bold;
                background: transparent;
                padding: 2px;
            }
            QTextEdit {
                background: rgba(0, 0, 0, 160);
                color: #ffaa33;
                font-family: 'Courier New';
                font-size: 12px;
                border: 1px solid rgba(255, 120, 20, 60);
                border-radius: 4px;
                padding: 6px;
            }
            QTextEdit:focus {
                border: 1px solid rgba(255, 180, 60, 180);
            }
            QPushButton {
                background: rgba(255, 120, 20, 30);
                color: #ff8c1a;
                font-family: 'Courier New';
                font-size: 12px;
                font-weight: bold;
                border: 1px solid rgba(255, 120, 20, 120);
                border-radius: 4px;
                padding: 6px 10px;
                min-width: 60px;
            }
            QPushButton:hover {
                background: rgba(255, 120, 20, 80);
                border: 1px solid #ffaa33;
                color: #ffcc66;
            }
            QPushButton:pressed {
                background: rgba(255, 80, 10, 100);
            }
            QListWidget {
                background: rgba(0, 0, 0, 160);
                color: #ffaa33;
                font-family: 'Courier New';
                font-size: 12px;
                border: 1px solid rgba(255, 120, 20, 60);
                border-radius: 4px;
                outline: none;
            }
            QListWidget::item:selected {
                background: rgba(255, 120, 20, 60);
                color: #ffdd88;
            }
            QListWidget::item:hover {
                background: rgba(255, 120, 20, 30);
            }
            QScrollBar:vertical {
                background: rgba(0, 0, 0, 80);
                width: 8px;
                border: none;
            }
            QScrollBar::handle:vertical {
                background: rgba(255, 120, 20, 80);
                border-radius: 4px;
                min-height: 20px;
            }
            QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical {
                height: 0px;
            }
            /* Style for the tab widget inside the panel */
            QTabWidget::pane {
                background: transparent;
                border: none;
            }
            QTabBar::tab {
                background: rgba(255, 120, 20, 25);
                color: #ff8c1a;
                font-family: 'Courier New';
                font-size: 11px;
                font-weight: bold;
                padding: 6px 14px;
                border: 1px solid rgba(255, 120, 20, 60);
                border-bottom: none;
                border-top-left-radius: 4px;
                border-top-right-radius: 4px;
                margin-right: 2px;
            }
            QTabBar::tab:selected {
                background: rgba(255, 120, 20, 60);
                color: #ffdd88;
            }
            QTabBar::tab:hover {
                background: rgba(255, 120, 20, 45);
            }
        """)
        self.inner.setObjectName("neonInner")

        inner_layout = QVBoxLayout(self)
        inner_layout.setContentsMargins(3, 3, 3, 3)

        title_bar = QLabel(f"  ▸ {title}")
        title_bar.setStyleSheet(
            "color: #ff8c1a; font-size: 14px; font-weight: bold;"
            "background: rgba(255, 120, 20, 20); padding: 4px 8px;"
            "border-bottom: 1px solid rgba(255, 120, 20, 80);"
        )
        inner_layout.addWidget(title_bar)

        self.content_layout = QVBoxLayout()
        self.content_layout.setContentsMargins(8, 8, 8, 8)
        inner_layout.addLayout(self.content_layout)

    def paintEvent(self, event) -> None:  # noqa: N802
        super().paintEvent(event)
        self._pulse += 0.03
        alpha = int(60 + 40 * (0.5 + 0.5 * math.sin(self._pulse)))
        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)
        pen = QPen(QColor(255, 120, 20, alpha), 2)
        painter.setPen(pen)
        painter.drawRoundedRect(1, 1, self.width() - 2, self.height() - 2, 8, 8)
        pen2 = QPen(QColor(255, 180, 60, alpha // 2), 1)
        painter.setPen(pen2)
        painter.drawRoundedRect(4, 4, self.width() - 8, self.height() - 8, 6, 6)

    def resizeEvent(self, event) -> None:  # noqa: N802
        super().resizeEvent(event)
        self.inner.setGeometry(0, 0, self.width(), self.height())


# ---------------------------------------------------------------------------
# Helper: build a button row
# ---------------------------------------------------------------------------
def _btn(text: str, slot) -> QPushButton:
    b = QPushButton(text)
    b.clicked.connect(slot)
    return b


# ---------------------------------------------------------------------------
# Main Window
# ---------------------------------------------------------------------------
class MainWindow(QMainWindow):
    """Futuristic JARVIS main window with animated brain background."""

    def __init__(self, assistant: Optional[Assistant] = None) -> None:
        super().__init__()
        self.assistant = assistant or Assistant()

        self.setWindowTitle(Settings.WINDOW_TITLE)
        self.resize(Settings.WINDOW_WIDTH, Settings.WINDOW_HEIGHT)
        self.setMinimumSize(1000, 650)
        self.setStyleSheet("QMainWindow { background: #08020c; }")

        # Background brain
        if _HAS_OPENGL:
            try:
                self.brain = GLBrainWidget()
            except Exception:
                logger.warning("OpenGL Widget failed – using 2D BrainWidget")
                self.brain = BrainWidget()
        else:
            logger.warning("OpenGL not available – using 2D BrainWidget")
            self.brain = BrainWidget()
        self.brain.setSizePolicy(QSizePolicy.Policy.Expanding,
                                 QSizePolicy.Policy.Expanding)

        # Overlay
        central = QWidget()
        self.setCentralWidget(central)
        overlay = QWidget(central)
        overlay.setObjectName("overlay")
        overlay.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground)
        overlay.setStyleSheet("background: transparent;")

        ol = QVBoxLayout(overlay)
        ol.setContentsMargins(20, 20, 20, 20)

        # ── Top row ────────────────────────────────────────────────────
        top = QHBoxLayout()
        self._build_status_panel()
        top.addWidget(self._status_panel, 1)
        top.addStretch(2)
        self._build_voice_panel()
        top.addWidget(self._voice_panel, 1)
        ol.addLayout(top)

        # ── Middle row: Tasks / Reminders tabbed + AI ──────────────────
        mid = QHBoxLayout()
        self._build_left_tab_panel()
        mid.addWidget(self._left_tab_panel, 2)
        self._build_ai_panel()
        mid.addWidget(self._ai_panel, 3)
        ol.addLayout(mid, stretch=1)

        # ── Bottom row: Console ────────────────────────────────────────
        self._build_console_panel()
        ol.addWidget(self._console_panel)

        # Stack
        main_layout = QVBoxLayout(central)
        main_layout.setContentsMargins(0, 0, 0, 0)
        main_layout.addWidget(self.brain)
        overlay.raise_()
        overlay.setGeometry(central.rect())

        self._refresh_tasks()
        self._refresh_reminders()

    def resizeEvent(self, event) -> None:  # noqa: N802
        """Keep overlay panels sized to the central widget."""
        super().resizeEvent(event)
        central = self.centralWidget()
        if central:
            overlay = central.findChild(QWidget, "overlay")
            if overlay:
                overlay.setGeometry(central.rect())

    # ==================================================================
    # Status panel
    # ==================================================================
    def _build_status_panel(self) -> None:
        self._status_panel = NeonPanel("SYSTEM STATUS")
        layout = QVBoxLayout()
        layout.setSpacing(4)

        info = [
            ("CORE:", "ONLINE"),
            ("DATABASE:", "CONNECTED"),
            ("REMINDERS:", "READY"),
            ("AI:", "READY"),
            ("VOICE:", "OFF"),
            ("UPTIME:", "0s"),
        ]
        self._status_labels = []
        for label, value in info:
            row = QHBoxLayout()
            lbl = QLabel(label)
            lbl.setStyleSheet("color: #ff6611; font-size: 12px;")
            val = QLabel(value)
            val.setStyleSheet("color: #ffcc66; font-size: 12px;")
            val.setAlignment(Qt.AlignmentFlag.AlignRight |
                             Qt.AlignmentFlag.AlignVCenter)
            row.addWidget(lbl)
            row.addStretch()
            row.addWidget(val)
            layout.addLayout(row)
            self._status_labels.append(val)

        layout.addStretch()
        self._status_panel.content_layout.addLayout(layout)

        self._uptime_timer = QTimer(self)
        self._uptime_timer.timeout.connect(self._update_uptime)
        self._uptime_timer.start(1000)
        self._uptime_seconds = 0

    def _update_uptime(self) -> None:
        self._uptime_seconds += 1
        s = self._uptime_seconds
        text = f"{s}s" if s < 60 else f"{s // 60}m {s % 60}s"
        self._status_labels[5].setText(text)

    def _update_voice_status(self, active: bool) -> None:
        lbl = self._status_labels[4]
        if active:
            lbl.setText("ACTIVE")
            lbl.setStyleSheet("color: #00ff88; font-size: 12px;")
        else:
            lbl.setText("OFF")
            lbl.setStyleSheet("color: #ff6611; font-size: 12px;")

    # ==================================================================
    # Voice panel
    # ==================================================================
    def _build_voice_panel(self) -> None:
        self._voice_panel = NeonPanel("SPRACHSTEUERUNG")
        layout = QVBoxLayout()
        layout.setSpacing(6)

        self._voice_label = QLabel("🎤 Mikrofon")
        self._voice_label.setStyleSheet("color: #ffcc66; font-size: 16px;")
        self._voice_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(self._voice_label)

        self._mic_btn = QPushButton("🎤  AKTIVIEREN")
        self._style_mic_btn(False)
        self._mic_btn.clicked.connect(self._toggle_voice)
        layout.addWidget(self._mic_btn)

        hint = QLabel("Befehle: YouTube · Google ·\nChrome · Discord · Beenden")
        hint.setStyleSheet("color: #ff8833; font-size: 10px;")
        hint.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(hint)

        self._voice_hint = QLabel("")
        self._voice_hint.setStyleSheet("color: #ffcc66; font-size: 12px;")
        self._voice_hint.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self._voice_hint.setWordWrap(True)
        layout.addWidget(self._voice_hint)

        layout.addStretch()
        self._voice_panel.content_layout.addLayout(layout)

    def _style_mic_btn(self, active: bool) -> None:
        if active:
            self._mic_btn.setStyleSheet("""
                QPushButton {
                    background: rgba(255, 40, 20, 60);
                    color: #ff6644; font-size: 14px; font-weight: bold;
                    padding: 12px;
                    border: 2px solid rgba(255, 60, 20, 180);
                    border-radius: 8px;
                }
                QPushButton:hover {
                    background: rgba(255, 40, 20, 100);
                    border: 2px solid #ff4444; color: #ff8888;
                }
            """)
        else:
            self._mic_btn.setStyleSheet("""
                QPushButton {
                    background: rgba(255, 120, 20, 40);
                    color: #ff8c1a; font-size: 14px; font-weight: bold;
                    padding: 12px;
                    border: 2px solid rgba(255, 120, 20, 150);
                    border-radius: 8px;
                }
                QPushButton:hover {
                    background: rgba(255, 120, 20, 80);
                    border: 2px solid #ffaa33; color: #ffcc66;
                }
            """)

    def _toggle_voice(self) -> None:
        if self.assistant.is_voice_active:
            self.assistant.stop_voice_control()
            self._mic_btn.setText("🎤  AKTIVIEREN")
            self._style_mic_btn(False)
            self._voice_label.setText("🎤 Mikrofon")
            self._voice_label.setStyleSheet("color: #ffcc66; font-size: 16px;")
            self._update_voice_status(False)
        else:
            self.assistant.start_voice_control(on_shutdown=self._on_voice_shutdown)
            self._mic_btn.setText("🔴  DEAKTIVIEREN")
            self._style_mic_btn(True)
            self._voice_label.setText("🎤 Höre zu …")
            self._voice_label.setStyleSheet("color: #00ff88; font-size: 16px;")
            self._update_voice_status(True)

    def _on_voice_shutdown(self) -> None:
        self._mic_btn.setText("🎤  AKTIVIEREN")
        self._style_mic_btn(False)
        self._voice_label.setText("🎤 Mikrofon")
        self._voice_label.setStyleSheet("color: #ffcc66; font-size: 16px;")
        self._update_voice_status(False)
        QTimer.singleShot(2000, self.close)

    # ==================================================================
    # Left tab panel – Tasks + Reminders
    # ==================================================================
    def _build_left_tab_panel(self) -> None:
        self._left_tab_panel = NeonPanel("AUFGABEN & ERINNERUNGEN")
        tabs = QTabWidget()
        tabs.addTab(self._make_tasks_tab(), "TASKS")
        tabs.addTab(self._make_reminders_tab(), "REMINDERS")
        self._left_tab_panel.content_layout.addWidget(tabs)

    # ── Tasks tab content ──────────────────────────────────────────────
    def _make_tasks_tab(self) -> QWidget:
        tab = QWidget()
        tab.setStyleSheet("background: transparent;")
        lo = QVBoxLayout(tab)
        lo.setContentsMargins(0, 6, 0, 0)
        lo.setSpacing(6)

        self.task_input = QTextEdit()
        self.task_input.setPlaceholderText("Enter new task …")
        self.task_input.setMaximumHeight(50)
        lo.addWidget(self.task_input)

        br = QHBoxLayout()
        br.addWidget(_btn("➕ ADD", self._on_add_task))
        br.addWidget(_btn("✔ DONE", self._on_complete_task))
        br.addWidget(_btn("✖ DEL", self._on_delete_task))
        br.addWidget(_btn("⟳ RELOAD", self._refresh_tasks))
        lo.addLayout(br)

        self.task_list = QListWidget()
        self.task_list.setSelectionMode(
            QAbstractItemView.SelectionMode.SingleSelection)
        lo.addWidget(self.task_list)
        return tab

    # ── Reminders tab content ──────────────────────────────────────────
    def _make_reminders_tab(self) -> QWidget:
        tab = QWidget()
        tab.setStyleSheet("background: transparent;")
        lo = QVBoxLayout(tab)
        lo.setContentsMargins(0, 6, 0, 0)
        lo.setSpacing(6)

        # Input row: title + optional date
        input_row = QHBoxLayout()
        self.reminder_input = QTextEdit()
        self.reminder_input.setPlaceholderText("Erinnerung …")
        self.reminder_input.setMaximumHeight(50)
        input_row.addWidget(self.reminder_input)

        self.reminder_date = QTextEdit()
        self.reminder_date.setPlaceholderText("Datum (2026-07-10)")
        self.reminder_date.setMaximumHeight(50)
        self.reminder_date.setMaximumWidth(130)
        input_row.addWidget(self.reminder_date)
        lo.addLayout(input_row)

        br = QHBoxLayout()
        br.addWidget(_btn("➕ HINZUFÜGEN", self._on_add_reminder))
        br.addWidget(_btn("✔ ERLEDIGT", self._on_done_reminder))
        br.addWidget(_btn("✖ LÖSCHEN", self._on_delete_reminder))
        br.addWidget(_btn("⟳ AKTUALISIEREN", self._refresh_reminders))
        lo.addLayout(br)

        self.reminder_list = QListWidget()
        self.reminder_list.setSelectionMode(
            QAbstractItemView.SelectionMode.SingleSelection)
        lo.addWidget(self.reminder_list)
        return tab

    # ── Task slots ─────────────────────────────────────────────────────
    def _on_add_task(self) -> None:
        text = self.task_input.toPlainText().strip()
        if not text:
            return
        try:
            self.assistant.create_task(text)
            self.task_input.clear()
            self._refresh_tasks()
        except Exception as exc:
            QMessageBox.critical(self, "Error", str(exc))

    def _refresh_tasks(self) -> None:
        self.task_list.clear()
        try:
            for t in self.assistant.list_tasks():
                item = QListWidgetItem(f"[{t['status'].upper()}] {t['title']}")
                item.setData(Qt.ItemDataRole.UserRole, t["id"])
                self.task_list.addItem(item)
        except Exception:
            logger.exception("refresh tasks")

    def _on_complete_task(self) -> None:
        item = self.task_list.currentItem()
        if item is None:
            return
        self.assistant.complete_task(item.data(Qt.ItemDataRole.UserRole))
        self._refresh_tasks()

    def _on_delete_task(self) -> None:
        item = self.task_list.currentItem()
        if item is None:
            return
        self.assistant.db.delete_task(item.data(Qt.ItemDataRole.UserRole))
        self._refresh_tasks()

    # ── Reminder slots ─────────────────────────────────────────────────
    def _on_add_reminder(self) -> None:
        title = self.reminder_input.toPlainText().strip()
        if not title:
            return
        due = self.reminder_date.toPlainText().strip()
        try:
            self.assistant.add_reminder(title, due_date=due)
            self.reminder_input.clear()
            self.reminder_date.clear()
            self._refresh_reminders()
        except Exception as exc:
            QMessageBox.critical(self, "Error", str(exc))

    def _refresh_reminders(self) -> None:
        self.reminder_list.clear()
        try:
            for r in self.assistant.list_reminders(include_done=False):
                due = f" [{r['due_date']}]" if r.get("due_date") else ""
                done = "✓" if r["is_done"] else "○"
                item = QListWidgetItem(f"{done} {r['title']}{due}")
                item.setData(Qt.ItemDataRole.UserRole, r["id"])
                self.reminder_list.addItem(item)
        except Exception:
            logger.exception("refresh reminders")

    def _on_done_reminder(self) -> None:
        item = self.reminder_list.currentItem()
        if item is None:
            return
        self.assistant.mark_reminder_done(item.data(Qt.ItemDataRole.UserRole))
        self._refresh_reminders()

    def _on_delete_reminder(self) -> None:
        item = self.reminder_list.currentItem()
        if item is None:
            return
        self.assistant.delete_reminder(item.data(Qt.ItemDataRole.UserRole))
        self._refresh_reminders()

    # ==================================================================
    # AI Chat panel
    # ==================================================================
    def _build_ai_panel(self) -> None:
        self._ai_panel = NeonPanel("JARVIS KI")
        lo = QVBoxLayout()
        lo.setSpacing(6)

        self.ai_output = QTextEdit()
        self.ai_output.setReadOnly(True)
        self.ai_output.setPlaceholderText("JARVIS KI Antworten …")
        lo.addWidget(self.ai_output)

        inp = QHBoxLayout()
        self.ai_input = QTextEdit()
        self.ai_input.setPlaceholderText("Frage JARVIS etwas …")
        self.ai_input.setMaximumHeight(50)
        inp.addWidget(self.ai_input)
        inp.addWidget(_btn("⚡ FRAGEN", self._on_ask_ai))
        inp.addWidget(_btn("🗑 LEEREN", self.ai_output.clear))
        lo.addLayout(inp)

        self._ai_panel.content_layout.addLayout(lo)

    def _on_ask_ai(self) -> None:
        prompt = self.ai_input.toPlainText().strip()
        if not prompt:
            return
        self.ai_input.clear()
        self.ai_output.append(f"👤 >>> {prompt}")
        self.ai_output.append("⏳ JARVIS denkt nach …")

        from PyQt6.QtWidgets import QApplication
        QApplication.processEvents()

        try:
            answer = self.assistant.ask_ai(prompt)
            cursor = self.ai_output.textCursor()
            cursor.movePosition(QTextCursor.MoveOperation.End)
            cursor.movePosition(QTextCursor.MoveOperation.StartOfLine,
                                QTextCursor.MoveMode.KeepAnchor)
            cursor.removeSelectedText()
            cursor.deleteChar()
            self.ai_output.append(f"🤖 JARVIS >>> {answer}")
        except RuntimeError as exc:
            cursor = self.ai_output.textCursor()
            cursor.movePosition(QTextCursor.MoveOperation.End)
            cursor.movePosition(QTextCursor.MoveOperation.StartOfLine,
                                QTextCursor.MoveMode.KeepAnchor)
            cursor.removeSelectedText()
            cursor.deleteChar()
            self.ai_output.append(f"⚠️  {exc}")
            self.ai_output.append(
                "→ Füge deinen OpenAI API-Key in jarvis/.env ein:\n"
                "  OPENAI_API_KEY=sk-...")

        self.ai_output.append("")
        cursor = self.ai_output.textCursor()
        cursor.movePosition(QTextCursor.MoveOperation.End)
        self.ai_output.setTextCursor(cursor)

    # ==================================================================
    # Console panel
    # ==================================================================
    def _build_console_panel(self) -> None:
        self._console_panel = NeonPanel("CONSOLE")
        lo = QVBoxLayout()
        lo.setSpacing(6)

        self.console_output = QTextEdit()
        self.console_output.setReadOnly(True)
        self.console_output.setPlaceholderText("Output …")
        self.console_output.setMaximumHeight(120)
        lo.addWidget(self.console_output)

        inp = QHBoxLayout()
        self.cmd_input = QTextEdit()
        self.cmd_input.setPlaceholderText(">_  Enter command …")
        self.cmd_input.setMaximumHeight(50)
        inp.addWidget(self.cmd_input)
        inp.addWidget(_btn("▶ RUN", self._on_run_command))
        lo.addLayout(inp)

        self._console_panel.content_layout.addLayout(lo)

    def _on_run_command(self) -> None:
        cmd = self.cmd_input.toPlainText().strip()
        if not cmd:
            return
        self.cmd_input.clear()
        self.console_output.append(f">>> {cmd}")
        output = self.assistant.execute_command(cmd)
        self.console_output.append(output)
        self.console_output.append("")
        cursor = self.console_output.textCursor()
        cursor.movePosition(QTextCursor.MoveOperation.End)
        self.console_output.setTextCursor(cursor)

    # ==================================================================
    # Lifecycle
    # ==================================================================
    def closeEvent(self, event) -> None:  # noqa: N802
        self.assistant.shutdown()
        super().closeEvent(event)
