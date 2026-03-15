#!/usr/bin/env bash
# Outputs: rx_bytes tx_bytes  (cumulative, from /proc/net/dev)
# Uses the default-route interface, falls back to first non-lo iface

iface=$(ip route show default 2>/dev/null | awk 'NR==1{print $5; exit}')
if [ -z "$iface" ]; then
    iface=$(awk 'NR>2 && $1!="lo:"{gsub(":",""); print $1; exit}' /proc/net/dev)
fi
awk -v i="${iface}:" '$1==i{print $2, $10}' /proc/net/dev
