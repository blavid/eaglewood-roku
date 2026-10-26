"""Greeting rules mirrored from channel/components/MainScene.brs.

scripts/validate.py checks that the regular expression below is the same
string embedded in that BrightScript file. Keep the two implementations
together: first token, 20 characters, trailing hyphen or apostrophe removed,
then only ASCII letters, hyphens, and straight apostrophes.
"""

from __future__ import annotations

import re

NAME_PATTERN = re.compile(r"^[A-Za-z]([A-Za-z'-]*[A-Za-z])?$")
FALLBACK = "Welcome to Eaglewood"


def sanitize_first_name(raw: str | None) -> str:
    if raw is None:
        return ""
    text = raw.strip()
    if not text:
        return ""
    token = text.split(" ")[0]
    # Only a cut-off at 20 characters drops a dangling hyphen or apostrophe.
    if len(token) > 20:
        token = token[:20]
        while token.endswith("-") or token.endswith("'"):
            token = token[:-1]
    if not token or NAME_PATTERN.fullmatch(token) is None:
        return ""
    return token


def build_greeting(raw: str | None) -> str:
    name = sanitize_first_name(raw)
    if not name:
        return FALLBACK
    return "Welcome, " + name
