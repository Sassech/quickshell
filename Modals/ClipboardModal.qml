// qmllint disable uncreatable-type
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Io
import "../Components"

QmModalBase {
    id: root

    cardWidth: 580
    cardFixedHeight: 520
    cardHeightFactor: 0.65
    cardRadius: 14
    cardBorderColor: Qt.rgba(1, 1, 1, 0.06)
    cardClip: true

    // ── Data ────────────────────────────────────────────────────────────
    property var  allEntries:  []
    property int  entryCount:  0
    property bool isLoading:   false

    signal countChanged(int n)

    onVisibleChanged: {
        if (visible) {
            searchField.text = ""
            updateDisplay()
            loadEntries()
        }
    }

    // Pre-carga al inicio para que la primera apertura sea instantánea
    Component.onCompleted: loadEntries()

    property string _listBuf: ""

    function loadEntries() {
        if (isLoading) return
        isLoading = true
        _listBuf = ""
        listProc.running = true
    }

    function updateDisplay() {
        var q = searchField.text.toLowerCase()
        displayModel.clear()
        var src = q ? allEntries.filter(function(e) {
            return e.preview.toLowerCase().indexOf(q) >= 0
        }) : allEntries
        for (var i = 0; i < src.length; i++) displayModel.append(src[i])
    }

    // ── Debounce búsqueda ────────────────────────────────────────────────
    Timer {
        id: searchDebounce
        interval: 150
        onTriggered: root.updateDisplay()
    }

    // ── Carga la lista ──────────────────────────────────────────────────
    Process {
        id: listProc
        command: ["bash", Paths.scripts + "/clipboard-list.sh"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => root._listBuf += data
        }
        // qmllint disable signal-handler-parameters
        onExited: function(exitCode) {
            if (exitCode !== 0) {
                console.log("[ClipboardModal] listProc failed with code:", exitCode)
            }

            try {
                var parsed = JSON.parse(root._listBuf)
                if (Array.isArray(parsed)) {
                    root.allEntries = parsed
                } else {
                    console.log("[ClipboardModal] JSON invalid - expected array")
                    root.allEntries = []
                }
            } catch(e) {
                console.log("[ClipboardModal] JSON parse error:", e)
                root.allEntries = []
            }

            root.isLoading = false
            root.entryCount = root.allEntries.length
            root.countChanged(root.entryCount)
            root.updateDisplay()
        }
        // qmllint enable signal-handler-parameters
    }

    // ── Copia al portapapeles ───────────────────────────────────────────
    Process {
        id: copyProc

            property bool _isCopying: false

        function copyEntry(id) {
            if (_isCopying) return
            _isCopying = true
            copyProc.command = ["bash", Paths.scripts + "/clipboard-copy.sh", id]
            copyProc.running = true
        }

        // qmllint disable signal-handler-parameters
        onExited: function(exitCode) {
            _isCopying = false
            if (exitCode !== 0) {
                console.log("[ClipboardModal] copyProc failed with code:", exitCode)
                root.close()
                return
            }
            // No recargar inmediatamente - los IDs cambian al copiar porque
            // cliphist store detecta el cambio y crea nueva entrada
            // El usuario puede recargar manualmente si necesita ver actualizaciones
            delayClose.start()
        }
        // qmllint enable signal-handler-parameters
    }

    // Timer para cerrar modal después de copiar
    Timer {
        id: delayClose
        interval: 100
        onTriggered: root.close()
    }

    // ── Limpia todo ─────────────────────────────────────────────────────
    Process {
        id: wipeProc
        command: ["bash", "-c", "cliphist wipe 2>>/tmp/qs-clipboard.log"]
        // qmllint disable signal-handler-parameters
        onExited: function(exitCode) {
            if (exitCode !== 0) {
                console.log("[ClipboardModal] wipeProc failed with code:", exitCode)
            }
            root.loadEntries()
        }
        // qmllint enable signal-handler-parameters
    }

    ListModel { id: displayModel }

    // ── UI ──────────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        anchors.topMargin: 20
        spacing: 10

        // ── Header ───────────────────────────────────────────────
        RowLayout {
            spacing: 8
            Layout.fillWidth: true

            Text {
                text: "󱉫"
                font.pixelSize: 18
                color: Theme.accent2
            }
            Text {
                text: "Historial del portapapeles"
                font.pixelSize: 14
                font.weight: Font.DemiBold
                color: Theme.text
            }
            Text {
                text: "(" + displayModel.count + ")"
                font.pixelSize: 13
                color: Theme.muted3
            }

            Item { Layout.fillWidth: true }

            // Limpiar todo
            Rectangle {
                Layout.preferredWidth: 28; Layout.preferredHeight: 28; radius: 8
                color: wipeMa.containsMouse ? Theme.error : Theme.warning
                opacity: wipeMa.containsMouse ? 1.0 : 0.7
                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on opacity { NumberAnimation { duration: 120 } }
                Text {
                    anchors.centerIn: parent
                    text: "󱃦"
                    font.pixelSize: 14
                    color: wipeMa.containsMouse ? Theme.cardBg3 : Theme.text
                }
                MouseArea {
                    id: wipeMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: wipeProc.running = true
                }
            }
        }

        // ── Buscador ──────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 40

            // Foco visual (borde accent)
            Rectangle {
                anchors.fill: parent
                radius: 10
                color: "transparent"
                border.color: searchField.activeFocus ? Theme.accent : "transparent"
                border.width: 2
                Behavior on border.color { ColorAnimation { duration: 150 } }
            }

            // Icono lupa
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: "󰍉"
                font.pixelSize: 18
                color: searchField.text !== "" ? Theme.accent2 : Theme.muted3
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            TextInput {
                id: searchField
                anchors.fill: parent
                leftPadding: 40
                rightPadding: 12
                font.pixelSize: 16
                color: Theme.text
                selectionColor: Theme.accent
                selectedTextColor: Theme.text
                clip: true
                verticalAlignment: TextInput.AlignVCenter

                Text {
                    anchors.fill: parent
                    text: "Buscar en portapapeles..."
                    font.pixelSize: 15
                    color: Theme.muted3
                    visible: !parent.text && !parent.activeFocus
                    verticalAlignment: Text.AlignVCenter
                }

                onTextChanged: searchDebounce.restart()
                Keys.onEscapePressed: root.close()
                Keys.onReturnPressed: {
                    if (displayModel.count > 0)
                        copyProc.copyEntry(displayModel.get(0).id)
                }
                Keys.onDownPressed: {
                    listView.focus = true
                    listView.currentIndex = 0
                }
            }
        }

        // ── Lista ─────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Empty / Loading state
            Column {
                anchors.centerIn: parent
                spacing: 8
                visible: displayModel.count === 0

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.isLoading ? "Cargando..." : "󰆏"
                    font.pixelSize: root.isLoading ? 13 : 32
                    color: Theme.muted3
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.isLoading ? "" : (searchField.text ? "Sin resultados" : "No hay entradas en el portapapeles")
                    font.pixelSize: 12
                    color: Theme.surface3
                }
            }

            ListView {
                id: listView
                anchors.fill: parent
                model: displayModel
                spacing: 2
                clip: true
                focus: false
                keyNavigationEnabled: true
                highlightFollowsCurrentItem: true
                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle {
                        implicitWidth: 4
                        radius: 2
                        color: Theme.surface3
                    }
                }

                // Resaltado de navegación por teclado
                highlight: Rectangle {
                    radius: 8
                    color: Qt.rgba(1, 1, 1, 0.08)
                    Behavior on y { NumberAnimation { duration: 100 } }
                }

                Keys.onReturnPressed: {
                    if (currentIndex >= 0 && currentIndex < displayModel.count)
                        copyProc.copyEntry(displayModel.get(currentIndex).id)
                }
                Keys.onEnterPressed: {
                    if (currentIndex >= 0 && currentIndex < displayModel.count)
                        copyProc.copyEntry(displayModel.get(currentIndex).id)
                }
                Keys.onEscapePressed: root.close()

                delegate: Rectangle {
                    id: row
                    width: ListView.view.width - 8
                    height: hasThumb ? 84 : 40
                    radius: 8
                    color: rowMa.containsMouse ? Theme.surface2 : "transparent"
                    Behavior on color { ColorAnimation { duration: 100 } }
                    clip: true

                    required property var model
                    required property int index

                    property bool hasThumb: row.model.thumb !== undefined && row.model.thumb !== ""

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 6
                        anchors.topMargin: row.hasThumb ? 6 : 0
                        anchors.bottomMargin: row.hasThumb ? 6 : 0
                        spacing: 8

                        // Thumbnail de imagen
                        Image {
                            visible: row.hasThumb
                            source: row.hasThumb ? ("file://" + row.model.thumb) : ""
                            sourceSize.width: 72; sourceSize.height: 72
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            Layout.preferredWidth: 72
                            Layout.preferredHeight: 72
                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                                border.color: Theme.surface3
                                border.width: 1
                                radius: 4
                            }
                        }

                        // Icono de tipo (solo para texto)
                        Text {
                            visible: !row.hasThumb
                            text: row.model.isBinary ? "󰋼" : "󰆏"
                            font.pixelSize: 13
                            color: row.model.isBinary ? Theme.sky : Theme.muted3
                            Layout.preferredWidth: 16
                        }

                        // Preview / dimensiones
                        Text {
                            Layout.fillWidth: true
                            text: row.model.preview
                            font.pixelSize: row.hasThumb ? 10 : 12
                            color: row.model.isBinary ? Theme.muted3 : Theme.text
                            elide: Text.ElideRight
                            font.italic: row.model.isBinary && !row.hasThumb
                        }
                    }

                    MouseArea {
                        id: rowMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            copyProc.copyEntry(row.model.id)
                        }
                    }
                }
            }
        }
    }
}
