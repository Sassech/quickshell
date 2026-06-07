#!/usr/bin/env python3
"""
wallpaper-save-config.py <folder>
Saves the wallpaper folder config to JSON file.
"""
import sys
import json
import os

config_home = os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config"))
CONFIG_PATH = os.path.join(config_home, "quickshell", "config", "wallpaper-config.json")

if len(sys.argv) < 2:
    print("Usage: wallpaper-save-config.py <folder>", file=sys.stderr)
    sys.exit(1)

folder = sys.argv[1]

try:
    os.makedirs(os.path.dirname(CONFIG_PATH), exist_ok=True)
    tmp = CONFIG_PATH + ".tmp"
    with open(tmp, "w") as f:
        json.dump({"folder": folder}, f)
    os.replace(tmp, CONFIG_PATH)
except Exception as e:
    print(f"Error saving config: {e}", file=sys.stderr)
    sys.exit(1)
