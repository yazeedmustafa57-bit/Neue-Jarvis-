"""
AI module for JARVIS.

Loads the OpenAI API key from a .env file (or environment variable)
and provides the ask_ai() function for prompting GPT.

Usage:
    from jarvis.core.ai import ask_ai
    reply = ask_ai("Wie heißt du?")
"""

import logging
import os
from typing import Optional

from dotenv import load_dotenv
from openai import OpenAI

logger = logging.getLogger(__name__)

# Load .env from the project root (next to main.py)
_env_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), ".env")
load_dotenv(_env_path)

_api_key: Optional[str] = os.getenv("OPENAI_API_KEY")
_client: Optional[OpenAI] = None

# ── Validate the key ──────────────────────────────────────────────────
_PLACEHOLDER = "sk-dein-openai-api-key-hier"

if _api_key and _api_key == _PLACEHOLDER:
    logger.warning("OPENAI_API_KEY is still the placeholder value.")
    _api_key = None
elif _api_key and not _api_key.startswith("sk-"):
    logger.warning("OPENAI_API_KEY does not start with 'sk-' – key ignored.")
    _api_key = None


def _get_client() -> OpenAI:
    """Lazy-initialise and return the OpenAI client."""
    global _client
    if _client is None:
        if not _api_key:
            raise RuntimeError(
                "OPENAI_API_KEY ist nicht gesetzt.\n"
                "Füge ihn in jarvis/.env ein:\n"
                "  OPENAI_API_KEY=sk-..."
            )
        _client = OpenAI(api_key=_api_key)
    return _client


def ask_ai(prompt: str, model: str = "gpt-4o-mini", max_tokens: int = 512) -> str:
    """
    Send a prompt to OpenAI and return the text response.

    Parameters
    ----------
    prompt : str
        The user's question or instruction.
    model : str
        OpenAI model ID (default: gpt-4o-mini).
    max_tokens : int
        Maximum tokens in the response (default: 512).

    Returns
    -------
    str
        The model's reply, or an error message.
    """
    try:
        client = _get_client()
        logger.info("Prompt an %s senden (%d Tokens max) …", model, max_tokens)

        response = client.chat.completions.create(
            model=model,
            messages=[
                {
                    "role": "system",
                    "content": (
                        "Du bist JARVIS, ein futuristischer KI-Assistent im Stil "
                        "von Iron Man. Antworte auf Deutsch, präzise und technisch. "
                        "Du hilfst bei Aufgaben, Analysen und Automation."
                    ),
                },
                {"role": "user", "content": prompt},
            ],
            max_tokens=max_tokens,
            temperature=0.7,
        )

        reply = response.choices[0].message.content or ""
        logger.info("KI-Antwort erhalten (%d Zeichen).", len(reply))
        return reply

    except RuntimeError:
        raise  # No API key → caller shows the message
    except Exception as exc:
        logger.exception("OpenAI API call failed")
        return f"Fehler bei der KI-Anfrage: {exc}"
