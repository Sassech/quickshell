#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# network-stats.sh — Network status (WiFi + Ethernet) + speeds
#
# Output (5 lines):
#   Line 1: wifi radio state (enabled/disabled)
#   Line 2: connection_type:ssid (wifi:SSID or ethernet: or none:)
#   Line 3: wifi_extra:signal:mac (wifi active) or empty
#   Line 4: ethernet:ip:mac:speed (ethernet active) or empty
#   Line 5: rx_bytes tx_bytes (from /proc/net/dev)
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
# NOT set -e: grep returning 1 (no match) is expected in many pipelines below

# Line 1: WiFi radio state
LANG=C nmcli radio wifi 2>/dev/null || echo "disabled"

# Line 2: Connection type + SSID
# Check ethernet first (more reliable when both are connected)
ETH_IFACE=$(LANG=C nmcli -t -f DEVICE,TYPE,STATE dev 2>/dev/null \
    | grep ':ethernet:connected' | cut -d: -f1 | head -1)
if [ -n "$ETH_IFACE" ]; then
    echo "ethernet:"
else
    SSID=$(LANG=C nmcli -t -f active,ssid dev wifi list 2>/dev/null \
        | grep '^yes:' | cut -d: -f2- | head -1)
    echo "wifi:${SSID:-}"
fi

# Line 3: WiFi extra info (signal, MAC)
WIFI_IFACE=$(LANG=C nmcli -t -f DEVICE,TYPE,STATE dev 2>/dev/null \
    | grep ':wifi:connected' | cut -d: -f1 | head -1)
if [ -n "$WIFI_IFACE" ]; then
    SIGNAL=$(LANG=C nmcli -t -f active,signal dev wifi list 2>/dev/null \
        | grep '^yes:' | cut -d: -f2 | head -1)
    MAC=$(LANG=C nmcli -g GENERAL.HWADDR dev show "$WIFI_IFACE" 2>/dev/null)
    echo "wifi_extra:${SIGNAL:-0}:${MAC:-}"
else
    echo ""
fi

# Line 4: Ethernet info (ip, mac, speed)
if [ -n "$ETH_IFACE" ]; then
    ETH_IP=$(LANG=C nmcli -t -f IP4.ADDRESS dev show "$ETH_IFACE" 2>/dev/null \
        | cut -d: -f2 | head -1 | cut -d/ -f1)
    ETH_MAC=$(LANG=C nmcli -g GENERAL.HWADDR dev show "$ETH_IFACE" 2>/dev/null)
    ETH_SPEED=$(ethtool "$ETH_IFACE" 2>/dev/null | grep "Speed:" | awk '{print $2}')
    echo "ethernet:${ETH_IP:-}:${ETH_MAC:-}:${ETH_SPEED:-Unknown}"
else
    echo ""
fi

# Line 5: Network bytes (rx tx) from default interface
iface=$(ip route show default 2>/dev/null | awk 'NR==1{print $5; exit}')
if [ -z "$iface" ]; then
    iface=$(awk 'NR>2 && $1!="lo:"{gsub(":",""); print $1; exit}' /proc/net/dev)
fi
if [ -n "$iface" ]; then
    awk -v i="${iface}:" '$1==i{print $2, $10}' /proc/net/dev
else
    echo "0 0"
fi
