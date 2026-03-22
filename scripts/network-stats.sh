#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# network-stats.sh — Wifi + Network speeds
#
# Output (3 lines):
#   Line 1: nmcli radio wifi state (enabled/disabled)
#   Line 2: active:ssid:signal (from nmcli)
#   Line 3: rx_bytes tx_bytes (from /proc/net/dev)
# ─────────────────────────────────────────────────────────────────────────────

# Line 1: WiFi radio state
LANG=C nmcli radio wifi 2>/dev/null

# Line 2: Active connection info
LANG=C nmcli -t -f active,ssid,signal dev wifi list 2>/dev/null | grep '^yes:' | head -1

# Line 3: Network bytes (rx tx) from default interface
iface=$(ip route show default 2>/dev/null | awk 'NR==1{print $5; exit}')
if [ -z "$iface" ]; then
    iface=$(awk 'NR>2 && $1!="lo:"{gsub(":",""); print $1; exit}' /proc/net/dev)
fi
awk -v i="${iface}:" '$1==i{print $2, $10}' /proc/net/dev
