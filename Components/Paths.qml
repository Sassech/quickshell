pragma Singleton
import QtQuick

// Paths — resolved once, shared by all widgets and modals.
// Eliminates 17 duplicate Qt.resolvedUrl() calls across the codebase.
QtObject {
    readonly property string scripts: Qt.resolvedUrl("../scripts").toString().replace("file://", "")
    readonly property string config:  Qt.resolvedUrl("../config").toString().replace("file://", "")
}
