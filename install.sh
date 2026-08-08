#!/bin/bash
# install.sh — QuickShell configuration and package installer
set -euo pipefail

# Require root — re-launch with sudo automatically
if [[ "$EUID" -ne 0 ]]; then
    exec sudo bash "$0" "$@"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CURRENT_USER="${SUDO_USER:-$USER}"
USER_HOME="$(getent passwd "$CURRENT_USER" | cut -d: -f6)"
USER_UID="$(id -u "$CURRENT_USER")"
LOG_FILE="/tmp/quickshell-install.log"
export LOG_FILE

# Start with a fresh log for this run
: > "$LOG_FILE"
echo "QuickShell install log — $(date)" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# Run a systemd --user command as the original (non-root) user.
# Uses runuser (no login shell) to avoid sourcing .bashrc/.zshrc which can
# hang waiting for Wayland sockets or display servers.
# Full output goes to LOG_FILE; only errors are shown on terminal.
user_systemctl() {
    runuser -u "$CURRENT_USER" -- \
        env XDG_RUNTIME_DIR="/run/user/${USER_UID}" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${USER_UID}/bus" \
        systemctl --user "$@" >> "$LOG_FILE" 2>&1
}

# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────
ok()   { echo "✅ $*"; }
warn() { echo "⚠️  $*"; }
info() { echo "   $*"; }

# ─────────────────────────────────────────────────────────────────────────────
# 0. Install packages
# ─────────────────────────────────────────────────────────────────────────────
"$SCRIPT_DIR/packages.sh" || true
# packages.sh always exits 0; failures are reported in its summary.

# ─────────────────────────────────────────────────────────────────────────────
# 0.5 Build and install qs-helper (Go binary)
# ─────────────────────────────────────────────────────────────────────────────
echo ""
info "▶ Compilando qs-helper (Go)..."
QS_HELPER_DIR="$SCRIPT_DIR/scripts/qs-helper"
QS_BIN_DIR="$USER_HOME/.local/bin"
mkdir -p "$QS_BIN_DIR"

if command -v go >/dev/null 2>&1; then
    if (cd "$QS_HELPER_DIR" && go build -trimpath -ldflags="-s -w" -o qs-helper .) >> "$LOG_FILE" 2>&1; then
        install -m 0755 "$QS_HELPER_DIR/qs-helper" "$QS_BIN_DIR/qs-helper"
        ok "qs-helper compilado e instalado en $QS_BIN_DIR/qs-helper."
    else
        warn "Fallo al compilar qs-helper. Ver $LOG_FILE. El repo conserva el binario precompilado."
    fi
else
    warn "Go no está instalado. Usando binario precompilado si existe."
    if [ -x "$QS_HELPER_DIR/qs-helper" ]; then
        install -m 0755 "$QS_HELPER_DIR/qs-helper" "$QS_BIN_DIR/qs-helper"
        ok "Binario precompilado instalado en $QS_BIN_DIR/qs-helper."
    else
        warn "No hay binario precompilado ni Go: los modales que usan qs-helper fallarán."
    fi
fi
chown -R "$CURRENT_USER:$CURRENT_USER" "$QS_BIN_DIR" 2>/dev/null || true

# ─────────────────────────────────────────────────────────────────────────────
# 1. sudoers rules for quickshell scripts
# ─────────────────────────────────────────────────────────────────────────────
echo ""

echo "$CURRENT_USER ALL=(ALL) NOPASSWD: $SCRIPT_DIR/scripts/set-power-mode.sh" \
    | tee /etc/sudoers.d/quickshell-power > /dev/null

echo "$CURRENT_USER ALL=(ALL) NOPASSWD: $SCRIPT_DIR/scripts/fan-control.sh" \
    | tee /etc/sudoers.d/quickshell-fan > /dev/null

chmod 440 /etc/sudoers.d/quickshell-power /etc/sudoers.d/quickshell-fan

# Validate only the files we just wrote, not the entire sudoers config
if visudo -c -f /etc/sudoers.d/quickshell-power &>/dev/null \
&& visudo -c -f /etc/sudoers.d/quickshell-fan &>/dev/null; then
    ok "Reglas sudoers instaladas."
else
    echo "sudoers syntax error in quickshell files."
    exit 1
fi

# ─────────────────────────────────────────────────────────────────────────────
# 2. mpDris2 — bridge MPD → MPRIS2
# ─────────────────────────────────────────────────────────────────────────────

MPDRIS2_CONF_DIR="$USER_HOME/.config/mpDris2"
MPDRIS2_CONF="$MPDRIS2_CONF_DIR/mpDris2.conf"

if [ ! -f "$MPDRIS2_CONF" ]; then
    mkdir -p "$MPDRIS2_CONF_DIR"

    MPD_MUSIC_DIR=""
    MPD_CONF="$USER_HOME/.config/mpd/mpd.conf"
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

echo ""
echo "▶ Habilitando servicio mpDris2 (systemd user)..."

DROPIN_DIR="$USER_HOME/.config/systemd/user/mpDris2.service.d"
mkdir -p "$DROPIN_DIR"
cat > "$DROPIN_DIR/restart.conf" <<'EOF'
[Service]
Restart=always
RestartSec=2
EOF

user_systemctl daemon-reload || true
user_systemctl enable mpDris2.service || true
# --no-block: don't wait for mpDris2 to fully start (MPD may not be running yet)
user_systemctl start --no-block mpDris2.service || true
ok "Servicio mpDris2 habilitado e iniciado (Restart=always)."

# ─────────────────────────────────────────────────────────────────────────────
# 3. Geoclue2 — location provider for weather info
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "▶ Configuring geoclue2..."

GEOCLUE_CONF_DIR="/etc/geoclue/conf.d"
GEOCLUE_CONF="$GEOCLUE_CONF_DIR/quickshell.conf"

if [ -d "$GEOCLUE_CONF_DIR" ]; then
    if [ ! -f "$GEOCLUE_CONF" ]; then
        printf '[quickshell]\nenable=true\n' > "$GEOCLUE_CONF"
        ok "Configuration created at $GEOCLUE_CONF"
    else
        ok "Configuration for geoclue2 already exists."
    fi

    BEACONDB_CONF="$GEOCLUE_CONF_DIR/99-beacondb.conf"
    if [ ! -f "$BEACONDB_CONF" ]; then
        printf '[wifi]\nenable=true\nurl=https://api.beacondb.net/v1/geolocate\n' > "$BEACONDB_CONF"
        ok "Configuration for beaconDB created at $BEACONDB_CONF"
    else
        ok "Configuration for beaconDB already exists."
    fi

    systemctl try-restart geoclue 2>/dev/null || systemctl restart geoclue 2>/dev/null || true
    ok "Service geoclue restarted."
else
    warn "Directory $GEOCLUE_CONF_DIR does not exist. Install geoclue2 if you need location services."
fi

# ─────────────────────────────────────────────────────────────────────────────
echo ""
ok "Installation complete. Restart your session if this is a new environment."

# Mark installation as done so .zshrc doesn't re-run this script
touch "$USER_HOME/.config/quickshell/config/.installed"
