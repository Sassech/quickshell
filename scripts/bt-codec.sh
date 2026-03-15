#!/usr/bin/env bash
# bt-codec.sh — Bluetooth codec query / set via PipeWire (pactl + pw-dump)
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

# --- pw-dump: codec from node + quality param (for LDAC bitrate mode) ---
pw_codec   = ""
ldac_quality = None   # -1=auto/adaptive, 0=HQ 990k, 1=SQ 660k, 2=MQ 330k
audio_rate = ""
try:
    dump = json.loads(subprocess.check_output(["pw-dump"], stderr=subprocess.DEVNULL))
    for obj in dump:
        props  = obj.get("info", {}).get("props", {})
        params = obj.get("info", {}).get("params", {})
        if props.get("api.bluez5.address", "").upper() != mac:
            continue
        c = props.get("api.bluez5.codec", "")
        if c:
            pw_codec = c.lower()
        # Read quality from Props param list (list of dicts)
        for p in params.get("Props", []):
            if isinstance(p, dict):
                if "quality" in p:
                    ldac_quality = p["quality"]
                r = p.get("audio.rate") or p.get("rate")
                if r:
                    audio_rate = str(r)
        # Format params when streaming
        for fmt in params.get("Format", []):
            if isinstance(fmt, dict):
                r = fmt.get("rate")
                if r:
                    audio_rate = str(r)
except Exception:
    pass

# --- pactl: active profile + available profiles ---
active   = ""
profiles = []
try:
    raw = subprocess.check_output(["pactl", "list", "cards"],
                                  stderr=subprocess.DEVNULL).decode(errors="replace")
    section = ""
    in_card = False
    for line in raw.splitlines():
        if card in line:
            in_card = True
        if in_card:
            section += line + "\n"

    for line in section.splitlines():
        if "Perfil Activo" in line or "Active Profile" in line:
            active = line.split(":", 1)[-1].strip()

    for line in section.splitlines():
        m = re.match(r'\s+([\w-]+):\s.*\bcodec\s+([\w\-\+]+)\)', line)
        if m:
            profiles.append({"id": m.group(1), "label": m.group(2)})
except Exception:
    pass

# --- Codec label map (from profile id) ---
profile_to_label = {p["id"]: p["label"] for p in profiles}
profile_to_label.update({
    "a2dp-sink-sbc":          "SBC",
    "a2dp-sink-sbc_xq":       "SBC-XQ",
    "a2dp-sink-aac":          "AAC",
    "a2dp-sink":              "LDAC",
    "headset-head-unit":      "mSBC",
    "headset-head-unit-cvsd": "CVSD",
})
final_codec = profile_to_label.get(active, "") or pw_codec.upper() or active.upper()

# --- Bitrate per codec (max/typical kbps) ---
CODEC_BITRATE = {
    "SBC":   "328 kbps",
    "SBC-XQ":"492 kbps",
    "AAC":   "256 kbps",
    "LDAC":  "",           # determined by quality level below
    "mSBC":  "64 kbps",
    "CVSD":  "64 kbps",
}

bitrate = CODEC_BITRATE.get(final_codec, "")

if final_codec == "LDAC":
    if ldac_quality is None or ldac_quality == -1:
        bitrate = "≤990 kbps (auto)"
    elif ldac_quality == 0:
        bitrate = "990 kbps (HQ)"
    elif ldac_quality == 1:
        bitrate = "660 kbps (SQ)"
    elif ldac_quality == 2:
        bitrate = "330 kbps (MQ)"
    else:
        bitrate = "990 kbps"

# Annotate each profile with its known max bitrate and sort low→high
PROFILE_BITRATE = {
    "a2dp-sink-sbc":          "328 kbps",
    "a2dp-sink-sbc_xq":       "492 kbps",
    "a2dp-sink-aac":          "256 kbps",
    "a2dp-sink":              "990 kbps",
    "headset-head-unit":      "64 kbps",
    "headset-head-unit-cvsd": "64 kbps",
}
PROFILE_BITRATE_ORDER = {
    "a2dp-sink-sbc":          328,
    "a2dp-sink-sbc_xq":       492,
    "a2dp-sink-aac":          256,
    "a2dp-sink":              990,
    "headset-head-unit":       64,
    "headset-head-unit-cvsd":  64,
}
for p in profiles:
    p["bitrate"] = PROFILE_BITRATE.get(p["id"], "")
profiles.sort(key=lambda p: PROFILE_BITRATE_ORDER.get(p["id"], 0))

print(json.dumps({
    "codec":    final_codec,
    "active":   active,
    "rate":     audio_rate,
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
