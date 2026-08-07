#!/usr/bin/env python3
"""
wallpaper-list.py <folder>
Lists image (and video, if mpvpaper is installed) files in <folder>,
generates 180x120 thumbnails via magick (images) or ffmpeg (videos),
outputs JSON array [{path, thumb, name, type}].
"""
import sys
import os
import json
import shutil
import subprocess
import glob

folder = os.path.expanduser(sys.argv[1]) if len(
    sys.argv) > 1 else os.path.expanduser("~/Imágenes")
THUMB_DIR = "/tmp/qs-wallpaper-thumbs"
EXTS = {".jpg", ".jpeg", ".png", ".webp", ".bmp", ".tiff", ".tif", ".gif"}
VIDEO_EXTS = {".mp4", ".webm", ".mkv", ".mov"}
HAS_MPVPAPER = shutil.which("mpvpaper") is not None

os.makedirs(THUMB_DIR, exist_ok=True)


def find_images(d):
    results = []
    try:
        for entry in sorted(os.scandir(d), key=lambda e: e.name.lower()):
            if not entry.is_file():
                continue
            ext = os.path.splitext(entry.name)[1].lower()
            if ext in EXTS:
                results.append(entry.path)
            elif ext in VIDEO_EXTS and HAS_MPVPAPER:
                results.append(entry.path)
    except PermissionError:
        pass
    return results


def make_thumb(path):
    safe = path.replace("/", "_").replace(" ", "_")
    thumb = os.path.join(THUMB_DIR, safe + ".jpg")
    is_video = os.path.splitext(path)[1].lower() in VIDEO_EXTS
    if not os.path.exists(thumb):
        try:
            if is_video:
                subprocess.run(
                    ["ffmpeg", "-y", "-ss", "00:00:00.5", "-i", path,
                     "-frames:v", "1", "-q:v", "3",
                     "-vf", "scale=180:120:force_original_aspect_ratio=increase,crop=180:120",
                     thumb],
                    timeout=10, capture_output=True
                )
            else:
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
    item_type = "video" if os.path.splitext(p)[1].lower() in VIDEO_EXTS else "image"
    out.append({
        "path":  p,
        "thumb": thumb,
        "name":  os.path.basename(p),
        "type":  item_type,
    })

print(json.dumps(out))
