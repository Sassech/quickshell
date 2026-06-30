#!/usr/bin/env bash
# packages.sh — Install necessary packages for quickshell (Fedora/dnf only)
set -uo pipefail
# Note: set -e intentionally omitted — we collect failures and report at the end
# instead of aborting mid-run. The caller (install.sh) checks exit code.

# Require root for package installation
if [[ "$EUID" -ne 0 ]]; then
    echo "⚠️  This script needs root to install packages."
    echo "   Run: sudo $0"
    exit 1
fi

LOG_FILE="${LOG_FILE:-/tmp/quickshell-install.log}"

# ── Packages where binary name == dnf package name ────────────────────────────
# swww=wallpaper daemon, matugen=Material You colors, cava=audio visualizer,
# grim/slurp=screenshot, mako=notifications, brightnessctl=backlight,
# curl=HTTP client, kitty=terminal
SIMPLE_PKGS=(
  swww
  matugen
  cava
  grimblast
  grim
  slurp
  mako
  brightnessctl
  curl
  kitty
)

# ── Packages where binary != dnf package name ─────────────────────────────────
# Format: ["binary_to_check"]="dnf_package_name"
declare -A MAPPED_PKGS=(
  ["fd"]="fd"                    # spotlight-search.py file search
  ["bluetoothctl"]="bluez"       # Quickshell.Bluetooth native QML
  ["wl-copy"]="wl-clipboard"     # clipboard (wl-copy / wl-paste)
  ["cliphist"]="cliphist"        # clipboard history
  ["magick"]="ImageMagick"       # image processing (v7)
  ["lspci"]="pciutils"           # gpu-detail.sh
  ["notify-send"]="libnotify"    # screenshot.sh notifications
  ["nmcli"]="NetworkManager"     # WiFi/Ethernet backend
  ["xdg-open"]="xdg-utils"      # spotlight-search.py
)

# ── Packages with no binary — checked via systemd service ─────────────────────
# Format: ["systemd_service_name"]="dnf_package_name"
declare -A SERVICE_PKGS=(
  ["geoclue"]="geoclue2"         # location service for weather
  ["mpDris2"]="mpDris2"          # MPD → MPRIS2 bridge (Python app, service-based)
)

# ── Packages not in standard Fedora repos — manual install required ────────────
# These are skipped by dnf but flagged with instructions at the end.
declare -A MANUAL_PKGS=(
  ["dgop"]="https://github.com/niceDev0/dgop — dgop (disk/gpu info tool, build from source)"
)

# ── dnf options — quiet + timeout prevents hanging on slow/dead mirrors ────────
# Full output goes to LOG_FILE; only ✅/❌/⚠️ lines shown on terminal.
DNF_OPTS=(-y -q --setopt=timeout=30 --setopt=minrate=1000)

# ──────────────────────────────────────────────────────────────────────────────

failed=0
total=0
skipped_manual=()

# Helper: safe increment — avoids set -e footgun with (( var++ )) when var=0
inc() { eval "$1=$(( ${!1} + 1 ))"; }

# Helper: run dnf silently on terminal, full output to log
dnf_install() {
    local pkg="$1"
    dnf install "${DNF_OPTS[@]}" "$pkg" >> "$LOG_FILE" 2>&1
}

echo "Verifying and installing packages..."
echo "   (full dnf output → $LOG_FILE)"
echo ""

for pkg in "${SIMPLE_PKGS[@]}"; do
    inc total
    if command -v "$pkg" &>/dev/null; then
        echo "   ✅ $pkg"
    else
        echo "   ⬇  $pkg — installing..."
        if dnf_install "$pkg"; then
            echo "   ✅ $pkg installed"
        else
            inc failed
            echo "   ❌ $pkg — install failed (see $LOG_FILE)"
        fi
    fi
done

for cmd in "${!MAPPED_PKGS[@]}"; do
    inc total
    pkg="${MAPPED_PKGS[$cmd]}"
    if command -v "$cmd" &>/dev/null; then
        echo "   ✅ $cmd"
    else
        echo "   ⬇  $cmd ($pkg) — installing..."
        if dnf_install "$pkg"; then
            echo "   ✅ $cmd installed"
        else
            inc failed
            echo "   ❌ $cmd ($pkg) — install failed (see $LOG_FILE)"
        fi
    fi
done

for svc in "${!SERVICE_PKGS[@]}"; do
    inc total
    pkg="${SERVICE_PKGS[$svc]}"
    if systemctl list-unit-files "${svc}.service" 2>/dev/null | grep -q "$svc"; then
        echo "   ✅ $svc (service)"
    else
        echo "   ⬇  $svc ($pkg) — installing..."
        if dnf_install "$pkg"; then
            echo "   ✅ $svc installed"
        else
            inc failed
            echo "   ❌ $svc ($pkg) — install failed (see $LOG_FILE)"
        fi
    fi
done

for tool in "${!MANUAL_PKGS[@]}"; do
    inc total
    if command -v "$tool" &>/dev/null; then
        echo "   ✅ $tool"
    else
        skipped_manual+=("$tool — ${MANUAL_PKGS[$tool]}")
        echo "   ⚠️  $tool — not in Fedora repos, manual install needed (see summary)"
    fi
done

echo ""
echo "════════════════════════════════════════"
echo "  Packages: $total total, $failed failed"
if [[ ${#skipped_manual[@]} -gt 0 ]]; then
    echo "  Manual installs needed:"
    for entry in "${skipped_manual[@]}"; do
        echo "    • $entry"
    done
fi
echo "════════════════════════════════════════"

# Exit 0 always — install.sh must not abort due to optional package failures.
# Failed count is shown in the summary above for the user to act on.
exit 0
