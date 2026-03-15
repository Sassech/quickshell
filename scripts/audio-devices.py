#!/usr/bin/env python3
"""
audio-devices.py — Lista sinks y sources disponibles via pactl.
Filtra dispositivos cuyo único puerto está marcado como "no disponible".
Salida por línea: TYPE:active:stable_name:Human Description
  TYPE   = SINK | SOURCE
  active = 1 | 0
"""
import subprocess
import re
import sys


def run(cmd):
    try:
        return subprocess.check_output(cmd, stderr=subprocess.DEVNULL).decode(errors="replace")
    except Exception:
        return ""


def parse_blocks(raw, header_re):
    """Split pactl verbose output into per-device blocks."""
    blocks = re.split(header_re, raw)
    return [b for b in blocks if b.strip()]


def is_available(block):
    """
    Returns True if the device should be shown:
    - BT / no ports at all → always show
    - At least one port marked disponible/available → show
    - All ports marked no disponible / not available → hide
    """
    # Find all port availability markers (end of port line)
    ports = re.findall(r'(?:disponible|available)\)', block)
    unavail = re.findall(r'(?:no disponible|not available)\)', block)
    if not ports:        # no port info → BT or virtual → show
        return True
    return len(ports) > len(unavail)   # at least one available port


def get_default(kind):
    info = run(["pactl", "info"])
    # Handles Spanish (Destino/Fuente por defecto) and English (Default Sink/Source)
    patterns = {
        "sink":   r'(?:Default Sink|Destino por defecto):\s*(\S+)',
        "source": r'(?:Default Source|Fuente por defecto):\s*(\S+)',
    }
    m = re.search(patterns[kind], info, re.IGNORECASE)
    return m.group(1) if m else ""


def parse_devices(raw, kind):
    # Handles English (Sink/Source #N) and Spanish (Destino/Fuente #N)
    if kind == "sink":
        header_re = r'\n(?:Sink|Destino) #\d+'
    else:
        header_re = r'\n(?:Source|Fuente) #\d+'
    blocks = parse_blocks(raw, header_re)
    default = get_default(kind)
    results = []
    type_label = "SINK" if kind == "sink" else "SOURCE"

    for block in blocks:
        m_name = re.search(r'(?:Nombre|Name):\s*(\S+)', block)
        m_desc = re.search(r'(?:Descripci[oó]n|Description):\s*(.+)', block)
        if not m_name:
            continue
        name = m_name.group(1).strip()
        desc = m_desc.group(1).strip() if m_desc else name

        # Skip .monitor sources
        if name.endswith(".monitor"):
            continue

        # Skip unavailable devices
        if not is_available(block):
            continue

        active = "1" if name == default else "0"
        results.append(f"{type_label}:{active}:{name}:{desc}")

    return results


sinks_raw = run(["pactl", "list", "sinks"])
sources_raw = run(["pactl", "list", "sources"])

lines = parse_devices(sinks_raw, "sink") + parse_devices(sources_raw, "source")
print("\n".join(lines))
