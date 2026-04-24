#!/usr/bin/env python3
"""
Quickshell System Data Backend
===============================
Single process that polls all system metrics and outputs JSON lines to stdout.
Each line is a JSON object with a "t" (type) field.

Types emitted:
  cpu    — CPU usage %, temperature
  ram    — RAM usage %, GB used/total/avail, swap %
  gpu    — GPU usage %, temperature, name
  disk   — Disk used/avail GB, usage %
  net    — Network radio, connection, SSID, signal, down/up speeds
  fan    — Fan RPMs, percents, temps, thermal profile

Usage: python3 quickshell_backend.py
"""

import json
import os
import subprocess
import sys
import threading
import time
import signal as signal_mod
from datetime import datetime

# ── Configuration ────────────────────────────────────────────────────────────
POLL_CPU     = 4    # seconds
POLL_RAM     = 4
POLL_GPU     = 4
POLL_DISK    = 30
POLL_NET     = 3
POLL_FAN     = 5

# ── Fan sysfs paths (Alienware) ──────────────────────────────────────────────
HWMON_SMM  = "/sys/class/hwmon/hwmon5"
HWMON_AWCC = "/sys/class/hwmon/hwmon4"
PLATFORM_PROFILE = "/sys/class/platform-profile/platform-profile-0"

_running = True
_cpu_cursor = ""


def _log(msg: str) -> None:
    """Log to stderr (Quickshell picks it up)."""
    ts = datetime.now().strftime("%H:%M:%S")
    print(f"[{ts}] [backend] {msg}", file=sys.stderr, flush=True)


def _emit(data: dict) -> None:
    """Write a single JSON line to stdout (flushed)."""
    try:
        print(json.dumps(data, separators=(",", ":")), flush=True)
    except BrokenPipeError:
        global _running
        _running = False
    except Exception:
        pass


def _read_sys(path: str) -> str:
    """Read a sysfs file, return stripped content or empty string."""
    try:
        with open(path) as f:
            return f.read().strip()
    except Exception:
        return ""


def _run_cmd(cmd: list[str], timeout: int = 5) -> tuple[int, str]:
    """Run a subprocess, return (rc, stdout)."""
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return r.returncode, r.stdout.strip()
    except Exception:
        return 1, ""


# ══════════════════════════════════════════════════════════════════════════════
# DATA FETCHERS
# ══════════════════════════════════════════════════════════════════════════════

def fetch_cpu() -> dict:
    global _cpu_cursor
    cmd = ["dgop", "meta", "--modules", "cpu", "--json"]
    if _cpu_cursor:
        cmd.extend(["--cpu-cursor", _cpu_cursor])

    rc, out = _run_cmd(cmd, timeout=3)
    if rc != 0 or not out:
        return {}

    try:
        d = json.loads(out)
        c = d.get("cpu", {})
        if "usage" not in c:
            return {}
        usage = round(c.get("usage", 0))
        temp  = round(c.get("temperature", 0))
        cur   = c.get("cursor", "")
        if cur:
            _cpu_cursor = cur
        return {"t": "cpu", "u": usage, "tmp": temp}
    except Exception:
        return {}


def fetch_ram() -> dict:
    try:
        with open("/proc/meminfo") as f:
            lines = f.read()
    except FileNotFoundError:
        return {}

    mem_total = mem_avail = swap_total = swap_free = 0
    for line in lines.splitlines():
        parts = line.split()
        if len(parts) < 2:
            continue
        key, val = parts[0], int(parts[1])
        if key == "MemTotal:":
            mem_total = val
        elif key == "MemAvailable:":
            mem_avail = val
        elif key == "SwapTotal:":
            swap_total = val
        elif key == "SwapFree:":
            swap_free = val

    if mem_total <= 0 or mem_avail <= 0:
        return {}

    used = mem_total - mem_avail
    return {
        "t": "ram",
        "p": round(used * 100 / mem_total),
        "ug": round(used / 1048576, 1),
        "tg": round(mem_total / 1048576, 1),
        "ag": round(mem_avail / 1048576, 1),
        "sp": round((swap_total - swap_free) * 100 / swap_total) if swap_total > 0 else 0,
    }


