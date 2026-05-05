#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

packages=(
  swww               # Wallpaper
# swaybg             # Wallpaper (fallback) (eliminado, no se usa)
  matugen            # Material You color generation
  mpDris2            # MPD → MPRIS2 bridge
  cava               # Audio visualizer for terminal
  bluez              # Bluetooth
  grimblast          # Screenshot grim wrapper
  grim               # Screenshot
  slurp              # Screen region selector
  wl-clipboard       # Clipboard (Wayland)
  cliphist           # Clipboard history manager
  magick             # Image manipulation
  mako               # Notification daemon
  brightnessctl      # Brightness control
  curl               # Network / Weather API
  fd                 # Fast file search
  xdg-utils          # xdg-open, etc.
)

install_packages() {
    local -n _pkgs=$1
    local failed=0

    for pkg in "${_pkgs[@]}"; do
        if ! command -v "$pkg" &>/dev/null; then
            echo "$pkg not found, installing..."
            if command -v dnf &>/dev/null; then
                sudo dnf install -y "$pkg" || ((failed++))
            elif command -v pacman &>/dev/null; then
                sudo pacman -S --noconfirm "$pkg" || ((failed++))
            elif command -v apt &>/dev/null; then
                sudo apt install -y "$pkg" || ((failed++))
            else
                echo "Package manager not recognized for installing $pkg"
                ((failed++))
            fi
        else
            echo "$pkg already installed."
        fi
    done

    return "$failed"
}

echo "▶ Installing packages..."
failed=0
install_packages packages || failed=$?

total=${#packages[@]}
echo ""
echo "════════════════════════════════════════"
echo "  Packages: $total total, $failed failed"
echo "════════════════════════════════════════"

exit "$failed"
