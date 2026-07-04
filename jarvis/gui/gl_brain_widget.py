"""
OpenGL-accelerated 3D brain network visualization for JARVIS.
Renders ~3000+ connected particles with neon glow, 3D rotation,
additive blending, and real-time organic movement at 60 FPS.

Inspired by the Iron Man JARVIS interface.
"""

import math
import random
from typing import List, Tuple

import numpy as np

from PyQt6.QtCore import Qt, QTimer
from PyQt6.QtGui import QColor, QFont, QLinearGradient, QPainter, QPen
from PyQt6.QtOpenGLWidgets import QOpenGLWidget

from OpenGL import GL
from OpenGL.GLU import gluPerspective, gluLookAt


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
NUM_NODES = 3200
CONNECTION_DIST = 0.40  # lower = fewer connections (cleaner look)
BG_COLOR = (0.015, 0.005, 0.03, 1.0)


# ---------------------------------------------------------------------------
# 3D brain node
# ---------------------------------------------------------------------------
class BrainNode:
    """A single 3D particle with its own oscillation phase."""

    __slots__ = ("phase", "speed", "amp")

    def __init__(self) -> None:
        self.phase = random.uniform(0, 2.0 * math.pi)
        self.speed = random.uniform(0.4, 1.0)
        self.amp = random.uniform(0.008, 0.025)


