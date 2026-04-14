#!/bin/bash

# List of packages timestamps:

#!/bin/bash
set -euo pipefail

# Load common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Initialize log
init_log "hypr-pkgs"

packages=(
  swww               # Wallpaper
  swaybg            
  matugen
  pactl              # Audio 
  wpctl
  pw-dump
  mpdris2
  cava               # Audio visualizer for terminal
  bluex              # Bluetooth
  grim               # Screenshot
  slurp
  wl-clipboard       # Clipboard
  cliphist           # Clipboard manager 
  magickw
  mako               # Notification daemon 
  brightnessctl      # Brightness
  curl               # Network / Weather
  fd                 # File search / Launcher
  xdg-utils
  awk                # Verificar cuales viene por defecto
  pkill
  pgrep
  nohup
  bash
  coreutils
)

install_packages() {
    local -n packages=$1
    local failed=0
    
    for pkg in "${packages[@]}"; do
        install_pkg "$pkg" || ((failed++))
    done
    
    return $failed
}

log_info "Installing main packages..."
for pkg in "${packages[@]}"; do
  install_pkg "$pkg" || ((failed++))
done

total=$((${#packages[@]}))
installation_summary $total $failed "quickshell packages installation"
exit $?
