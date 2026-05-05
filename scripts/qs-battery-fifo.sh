#!/usr/bin/env bash
# qs-battery-fifo — monitorea batería vía sysfs y emite eventos a Quickshell
# Eventos: "low:<pct>" | "state:<status>" | "full:<pct>"
# Comandos FIFO: "check" (forzar lectura), "stop" (salir)

set -euo pipefail

# ── Configuración ────────────────────────────────────────────────────────────
readonly FIFO="/tmp/qs-battery"
readonly POLL_INTERVAL=10          # segundos entre checks

# Umbrales de batería baja (de mayor a menor, cada uno se notifica una vez)
readonly LOW_THRESHOLDS="40 30 20"

# ── Detección de batería ─────────────────────────────────────────────────────
bat_path=""
for d in /sys/class/power_supply/BAT*; do
    [ -d "$d" ] && bat_path="$d" && break
done

if [ -z "$bat_path" ]; then
    # Sin batería — silencioso, salimos limpio
    exit 0
fi

# ── Funciones de lectura ─────────────────────────────────────────────────────
read_cap()   { cat "$bat_path/capacity" 2>/dev/null || echo "0"; }
read_status() { cat "$bat_path/status" 2>/dev/null || echo "Unknown"; }

# ── Estado previo ────────────────────────────────────────────────────────────
prev_cap=-1
prev_status=""
fired_low=-1   # último umbral low que ya disparó (evita repetir)

# ── Check y emisión de eventos ───────────────────────────────────────────────
check_and_emit() {
    local cap status
    cap=$(read_cap)
    status=$(read_status)
    cap=${cap:-0}
    status=${status:-Unknown}

    # Evitar lecturas idénticas
    if [ "$cap" = "$prev_cap" ] && [ "$status" = "$prev_status" ]; then
        return
    fi

    # ── Evento: carga completa ───────────────────────────────────────────
    if [ "$cap" -ge 100 ] || [ "$status" = "Full" ]; then
        if [ "$prev_status" != "Full" ] && [ "$prev_cap" -lt 100 ] 2>/dev/null; then
            echo "full:${cap}"
        fi
    fi

    # ── Evento: batería baja (solo si está descargando) ──────────────────
    if [ "$status" = "Discharging" ]; then
        for t in $LOW_THRESHOLDS; do
            if [ "$cap" -le "$t" ] && [ "$fired_low" -gt "$t" ] 2>/dev/null \
               || [ "$fired_low" = "-1" ] && [ "$cap" -le "$t" ]; then
                echo "low:${cap}"
                fired_low=$t
                break
            fi
        done
    fi

    # ── Reset de low si se conectó cargador o subió por encima del umbral ──
    if [ "$status" != "Discharging" ]; then
        fired_low=-1
    elif [ "$fired_low" -ne -1 ] && [ "$cap" -gt "$fired_low" ]; then
        fired_low=-1
    fi

    # ── Evento: cambio de estado (Charging ↔ Discharging) ───────────────
    if [ -n "$prev_status" ] && [ "$status" != "$prev_status" ]; then
        case "$status" in
            Charging|Discharging)
                echo "state:${status}:${cap}"
                ;;
        esac
    fi

    prev_cap=$cap
    prev_status=$status
}

# ── Main loop: polling + FIFO ────────────────────────────────────────────────
rm -f "$FIFO"
mkfifo "$FIFO"
exec 3<>"$FIFO"

# Primera lectura silenciosa (para setear estado sin emitir eventos)
prev_cap=$(read_cap)
prev_status=$(read_status)
# Inicializar fired_low si arranca baja
if [ "$prev_status" = "Discharging" ]; then
    for t in $LOW_THRESHOLDS; do
        if [ "$prev_cap" -le "$t" ]; then
            fired_low=$t
            break
        fi
    done
fi

while true; do
    # Leer FIFO con timeout (dd es POSIX-friendly para timeout)
    cmd=""
    if cmd=$(timeout "$POLL_INTERVAL" cat <&3 2>/dev/null); then
        case "$cmd" in
            stop) exit 0 ;;
            check) check_and_emit ;;
        esac
    fi
    # Si timeout → polling normal
    check_and_emit
done
