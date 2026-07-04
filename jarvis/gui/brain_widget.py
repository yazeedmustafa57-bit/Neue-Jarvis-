import math
import random
from typing import List, Tuple

from PyQt6.QtCore import QPointF, QRectF, QTimer, Qt
from PyQt6.QtGui import (
    QBrush,
    QColor,
    QLinearGradient,
    QPainter,
    QPainterPath,
    QPen,
    QRadialGradient,
)
from PyQt6.QtWidgets import QWidget


class Node:
    """A single particle/node in the neural network."""

    def __init__(self, x: float, y: float) -> None:
        self.pos = QPointF(x, y)
        self.vel = QPointF(random.uniform(-0.3, 0.3), random.uniform(-0.3, 0.3))
        self.radius = random.uniform(1.5, 3.5)
        self.pulse_phase = random.uniform(0, 2 * math.pi)

    def update(self, bounds: QRectF, dt: float = 1.0) -> None:
        # Brownian-like movement
        self.vel += QPointF(
            random.uniform(-0.05, 0.05), random.uniform(-0.05, 0.05)
        )
        max_speed = 0.5
        speed = math.hypot(self.vel.x(), self.vel.y())
        if speed > max_speed:
            self.vel *= max_speed / speed

        self.pos += self.vel * dt

        # Wrap around edges with a soft margin
        margin = 40
        w, h = bounds.width(), bounds.height()
        if self.pos.x() < -margin:
            self.pos.setX(w + margin)
        elif self.pos.x() > w + margin:
            self.pos.setX(-margin)
        if self.pos.y() < -margin:
            self.pos.setY(h + margin)
        elif self.pos.y() > h + margin:
            self.pos.setY(-margin)

        self.pulse_phase += 0.03 * dt