# ===================================================================
# OpenGL brain widget
# ===================================================================
class GLBrainWidget(QOpenGLWidget):
    """Renders an animated, rotating 3D brain using OpenGL with additive glow."""

    def __init__(self, parent=None) -> None:
        super().__init__(parent)
        self.setMinimumSize(800, 500)

        # ── 60 FPS timer ────────────────────────────────────────────
        self._timer = QTimer(self)
        self._timer.timeout.connect(self._tick)
        self._timer.start(16)

        self._elapsed = 0.0
        self._rotation_x = 0.0
        self._rotation_y = 0.0

        # ── Node storage ────────────────────────────────────────────
        self.nodes: List[BrainNode] = []
        self._init_positions: np.ndarray = np.empty((0, 3), dtype=np.float32)
        self._positions: np.ndarray = np.empty((0, 3), dtype=np.float32)
        self._node_phases: np.ndarray = np.empty(0, dtype=np.float32)
        self._node_speeds: np.ndarray = np.empty(0, dtype=np.float32)
        self._node_amps: np.ndarray = np.empty(0, dtype=np.float32)

        self._generate_nodes()

        # ── Precomputed connection pairs ────────────────────────────
        self._conn_pairs: List[Tuple[int, int]] = []
        self._compute_connections()

        # ── OpenGL state ────────────────────────────────────────────
        self._gl_initialized = False

    # ================================================================
    # Node generation – anatomically inspired brain shape
    # ================================================================
    def _generate_nodes(self) -> None:
        n = NUM_NODES
        self.nodes = [BrainNode() for _ in range(n)]
        positions = []
        phases = []
        speeds = []
        amps = []

        for i in range(n):
            node = self.nodes[i]
            region = random.random()

            # ── Two hemispheres (left & right) ──────────────────────
            if region < 0.28:  # Left hemisphere
                rx, ry, rz = 1.9, 1.5, 1.6
                cx, cy, cz = -0.5, 0.15, 0.0
                sf = random.uniform(0.25, 1.0)
            elif region < 0.56:  # Right hemisphere
                rx, ry, rz = 1.9, 1.5, 1.6
                cx, cy, cz = 0.5, 0.15, 0.0
                sf = random.uniform(0.25, 1.0)
            elif region < 0.72:  # Corpus callosum / connecting fibres
                rx, ry, rz = 1.3, 1.1, 1.3
                cx, cy, cz = 0.0, 0.05, 0.0
                sf = random.uniform(0.1, 0.7)
            elif region < 0.84:  # Brainstem / lower region
                rx, ry, rz = 0.6, 1.3, 0.8
                cx, cy, cz = 0.0, -1.4, 0.2
                sf = random.uniform(0.1, 0.9)
            else:  # Cerebellum (back-bottom)
                rx, ry, rz = 1.1, 0.7, 1.0
                cx, cy, cz = 0.0, -0.6, -1.6
                sf = random.uniform(0.2, 0.9)

            theta = random.uniform(0, math.pi)
            phi = random.uniform(0, 2.0 * math.pi)

            x = cx + rx * sf * math.sin(theta) * math.cos(phi)
            y = cy + ry * sf * math.cos(theta)
            z = cz + rz * sf * math.sin(theta) * math.sin(phi)

            # Central fissure separation
            if abs(x) < 0.6 and abs(y) < 1.2:
                push = 0.4 - abs(x)
                if push > 0.0:
                    x += push * random.choice([-1, 1]) * 0.9

            # Surface noise for organic feel
            x += random.uniform(-0.08, 0.08)
            y += random.uniform(-0.08, 0.08)
            z += random.uniform(-0.08, 0.08)

            positions.append((x, y, z))
            phases.append(node.phase)
            speeds.append(node.speed)
            amps.append(node.amp * random.uniform(0.8, 1.2))

        arr = np.array(positions, dtype=np.float32)

        # Normalize to roughly unit sphere
        max_r = np.max(np.linalg.norm(arr, axis=1))
        arr = arr / max_r * 2.8

        self._init_positions = arr
        self._positions = arr.copy()
        self._node_phases = np.array(phases, dtype=np.float32)
        self._node_speeds = np.array(speeds, dtype=np.float32)
        self._node_amps = np.array(amps, dtype=np.float32)

    # ================================================================
    # Connection computation (brute-force precompute)
    # ================================================================
    def _compute_connections(self) -> None:
        n = len(self._init_positions)
        positions = self._init_positions
        pairs: List[Tuple[int, int]] = []

        # Use spatial hashing for efficiency
        # Simple approach: only check within grid cells
        cell_size = CONNECTION_DIST * 1.5
        grid: dict = {}

        def _cell_key(pos) -> Tuple[int, int, int]:
            return (int(pos[0] / cell_size),
                    int(pos[1] / cell_size),
                    int(pos[2] / cell_size))

        for i in range(n):
            key = _cell_key(positions[i])
            grid.setdefault(key, []).append(i)

        for i in range(n):
            cx, cy, cz = _cell_key(positions[i])
            # Check 27 neighbouring cells
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    for dz in (-1, 0, 1):
                        neigh = grid.get((cx + dx, cy + dy, cz + dz), [])
                        for j in neigh:
                            if j <= i:
                                continue
                            dist = np.linalg.norm(positions[i] - positions[j])
                            if dist < CONNECTION_DIST:
                                pairs.append((i, j))

        self._conn_pairs = pairs

    # ================================================================
    # OpenGL initialization
    # ================================================================
    def initializeGL(self) -> None:  # noqa: N802
        GL.glClearColor(*BG_COLOR)
        GL.glEnable(GL.GL_DEPTH_TEST)
        GL.glEnable(GL.GL_BLEND)
        GL.glBlendFunc(GL.GL_SRC_ALPHA, GL.GL_ONE)  # additive blending
        GL.glEnable(GL.GL_POINT_SMOOTH)
        GL.glEnable(GL.GL_LINE_SMOOTH)
        GL.glHint(GL.GL_POINT_SMOOTH_HINT, GL.GL_NICEST)
        GL.glHint(GL.GL_LINE_SMOOTH_HINT, GL.GL_NICEST)

        # Point sprite for glow
        GL.glEnable(GL.GL_VERTEX_PROGRAM_POINT_SIZE)
        self._gl_initialized = True

    # ================================================================
    # Resize
    # ================================================================
    def resizeGL(self, w: int, h: int) -> None:  # noqa: N802
        GL.glViewport(0, 0, w, h)
        GL.glMatrixMode(GL.GL_PROJECTION)
        GL.glLoadIdentity()
        aspect = w / h if h > 0 else 1.0
        gluPerspective(30.0, aspect, 0.1, 40.0)
        GL.glMatrixMode(GL.GL_MODELVIEW)

    # ================================================================
    # Paint
    # ================================================================
    def paintGL(self) -> None:  # noqa: N802
        GL.glClear(GL.GL_COLOR_BUFFER_BIT | GL.GL_DEPTH_BUFFER_BIT)
        GL.glLoadIdentity()

        # ── Camera ──────────────────────────────────────────────────
        gluLookAt(0.0, 0.8, 7.5, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0)

        GL.glRotatef(self._rotation_x, 1.0, 0.0, 0.0)
        GL.glRotatef(self._rotation_y, 0.0, 1.0, 0.0)

        n = NUM_NODES
        pos = self._positions
        t = self._elapsed

        # ── Compute node brightness pulse ───────────────────────────
        # Each node pulses independently
        pulse = 0.65 + 0.35 * np.sin(t * 1.2 + self._node_phases * 1.5)

        # ── Draw connections (lines with additive blending) ─────────
        if self._conn_pairs:
            # Pack connection vertices
            num_conn = len(self._conn_pairs)
            conn_verts = np.empty((num_conn * 2, 3), dtype=np.float32)
            conn_colors = np.empty((num_conn * 2, 4), dtype=np.float32)

            for k, (i, j) in enumerate(self._conn_pairs):
                p_i = pos[i]
                p_j = pos[j]
                dist = np.linalg.norm(p_i - p_j)
                # Alpha inversely proportional to distance
                alpha = max(0.0, 1.0 - (dist / CONNECTION_DIST))
                alpha *= 0.25  # subtle lines
                alpha *= 0.8 + 0.2 * pulse[i]

                conn_verts[k * 2] = p_i
                conn_verts[k * 2 + 1] = p_j
                # Warm orange-red color
                r, g = 1.0, 0.35 + 0.25 * pulse[i]
                conn_colors[k * 2] = (r, g, 0.05, alpha)
                conn_colors[k * 2 + 1] = (r, g, 0.05, alpha)

            GL.glDisable(GL.GL_DEPTH_TEST)
            GL.glBlendFunc(GL.GL_SRC_ALPHA, GL.GL_ONE)
            GL.glLineWidth(1.2)

            GL.glEnableClientState(GL.GL_VERTEX_ARRAY)
            GL.glEnableClientState(GL.GL_COLOR_ARRAY)
            GL.glVertexPointer(3, GL.GL_FLOAT, 0, conn_verts)
            GL.glColorPointer(4, GL.GL_FLOAT, 0, conn_colors)
            GL.glDrawArrays(GL.GL_LINES, 0, num_conn * 2)
            GL.glDisableClientState(GL.GL_VERTEX_ARRAY)
            GL.glDisableClientState(GL.GL_COLOR_ARRAY)

            GL.glEnable(GL.GL_DEPTH_TEST)

        # ── Draw nodes with glow (additive blending) ────────────────
        # Two-pass: first draw larger transparent halos, then bright cores
        GL.glDisable(GL.GL_DEPTH_TEST)

        # Pass 1: Glow halos (large, transparent)
        GL.glPointSize(8.0 + 2.0 * pulse)
        GL.glBlendFunc(GL.GL_SRC_ALPHA, GL.GL_ONE)

        halo_colors = np.zeros((n, 4), dtype=np.float32)
        for i in range(n):
            p = pulse[i]
            alpha = 0.12 + 0.08 * p
            # Orange-red: #ff6600 → #ff3300 depending on pulse
            r = 1.0
            g = 0.35 + 0.15 * p
            b = 0.02 + 0.04 * p
            halo_colors[i] = (r, g, b, alpha)

        GL.glEnableClientState(GL.GL_VERTEX_ARRAY)
        GL.glEnableClientState(GL.GL_COLOR_ARRAY)
        GL.glVertexPointer(3, GL.GL_FLOAT, 0, pos)
        GL.glColorPointer(4, GL.GL_FLOAT, 0, halo_colors)
        GL.glDrawArrays(GL.GL_POINTS, 0, n)

        # Pass 2: Bright cores (smaller, opaque)
        GL.glPointSize(3.0 + 1.0 * pulse)
        GL.glBlendFunc(GL.GL_SRC_ALPHA, GL.GL_ONE)

        core_colors = np.zeros((n, 4), dtype=np.float32)
        for i in range(n):
            p = pulse[i]
            # Brighter cores
            r = 1.0
            g = 0.5 + 0.3 * p
            b = 0.05 + 0.08 * p
            alpha = 0.7 + 0.3 * p
            core_colors[i] = (r, g, b, alpha)

        GL.glColorPointer(4, GL.GL_FLOAT, 0, core_colors)
        GL.glDrawArrays(GL.GL_POINTS, 0, n)

        GL.glDisableClientState(GL.GL_VERTEX_ARRAY)
        GL.glDisableClientState(GL.GL_COLOR_ARRAY)

        GL.glEnable(GL.GL_DEPTH_TEST)
        GL.glBlendFunc(GL.GL_SRC_ALPHA, GL.GL_ONE_MINUS_SRC_ALPHA)

        # ── Cortex highlight pass (select outer nodes) ──────────────
        # Draw a subset of surface nodes brighter
        radii = np.linalg.norm(pos, axis=1)
        surface_mask = radii > 1.8
        surface_indices = np.where(surface_mask)[0]
        if len(surface_indices) > 0:
            surface_pos = pos[surface_indices]
            surface_colors = np.zeros((len(surface_indices), 4), dtype=np.float32)
            for idx, orig_i in enumerate(surface_indices):
                p = pulse[orig_i]
                r = 1.0
                g = 0.6 + 0.3 * p
                b = 0.1 + 0.1 * p
                alpha = 0.5 + 0.4 * p
                surface_colors[idx] = (r, g, b, alpha)

            GL.glPointSize(2.5)
            GL.glDisable(GL.GL_DEPTH_TEST)
            GL.glBlendFunc(GL.GL_SRC_ALPHA, GL.GL_ONE)

            GL.glEnableClientState(GL.GL_VERTEX_ARRAY)
            GL.glEnableClientState(GL.GL_COLOR_ARRAY)
            GL.glVertexPointer(3, GL.GL_FLOAT, 0, surface_pos)
            GL.glColorPointer(4, GL.GL_FLOAT, 0, surface_colors)
            GL.glDrawArrays(GL.GL_POINTS, 0, len(surface_indices))
            GL.glDisableClientState(GL.GL_VERTEX_ARRAY)
            GL.glDisableClientState(GL.GL_COLOR_ARRAY)

            GL.glEnable(GL.GL_DEPTH_TEST)

        # ── Draw overlay via QPainter ───────────────────────────────
        painter = QPainter(self)
        painter.begin(self)
        self._draw_overlay(painter)
        painter.end()

    # ================================================================
    # QPainter overlay (HUD, scanlines, brackets)
    # ================================================================
    def _draw_overlay(self, painter: QPainter) -> None:
        w = self.width()
        h = self.height()

        painter.setRenderHint(QPainter.RenderHint.Antialiasing)

        # ── Top-left header ─────────────────────────────────────────
        font = QFont("Courier New", 13, QFont.Weight.Bold)
        painter.setFont(font)
        painter.setPen(QColor(255, 140, 30, 200))

        lines = [
            "JARVIS v1.0",
            "SYSTEM:  ONLINE",
            f"NODES:   {NUM_NODES}",
            "STATUS:  OPERATIONAL",
        ]
        x, y = 28, 34
        for line in lines:
            painter.drawText(x, y, line)
            y += 21

        # ── Bottom-right metrics ────────────────────────────────────
        font.setPixelSize(11)
        painter.setFont(font)
        painter.setPen(QColor(255, 100, 20, 130))
        painter.drawText(
            w - 200, h - 20,
            f"  {self._elapsed:.1f}s  |  60 FPS  |  CORE 4.2",
        )

        # ── Scanner line ────────────────────────────────────────────
        scan_y = int((self._elapsed * 60) % h)
        grad = QLinearGradient(0, scan_y, w, scan_y)
        grad.setColorAt(0.0, QColor(255, 100, 15, 0))
        grad.setColorAt(0.3, QColor(255, 100, 15, 40))
        grad.setColorAt(0.5, QColor(255, 180, 60, 100))
        grad.setColorAt(0.7, QColor(255, 100, 15, 40))
        grad.setColorAt(1.0, QColor(255, 100, 15, 0))
        painter.setPen(QPen(grad, 1.5))
        painter.drawLine(0, scan_y, w, scan_y)

        # ── Scanline overlay effect ────────────────────────────────
        painter.setPen(QPen(QColor(255, 100, 15, 8), 1))
        for sy in range(0, h, 3):
            painter.drawLine(0, sy, w, sy)

        # ── Corner brackets ─────────────────────────────────────────
        pen = QPen(QColor(255, 130, 25, 120), 2)
        painter.setPen(pen)
        bs = 35  # bracket size
        m = 14  # margin
        # Top-left
        x, y = m, m
        painter.drawLine(x, y, x + bs, y)
        painter.drawLine(x, y, x, y + bs)
        # Top-right
        x, y = w - m - bs, m
        painter.drawLine(x, y, x + bs, y)
        painter.drawLine(x + bs, y, x + bs, y + bs)
        # Bottom-left
        x, y = m, h - m - bs
        painter.drawLine(x, y, x, y + bs)
        painter.drawLine(x, y + bs, x + bs, y + bs)
        # Bottom-right
        x, y = w - m - bs, h - m - bs
        painter.drawLine(x, y + bs, x + bs, y + bs)
        painter.drawLine(x + bs, y, x + bs, y + bs)

        # ── Center crosshair (subtle) ───────────────────────────────
        painter.setPen(QPen(QColor(255, 100, 15, 30), 1))
        painter.drawLine(w // 2 - 15, h // 2, w // 2 + 15, h // 2)
        painter.drawLine(w // 2, h // 2 - 15, w // 2, h // 2 + 15)

    # ================================================================
    # Animation tick
    # ================================================================
    def _tick(self) -> None:
        self._elapsed += 0.016
        n = NUM_NODES

        # Smooth rotation
        self._rotation_y += 0.25
        self._rotation_x = 3.0 * math.sin(self._elapsed * 0.06)

        # Organic breathing motion
        t = self._elapsed
        phases = self._node_phases
        speeds = self._node_speeds
        amps = self._node_amps

        self._positions[:, 0] = self._init_positions[:, 0] + amps * np.sin(
            t * 0.5 * speeds + phases * 1.0
        )
        self._positions[:, 1] = self._init_positions[:, 1] + amps * np.sin(
            t * 0.7 * speeds + phases * 1.3
        )
        self._positions[:, 2] = self._init_positions[:, 2] + amps * np.sin(
            t * 0.6 * speeds + phases * 0.9
        )

        self.update()

    # ================================================================
    # Resize
    # ================================================================
    def resizeEvent(self, event) -> None:  # noqa: N802
        super().resizeEvent(event)
        # Viewport handled by resizeGL
