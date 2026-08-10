// qmllint disable uncreatable-type
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Io
import Qt.labs.platform
import "../Components"

QmModalBase {
    id: root

    cardWidth: 740
    cardFixedHeight: 560
    cardHeightFactor: 0.78
    cardRadius: 16
    cardBorderColor: Theme.surface2
    cardClip: true
    hasStripe: true

    // ── API pública ───────────────────────────────────────────
    signal folderSelected(string path)

    property string initialPath: "~"

    // Home dir portable — evita hardcodear nombre de usuario
    readonly property string _homePath: StandardPaths.standardLocations(StandardPaths.HomeLocation)[0] ?? ""

    function open(startPath) {
        initialPath = startPath || "~"
        navigate(initialPath)
        visible = true
    }

    // ── Estado ────────────────────────────────────────────────
    property string currentPath: ""
    property string parentPath:  ""
    property bool   _loading:    false
    property string _buf:        ""

    ListModel { id: entryModel }

    // ── Accesos rápidos ───────────────────────────────────────
    readonly property var quickAccess: [
        { label: "Inicio",      icon: "󰋞", path: "~" },
        { label: "Imágenes",    icon: "󰋩", path: "~/Imágenes" },
        { label: "Pictures",    icon: "󰋩", path: "~/Pictures" },
        { label: "Descargas",   icon: "󰇚", path: "~/Downloads" },
        { label: "Documentos",  icon: "󰈙", path: "~/Documentos" },
        { label: "Escritorio",  icon: "󰇄", path: "~/Escritorio" },
        { label: "Música",      icon: "󱍙", path: "~/Music" },
        { label: "Videos",      icon: "󰿎", path: "~/Videos" },
    ]

    // ── Proceso de listado ────────────────────────────────────
    Process {
        id: listProc
        property string targetPath: ""
        command: [Paths.scripts + "/qs-helper/qs-helper",
            "folder",
            targetPath
        ]
        stdout: SplitParser {
            splitMarker: ""
            onRead: d => root._buf += d
        }
        // qmllint disable signal-handler-parameters
        onExited: function(exitCode) {
            listWatchdog.stop()
            root._loading = false
            try {
                var res = JSON.parse(root._buf)
                root.currentPath = res.path
                root.parentPath  = res.parent
                entryModel.clear()
                for (var i = 0; i < res.entries.length; i++)
                    entryModel.append(res.entries[i])
            } catch(e) {}
            root._buf = ""
        }
        // qmllint enable signal-handler-parameters
    }

    function navigate(p) {
        if (_loading) return
        _loading = true
        _buf = ""
        listWatchdog.restart()
        listProc.targetPath = p
        listProc.running = true
    }

    // Watchdog: si qs-helper folder cuelga sin onExited, lo mata y desbloquea
    Timer {
        id: listWatchdog
        interval: 15000
        onTriggered: {
            listProc.running = false
            root._loading = false
            root._buf = ""
        }
    }

    // ── UI ────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 0
        spacing: 0

        // ── Header ─────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            color: "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 12
                spacing: 8

                // Icono
                Text {
                    text: "󰉋"
                    font.pixelSize: 18
                    color: Theme.accent2
                }

                // Botón atrás
                Rectangle {
                    Layout.preferredWidth: 28; Layout.preferredHeight: 28; radius: 8
                    color: backMa.containsMouse ? Theme.surface2 : "transparent"
                    visible: root.currentPath !== "/" && root.currentPath !== ""
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Text {
                        anchors.centerIn: parent
                        text: "󰁍"
                        font.pixelSize: 16
                        color: backMa.containsMouse ? Theme.text : Theme.muted3
                    }
                    MouseArea {
                        id: backMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.navigate(root.parentPath)
                    }
                }

                // Ruta actual
                Text {
                    Layout.fillWidth: true
                    text: root._homePath ? root.currentPath.replace(root._homePath, "~") : root.currentPath
                    font.pixelSize: 13
                    color: Theme.muted1
                    elide: Text.ElideLeft
                }

                // Cerrar
                Rectangle {
                    Layout.preferredWidth: 28; Layout.preferredHeight: 28; radius: 8
                    color: closeMa.containsMouse ? Theme.surface3 : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        font.pixelSize: 13
                        color: closeMa.containsMouse ? Theme.text : Theme.muted3
                    }
                    MouseArea {
                        id: closeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.close()
                    }
                }
            }

            // Separador
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1; color: Theme.surface2
            }
        }

        // ── Body: sidebar + lista ─────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // ── Sidebar accesos rápidos ─────────────────
            Rectangle {
                Layout.preferredWidth: 160
                Layout.fillHeight: true
                color: Theme.cardBg3

                Column {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: 12
                    spacing: 2

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        text: "ACCESOS RÁPIDOS"
                        font.pixelSize: 9
                        font.weight: Font.Normal
                        color: Theme.muted3
                        bottomPadding: 6
                    }

                    Repeater {
                        model: root.quickAccess

                        Rectangle {
                            id: qaItem
                            required property var modelData
                            width: parent.width
                            height: 34
                            color: qaMa.containsMouse ? Theme.surface2 : "transparent"
                            Behavior on color { ColorAnimation { duration: 80 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 8
                                spacing: 8

                                Text {
                                    text: qaItem.modelData.icon
                                    font.pixelSize: 15
                                    color: Theme.muted3
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: qaItem.modelData.label
                                    font.pixelSize: 12
                                    color: Theme.muted1
                                    elide: Text.ElideRight
                                }
                            }

                            MouseArea {
                                id: qaMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.navigate(qaItem.modelData.path)
                            }
                        }
                    }
                }

                // Borde derecho
                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 1; color: Theme.surface2
                }
            }

            // ── Lista de entradas ────────────────────────
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                // Spinner
                Column {
                    anchors.centerIn: parent
                    spacing: 10
                    visible: root._loading
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "󰔟"
                        font.pixelSize: 28
                        color: Theme.accent2
                        RotationAnimation on rotation {
                            running: root._loading
                            from: 0; to: 360; duration: 800
                            loops: Animation.Infinite
                        }
                    }
                }

                // Vacío
                Column {
                    anchors.centerIn: parent
                    spacing: 8
                    visible: !root._loading && entryModel.count === 0
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "󰉖"; font.pixelSize: 32; color: Theme.surface2
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Carpeta vacía"; font.pixelSize: 12; color: Theme.surface3
                    }
                }

                ListView {
                    anchors.fill: parent
                    anchors.topMargin: 4
                    anchors.bottomMargin: 4
                    clip: true
                    model: entryModel
                    spacing: 1
                    visible: !root._loading && entryModel.count > 0

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                        contentItem: Rectangle {
                            implicitWidth: 4; radius: 2; color: Theme.surface3
                        }
                    }

                    delegate: Rectangle {
                        id: row
                        width: ListView.view.width - 8
                        height: 36
                        radius: 8
                        color: rowMa.containsMouse ? Theme.surface2 : "transparent"
                        Behavior on color { ColorAnimation { duration: 80 } }

                        required property var   model
                        required property int   index

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 8
                            spacing: 10

                            Text {
                                text: row.model.isDir ? "󰉋" : "󰈙"
                                font.pixelSize: 15
                                color: row.model.isDir ? Theme.accent : Theme.muted3
                            }

                            Text {
                                Layout.fillWidth: true
                                text: row.model.name
                                font.pixelSize: 13
                                color: row.model.isDir ? Theme.text : Theme.muted3
                                elide: Text.ElideRight
                            }

                            Text {
                                visible: row.model.isDir && rowMa.containsMouse
                                text: "󰁔"
                                font.pixelSize: 13
                                color: Theme.muted3
                            }
                        }

                        MouseArea {
                            id: rowMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: row.model.isDir ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: {
                                if (row.model.isDir) root.navigate(row.model.path)
                            }
                        }
                    }
                }
            }
        }

        // ── Footer: ruta actual + botón seleccionar ──────
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            color: Theme.cardBg3

            // Borde superior
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1; color: Theme.surface2
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 12

                Column {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        text: "Carpeta seleccionada"
                        font.pixelSize: 10
                        color: Theme.muted3
                    }
                    Text {
                        width: parent.width
                        text: root._homePath ? root.currentPath.replace(root._homePath, "~") : root.currentPath
                        font.pixelSize: 12
                        color: Theme.accent2
                        elide: Text.ElideLeft
                    }
                }

                // Botón cancelar
                Rectangle {
                    Layout.preferredWidth: 90; Layout.preferredHeight: 34; radius: 9
                    color: cancelMa.containsMouse ? Theme.surface2 : Theme.surface1
                    border.color: Theme.surface3
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Text {
                        anchors.centerIn: parent
                        text: "Cancelar"
                        font.pixelSize: 12
                        color: Theme.muted3
                    }
                    MouseArea {
                        id: cancelMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.close()
                    }
                }

                // Botón seleccionar
                Rectangle {
                    Layout.preferredWidth: 130; Layout.preferredHeight: 34; radius: 9
                    color: selectMa.containsMouse ? Theme.accent : Theme.accent2
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Text {
                        anchors.centerIn: parent
                        text: "󰄬  Seleccionar"
                        font.pixelSize: 12
                        font.weight: Font.Normal
                        color: Theme.cardBg3
                    }
                    MouseArea {
                        id: selectMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.folderSelected(root.currentPath)
                            root.close()
                        }
                    }
                }
            }
        }
    }
}