class BrainWidget(QWidget):
    """Custom widget that renders an animated neural network in sci-fi style."""

    # Colour palette (orange‑red neon)
    NEON_ORANGE = QColor(255, 120, 20)
    NEON_RED = QColor(255, 40, 20)
    NEON_DIM = QColor(200, 80, 10, 60)
    BG_COLOR = QColor(8, 2, 12)

    LINE_COLORS = [
        QColor(255, 140, 30, 80),
        QColor(255, 80, 20, 60),
        QColor(200, 50, 10, 40),
    ]

    def __init__(self, parent: QWidget = None) -> None:
        super().__init__(parent)
        self.setMinimumSize(800, 500)
        self.nodes: List[Node] = []
        self._generate_nodes(120)

        # 60 FPS timer
        self._timer = QTimer(self)
        self._timer.timeout.connect(self._tick)
        self._timer.start(16)  # ~62.5 FPS

        # Keep track of elapsed time for pulsing etc.
        self._elapsed = 0.0

    def _generate_nodes(self, count: int) -> None:
        w, h = self.width(), self.height()
        margin = 50
        self.nodes = [
            Node(
                random.uniform(margin, max(w - margin, margin + 1)),
                random.uniform(margin, max(h - margin, margin + 1)),
            )
            for _ in range(count)
        ]

    def _tick(self) -> None:
        self._elapsed += 0.016
        bounds = QRectF(0, 0, self.width(), self.height())
        for node in self.nodes:
            node.update(bounds)
        self.update()  # trigger repaint

    # ------------------------------------------------------------------
    # Painting
    # ------------------------------------------------------------------
    def paintEvent(self, event) -> None:  # noqa: N802
        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)

        self._draw_background(painter)
        self._draw_connections(painter)
        self._draw_nodes(painter)
        self._draw_vignette(painter)
        self._draw_overlay_text(painter)

    def _draw_background(self, painter: QPainter) -> None:
        painter.fillRect(self.rect(), self.BG_COLOR)

        # Subtle radial gradient glow in the centre
        centre = QPointF(self.width() / 2, self.height() / 2)
        radius = min(self.width(), self.height()) * 0.45
        grad = QRadialGradient(centre, radius)
        grad.setColorAt(0.0, QColor(255, 80, 20, 30))
        grad.setColorAt(0.5, QColor(180, 40, 10, 12))
        grad.setColorAt(1.0, QColor(0, 0, 0, 0))
        painter.setBrush(QBrush(grad))
        painter.setPen(Qt.PenStyle.NoPen)
        painter.drawEllipse(centre, radius, radius)

    def _draw_connections(self, painter: QPainter) -> None:
        w, h = self.width(), self.height()
        max_dist = min(w, h) * 0.18  # connection threshold
        nodes = self.nodes
        n = len(nodes)

        # Pre-calculate for performance (only check nearby nodes)
        for i in range(n):
            for j in range(i + 1, n):
                dx = nodes[i].pos.x() - nodes[j].pos.x()
                dy = nodes[i].pos.y() - nodes[j].pos.y()
                dist = math.hypot(dx, dy)
                if dist > max_dist or dist < 1:
                    continue

                alpha = max(0, 1.0 - dist / max_dist)
                # Pulse effect
                pulse = math.sin(
                    self._elapsed * 1.5 + nodes[i].pulse_phase + nodes[j].pulse_phase
                )
                alpha *= max(0.1, 0.5 + 0.5 * pulse)

                # Glow layers (thick → thin)
                line_alpha = int(alpha * 40)
                if line_alpha < 3:
                    continue

                # Outer glow
                pen = QPen(QColor(255, 120, 30, line_alpha // 3), 3.0)
                painter.setPen(pen)
                painter.drawLine(nodes[i].pos, nodes[j].pos)

                # Mid glow
                pen = QPen(QColor(255, 180, 60, line_alpha // 2), 1.5)
                painter.setPen(pen)
                painter.drawLine(nodes[i].pos, nodes[j].pos)

                # Core line
                pen = QPen(QColor(255, 220, 120, line_alpha), 0.8)
                painter.setPen(pen)
                painter.drawLine(nodes[i].pos, nodes[j].pos)

    def _draw_nodes(self, painter: QPainter) -> None:
        for node in self.nodes:
            pulse = math.sin(self._elapsed * 2.0 + node.pulse_phase)
            r = node.radius * (0.8 + 0.4 * pulse)

            # Outer glow
            grad = QRadialGradient(node.pos, r * 6)
            grad.setColorAt(0.0, QColor(255, 160, 40, 120))
            grad.setColorAt(0.3, QColor(255, 100, 20, 60))
            grad.setColorAt(1.0, QColor(255, 60, 10, 0))
            painter.setBrush(QBrush(grad))
            painter.setPen(Qt.PenStyle.NoPen)
            painter.drawEllipse(node.pos, r * 6, r * 6)

            # Bright core
            grad2 = QRadialGradient(node.pos, r)
            grad2.setColorAt(0.0, QColor(255, 255, 240, 220))
            grad2.setColorAt(0.5, QColor(255, 180, 80, 180))
            grad2.setColorAt(1.0, QColor(255, 80, 20, 60))
            painter.setBrush(QBrush(grad2))
            painter.drawEllipse(node.pos, r, r)

    def _draw_vignette(self, painter: QPainter) -> None:
        w, h = self.width(), self.height()
        path = QPainterPath()
        path.addRect(0, 0, w, h)

        inner = QPainterPath()
        inner.addRoundedRect(w * 0.08, h * 0.08, w * 0.84, h * 0.84, 40, 40)
        path -= inner

        painter.setPen(Qt.PenStyle.NoPen)
        painter.setBrush(QBrush(QColor(0, 0, 0, 180)))
        painter.drawPath(path)

        # Screen edge scanlines (very subtle)
        pen = QPen(QColor(255, 120, 20, 12), 1)
        painter.setPen(pen)
        for y in range(0, h, 4):
            painter.drawLine(0, y, w, y)

    def _draw_overlay_text(self, painter: QPainter) -> None:
        w, h = self.width(), self.height()

        # Top‑left corner header
        painter.setPen(QColor(255, 160, 40, 180))
        font = painter.font()
        font.setFamily("Courier New")
        font.setPixelSize(14)
        font.setBold(True)
        painter.setFont(font)

        lines = [
            "JARVIS v1.0",
            "SYSTEM: ONLINE",
            f"  NODES: {len(self.nodes)}",
            "STATUS: OPERATIONAL",
        ]
        x = 30
        y = 35
        for line in lines:
            painter.drawText(x, y, line)
            y += 22

        # Bottom‑right corner status
        painter.setPen(QColor(255, 120, 30, 100))
        font.setPixelSize(11)
        painter.setFont(font)
        painter.drawText(
            w - 180, h - 20,
            f"  {self._elapsed:.1f}s  |  60 FPS  |  CORE 4.2",
        )

        # Horizontal scanner line
        scan_y = int((self._elapsed * 60) % h)
        grad = QLinearGradient(0, scan_y, w, scan_y)
        grad.setColorAt(0.0, QColor(255, 120, 20, 0))
        grad.setColorAt(0.3, QColor(255, 120, 20, 60))
        grad.setColorAt(0.5, QColor(255, 200, 80, 120))
        grad.setColorAt(0.7, QColor(255, 120, 20, 60))
        grad.setColorAt(1.0, QColor(255, 120, 20, 0))
        painter.setPen(QPen(QBrush(grad), 1.5))
        painter.drawLine(0, scan_y, w, scan_y)

        # Corner brackets
        self._draw_corner_bracket(painter, 15, 15, 50, 50)
        self._draw_corner_bracket(painter, w - 65, 15, 50, 50)
        self._draw_corner_bracket(painter, 15, h - 65, 50, 50)
        self._draw_corner_bracket(painter, w - 65, h - 65, 50, 50)

    def _draw_corner_bracket(
        self, painter: QPainter, x: int, y: int, w: int, h: int
    ) -> None:
        pen = QPen(QColor(255, 140, 30, 100), 2)
        painter.setPen(pen)
        painter.drawLine(x, y, x + w, y)    # top
        painter.drawLine(x, y, x, y + h)     # left

    # ------------------------------------------------------------------
    # Resize handling
    # ------------------------------------------------------------------
    def resizeEvent(self, event) -> None:  # noqa: N802
        super().resizeEvent(event)
        # Regenerate nodes on resize so they spread across the new area
        self._generate_nodes(len(self.nodes))
