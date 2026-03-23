#!/usr/bin/env bash
# bt-pair.sh <MAC>
# Empareja y confia el dispositivo, verificando estado real.
set -euo pipefail
IFS=$'\n\t'

MAC="${1:-}"

if [[ -z "$MAC" ]]; then
  echo "Uso: $0 <MAC>" >&2
  exit 2
fi

if [[ ! "$MAC" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]; then
  echo "MAC inválida: $MAC" >&2
  exit 2
fi

run_bt() {
  printf '%s\n' "$@" | LANG=C bluetoothctl >/dev/null 2>&1 || true
}

is_paired() {
  LANG=C bluetoothctl info "$MAC" 2>/dev/null | grep -q "Paired: yes"
}

is_trusted() {
  LANG=C bluetoothctl info "$MAC" 2>/dev/null | grep -q "Trusted: yes"
}

# Ensure adapter is ready
run_bt "power on" "agent on" "default-agent" "pairable on" "discoverable on" "quit"

# Pair with retries
for _ in 1 2 3; do
  run_bt "pair $MAC" "quit"
  sleep 2
  if is_paired; then
    break
  fi
done

if ! is_paired; then
  echo "No se pudo emparejar: $MAC" >&2
  exit 1
fi

# Trust with retries
for _ in 1 2 3; do
  run_bt "trust $MAC" "quit"
  sleep 1
  if is_trusted; then
    break
  fi
done

if ! is_trusted; then
  echo "No se pudo confiar: $MAC" >&2
  exit 1
fi

# Try connecting once (best effort)
LANG=C bluetoothctl connect "$MAC" >/dev/null 2>&1 || true

exit 0
