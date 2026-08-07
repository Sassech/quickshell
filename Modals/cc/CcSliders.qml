pragma ComponentBehavior: Bound

import QtQuick
import "../../Components"

// ── Sliders: volumen master, micrófono, brillo ────────────────────────────────
Column {
    id: root
    spacing: 0

    // ── Required properties ───────────────────────────────────────────────
    required property real masterVolume
    required property bool masterMuted
    required property real micVolume
    required property bool micMuted
    required property int  brightness

    // ── Signals ───────────────────────────────────────────────────────────
    signal setMasterVolume(real v)
    signal toggleMasterMute()
    signal setMicVol(real v)
    signal toggleMicMute()
    signal setBrightness(int v)

    // ── Slider volumen master ─────────────────────────────────────────────
    CcSlider {
        value:      root.masterVolume
        maxValue:   1.5
        icon:       IconHelpers.volIcon(root.masterVolume, root.masterMuted)
        iconColor:  root.masterMuted ? Theme.muted2 : Theme.accent
        iconButton: true
        muted:      root.masterMuted
        label:      root.masterMuted ? "Muted" : Math.round(root.masterVolume * 100) + "%"
        labelColor: Theme.muted1
        onSetValue:   v => root.setMasterVolume(v)
        onIconClicked: root.toggleMasterMute()
    }

    // ── Slider micrófono ──────────────────────────────────────────────────
    CcSlider {
        value:      root.micVolume
        maxValue:   1.5
        icon:       root.micMuted ? "󰍭" : "󰍬"
        iconColor:  root.micMuted ? Theme.muted2 : Theme.accent
        iconButton: true
        muted:      root.micMuted
        label:      root.micMuted ? "Muted" : Math.round(root.micVolume * 100) + "%"
        labelColor: Theme.muted1
        onSetValue:   v => root.setMicVol(v)
        onIconClicked: root.toggleMicMute()
    }

    // ── Slider brillo ─────────────────────────────────────────────────────
    CcSlider {
        value:     root.brightness
        minValue:  1
        maxValue:  100
        icon:      IconHelpers.brightIcon(root.brightness)
        label:     root.brightness + "%"
        onSetValue: v => root.setBrightness(Math.round(v))
    }
}
