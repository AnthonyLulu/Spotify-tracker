#!/usr/bin/env python3
"""Configure PostgreSQL 17 only in a freshly initialized local Supabase config.

The CLI emits a TOML integer (major_version = 15), not a quoted string.
Never connect to or mutate any remote database here.
"""
import re
import sys
import tomllib
from pathlib import Path


def main():
    if len(sys.argv) != 2:
        raise SystemExit("Usage: cb-configure-local-pg17.py PATH_TO_CONFIG_TOML")
    path = Path(sys.argv[1])
    original = path.read_text(encoding="utf-8")
    pattern = r'(?m)^([ \t]*major_version[ \t]*=[ \t]*)(?:"[0-9]+"|[0-9]+)([ \t]*(?:#.*)?)$'
    updated, count = re.subn(pattern, lambda match: match[1] + "17" + match[2], original)
    if count != 1:
        raise SystemExit(f"Expected exactly one major_version setting, found {count}")
    parsed = tomllib.loads(updated)
    if parsed.get("db", {}).get("major_version") != 17:
        raise SystemExit("Cannot verify [db].major_version as integer 17")
    path.write_text(updated, encoding="utf-8")
    print("Verified local PostgreSQL major version: 17")


if __name__ == "__main__":
    main()
