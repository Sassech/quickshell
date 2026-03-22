#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# network-stats.sh — Network status (WiFi + Ethernet) + speeds
#
# Output (5 lines):
#   Line 1: wifi radio state (enabled/disabled)
#   Line 2: connection_type:ssid (wifi:SSID or ethernet: or none:)
#   Line 3: wifi_extra:channel:linkSpeed:mac (wifi active) or empty
#   Line 4: ethernet:ip:mac:speed (ethernet active) or empty
#   Line 5: rx_bytes tx_bytes (from /proc/net/dev)
# ─────────────────────────────────────────────────────────────────────────────

# Line 1: WiFi radio state
LANG=C nmcli radio wifi 2>/dev/null

# Line 2: Connection type + SSID
if LANG=C nmcli dev status 2>/dev/null | grep -qE "^ethernet:connected"; then
    echo "ethernet:"
else
    # WiFi connection
    SSID=$(LANG=C nmcli -t -f active,ssid dev wifi list 2>/dev/null | grep '^yes:' | cut -d: -f2)
    echo "wifi:$SSID"
fi

# Line 3: WiFi extra info (channel, link speed, MAC)
WIFI_IFACE=$(LANG=C nmcli -t -f DEVICE,TYPE,STATE dev 2>/dev/null | grep ':wifi:connected' | cut -d: -f1)
if [ -n "$WIFI_IFACE" ]; then
    # Get channel and link speed from wifi list
    WIFI_EXTRA=$(LANG=C nmcli -t -f CHAN,SIGNAL dev wifi list 2>/dev/null | head -1)
    CHAN=$(echo "$WIFI_EXTRA" | cut -d: -f1)
    # Get link speed
    LINK_SPEED=$(LANG=C nmcli -t -f GENERAL.DEVICE,GENERAL.TYPE,GENERAL.LINK | dev show 2>/dev/null | grep ":$WIFI_IFACE:" | cut -d: -f3 | head -1)
    # Get MAC address
    WIFI_MAC=$(LANG=C nmcli -t -f DEVICE,HWADDR dev show 2>/dev/null | grep "^$WIFI_IFACE:" | cut -d: -f2)
    echo "wifi_extra:$CHAN:$LINK_SPEED:$WIFI_MAC"
else
    echo ""
fi

# Line 4: Ethernet info (ip, mac, speed)
ETH_IFACE=$(LANG=C nmcli -t -f DEVICE,TYPE,STATE dev 2>/dev/null | grep ':ethernet:connected' | cut -d: -f1)
if [ -n "$ETH_IFACE" ]; then
    # Get IP
    ETH_IP=$(LANG=C nmcli -t -f IP4.ADDRESS dev show "$ETH_IFACE" 2>/dev/null | cut -d: -f2 | head -1 | cut -d/ -f1)
    # Get MAC
    ETH_MAC=$(LANG=C nmcli -t -f DEVICE,HWADDR dev show 2>/dev/null | grep "^$ETH_IFACE:" | cut -d: -f2)
    # Get speed (from ethtool or nmcli)
    ETH_SPEED=$(ethtool "$ETH_IFACE" 2>/dev/null | grep "Speed:" | awk '{print $2}')
    if [ -z "$ETH_SPEED" ]; then
        ETH_SPEED="Unknown"
    fi
    echo "ethernet:$ETH_IP:$ETH_MAC:$ETH_SPEED"
else
    echo ""
fi

# Line 5: Network bytes (rx tx) from default interface
iface=$(ip route show default 2>/dev/null | awk 'NR==1{print $5; exit}')
if [ -z "$iface" ]; then
    iface=$(awk 'NR>2 && $1!="lo:"{gsub(":",""); print $1; exit}' /proc/net/dev)
fi
awk -v i="${iface}:" '$1==i{print $2, $10}' /proc/net/dev
