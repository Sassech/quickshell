// qmllint disable uncreatable-type
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
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

    // ── Estado ─────────────────────────────────────────────────
    property string currentFolder: "~/Imágenes"
    property string currentWallpaper: ""
    property bool   _loading: false
    property string _listBuf: ""

    signal requestFolderBrowser(string currentPath)

    function receiveFolderResult(path) {
        saveFolder(path)
    }

    ListModel { id: imageModel }

    // ── Carga config al inicio ─────────────────────────────────
    Component.onCompleted: {
        configReadProc.running = true
    }

    Process {
        id: configReadProc
        command: ["bash", "-c",
            "cat \"" + Paths.config + "/wallpaper-config.json\" 2>/dev/null; " +
            "echo '---'; " +
            "cat \"" + Paths.config + "/wallpaper-monitors.json\" 2>/dev/null || true"
        ]
        property string buf: ""
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: d => configReadProc.buf += d + "\n"
        }
        // qmllint disable signal-handler-parameters
        onExited: {
            var parts = buf.split("---")
            try {
                var cfg = JSON.parse(parts[0].trim())
                if (cfg.folder) root.currentFolder = cfg.folder
            } catch(e) {}
            try {
                var perMonitor = JSON.parse(parts[1].trim())
                var outName = root.screen ? root.screen.name : ""
                if (outName && perMonitor[outName]) root.currentWallpaper = perMonitor[outName]
            } catch(e) {}
            buf = ""
        }
        // qmllint enable signal-handler-parameters
    }

    onVisibleChanged: {
        if (visible) {
            loadImages()
            Qt.callLater(function() { card.forceActiveFocus() })
        }
    }

    Component.onDestruction: {
        listProc.running = false
        setProc.running = false
        saveConfigProc.running = false
    }

    // Safety net: si wallpaper-list.py cuelga, desbloquea _loading
    Timer {
        id: loadSafetyTimer
        interval: 10000
        onTriggered: root._loading = false
    }

    // ── Carga imágenes ─────────────────────────────────────────
    function loadImages() {
        // Si ya hay una carga en curso, la cancela y reintenta
        if (_loading) {
            listProc.running = false
            root._loading = false
        }
        _loading = true
        _listBuf = ""
        imageModel.clear()
        loadSafetyTimer.restart()
        listProc.running = true
    }

    Process {
        id: listProc
        command: ["python3",
            Paths.scripts + "/wallpaper-list.py",
            root.currentFolder
        ]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: d => root._listBuf += d + "\n"
        }
        // qmllint disable signal-handler-parameters
        onExited: {
            loadSafetyTimer.stop()
            root._loading = false
            var items = []
            try { items = JSON.parse(root._listBuf) } catch(e) {}
            for (var i = 0; i < items.length; i++) imageModel.append(items[i])
        }
        // qmllint enable signal-handler-parameters
    }

    // ── Aplica wallpaper ───────────────────────────────────────
    Process {
        id: setProc
        property string pending: ""
        running: false
        // qmllint disable signal-handler-parameters
        onExited: {
            root.currentWallpaper = pending
        }
        // qmllint enable signal-handler-parameters
    }

    // ── Guarda config ──────────────────────────────────────────
    Process {
        id: saveConfigProc
        command: ["python3", Paths.scripts + "/wallpaper-save-config.py", ""]
        property string pendingFolder: ""
        running: false
    }

    function saveFolder(f) {
        currentFolder = f
        saveConfigProc.command = ["python3", Paths.scripts + "/wallpaper-save-config.py", f]
        saveConfigProc.running = true
        loadImages()
    }

    // ── UI ─────────────────────────────────────────────────────
    // Overlay oscuro
    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        MouseArea {
            anchors.fill: parent
            onClicked: root.visible = false
        }
    }

    // Card
    Rectangle {
        id: card
        focus: true
        anchors.centerIn: parent
        width: 720
        height: Math.min(620, root.height * 0.82)
        radius: 16
        color: Theme.cardBg3
        border.color: Theme.surface2
        border.width: 1
        clip: true

        Keys.onEscapePressed: root.visible = false

        // Stripe superior
        Rectangle {
            width: parent.width; height: 3; radius: 3
            anchors.top: parent.top
            color: Theme.accent2
            Rectangle {
                width: parent.width * 0.45; height: parent.height
                anchors.right: parent.right
                color: Theme.accent
            }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            anchors.topMargin: 20
            spacing: 10

            // ── Header ───────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "󰡔"
                    font.pixelSize: 18
                    color: Theme.accent2
                }
                Text {
                    text: "Fondos de pantalla"
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    color: Theme.text
                }
                Text {
                    text: "(" + imageModel.count + ")"
                    font.pixelSize: 13
                    color: Theme.muted3
                    visible: !root._loading
                }
                Text {
                    text: "cargando..."
                    font.pixelSize: 12
                    color: Theme.muted3
                    visible: root._loading
                }

                Item { Layout.fillWidth: true }

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
                        onClicked: root.visible = false
                    }
                }
            }

            // ── Selector de carpeta ───────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                radius: 10
                color: Theme.cardBg3
                border.color: folderBarMa.containsMouse ? Theme.accent2 : Theme.surface2
                border.width: 1
                Behavior on border.color { ColorAnimation { duration: 150 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 6
                    spacing: 6

                    Text {
                        text: "󰉋"
                        font.pixelSize: 14
                        color: Theme.muted3
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.currentFolder
                        font.pixelSize: 12
                        color: Theme.muted1
                        elide: Text.ElideLeft
                    }

                    // Botón abrir explorador
                    Rectangle {
                        Layout.preferredWidth: 28; Layout.preferredHeight: 28; radius: 7
                        color: editBtnMa.containsMouse ? Theme.surface2 : "transparent"
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Text {
                            anchors.centerIn: parent
                            text: "󱂵"
                            font.pixelSize: 14
                            color: editBtnMa.containsMouse ? Theme.accent2 : Theme.muted3
                        }
                        MouseArea {
                            id: editBtnMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.requestFolderBrowser(root.currentFolder)
                        }
                    }
                }

                MouseArea {
                    id: folderBarMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.requestFolderBrowser(root.currentFolder)
                }
            }

            // ── Grid de imágenes ──────────────────────────────────
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                // Sin imágenes
                Column {
                    anchors.centerIn: parent
                    spacing: 10
                    visible: imageModel.count === 0 && !root._loading
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "󰋯"
                        font.pixelSize: 36
                        color: Theme.surface2
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "No se encontraron imágenes en esta carpeta"
                        font.pixelSize: 12
                        color: Theme.surface3
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Formatos: jpg, png, webp, bmp, gif"
                        font.pixelSize: 11
                        color: Theme.surface2
                    }
                }

                // Spinner de carga
                Column {
                    anchors.centerIn: parent
                    spacing: 10
                    visible: root._loading

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "󰔟"
                        font.pixelSize: 32
                        color: Theme.accent2
                        RotationAnimation on rotation {
                            running: root._loading
                            from: 0; to: 360
                            duration: 1000
                            loops: Animation.Infinite
                        }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Generando miniaturas..."
                        font.pixelSize: 12
                        color: Theme.muted3
                    }
                }

                GridView {
                    id: gridView
                    anchors.fill: parent
                    visible: imageModel.count > 0
                    model: imageModel
                    clip: true
                    reuseItems: true

                    cellWidth:  Math.floor(gridView.width / 3)
                    cellHeight: 158

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                        contentItem: Rectangle {
                            implicitWidth: 4; radius: 2; color: Theme.surface3
                        }
                    }

                    delegate: Item {
                        id: wpCell
                        width:  GridView.view.cellWidth
                        height: GridView.view.cellHeight

                        required property var   model
                        required property int   index

                        property bool isActive: root.currentWallpaper === wpCell.model.path

                        // reuseItems: resetear source al entrar al pool para evitar
                        // que la imagen anterior quede visible mientras carga la nueva
                        ListView.onPooled:  { thumb.source = "" }
                        ListView.onReused:  { thumb.source = wpCell.model.thumb !== "" ? ("file://" + wpCell.model.thumb) : "" }

                        Rectangle {
                            id: cellBg
                            anchors.fill: parent
                            anchors.margins: 4
                            radius: 10
                            color: cellMa.containsMouse ? Theme.surface2 : Theme.cardBg3
                            border.color: wpCell.isActive ? Theme.accent2 : (cellMa.containsMouse ? Theme.surface3 : Theme.surface2)
                            border.width: wpCell.isActive ? 2 : 1
                            clip: true
                            Behavior on border.color { ColorAnimation { duration: 100 } }

                            // Thumbnail
                            Image {
                                id: thumb
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: 120
                                source: wpCell.model.thumb !== "" ? ("file://" + wpCell.model.thumb) : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: true
                                smooth: true
                                clip: true

                                // Placeholder si falla la imagen
                                Rectangle {
                                    anchors.fill: parent
                                    color: Theme.cardBg3
                                    visible: thumb.status !== Image.Ready
                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰋯"
                                        font.pixelSize: 28
                                        color: Theme.surface2
                                    }
                                }
                            }

                            // Nombre del archivo
                            Text {
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.margins: 6
                                anchors.bottomMargin: 4
                                height: 30
                                text: wpCell.model.name
                                font.pixelSize: 10
                                color: Theme.muted1
                                elide: Text.ElideRight
                                verticalAlignment: Text.AlignVCenter
                            }

                            // Badge "activo"
                            Rectangle {
                                visible: wpCell.isActive
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: 6
                                width: 22; height: 22; radius: 11
                                color: Theme.accent2
                                Text {
                                    anchors.centerIn: parent
                                    text: "󰄬"
                                    font.pixelSize: 12
                                    color: Theme.cardBg3
                                }
                            }

                            // Hover overlay
                            Rectangle {
                                anchors.fill: thumb
                                color: Theme.hover2
                                visible: cellMa.containsMouse && !wpCell.isActive
                                radius: parent.radius
                                Behavior on opacity { NumberAnimation { duration: 100 } }
                            }
                        }

                        MouseArea {
                            id: cellMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                setProc.pending = wpCell.model.path
                                var outName = root.screen ? root.screen.name : ""
                                var cmd = ["bash", Paths.scripts + "/wallpaper-set.sh", wpCell.model.path]
                                if (outName) cmd.push(outName)
                                setProc.command = cmd
                                setProc.running = true
                            }
                        }
                    }
                }
            }
        }
    }
}
