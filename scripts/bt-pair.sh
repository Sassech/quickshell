#!/bin/bash
# bt-pair.sh <MAC>
# Realiza pair + trust completo con agente activo y esperas adecuadas.
# Los comandos se envían con tiempos entre sí para que el handshake
# de bonding termine antes del siguiente paso.
set -e
MAC="$1"
(
  echo "agent on"
  echo "default-agent"
  echo "pairable on"
  sleep 1
  echo "pair $MAC"
  sleep 10   # espera el handshake BT Classic (puede tardar varios segundos)
  echo "trust $MAC"
  sleep 1
  echo "quit"
) | bluetoothctl
