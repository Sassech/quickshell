#!/bin/bash
# ds4-led.sh <r> <g> <b> [global]
# Cambia el color del LED del DS4/DualShock 4.
# Ejemplo: ds4-led.sh 255 0 0        → rojo
#          ds4-led.sh 0 0 0          → apagado
#          ds4-led.sh 64 0 64        → morado tenue
#          ds4-led.sh 0 0 64 0       → global off (apaga el LED completamente)
R="${1:-0}"
G="${2:-0}"
B="${3:-0}"
GLOBAL="${4:-1}"

# Busca el directorio leds del DS4 (054C:09CC = DualShock 4)
# BT  → /sys/devices/virtual/misc/uhid/0005:054C:09CC.XXXX/leds/
# USB → /sys/devices/.../usb.../0003:054C:09CC.XXXX/leds/
LED_BASE=$(find /sys/devices -path "*054C:09CC*/leds" -maxdepth 8 \
    -type d 2>/dev/null | head -1)

if [ -z "$LED_BASE" ]; then
    echo "No se encontró el LED del DS4" >&2
    exit 1
fi

# El nombre del nodo input puede variar (input62, input83, etc.)
INPUT_NODE=$(ls "$LED_BASE" | grep ':red$' | sed 's/:red//')

echo "$R"      > "$LED_BASE/${INPUT_NODE}:red/brightness"
echo "$G"      > "$LED_BASE/${INPUT_NODE}:green/brightness"
echo "$B"      > "$LED_BASE/${INPUT_NODE}:blue/brightness"
echo "$GLOBAL" > "$LED_BASE/${INPUT_NODE}:global/brightness"
