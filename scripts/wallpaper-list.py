#!/usr/bin/env python3
"""
wallpaper-list.py <folder>
Lists image files in <folder>, generates 180x120 thumbnails via magick,
outputs JSON array [{path, thumb, name}].
"""
import sys
import os
import json
import subprocess
import glob

folder = os.path.expanduser(sys.argv[1]) if len(
    sys.argv) > 1 else os.path.expanduser("~/Imágenes")
THUMB_DIR = "/tmp/qs-wallpaper-thumbs"
EXTS = {".jpg", ".jpeg", ".png", ".webp", ".bmp", ".tiff", ".tif", ".gif"}

os.makedirs(THUMB_DIR, exist_ok=True)


def find_images(d):
    results = []
    try:
        for entry in sorted(os.scandir(d), key=lambda e: e.name.lower()):
            if entry.is_file() and os.path.splitext(entry.name)[1].lower() in EXTS:
                results.append(entry.path)
    except PermissionError:
        pass
    return results


def make_thumb(path):
    safe = path.replace("/", "_").replace(" ", "_")
    thumb = os.path.join(THUMB_DIR, safe + ".jpg")
    if not os.path.exists(thumb):
        try:
            subprocess.run(
                ["magick", path,
                 "-thumbnail", "180x120^",
                 "-gravity", "center",
                 "-extent", "180x120",
                 thumb],
                timeout=5, capture_output=True
            )
        except Exception:
            return ""
    return thumb if os.path.exists(thumb) else ""


images = find_images(folder)
out = []
for p in images[:60]:  # máximo 60 imágenes
    thumb = make_thumb(p)
    out.append({
        "path":  p,
        "thumb": thumb,
        "name":  os.path.basename(p),
    })

print(json.dumps(out))
