pragma ComponentBehavior: Bound

import QtQuick

// LockContext — shared auth/UI state for every lock surface.
// One instance lives in lockscreen/shell.qml; each LockSurface binds to it
// so password text, failure and caps state stay in sync across monitors.
QtObject {
    id: root

    // Password text shared by all per-screen fields.
    property string currentText: ""
    // Last PAM failure message shown under the password field ("" = none).
    property string failureMessage: ""
    // Heuristic caps-lock state, updated from key events in LockSurface.
    property bool capsOn: false
    // True while a PAM conversation is in flight (start() -> completed).
    property bool authInProgress: false

    function showFailure(message: string): void {
        root.failureMessage = message
    }

    function clearFailure(): void {
        root.failureMessage = ""
    }

    // Full reset: used on lock() and after a successful unlock.
    function clear(): void {
        root.currentText = ""
        root.failureMessage = ""
        root.capsOn = false
        root.authInProgress = false
    }
}
