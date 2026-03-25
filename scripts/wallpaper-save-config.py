#!/usr/bin/env python3
"""
wallpaper-save-config.py <folder>
Saves the wallpaper folder config to JSON file.
"""
import sys
import json
import os

CONFIG_PATH = "/home/sassech/.config/quickshell/config/wallpaper-config.json"

if len(sys.argv) < 2:
    print("Usage: wallpaper-save-config.py <folder>", file=sys.stderr)
    sys.exit(1)

folder = sys.argv[1]

try:
    with open(CONFIG_PATH, "w") as f:
        json.dump({"folder": folder}, f)
except Exception as e:
    print(f"Error saving config: {e}", file=sys.stderr)
    sys.exit(1)
