#!/usr/bin/env bash
# packages.sh — Install necessary packages for quickshell to work
# Each entry is: [cmd_to_check]="real_package_name_in_dnf|real_package_name_in_pacman|real_package_name_in_apt"
# If command and package have the same name, you can use the short form of the array (see SIMPLE_PKGS below).

set -euo pipefail
IFS=$'\n\t'

# ── Packages where command name == package name ────────────────────────────────
SIMPLE_PKGS=(
  swww               # Wallpaper daemon
  matugen            # Material You color generation
  cava               # Audio visualizer
  grimblast          # Screenshot wrapper sobre grim
  grim               # Screenshot
  slurp              # Screenshot selection
  mako               # Notification daemon
  brightnessctl      # Brightness control
  curl               # HTTP client (WeatherProvider, geolocalizacion)
  kitty              # Terminal (usado por SpotlightModal para comandos de shell)
  geoclue2           # Location service (weather info)
)

# ── Packages where cmd != name of package in the package manager ────────────────────
# Format: ["binary_command"]="dnf_pkg|pacman_pkg|apt_pkg"
#   - Use the same name in all if it matches
#   - Use "*" if it doesn't apply to that distribution
declare -A MAPPED_PKGS=(

  # fd — usado en spotlight-search.py for file searching
  ["fd"]="fd|fd|fd-find"
  
  # quickshell_backend.py, cpu-detail.sh, disk-detail.sh
  ["dgop"]="dgop|dgop|dgop"

  # Bluetooth nativo QML (Quickshell.Bluetooth) — the real package is bluez
  ["bluetoothctl"]="bluez|bluez|bluez"

  # wl-clipboard provee los comandos wl-copy y wl-paste
  ["wl-copy"]="wl-clipboard|wl-clipboard|wl-clipboard"

  # cliphist — clipboard history tool
  ["cliphist"]="cliphist|cliphist|cliphist"

  # ImageMagick: "magick" v7, "convert" v6
  ["magick"]="ImageMagick|imagemagick|imagemagick"

  # mpDris2 — puente MPD → MPRIS2
  ["mpDris2"]="mpDris2|mpdris2|mpdris2"

  # pciutils (lspci) — used in gpu-detail.sh to get GPU info from PCI bus
  ["lspci"]="pciutils|pciutils|pciutils"

  # libnotify — notify-send — used in screenshot.sh
  ["notify-send"]="libnotify|libnotify|libnotify"

  # NetworkManager — nmcli — red WiFi/Ethernet in  backend and CcWifiPanel
  ["nmcli"]="NetworkManager|networkmanager|network-manager"

  # xdg-utils — xdg-open — used in spotlight-search.py
  ["xdg-open"]="xdg-utils|xdg-utils|xdg-utils"
)

_install_pkg() {
    local dnf_pkg="$1" pac_pkg="$2" apt_pkg="$3"
    if command -v dnf &>/dev/null; then
        [[ "$dnf_pkg" != "*" ]] && sudo dnf install -y "$dnf_pkg" && return
    elif command -v pacman &>/dev/null; then
        [[ "$pac_pkg" != "*" ]] && sudo pacman -S --noconfirm "$pac_pkg" && return
    elif command -v apt &>/dev/null; then
        [[ "$apt_pkg" != "*" ]] && sudo apt install -y "$apt_pkg" && return
    fi
    echo "Package manager not recognized or package not available." >&2
    return 1
}

failed=0
total=0

echo "Verifying and installing packages..."
echo ""

for pkg in "${SIMPLE_PKGS[@]}"; do
    ((total++))
    if command -v "$pkg" &>/dev/null; then
        echo "   ✅ $pkg"
    else
        echo "   ⬇  $pkg — installing..."
        _install_pkg "$pkg" "$pkg" "$pkg" || { ((failed++)); echo "   ❌ $pkg failed"; }
    fi
done

# ── Packages where cmd != name of package in the package manager ────────────────────
for cmd in "${!MAPPED_PKGS[@]}"; do
    ((total++))
    IFS='|' read -r dnf_pkg pac_pkg apt_pkg <<< "${MAPPED_PKGS[$cmd]}"
    if command -v "$cmd" &>/dev/null; then
        echo "   ✅ $cmd"
    else
        echo "   ⬇  $cmd — installing..."
        _install_pkg "$dnf_pkg" "$pac_pkg" "$apt_pkg" || { ((failed++)); echo "   ❌ $cmd failed"; }
    fi
done

echo ""
echo "════════════════════════════════════════"
echo "  Packages: $total total, $failed failed"
echo "════════════════════════════════════════"

exit "$failed"
