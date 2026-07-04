"""
JARVIS GUI package.

Provides BrainWidget (2D) and GLBrainWidget (OpenGL 3D) for the
neural-network animation, plus the MainWindow that ties it all together.
"""

import logging

logger = logging.getLogger(__name__)

# GLBrainWidget is optional – import only when OpenGL is available
try:
    from jarvis.gui.gl_brain_widget import GLBrainWidget
    _HAS_GL = True
except Exception as exc:
    logger.warning("OpenGL not available: %s", exc)
    GLBrainWidget = None  # type: ignore
    _HAS_GL = False

from jarvis.gui.brain_widget import BrainWidget
from jarvis.gui.main_window import MainWindow

__all__ = ["BrainWidget", "GLBrainWidget", "MainWindow"]
