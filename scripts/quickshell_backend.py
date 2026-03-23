#!/usr/bin/env python3
"""
Quickshell Backend Service

This service centralizes data fetching for various widgets (CPU, RAM, etc.)
to improve performance and reduce redundant system calls.
It writes updated data to dedicated FIFOs for QML components to consume.
"""

import json
import os
import sys
import subprocess
import time
import threading
import signal
from datetime import datetime

# --- Configuration ---
LOG_FILE = "/tmp/qs-backend.log"
CPU_FIFO = "/tmp/qs-cpu-fifo"
RAM_FIFO = "/tmp/qs-ram-fifo"
CPU_CURSOR_FILE = "/tmp/qs-cpu-cursor" # For dgop cursor management

POLL_INTERVAL_CPU = 2 # seconds
POLL_INTERVAL_RAM = 3 # seconds

# --- Global State ---
_running = True
_cpu_cursor = ""

# --- Helper Functions ---
def _log(msg: str) -> None:
    """Writes a log message to the LOG_FILE."""
    try:
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        with open(LOG_FILE, "a") as f:
            f.write(f"[{timestamp}] [backend] {msg}\n")
    except Exception as e:
        # Fallback to stderr if logging to file fails
        print(f"[{timestamp}] [backend] ERROR: Could not write to log file: {e} - {msg}", file=sys.stderr)

def _run_cmd(cmd: list[str], timeout: int = 5) -> tuple[int, str, str]:
    """Runs a subprocess command and returns (returncode, stdout, stderr)."""
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout
        )
        return result.returncode, result.stdout.strip(), result.stderr.strip()
    except subprocess.TimeoutExpired:
        _log(f"Command timed out: {' '.join(cmd)}")
        return 1, "", "TimeoutExpired"
    except FileNotFoundError:
        _log(f"Command not found: {' '.join(cmd)}")
        return 1, "", "FileNotFoundError"
    except Exception as e:
        _log(f"Error running command {' '.join(cmd)}: {e}")
        return 1, "", str(e)

def _write_to_fifo(fifo_path: str, content: str) -> None:
    """Writes content to a named pipe (FIFO). Creates the FIFO if it doesn't exist."""
    try:
        if not os.path.exists(fifo_path):
            os.mkfifo(fifo_path)
        with open(fifo_path, "w") as f:
            f.write(content + "\n")
    except Exception as e:
        _log(f"Error writing to FIFO {fifo_path}: {e}")

# --- Data Fetching Functions ---
def _get_cpu_stats() -> dict:
    """Fetches CPU usage and temperature using dgop."""
    global _cpu_cursor
    cmd = ["dgop", "meta", "--modules", "cpu", "--json"]
    if _cpu_cursor:
        cmd.extend(["--cpu-cursor", _cpu_cursor])

    returncode, stdout, stderr = _run_cmd(cmd, timeout=3)

    if returncode != 0:
        _log(f"dgop cpu command failed: {stderr}")
        return {}

    try:
        data = json.loads(stdout)
        cpu_data = data.get('cpu', {})
        usage = round(cpu_data.get('usage', 0))
        temp = round(cpu_data.get('temperature', 0))
        new_cursor = cpu_data.get('cursor', '')
        if new_cursor:
            _cpu_cursor = new_cursor
            # Persist cursor to file in case of restart
            with open(CPU_CURSOR_FILE, "w") as f:
                f.write(new_cursor)
        return {"usage": usage, "temperature": temp}
    except json.JSONDecodeError as e:
        _log(f"Error parsing dgop CPU JSON: {e} -> {stdout}")
        return {}
    except Exception as e:
        _log(f"Unexpected error in _get_cpu_stats: {e}")
        return {}

