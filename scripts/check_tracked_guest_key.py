#!/usr/bin/env python3
"""Fail if a tracked file contains a concrete guest path key.

The documentation placeholder uses angle brackets, so it does not match.
Matching lines are not printed.
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# A real /tv/<segment>/guest.json. The placeholder uses <GUEST_PATH_KEY>.
URL_PATTERN = r"sunrivertownhome\.com/tv/[A-Za-z0-9._~-]+/guest\.json"
# A GuestPathKey-sized literal. Ordinary sentences do not match this shape.
LITERAL_PATTERN = r'return "[A-Za-z0-9._~-]{8,}"'


def git(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", *args],
        cwd=ROOT,
        check=False,
        capture_output=True,
        text=True,
    )


def fail(message: str, names: str = "") -> None:
    print(message, file=sys.stderr)
    cleaned = names.strip()
    if cleaned:
        print(cleaned, file=sys.stderr)
    raise SystemExit(1)


def require_clean(pattern: str, description: str, *paths: str) -> None:
    result = git("grep", "-E", "-I", "-l", pattern, "--", *paths)
    if result.returncode == 0:
        fail(description, result.stdout)
    if result.returncode != 1:
        detail = result.stderr.strip() or f"git grep exited {result.returncode}"
        fail(detail)


def main() -> None:
    tracked = git("ls-files", "--", "channel/components/secrets.brs", "channel/source/secrets.brs")
    if tracked.returncode != 0:
        fail(tracked.stderr.strip() or "git ls-files failed")
    if tracked.stdout.strip():
        fail("secrets.brs is tracked. It is generated at package time and must stay gitignored.", tracked.stdout)

    require_clean(
        URL_PATTERN,
        "A tracked file contains a guest path key. Remove it. The key is supplied at package time.",
        ".",
    )
    require_clean(
        LITERAL_PATTERN,
        "A tracked channel file returns a key-like literal. Keep that value out of git.",
        "channel",
    )
    print("tracked guest-key check ok")


if __name__ == "__main__":
    main()
