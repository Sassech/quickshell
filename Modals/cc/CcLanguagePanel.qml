pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../Components"

// CcLanguagePanel
// Panel de selección de layout de teclado y locale del sistema.
Rectangle {
    id: root
    implicitWidth: 320
    implicitHeight: langDetailCol.implicitHeight + 32
    radius: 14
    color: Theme.cardBg3

    // Borde sutil
    Rectangle {
        anchors.fill: parent; radius: parent.radius; color: "transparent"
        border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2); border.width: 1
    }

    // Inputs
    required property var    filteredLayouts
    required property var    filteredLocales
    required property string langLayout
    required property string langLocale
    required property string langTab
    required property string langSearch

    // Outputs
    signal closeRequested()
    signal tabChanged(string tab)
    signal searchChanged(string query)
    signal setLayout(string code)
    signal setLocale(string value)

    // Sincroniza el TextInput cuando el padre resetea langSearch a ""
    onLangSearchChanged: {
        if (langSearchInput.text !== root.langSearch)
            langSearchInput.text = root.langSearch
    }

    Column {
        id: langDetailCol
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
        spacing: 8

        // Header
        Item {
            width: parent.width; height: 28
            Text {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                text: "Language & Locale"
                font.pixelSize: 12; font.weight: Font.DemiBold; color: Theme.text
            }
            Rectangle {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                width: 26; height: 26; radius: 7
                color: lCloseMA.containsMouse ? Theme.surface3 : Theme.surface2
                Behavior on color { ColorAnimation { duration: 100 } }
                Text { anchors.centerIn: parent; text: "󰅖"; font.pixelSize: 11; color: Theme.muted2 }
                MouseArea {
                    id: lCloseMA; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.closeRequested()
                }
            }
        }

        // Mini tabs
        Row {
            width: parent.width
            spacing: 4
            Repeater {
                model: [
                    { id: "keyboard", icon: "󰌌", label: "Keyboard" },
                    { id: "locale",   icon: "󰗊", label: "Locale"   }
                ]
                Rectangle {
                    id: tabBtn
                    required property var modelData
                    height: 24
                    width: langTabInner.implicitWidth + 16
                    radius: 6
                    color: root.langTab === tabBtn.modelData.id ? Theme.accentSurface : "transparent"
                    Behavior on color { ColorAnimation { duration: 80 } }
                    Row {
                        id: langTabInner
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: tabBtn.modelData.icon; font.pixelSize: 10
                            anchors.verticalCenter: parent.verticalCenter
                            color: root.langTab === tabBtn.modelData.id ? Theme.accent : Theme.muted3
                            Behavior on color { ColorAnimation { duration: 80 } }
                        }
                        Text {
                            text: tabBtn.modelData.label; font.pixelSize: 10
                            anchors.verticalCenter: parent.verticalCenter
                            color: root.langTab === tabBtn.modelData.id ? Theme.accent : Theme.muted3
                            Behavior on color { ColorAnimation { duration: 80 } }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.tabChanged(tabBtn.modelData.id)
                            root.searchChanged("")
                        }
                    }
                }
            }
        }

        // Search
        Rectangle {
            width: parent.width; height: 28; radius: 7
            color: Theme.surface3

            Row {
                anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                spacing: 6
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰍉"; font.pixelSize: 11; color: Theme.muted2
                }
                TextInput {
                    id: langSearchInput
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 26
                    font.pixelSize: 10; color: Theme.text
                    selectionColor: Theme.accent; selectedTextColor: Theme.text
                    clip: true
                    onTextChanged: root.searchChanged(text)
                    Text {
                        anchors.fill: parent
                        text: root.langTab === "keyboard" ? "Search layout…" : "Search locale…"
                        font.pixelSize: 10; color: Theme.muted2
                        visible: !parent.text && !parent.activeFocus
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }

        // Keyboard tab: layout list
        Item {
            visible: root.langTab === "keyboard"
            width: parent.width
            height: visible ? Math.min(root.filteredLayouts.length, 5) * 32 + 4 : 0
            clip: true

            ListView {
                anchors.fill: parent
                model: root.filteredLayouts
                spacing: 2
                clip: true

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle { implicitWidth: 3; radius: 2; color: Theme.surface3 }
                }

                delegate: Rectangle {
                    id: langItem
                    required property var modelData
                    required property int index
                    width: ListView.view.width; height: 30; radius: 7
                    property bool isActive: {
                        var layout = (root.langLayout || "").toLowerCase()
                        var code   = (langItem.modelData.code || "").toLowerCase()
                        return layout.indexOf(code) >= 0 || code.indexOf(layout) >= 0
                    }
                    color: langItemHov.containsMouse
                        ? Theme.surface3
                        : (langItem.isActive ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15) : "transparent")
                    Behavior on color { ColorAnimation { duration: 80 } }

                    Rectangle {
                        visible: langItem.isActive
                        width: 3; height: 14; radius: 2
                        anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
                        color: Theme.accent
                    }

                    RowLayout {
                        anchors { fill: parent; leftMargin: langItem.isActive ? 12 : 8; rightMargin: 8 }
                        Text {
                            Layout.fillWidth: true
                            text: langItem.modelData.code
                            font.pixelSize: 10; color: Theme.text
                            elide: Text.ElideRight
                        }
                        Text {
                            visible: langItem.isActive
                            text: "󰄬"; font.pixelSize: 10; color: Theme.accent
                        }
                    }

                    MouseArea {
                        id: langItemHov
                        anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.setLayout(langItem.modelData.code)
                    }
                }
            }
        }

        // Locale tab: locale list
        Item {
            visible: root.langTab === "locale"
            width: parent.width
            height: visible ? Math.min(root.filteredLocales.length, 5) * 32 + 4 : 0
            clip: true

            ListView {
                anchors.fill: parent
                model: root.filteredLocales
                spacing: 2
                clip: true

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle { implicitWidth: 3; radius: 2; color: Theme.surface3 }
                }

                delegate: Rectangle {
                    id: localeItem
                    required property var modelData
                    required property int index
                    width: ListView.view.width; height: 30; radius: 7
                    property bool isActive: {
                        var locale = (root.langLocale || "").toLowerCase()
                        var value  = (localeItem.modelData.value || "").toLowerCase()
                        return locale.indexOf(value) >= 0 || value.indexOf(locale) >= 0
                    }
                    color: localeItemHov.containsMouse
                        ? Theme.surface3
                        : (localeItem.isActive ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15) : "transparent")
                    Behavior on color { ColorAnimation { duration: 80 } }

                    Rectangle {
                        visible: localeItem.isActive
                        width: 3; height: 14; radius: 2
                        anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
                        color: Theme.accent
                    }

                    RowLayout {
                        anchors { fill: parent; leftMargin: localeItem.isActive ? 12 : 8; rightMargin: 8 }
                        Text {
                            Layout.fillWidth: true
                            text: localeItem.modelData.value
                            font.pixelSize: 10; color: Theme.text
                            elide: Text.ElideRight
                        }
                        Text {
                            visible: localeItem.isActive
                            text: "󰄬"; font.pixelSize: 10; color: Theme.accent
                        }
                    }

                    MouseArea {
                        id: localeItemHov
                        anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.setLocale(localeItem.modelData.value)
                    }
                }
            }
        }
    }
}
