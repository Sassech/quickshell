#!/bin/bash
# install.sh — QuickShell configuration and package installer
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CURRENT_USER="${SUDO_USER:-$USER}"

# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────
ok()   { echo "✅ $*"; }
warn() { echo "⚠️  $*"; }
info() { echo "   $*"; }


# ─────────────────────────────────────────────────────────────────────────────
# 0. Install packages
# ─────────────────────────────────────────────────────────────────────────────
"${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/packages.sh"

# ─────────────────────────────────────────────────────────────────────────────
# 1. sudoers rules for quickshell scripts
# ─────────────────────────────────────────────────────────────────────────────
echo ""

# set-power-mode.sh
echo "$CURRENT_USER ALL=(ALL) NOPASSWD: $SCRIPT_DIR/scripts/set-power-mode.sh" \
    | sudo tee /etc/sudoers.d/quickshell-power > /dev/null

# fan-control.sh
echo "$CURRENT_USER ALL=(ALL) NOPASSWD: $SCRIPT_DIR/scripts/fan-control.sh" \
    | sudo tee /etc/sudoers.d/quickshell-fan > /dev/null

sudo chmod 440 /etc/sudoers.d/quickshell-power /etc/sudoers.d/quickshell-fan

if sudo visudo -c &>/dev/null; then
    ok "Reglas sudoers instaladas."
else
    echo "sudoers syntax error."
    exit 1
fi

# ─────────────────────────────────────────────────────────────────────────────
# 2. quickshell-backend — systemd user service to 
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "▶ Installing systemd user service..."

BACKEND_SERVICE_SRC="$SCRIPT_DIR/config/systemd/user/quickshell-backend.service"
BACKEND_SERVICE_DST="$HOME/.config/systemd/user/quickshell-backend.service"

mkdir -p "$HOME/.config/systemd/user"

# Replace __SCRIPT_DIR__ placeholder with actual path in the service file
sed "s|__SCRIPT_DIR__|$SCRIPT_DIR|g" "$BACKEND_SERVICE_SRC" > "$BACKEND_SERVICE_DST"

if [ "$EUID" -eq 0 ]; then
    sudo -u "$CURRENT_USER" systemctl --user daemon-reload
    sudo -u "$CURRENT_USER" systemctl --user enable quickshell-backend.service
    sudo -u "$CURRENT_USER" systemctl --user restart quickshell-backend.service
else
    systemctl --user daemon-reload
    systemctl --user enable quickshell-backend.service
    systemctl --user restart quickshell-backend.service
fi
ok "QuickShell backend service installed and started."

# ─────────────────────────────────────────────────────────────────────────────
# 4. mpDris2  —  bridge MPD → MPRIS2 (required for rmpc and other MPD clients)
# ─────────────────────────────────────────────────────────────────────────────

# mpDris2 configuration
MPDRIS2_CONF_DIR="$HOME/.config/mpDris2"
MPDRIS2_CONF="$MPDRIS2_CONF_DIR/mpDris2.conf"

if [ ! -f "$MPDRIS2_CONF" ]; then
    mkdir -p "$MPDRIS2_CONF_DIR"

    # Try to detect music_directory from mpd.conf, fallback to ~/Música if not found
    MPD_MUSIC_DIR=""
    MPD_CONF="$HOME/.config/mpd/mpd.conf"
    if [ -f "$MPD_CONF" ]; then
        MPD_MUSIC_DIR=$(grep -E '^\s*music_directory' "$MPD_CONF" | head -1 \
            | sed 's/.*music_directory[[:space:]]*"//;s/".*//')
    fi

    cat > "$MPDRIS2_CONF" <<EOF
[Connection]
host = 127.0.0.1
port = 6600

[Library]
music_dir = ${MPD_MUSIC_DIR:-~/Música}

[Bling]
mmkeys = False
notify = False
EOF
    ok "Configuración de mpDris2 creada en $MPDRIS2_CONF."
    [ -n "$MPD_MUSIC_DIR" ] && info "music_dir detectado desde mpd.conf: $MPD_MUSIC_DIR"
else
    ok "Configuración de mpDris2 ya existe, no se sobreescribe."
fi

# Enable and start mpDris2 service (with Restart=always)
echo ""
echo "▶ Habilitando servicio mpDris2 (systemd user)..."

# Drop-in: reinicio automático si el proceso muere
DROPIN_DIR="$HOME/.config/systemd/user/mpDris2.service.d"
mkdir -p "$DROPIN_DIR"
cat > "$DROPIN_DIR/restart.conf" <<'EOF'
[Service]
Restart=always
RestartSec=2
EOF

# Execute as current user if running as root, otherwise just run normally
if [ "$EUID" -eq 0 ]; then
    sudo -u "$CURRENT_USER" systemctl --user daemon-reload
    sudo -u "$CURRENT_USER" systemctl --user enable mpDris2.service
    sudo -u "$CURRENT_USER" systemctl --user restart mpDris2.service
else
    systemctl --user daemon-reload
    systemctl --user enable mpDris2.service
    systemctl --user restart mpDris2.service
fi
ok "Servicio mpDris2 habilitado e iniciado (Restart=always)."

# ─────────────────────────────────────────────────────────────────────────────
# 5. Geoclue2 — location provider for weather info
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "▶ Configuring geoclue2..."

GEOCLUE_CONF_DIR="/etc/geoclue/conf.d"
GEOCLUE_CONF="$GEOCLUE_CONF_DIR/quickshell.conf"

if [ -d "$GEOCLUE_CONF_DIR" ]; then
    if [ ! -f "$GEOCLUE_CONF" ]; then
        echo "[quickshell]
enable=true" | sudo tee "$GEOCLUE_CONF" > /dev/null
        ok "Configuration created at $GEOCLUE_CONF"
    else
        ok "Configuration for geoclue2 already exists."
    fi
    
    # Configure beaconDB as location provider (more accurate than Google)
    BEACONDB_CONF="$GEOCLUE_CONF_DIR/99-beacondb.conf"
    if [ ! -f "$BEACONDB_CONF" ]; then
        echo "[wifi]
enable=true
url=https://api.beacondb.net/v1/geolocate" | sudo tee "$BEACONDB_CONF" > /dev/null
        ok "Configuration for beaconDB created at $BEACONDB_CONF"
    else
        ok "Configuration for beaconDB already exists."
    fi
    
    sudo systemctl try-restart geoclue 2>/dev/null || sudo systemctl restart geoclue 2>/dev/null || true
    ok "Service geoclue restarted."
else
    warn "Directory $GEOCLUE_CONF_DIR does not exist. Install geoclue2 if you need location services."
fi

# ─────────────────────────────────────────────────────────────────────────────
echo ""
ok "Installation complete. Restart your session if this is a new environment."
