#!/usr/bin/env python3
"""Lista entradas del clipboard como JSON."""
import sys
import os
import subprocess
import json
import shutil

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
LOG_FILE = "/tmp/qs-clipboard.log"


def log(msg: str) -> None:
    try:
        from datetime import datetime
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        with open(LOG_FILE, "a") as f:
            f.write(f"[{timestamp}] {msg}\n")
    except Exception:
        pass


def has_imagemagick() -> bool:
    return shutil.which("magick") is not None


def main() -> None:
    try:
        result = subprocess.run(
            ["cliphist", "list"],
            capture_output=True,
            text=True,
            timeout=5
        )

        if result.returncode != 0:
            log("[list] cliphist error: %s" % result.stderr.strip())
            print("[]")
            return

        entries = []
        imagemagick = has_imagemagick()

        for line in result.stdout.splitlines():
            if "\t" not in line:
                continue

            parts = line.split("\t", 1)
            entry_id = parts[0]
            preview = parts[1] if len(parts) > 1 else ""
            is_binary = preview.startswith("[[ binary")
            thumb = ""

            if is_binary and "png" in preview.lower() and imagemagick:
                thumb = generate_thumbnail(entry_id)

            entries.append({
                "id": entry_id,
                "preview": preview,
                "isBinary": is_binary,
                "thumb": thumb
            })

        print(json.dumps(entries))

    except subprocess.TimeoutExpired:
        log("[list] Timeout esperando cliphist")
        print("[]")
    except Exception as e:
        log("[list] Error: %s" % e)
        print("[]")


def generate_thumbnail(entry_id: str) -> str:
    thumb_path = f"/tmp/qs-clip-{entry_id}.png"

    if os.path.exists(thumb_path):
        return thumb_path

    raw_path = f"/tmp/qs-raw-{entry_id}"

    try:
        # Obtener la entrada y decodificar en un solo pipeline
        decode_result = subprocess.run(
            ["bash", "-c", f"cliphist list | awk -F'\\t' '$1 == \"{entry_id}\" {{print; exit}}' | cliphist decode"],
            capture_output=True,
            timeout=10
        )

        if decode_result.returncode != 0 or len(decode_result.stdout) < 50:
            return ""

        with open(raw_path, "wb") as f:
            f.write(decode_result.stdout)

        subprocess.run(
            ["magick", raw_path, "-thumbnail", "72x72^",
             "-gravity", "center", "-extent", "72x72", thumb_path],
            capture_output=True,
            timeout=10
        )

        if os.path.exists(raw_path):
            os.unlink(raw_path)

        return thumb_path if os.path.exists(thumb_path) else ""

    except Exception as e:
        log("[thumb] Error generando thumbnail para %s: %s" % (entry_id, e))
        return ""


if __name__ == "__main__":
    main()