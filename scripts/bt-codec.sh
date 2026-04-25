#!/usr/bin/env bash
# bt-codec.sh — Bluetooth codec query / set via PipeWire (pactl only)
set -eo pipefail
#
# Usage:
#   bt-codec.sh info <MAC>             → JSON { codec, active, rate, bitrate, profiles:[{id,label,bitrate}] }
#   bt-codec.sh set  <MAC> <profile>   → JSON { ok: true|false }

MODE="$1"
MAC="$2"
CARD="bluez_card.$(echo "$MAC" | tr ':' '_')"

case "$MODE" in
  info)
    python3 - "$MAC" "$CARD" <<'PYEOF'
import json, sys, subprocess, re

mac  = sys.argv[1].upper()
card = sys.argv[2]

# --- Single source of truth: profile → (label, bitrate, sort_order) ---
PROFILES = {
    "a2dp-sink-sbc":          ("SBC",    "328 kbps",  328),
    "a2dp-sink-sbc_xq":       ("SBC-XQ", "492 kbps",  492),
    "a2dp-sink-aac":          ("AAC",    "256 kbps",  256),
    "a2dp-sink":              ("LDAC",   "990 kbps",  990),
    "headset-head-unit":      ("mSBC",   "64 kbps",    64),
    "headset-head-unit-cvsd": ("CVSD",   "64 kbps",    64),
}

# --- pactl: active profile + available profiles + sample rate ---
active    = ""
profiles  = []
pw_codec  = ""
rate      = ""

try:
    raw = subprocess.check_output(
        ["env", "LANG=C", "pactl", "--format=json", "list", "cards"],
        stderr=subprocess.DEVNULL,
    ).decode(errors="replace")

    # Try JSON parsing first (pactl >= 15)
    try:
        cards = json.loads(raw)
        for c in cards if isinstance(cards, list) else []:
            props = c.get("properties", {})
            if props.get("device.name", "").lower() == card.lower():
                active = c.get("active_profile", "")
                for p in c.get("profiles", []):
                    pid = p.get("name", "")
                    if pid in PROFILES:
                        profiles.append({"id": pid, "label": PROFILES[pid][0]})
                # Sample rate from state
                for s in c.get("state", {}).get("rates", []):
                    if s:
                        rate = str(s)
                        break
                pw_codec = props.get("device.api.bluez5.codec", "").upper()
                break
    except (json.JSONDecodeError, KeyError):
        # Fallback: text parsing (pactl < 15 or non-JSON output)
        section = ""
        in_card = False
        for line in raw.splitlines():
            if card.lower() in line.lower():
                in_card = True
            if in_card:
                section += line + "\n"
                if line.strip() == "" and section.strip():
                    break

        for line in section.splitlines():
            if "Active Profile" in line:
                active = line.split(":", 1)[-1].strip()
            if "api.bluez5.codec" in line:
                pw_codec = line.split("=", 1)[-1].strip().strip('"').upper()

        for line in section.splitlines():
            m = re.match(r'\s+([\w-]+):\s.*\bcodec\s+([\w\-\+]+)\)', line)
            if m and m.group(1) in PROFILES:
                profiles.append({"id": m.group(1), "label": PROFILES[m.group(1)][0]})

except Exception:
    pass

# --- Resolve final codec label ---
if active in PROFILES:
    final_codec = PROFILES[active][0]
elif pw_codec:
    final_codec = pw_codec
elif active:
    final_codec = active.upper()
else:
    final_codec = ""

# --- Bitrate ---
bitrate = PROFILES.get(active, (None, ""))[1] if active in PROFILES else ""
if final_codec == "LDAC" and not bitrate:
    bitrate = "990 kbps"

# --- Annotate profiles with bitrate, sort low→high ---
for p in profiles:
    p["bitrate"] = PROFILES[p["id"]][1] if p["id"] in PROFILES else ""
profiles.sort(key=lambda p: PROFILES.get(p["id"], ("", "", 0))[2])

print(json.dumps({
    "codec":    final_codec,
    "active":   active,
    "rate":     rate,
    "bitrate":  bitrate,
    "profiles": profiles,
}))
PYEOF
    ;;

  set)
    PROFILE="$3"
    if pactl set-card-profile "$CARD" "$PROFILE" 2>/dev/null; then
        echo '{"ok":true}'
    else
        echo '{"ok":false}'
    fi
    ;;

  *)
    echo '{"error":"usage: bt-codec.sh info|set <MAC> [profile]"}'
    ;;
esac