def fetch_gpu() -> dict:
    # Try NVIDIA first
    rc, out = _run_cmd(
        ["nvidia-smi", "--query-gpu=utilization.gpu,temperature.gpu,name",
         "--format=csv,noheader,nounits"],
        timeout=3,
    )
    if rc == 0 and out and "failed" not in out.lower():
        parts = out.split(", ")
        if len(parts) >= 2:
            pct = int(parts[0].strip() or "-1")
            tmp = int(parts[1].strip() or "0")
            name = parts[2].strip() if len(parts) > 2 else "NVIDIA"
            name = name.replace("NVIDIA GeForce ", "").replace("GeForce ", "")
            return {"t": "gpu", "u": pct, "tmp": tmp, "n": name}

    # Fallback: sysfs (AMD/Intel)
    pct, tmp, name = -1, 0, "GPU"
    for card in sorted(os.listdir("/sys/class/drm")):
        if not card.startswith("card"):
            continue
        cpath = f"/sys/class/drm/{card}"
        vendor = _read_sys(f"{cpath}/device/vendor")
        if "10de" in vendor:
            name = "NVIDIA"
        elif "8086" in vendor:
            name = "Intel"
        elif "1002" in vendor:
            name = "AMD"

        busy = _read_sys(f"{cpath}/device/gpu_busy_percent")
        if busy:
            try:
                pct = int("".join(filter(str.isdigit, busy)))
                break
            except ValueError:
                pass

        freq = _read_sys(f"{cpath}/gt_act_freq_mhz") or _read_sys(f"{cpath}/gt_cur_freq_mhz")
        maxf = _read_sys(f"{cpath}/gt_max_freq_mhz") or _read_sys(f"{cpath}/gt_RP0_freq_mhz")
        if freq and maxf:
            try:
                pct = int(int(freq) * 100 / int(maxf))
                break
            except (ValueError, ZeroDivisionError):
                pass

    return {"t": "gpu", "u": pct, "tmp": tmp, "n": name}


def fetch_disk() -> dict:
    rc, out = _run_cmd(["dgop", "disk", "--json"], timeout=5)
    if rc != 0 or not out:
        return {}

    try:
        d = json.loads(out)
    except Exception:
        return {}

    for m in d.get("mounts", []):
        if m.get("mount") != "/":
            continue
        raw = m.get("used", "0G").strip()
        num = float("".join(c for c in raw if c.isdigit() or c == ".") or "0")
        if raw.upper().endswith("T"):
            num *= 1024
        elif raw.upper().endswith("M"):
            num /= 1024
        used_gb = round(num)

        raw_a = m.get("avail", "0G").strip()
        num_a = float("".join(c for c in raw_a if c.isdigit() or c == ".") or "0")
        if raw_a.upper().endswith("T"):
            num_a *= 1024
        elif raw_a.upper().endswith("M"):
            num_a /= 1024
        avail_gb = round(num_a)

        pct_str = m.get("percent", "0%").rstrip("%")
        return {"t": "disk", "ug": used_gb, "ag": avail_gb, "p": int(pct_str)}

    return {}


def fetch_network(prev_rx: float, prev_tx: float) -> tuple[dict, float, float]:
    """Returns (data_dict, new_rx, new_tx)."""
    # Radio state
    radio = "disabled"
    rc, out = _run_cmd(["nmcli", "radio", "wifi"], timeout=3)
    if rc == 0 and out:
        radio = out.strip().lower()

    # Connection info — single nmcli call
    conn_type, ssid, signal_ = "none", "", 0
    rc, out = _run_cmd(
        ["env", "LANG=C", "nmcli", "-t", "-f", "TYPE,STATE,DEVICE,CONNECTION", "dev", "status"],
        timeout=4,
    )
    if rc == 0 and out:
        eth_iface = wifi_iface = ""
        for line in out.splitlines():
            parts = line.split(":")
            if len(parts) < 4:
                continue
            dtype, state, device = parts[0], parts[1], parts[2]
            if dtype == "ethernet" and state == "connected":
                eth_iface = device
            elif dtype == "wifi" and state == "connected":
                wifi_iface = device

        if eth_iface:
            conn_type = "ethernet"
        elif wifi_iface:
            conn_type = "wifi"
            # Get SSID + signal in one call (LANG=C ensures "yes" not "sí")
            rc2, out2 = _run_cmd(
                ["env", "LANG=C", "nmcli", "-t", "-f", "active,ssid,signal", "dev", "wifi", "list"],
                timeout=4,
            )
            if rc2 == 0 and out2:
                for wl in out2.splitlines():
                    if wl.startswith("yes:"):
                        wparts = wl.split(":")
                        if len(wparts) >= 3:
                            ssid = wparts[1]
                            try:
                                signal_ = int(wparts[2])
                            except ValueError:
                                pass
                        break

    # Speeds from /proc/net/dev
    rx, tx = prev_rx, prev_tx
    down_speed, up_speed = 0.0, 0.0
    try:
        # Find default interface
        iface = ""
        with open("/proc/net/route") as f:
            for rl in f:
                rparts = rl.split()
                if len(rparts) > 4 and rparts[1] != "00000000" and rparts[3] == "0003":
                    continue
                if len(rparts) > 1 and rparts[1] == "00000000":
                    iface = rparts[0]
                    break
        if not iface:
            with open("/proc/net/dev") as f:
                for dl in f.readlines()[2:]:
                    if ":" in dl and not dl.strip().startswith("lo"):
                        iface = dl.split(":")[0].strip()
                        break

        if iface:
            with open("/proc/net/dev") as f:
                for dl in f:
                    if dl.startswith(f"{iface}:"):
                        dparts = dl.split()
                        if len(dparts) >= 10:
                            rx = float(dparts[1])
                            tx = float(dparts[9])
                        break

        if prev_rx >= 0:
            down_speed = max(0, rx - prev_rx)
            up_speed = max(0, tx - prev_tx)
    except Exception:
        pass

    data = {
        "t": "net",
        "r": radio == "enabled",
        "ct": conn_type,
        "s": ssid,
        "sg": signal_,
        "ds": round(down_speed, 1),
        "us": round(up_speed, 1),
        "c": conn_type != "none",
    }
    return data, rx, tx


