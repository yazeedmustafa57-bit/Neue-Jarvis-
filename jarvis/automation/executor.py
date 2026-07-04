import logging
import subprocess
from jarvis.config.settings import Settings

logger = logging.getLogger(__name__)


class AutomationEngine:
    """Executes system commands and automation tasks."""

    def run(self, command: str) -> str:
        """Execute a shell command and return its output."""
        logger.info("Executing command: %s", command)
        try:
            result = subprocess.run(
                command,
                shell=True,
                capture_output=True,
                text=True,
                timeout=Settings.COMMAND_TIMEOUT,
            )
            output = result.stdout or result.stderr
            logger.debug("Command output: %s", output[:500])
            return output.strip()
        except subprocess.TimeoutExpired:
            msg = f"Command timed out after {Settings.COMMAND_TIMEOUT}s"
            logger.warning(msg)
            return msg
        except Exception as exc:
            logger.exception("Command failed")
            return f"Error: {exc}"

    def shutdown(self) -> None:
        """Clean up any resources."""
        logger.info("Automation engine shut down.")
