import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../Components"

PanelWindow {
    id: root

    visible: false
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    // ── State ─────────────────────────────────────────────────────────────
    property string currentLayout: "—"
    property string currentLocale: "—"

    // Common keyboard layouts to offer
    property var layouts: [
        { label: "Español  (es)",     code: "es"    },
        { label: "English  (us)",     code: "us"    },
        { label: "English UK (gb)",   code: "gb"    },
        { label: "Deutsch  (de)",     code: "de"    },
        { label: "Français  (fr)",    code: "fr"    },
        { label: "Português (pt)",    code: "pt"    },
        { label: "Italiano  (it)",    code: "it"    },
        { label: "日本語    (jp)",    code: "jp"    },
    ]

    // Common locales
    property var locales: [
        { label: "Español ES  (es_ES.UTF-8)", value: "es_ES.UTF-8" },
        { label: "Español MX  (es_MX.UTF-8)", value: "es_MX.UTF-8" },
        { label: "English US  (en_US.UTF-8)", value: "en_US.UTF-8" },
        { label: "English GB  (en_GB.UTF-8)", value: "en_GB.UTF-8" },
        { label: "Deutsch     (de_DE.UTF-8)", value: "de_DE.UTF-8" },
        { label: "Français    (fr_FR.UTF-8)", value: "fr_FR.UTF-8" },
    ]

    // Refresh current info whenever modal opens
    onVisibleChanged: {
        if (visible) {
            devProc.running = true
            localeProc.running = true
        }
    }

    // ── Data fetching ─────────────────────────────────────────────────────
    Process {
        id: devProc
        command: ["sh", "-c",
            "hyprctl devices -j 2>/dev/null | "
            + "awk -F'\"' '/active_keymap/{print $4; exit}'"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                var v = data.trim()
                if (v) root.currentLayout = v
            }
        }
    }

    Process {
        id: localeProc
        command: ["sh", "-c",
            "localectl status 2>/dev/null | awk -F= '/System Locale/{print $2}' | head -1"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => { var v = data.trim(); if (v) root.currentLocale = v }
        }
    }

    Process { id: setLayoutProc;  command: ["sh", "-c", ""] }
    Process { id: setLocaleProc;  command: ["sh", "-c", ""] }

    function setLayout(code) {
        setLayoutProc.command = ["sh", "-c",
            "hyprctl keyword input:kb_layout " + code + " 2>/dev/null"
            + " && sleep 0.4 && hyprctl dispatch switchxkblayout all 0"]
        setLayoutProc.running = true
        Qt.callLater(() => devProc.running = true)
    }

    function setLocale(value) {
        setLocaleProc.command = ["sh", "-c",
            "localectl set-locale LANG=" + value + " 2>/dev/null"]
        setLocaleProc.running = true
        root.currentLocale = value
    }

    // ── Dim backdrop — closes modal on click ──────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.55)
        MouseArea {
            anchors.fill: parent
            onClicked: root.visible = false
        }
    }

    // ── Centered card ─────────────────────────────────────────────────────
    Rectangle {
        anchors.centerIn: parent
        width:  420
        implicitHeight: contentCol.implicitHeight + 32
        radius: 14
        color:  Theme.base

        layer.enabled: true
        layer.effect: null

        // Thin accent border
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25)
            border.width: 1
        }

        // Stop backdrop click from passing through
        MouseArea { anchors.fill: parent }

        Column {
            id: contentCol
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: 16
            }
            spacing: 0

            // ── Header ────────────────────────────────────────────────────
            Rectangle {
                width: parent.width
                height: 48
                color: "transparent"

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    Text {
                        text: "󰌌"
                        font.pixelSize: 20
                        color: Theme.accent
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        Text {
                            text: "Teclado e Idioma"
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                            color: Theme.text
                        }

                        Text {
                            text: root.currentLayout + "  ·  " + root.currentLocale
                            font.pixelSize: 11
                            color: Theme.muted1
                        }
                    }
                }

                // Close button
                Rectangle {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    width: 26; height: 26; radius: 13
                    color: closeMA.containsMouse ? Theme.surface2 : "transparent"
                    Behavior on color { ColorAnimation { duration: 100 } }

                    Text {
                        anchors.centerIn: parent
                        text: "󰅖"
                        font.pixelSize: 13
                        color: Theme.muted1
                    }

                    MouseArea {
                        id: closeMA
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.visible = false
                    }
                }
            }

            // ── Separator ─────────────────────────────────────────────────
            Rectangle { width: parent.width; height: 1; color: Theme.surface2 }

            // ── Section label: Distribución ───────────────────────────────
            Text {
                topPadding: 12; bottomPadding: 6
                text: "Distribución de teclado"
                font.pixelSize: 11
                font.weight: Font.Normal
                color: Theme.muted1
                leftPadding: 0
            }

            // ── Layout grid ───────────────────────────────────────────────
            Grid {
                width: parent.width
                columns: 2
                columnSpacing: 8
                rowSpacing: 6

                Repeater {
                    model: root.layouts

                    Rectangle {
                        required property var modelData
                        width:  (parent.width - 8) / 2
                        height: 34
                        radius: 8
                        color:  layoutMA.containsMouse
                                    ? Theme.surface3
                                    : (root.currentLayout.toLowerCase().indexOf(modelData.code) >= 0
                                        ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                                        : Theme.surface2)
                        Behavior on color { ColorAnimation { duration: 100 } }

                        // Active indicator strip
                        Rectangle {
                            visible: root.currentLayout.toLowerCase().indexOf(parent.modelData.code) >= 0
                            width: 3; height: 16; radius: 2
                            anchors { left: parent.left; leftMargin: 6; verticalCenter: parent.verticalCenter }
                            color: Theme.accent
                        }

                        Text {
                            anchors {
                                verticalCenter: parent.verticalCenter
                                left: parent.left
                                leftMargin: 16
                            }
                            text: parent.modelData.label
                            font.pixelSize: 12
                            color: Theme.text
                        }

                        MouseArea {
                            id: layoutMA
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.setLayout(parent.modelData.code)
                        }
                    }
                }
            }

            // ── Separator ─────────────────────────────────────────────────
            Item { width: parent.width; height: 8 }
            Rectangle { width: parent.width; height: 1; color: Theme.surface2 }

            // ── Section label: Idioma ─────────────────────────────────────
            Text {
                topPadding: 12; bottomPadding: 6
                text: "Idioma del sistema"
                font.pixelSize: 11
                font.weight: Font.Normal
                color: Theme.muted1
            }

            // ── Locale list ───────────────────────────────────────────────
            Column {
                width: parent.width
                spacing: 4
                bottomPadding: 4

                Repeater {
                    model: root.locales

                    Rectangle {
                        required property var modelData
                        width:  parent.width
                        height: 34
                        radius: 8
                        color:  localeMA.containsMouse
                                    ? Theme.surface3
                                    : (root.currentLocale.indexOf(modelData.value.split(".")[0]) >= 0
                                        ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                                        : Theme.surface2)
                        Behavior on color { ColorAnimation { duration: 100 } }

                        // Active indicator strip
                        Rectangle {
                            visible: root.currentLocale.indexOf(parent.modelData.value.split(".")[0]) >= 0
                            width: 3; height: 16; radius: 2
                            anchors { left: parent.left; leftMargin: 6; verticalCenter: parent.verticalCenter }
                            color: Theme.accent
                        }

                        Text {
                            anchors {
                                verticalCenter: parent.verticalCenter
                                left: parent.left
                                leftMargin: 16
                            }
                            text: parent.modelData.label
                            font.pixelSize: 12
                            color: Theme.text
                        }

                        MouseArea {
                            id: localeMA
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.setLocale(parent.modelData.value)
                        }
                    }
                }
            }
        }
    }

}
