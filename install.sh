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
# 1. Regla sudoers para set-power-mode.sh
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "▶ Configurando regla sudoers para set-power-mode.sh..."
echo "$CURRENT_USER ALL=(ALL) NOPASSWD: $SCRIPT_DIR/scripts/set-power-mode.sh" \
    | sudo tee /etc/sudoers.d/quickshell-power > /dev/null
sudo chmod 440 /etc/sudoers.d/quickshell-power

if sudo visudo -c &>/dev/null; then
    ok "Regla sudoers instalada."
else
    echo "❌ Error en la sintaxis de sudoers. Revisa manualmente."
    exit 1
fi

# ─────────────────────────────────────────────────────────────────────────────
# 2. mpDris2  —  puente MPD → MPRIS2 (necesario para rmpc y otros clientes MPD)
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "▶ Instalando mpDris2..."

if command -v mpDris2 &>/dev/null; then
    ok "mpDris2 ya está instalado."
else
    if command -v dnf &>/dev/null; then
        sudo dnf install -y mpdris2
        ok "mpdris2 instalado via dnf."
    elif command -v pacman &>/dev/null; then
        sudo pacman -S --noconfirm mpdris2
        ok "mpdris2 instalado via pacman."
    elif command -v apt &>/dev/null; then
        sudo apt install -y mpdris2
        ok "mpdris2 instalado via apt."
    else
        warn "Gestor de paquetes no reconocido. Instala mpdris2 manualmente."
    fi
fi

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
echo ""
ok "Instalación completa. Reinicia la sesión si es un entorno nuevo."
