#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# Detectar hwmon dinámicamente — el número cambia entre boots
HWMON_SMM=""
HWMON_AWCC=""
for _h in /sys/class/hwmon/hwmon*/; do
    [ -r "${_h}name" ] || continue
    _nm=$(< "${_h}name")
    case "$_nm" in
        dell_smm) HWMON_SMM="${_h%/}" ;;
        awcc)     HWMON_AWCC="${_h%/}" ;;
    esac
done
PLATFORM_PROFILE="/sys/class/platform-profile/platform-profile-0"

_get_smm() {
    local key=$1
    [ -r "$HWMON_SMM/$key" ] && < "$HWMON_SMM/$key" 2>/dev/null || echo ""
}

_get_awcc() {
    local key=$1
    [ -r "$HWMON_AWCC/$key" ] && < "$HWMON_AWCC/$key" 2>/dev/null || echo ""
}

_get_profile() {
    [ -r "$PLATFORM_PROFILE/profile" ] && < "$PLATFORM_PROFILE/profile" 2>/dev/null || echo ""
}

_set_profile() {
    local profile=$1
    # Normalizar "auto" → "balanced"
    [[ "$profile" == "auto" ]] && profile="balanced"
    # Whitelist explícita — rechaza cualquier valor no conocido
    case "$profile" in
        balanced|performance|quiet|custom) ;;
        *)
            echo "Error: perfil inválido: '$profile'. Valores válidos: balanced, performance, quiet, custom, auto" >&2
            exit 1
            ;;
    esac
    echo "$profile" > "$PLATFORM_PROFILE/profile" 2>/dev/null || true
}

_set_pwm() {
    local pwm=$1
    if [[ $pwm -lt 0 || $pwm -gt 255 ]]; then
        echo "Error: PWM must be 0-255" >&2
        exit 1
    fi
    # Set custom profile first for manual control
    echo "custom" > "$PLATFORM_PROFILE/profile" 2>/dev/null || true
    # Write boost value via alienware_wmi
    echo "$pwm" > "$HWMON_AWCC/fan1_boost" 2>/dev/null || {
        echo "Error: Cannot write PWM" >&2
        exit 1
    }
}

case "${1:-}" in
    get_rpm)
        rpm1=$(_get_smm "fan1_input")
        rpm2=$(_get_smm "fan2_input")
        echo "${rpm1:-0},${rpm2:-0}"
        ;;
    get_max_rpm)
        max1=$(_get_smm "fan1_max")
        max2=$(_get_smm "fan2_max")
        echo "${max1:-3700},${max2:-4000}"
        ;;
    get_percent)
        rpm1=$(_get_smm "fan1_input")
        rpm2=$(_get_smm "fan2_input")
        max1=$(_get_smm "fan1_max")
        max2=$(_get_smm "fan2_max")
        p1=0; p2=0
        [[ -n "$rpm1" && -n "$max1" && "$max1" -gt 0 ]] && p1=$((rpm1 * 100 / max1))
        [[ -n "$rpm2" && -n "$max2" && "$max2" -gt 0 ]] && p2=$((rpm2 * 100 / max2))
        echo "$p1,$p2"
        ;;
    get_temp)
        temp1=$(_get_awcc "temp1_input")
        temp2=$(_get_awcc "temp2_input")
        t1c=""; t2c=""
        [[ -n "$temp1" ]] && t1c=$((temp1 / 1000))
        [[ -n "$temp2" ]] && t2c=$((temp2 / 1000))
        echo "${t1c:-0},${t2c:-0}"
        ;;
    get_pwm)
        pwm=$(_get_awcc "fan1_boost")
        echo "${pwm:-0}"
        ;;
    set_pwm)
        _set_pwm "${2:-128}"
        ;;
    get_profile)
        _get_profile
        ;;
    set_profile)
        _set_profile "${2:-balanced}"
        ;;
    list_profiles)
        # Print available profile ids — one per line
        echo "quiet"
        echo "balanced"
        echo "performance"
        ;;
    set_auto)
        _set_profile "balanced"
        ;;
    set_manual)
        _set_profile "custom"
        ;;
    *)
        echo "Usage: $0 {get_rpm|get_max_rpm|get_percent|get_temp|get_pwm|set_pwm <0-255>|get_profile|set_profile <name>|list_profiles|set_auto|set_manual}" >&2
        exit 1
        ;;
esac
