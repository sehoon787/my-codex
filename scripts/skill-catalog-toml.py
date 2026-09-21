#!/usr/bin/env python3
"""Read Codex skills.config paths from TOML on stdin."""
import json
import sys
import tomllib

data = tomllib.loads(sys.stdin.read())
configs = data.get("skills", {}).get("config", [])
if not isinstance(configs, list):
    raise TypeError("skills.config must be an array of tables")
entries = []
for item in configs:
    if not isinstance(item, dict):
        raise TypeError("each skills.config entry must be a table")
    value = item.get("path")
    if value is not None:
        if not isinstance(value, str):
            raise TypeError("skills.config path must be a string")
        enabled = item.get("enabled", True)
        if not isinstance(enabled, bool):
            raise TypeError("skills.config enabled must be a boolean")
        entries.append({"path": value, "enabled": enabled})
json.dump(entries, sys.stdout)
