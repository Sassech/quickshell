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
            "cat /home/sassech/.config/quickshell/config/wallpaper-config.json 2>/dev/null; " +
            "echo '---'; " +
            "cat /tmp/qs-current-wallpaper 2>/dev/null || true"
        ]
        property string buf: ""
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: d => configReadProc.buf += d + "\n"
        }
        onExited: {
            var parts = buf.split("---")
            try {
                var cfg = JSON.parse(parts[0].trim())
                if (cfg.folder) root.currentFolder = cfg.folder
            } catch(e) {}
            if (parts[1]) root.currentWallpaper = parts[1].trim()
            buf = ""
        }
    }

    onVisibleChanged: {
        if (visible) {
            loadImages()
        }
    }

    Component.onDestruction: {
        listProc.running = false
        setProc.running = false
        saveConfigProc.running = false
    }

    // ── Carga imágenes ─────────────────────────────────────────
    function loadImages() {
        if (_loading) return
        _loading = true
        _listBuf = ""
        imageModel.clear()
        listProc.running = true
    }

    Process {
        id: listProc
        command: ["python3",
            "/home/sassech/.config/quickshell/scripts/wallpaper-list.py",
            root.currentFolder
        ]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: d => root._listBuf += d + "\n"
        }
        onExited: {
            root._loading = false
            var items = []
            try { items = JSON.parse(root._listBuf) } catch(e) {}
            for (var i = 0; i < items.length; i++) imageModel.append(items[i])
        }
    }

    // ── Aplica wallpaper ───────────────────────────────────────
    Process {
        id: setProc
        property string pending: ""
        command: ["bash",
            "/home/sassech/.config/quickshell/scripts/wallpaper-set.sh",
            pending
        ]
        onExited: {
            root.currentWallpaper = pending
        }
    }

    // ── Guarda config ──────────────────────────────────────────
    Process {
        id: saveConfigProc
        command: ["python3", "/home/sassech/.config/quickshell/scripts/wallpaper-save-config.py", ""]
        property string pendingFolder: ""
        running: false
    }

    function saveFolder(f) {
        currentFolder = f
        saveConfigProc.command = ["python3", "/home/sassech/.config/quickshell/scripts/wallpaper-save-config.py", f]
        saveConfigProc.running = true
        loadImages()
    }

    // ── UI ─────────────────────────────────────────────────────
    // Overlay oscuro
    Rectangle {
        anchors.fill: parent
        color: "#88000000"
        MouseArea {
            anchors.fill: parent
            onClicked: root.visible = false
        }
    }

    // Card
    Rectangle {
        id: card
        anchors.centerIn: parent
        width: 720
        height: Math.min(620, root.height * 0.82)
        radius: 16
        color: Theme.base
        border.color: Theme.surface2
        border.width: 1
        clip: true

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
                    visible: !_loading
                }
                Text {
                    text: "cargando..."
                    font.pixelSize: 12
                    color: Theme.muted3
                    visible: _loading
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    width: 28; height: 28; radius: 8
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
                height: 38
                radius: 10
                color: Theme.base
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
                        width: 28; height: 28; radius: 7
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
                    visible: imageModel.count === 0 && !_loading
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
                    visible: _loading

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "󰔟"
                        font.pixelSize: 32
                        color: Theme.accent2
                        RotationAnimation on rotation {
                            running: _loading
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

                    cellWidth:  Math.floor(gridView.width / 3)
                    cellHeight: 158

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                        contentItem: Rectangle {
                            implicitWidth: 4; radius: 2; color: Theme.surface3
                        }
                    }

                    delegate: Item {
                        width:  gridView.cellWidth
                        height: gridView.cellHeight

                        required property var   model
                        required property int   index

                        property bool isActive: root.currentWallpaper === model.path

                        Rectangle {
                            id: cellBg
                            anchors.fill: parent
                            anchors.margins: 4
                            radius: 10
                            color: cellMa.containsMouse ? Theme.surface2 : Theme.base
                            border.color: isActive ? Theme.accent2 : (cellMa.containsMouse ? Theme.surface3 : Theme.surface2)
                            border.width: isActive ? 2 : 1
                            clip: true
                            Behavior on border.color { ColorAnimation { duration: 100 } }

                            // Thumbnail
                            Image {
                                id: thumb
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: 120
                                source: model.thumb !== "" ? ("file://" + model.thumb) : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: true
                                smooth: true
                                clip: true

                                // Placeholder si falla la imagen
                                Rectangle {
                                    anchors.fill: parent
                                    color: Theme.base
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
                                text: model.name
                                font.pixelSize: 10
                                color: Theme.muted1
                                elide: Text.ElideRight
                                verticalAlignment: Text.AlignVCenter
                            }

                            // Badge "activo"
                            Rectangle {
                                visible: isActive
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: 6
                                width: 22; height: 22; radius: 11
                                color: Theme.accent2
                                Text {
                                    anchors.centerIn: parent
                                    text: "󰄬"
                                    font.pixelSize: 12
                                    color: Theme.base
                                }
                            }

                            // Hover overlay
                            Rectangle {
                                anchors.fill: thumb
                                color: Theme.hover2
                                visible: cellMa.containsMouse && !isActive
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
                                setProc.pending = model.path
                                setProc.running = true
                            }
                        }
                    }
                }
            }
        }
    }
}
