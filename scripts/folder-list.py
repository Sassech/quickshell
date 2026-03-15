#!/usr/bin/env python3
"""
folder-list.py <path>
Lists directory contents for folder browser.
Outputs JSON:
{
  "path": "/absolute/path",
  "parent": "/parent/path",
  "entries": [
    {"name": "...", "path": "...", "isDir": true/false}
  ]
}
"""
import sys
import os
import json

raw = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser("~")
path = os.path.realpath(os.path.expanduser(raw))

if not os.path.isdir(path):
    path = os.path.expanduser("~")

parent = os.path.dirname(path) if path != "/" else "/"

entries = []
try:
    items = sorted(os.scandir(path), key=lambda e: (
        not e.is_dir(), e.name.lower()))
    for e in items:
        if e.name.startswith('.'):
            continue
        entries.append({
            "name":  e.name,
            "path":  e.path,
            "isDir": e.is_dir(follow_symlinks=True),
        })
except PermissionError:
    pass

print(json.dumps({"path": path, "parent": parent, "entries": entries}))