def _get_ram_stats() -> dict:
    """Fetches RAM statistics from /proc/meminfo."""
    try:
        with open("/proc/meminfo", "r") as f:
            meminfo = f.read()

        mem_total = 0
        mem_avail = 0
        mem_free = 0
        swap_total = 0
        swap_free = 0

        for line in meminfo.splitlines():
            if line.startswith("MemTotal:"):
                mem_total = int(line.split()[1]) # kB
            elif line.startswith("MemAvailable:"):
                mem_avail = int(line.split()[1]) # kB
            elif line.startswith("MemFree:"):
                mem_free = int(line.split()[1]) # kB
            elif line.startswith("SwapTotal:"):
                swap_total = int(line.split()[1]) # kB
            elif line.startswith("SwapFree:"):
                swap_free = int(line.split()[1]) # kB

        if mem_total <= 0:
            return {}

        mem_used = mem_total - mem_avail
        mem_percent = round((mem_used * 100) / mem_total) if mem_total > 0 else 0
        mem_used_gb = mem_used / (1024 * 1024)
        mem_total_gb = mem_total / (1024 * 1024)
        mem_avail_gb = mem_avail / (1024 * 1024)

        swap_used = swap_total - swap_free
        swap_percent = round((swap_used * 100) / swap_total) if swap_total > 0 else 0

        return {
            "percent": mem_percent,
            "used_gb": round(mem_used_gb, 1),
            "total_gb": round(mem_total_gb, 1),
            "avail_gb": round(mem_avail_gb, 1),
            "swap_percent": swap_percent
        }
    except FileNotFoundError:
        _log("/proc/meminfo not found. Cannot get RAM stats.")
        return {}
    except Exception as e:
        _log(f"Error getting RAM stats: {e}")
        return {}

# --- Periodic Tasks ---
def _cpu_task() -> None:
    """Fetches and writes CPU stats to FIFO."""
    while _running:
        stats = _get_cpu_stats()
        if stats:
            content = f"{stats['usage']}\n{stats['temperature']}"
            _write_to_fifo(CPU_FIFO, content)
        time.sleep(POLL_INTERVAL_CPU)

def _ram_task() -> None:
    """Fetches and writes RAM stats to FIFO."""
    while _running:
        stats = _get_ram_stats()
        if stats:
            content = (
                f"{stats['percent']}\n"
                f"{stats['used_gb']}\n"
                f"{stats['total_gb']}\n"
                f"{stats['avail_gb']}\n"
                f"{stats['swap_percent']}"
            )
            _write_to_fifo(RAM_FIFO, content)
        time.sleep(POLL_INTERVAL_RAM)

# --- Main Service Logic ---
def _cleanup() -> None:
    """Cleans up FIFOs on exit."""
    _log("Performing cleanup...")
    for f in [CPU_FIFO, RAM_FIFO, CPU_CURSOR_FILE]:
        if os.path.exists(f):
            try:
                os.remove(f)
                _log(f"Removed {f}")
            except OSError as e:
                _log(f"Error removing {f}: {e}")

def _signal_handler(signum, frame) -> None:
    """Handles termination signals."""
    global _running
    _log(f"Received signal {signum}. Shutting down.")
    _running = False

def main() -> None:
    """Main function to start the backend service."""
    global _cpu_cursor

    _log("Starting Quickshell Backend Service...")

    # Set up signal handlers for graceful shutdown
    signal.signal(signal.SIGINT, _signal_handler)
    signal.signal(signal.SIGTERM, _signal_handler)

    # Initialize CPU cursor from file if it exists
    if os.path.exists(CPU_CURSOR_FILE):
        try:
            with open(CPU_CURSOR_FILE, "r") as f:
                _cpu_cursor = f.read().strip()
            _log(f"Initialized CPU cursor from file: {_cpu_cursor}")
        except Exception as e:
            _log(f"Error reading CPU cursor file: {e}")

    # Ensure FIFOs are created before starting threads
    for fifo_path in [CPU_FIFO, RAM_FIFO]:
        if os.path.exists(fifo_path):
            os.remove(fifo_path) # Clean up old FIFOs
        os.mkfifo(fifo_path)
        _log(f"Created FIFO: {fifo_path}")

    # Start periodic tasks in separate threads
    cpu_thread = threading.Thread(target=_cpu_task, daemon=True)
    ram_thread = threading.Thread(target=_ram_task, daemon=True)

    cpu_thread.start()
    ram_thread.start()

    _log("Backend service running. Waiting for termination signal.")

    # Keep main thread alive until shutdown
    while _running:
        time.sleep(0.5)

    # Threads are daemon, so they will exit when main thread exits.
    # We could explicitly join them if needed for more complex cleanup.
    # cpu_thread.join()
    # ram_thread.join()

    _cleanup()
    _log("Quickshell Backend Service stopped.")

if __name__ == "__main__":
    main()
