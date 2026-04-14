#!/bin/bash
# install.sh — Configura el entorno completo de quickshell
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
$XDG_CONFIG_HOME/quickshell/packages.sh

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
    echo "sudoers sintaxys error."
    exit 1
fi

# ─────────────────────────────────────────────────────────────────────────────
# 2. mpDris2  —  puente MPD → MPRIS2 (necesario para rmpc y otros clientes MPD)
# ─────────────────────────────────────────────────────────────────────────────

# Configuración de mpDris2
MPDRIS2_CONF_DIR="$HOME/.config/mpDris2"
MPDRIS2_CONF="$MPDRIS2_CONF_DIR/mpDris2.conf"

if [ ! -f "$MPDRIS2_CONF" ]; then
    mkdir -p "$MPDRIS2_CONF_DIR"

    # Intentar leer music_directory del mpd.conf del usuario
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

# Habilitar e iniciar el servicio systemd de usuario
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

# Ejecutar como el usuario real (no root)
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
# 3. Geoclue2 — permisos de ubicación para el clima
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "▶ Configurando geoclue2 para ubicación del clima..."

GEOCLUE_CONF_DIR="/etc/geoclue/conf.d"
GEOCLUE_CONF="$GEOCLUE_CONF_DIR/quickshell.conf"

if [ -d "$GEOCLUE_CONF_DIR" ]; then
    if [ ! -f "$GEOCLUE_CONF" ]; then
        echo "[quickshell]
enable=true" | sudo tee "$GEOCLUE_CONF" > /dev/null
        ok "Configuración de geoclue2 creada en $GEOCLUE_CONF"
    else
        ok "Configuración de geoclue2 ya existe."
    fi
    
    # Configurar beaconDB como proveedor de ubicación (más preciso que Google)
    BEACONDB_CONF="$GEOCLUE_CONF_DIR/99-beacondb.conf"
    if [ ! -f "$BEACONDB_CONF" ]; then
        echo "[wifi]
enable=true
url=https://api.beacondb.net/v1/geolocate" | sudo tee "$BEACONDB_CONF" > /dev/null
        ok "Configuración beaconDB creada en $BEACONDB_CONF"
    else
        ok "Configuración beaconDB ya existe."
    fi
    
    sudo systemctl try-restart geoclue 2>/dev/null || sudo systemctl restart geoclue 2>/dev/null || true
    ok "Servicio geoclue reiniciado."
else
    warn "Directorio $GEOCLUE_CONF_DIR no existe. Instala geoclue2 si necesitas ubicación."
fi

# ─────────────────────────────────────────────────────────────────────────────
echo ""
ok "Instalación completa. Reinicia la sesión si es un entorno nuevo."