def fetch_fan() -> dict:
    rpm1 = _read_sys(f"{HWMON_SMM}/fan1_input")
    rpm2 = _read_sys(f"{HWMON_SMM}/fan2_input")
    max1 = _read_sys(f"{HWMON_SMM}/fan1_max") or "3700"
    max2 = _read_sys(f"{HWMON_SMM}/fan2_max") or "4000"

    r1 = int(rpm1) if rpm1 else 0
    r2 = int(rpm2) if rpm2 else 0
    m1 = int(max1) if max1 else 3700
    m2 = int(max2) if max2 else 4000

    p1 = round(r1 * 100 / m1) if m1 > 0 and r1 > 0 else 0
    p2 = round(r2 * 100 / m2) if m2 > 0 and r2 > 0 else 0

    # Temps
    t1_raw = _read_sys(f"{HWMON_AWCC}/temp1_input")
    t2_raw = _read_sys(f"{HWMON_AWCC}/temp2_input")
    t1 = int(t1_raw) // 1000 if t1_raw else 0
    t2 = int(t2_raw) // 1000 if t2_raw else 0

    # Profile
    profile = _read_sys(f"{PLATFORM_PROFILE}/profile")

    avail = r1 > 0 or r2 > 0

    return {
        "t": "fan",
        "r1": r1, "r2": r2,
        "p1": p1, "p2": p2,
        "t1": t1, "t2": t2,
        "pr": profile,
        "a": avail,
    }


# ══════════════════════════════════════════════════════════════════════════════
# WORKER THREADS
# ══════════════════════════════════════════════════════════════════════════════

def _poll(fn, interval: int) -> None:
    """Generic poller: call fn(), emit result, sleep interval."""
    while _running:
        data = fn()
        if data:
            _emit(data)
        time.sleep(interval)


def _poll_network() -> None:
    """Network poller with state tracking for speed calculation."""
    rx, tx = -1.0, -1.0
    while _running:
        data, rx, tx = fetch_network(rx, tx)
        _emit(data)
        time.sleep(POLL_NET)


def _signal_handler(signum, frame) -> None:
    global _running
    _running = False


def main() -> None:
    global _cpu_cursor, _running

    _log("Starting system data backend...")

    signal_mod.signal(signal_mod.SIGINT, _signal_handler)
    signal_mod.signal(signal_mod.SIGTERM, _signal_handler)

    # Restore CPU cursor
    cursor_file = "/tmp/qs-cpu-cursor"
    if os.path.exists(cursor_file):
        try:
            with open(cursor_file) as f:
                _cpu_cursor = f.read().strip()
        except Exception:
            pass

    threads = [
        threading.Thread(target=_poll, args=(fetch_cpu, POLL_CPU), daemon=True),
        threading.Thread(target=_poll, args=(fetch_ram, POLL_RAM), daemon=True),
        threading.Thread(target=_poll, args=(fetch_gpu, POLL_GPU), daemon=True),
        threading.Thread(target=_poll, args=(fetch_disk, POLL_DISK), daemon=True),
        threading.Thread(target=_poll_network, daemon=True),
        threading.Thread(target=_poll, args=(fetch_fan, POLL_FAN), daemon=True),
    ]

    for t in threads:
        t.start()

    _log(f"Running {len(threads)} poller threads")

    # Keep alive
    while _running:
        time.sleep(0.5)

    _log("Shutting down")


if __name__ == "__main__":
    main()
