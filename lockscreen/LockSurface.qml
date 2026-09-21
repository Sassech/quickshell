pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland

// LockSurface — minimal per-screen lock UI (v1).
// Shows clock, date, password field, PAM-failure message and caps hint.
// Blur, user switch, media and notifications are explicitly out of v1.
// Auth flow lives in shell.qml; this surface only binds shared state and
// emits attemptLogin when the user submits the password field.
//
// NOTE: self-contained palette (no `import "../Components"`). When
// lockscreen/ runs as its own config root (`qs -p lockscreen`), the
// Quickshell VFS blackholes QML imports escaping the config root, so the
// shared Theme singleton is unreachable (verified in qs runtime logs).
// A static dark palette keeps the locker dependency-free and always
// renderable; it mirrors the wallpaper-derived Theme values.
WlSessionLockSurface {
    id: root

    // Static palette mirroring Components/Theme.qml (see note above).
    readonly property color _bg:      "#1A1112"
    readonly property color _surface: "#22191A"
    readonly property color _surface2: "#271D1E"
    readonly property color _surface3: "#312828"
    readonly property color _text:    "#F0DEDF"
    readonly property color _muted1:  "#D7C1C2"
    readonly property color _muted3:  "#524344"
    readonly property color _accent:  "#FFB2B8"
    readonly property color _accent2: "#E5BDBF"
    readonly property color _error:   "#FFB4AB"
    readonly property color _warning: "#E8C08E"

    // Shared state from shell.qml (same text on every monitor).
    required property var ctx
    // True while the session is locked; focuses the password field on engage.
    required property bool locked

    // Fired when the user submits the password field (Enter).
    signal attemptLogin()

    color: root._surface

    onLockedChanged: {
        if (root.locked)
            passwordField.forceActiveFocus()
    }
    Component.onCompleted: {
        if (root.locked)
            passwordField.forceActiveFocus()
    }

    // Native clock (reactive, no Timer).
    SystemClock {
        id: sysClock
        precision: SystemClock.Seconds
    }

    readonly property string _timeStr: {
        const h = sysClock.hours
        const m = sysClock.minutes
        return h.toString().padStart(2, "0") + ":" + m.toString().padStart(2, "0")
    }
    readonly property string _dateStr: Qt.formatDateTime(sysClock.date, "dddd, d MMMM yyyy")

    // NOTE: no wallpaper layer in v1. The config sandbox (see palette note)
    // also blackholes FileView reads outside lockscreen/, so external
    // wallpaper coordination needs an in-root path file (follow-up,
    // e.g. written by wallpaper-set.sh). Solid background until then.

    Column {
        anchors.centerIn: parent
        spacing: 12

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: ""
            font.pixelSize: 40
            color: root._muted1
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root._timeStr
            font.pixelSize: 64
            font.bold: true
            font.family: "monospace"
            color: root._text
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root._dateStr
            font.pixelSize: 16
            color: root._muted1
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 280
            height: 44
            radius: 10
            color: root._surface2
            border.width: 2
            border.color: passwordField.activeFocus ? root._accent : root._surface3
            Behavior on border.color { ColorAnimation { duration: 150 } }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                text: ""
                font.pixelSize: 16
                color: root.ctx.currentText !== "" ? root._accent2 : root._muted3
            }

            Text {
                anchors.fill: parent
                anchors.leftMargin: 42
                anchors.rightMargin: 12
                verticalAlignment: Text.AlignVCenter
                text: "Password"
                font.pixelSize: 15
                color: root._muted3
                visible: root.ctx.currentText === ""
            }

            TextInput {
                id: passwordField
                anchors.fill: parent
                anchors.leftMargin: 42
                anchors.rightMargin: 12
                font.pixelSize: 15
                color: root._text
                selectionColor: root._accent
                selectedTextColor: root._text
                clip: true
                echoMode: TextInput.Password
                passwordCharacter: "•"
                verticalAlignment: TextInput.AlignVCenter

                text: root.ctx.currentText
                onTextChanged: root.ctx.currentText = text

                // Caps-lock heuristic: an uppercase letter without Shift
                // (or lowercase with Shift held off) flips the hint state.
                // Quickshell 0.3.1 exposes no keyboard-modifier state API.
                Keys.onPressed: event => {
                    const t = event.text
                    if (t.length === 1) {
                        const lower = t.toLowerCase()
                        const upper = t.toUpperCase()
                        if (lower !== upper) {
                            const shifted = (event.modifiers & Qt.ShiftModifier) !== 0
                            const isUpper = t === upper
                            root.ctx.capsOn = (isUpper !== shifted)
                        }
                    }
                }
                Keys.onReturnPressed: root.attemptLogin()
                Keys.onEnterPressed: root.attemptLogin()
                Keys.onEscapePressed: {
                    root.ctx.currentText = ""
                    root.ctx.clearFailure()
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.ctx.failureMessage
            font.pixelSize: 13
            color: root._error
            visible: root.ctx.failureMessage !== ""
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Caps Lock is on"
            font.pixelSize: 12
            color: root._warning
            visible: root.ctx.capsOn
        }
    }
}
