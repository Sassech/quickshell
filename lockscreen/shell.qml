pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam

// lockscreen — separate config owning WlSessionLock (qylock pattern).
// Runs via `qs -p lockscreen`; main shell.qml is untouched. Pre-gate hyprlock
// stays primary: this config idles unlocked until `qs ipc call lock lock`.
// Auth uses PamContext with the real 0.3.1 API (config + start()/respond() +
// completed(PamResult)); there is no service/tryUnlock/onUnlocked API.
ShellRoot {
    id: root

    // Password awaiting a PAM response slot (consumed by maybeRespond).
    property string _pendingPassword: ""

    LockContext {
        id: lockCtx
    }

    PamContext {
        id: pam
        // Service file lands in unit 2 (/etc/pam.d/quickshell-lock, root-owned).
        // Until then start() fails and the session stays locked by design.
        config: "quickshell-lock"

        onCompleted: result => {
            lockCtx.authInProgress = false
            root._pendingPassword = ""
            if (result === PamResult.Success) {
                sessionLock.locked = false
                lockCtx.clear()
            } else {
                if (result === PamResult.MaxTries)
                    console.warn("[lockscreen] PAM max tries reached")
                lockCtx.currentText = ""
                lockCtx.showFailure("Incorrect password, try again")
            }
        }
        onError: error => {
            lockCtx.authInProgress = false
            root._pendingPassword = ""
            lockCtx.showFailure("Authentication error, try again")
            console.warn("[lockscreen] PAM error: " + PamError.toString(error))
        }
        onResponseRequiredChanged: {
            if (pam.responseRequired)
                root.maybeRespond()
        }
    }

    WlSessionLock {
        id: sessionLock
        locked: false

        Component.onDestruction: {
            // Unlock-before-quit: never leave the session locked behind
            // a dying locker (placed here — children die before ShellRoot).
            // NOTE: `locked = false` is the release path; WlSessionLock has
            // no invokable unlock() on 0.3.1 (TypeError proven in testing).
            if (locked)
                locked = false
        }

        LockSurface {
            ctx: lockCtx
            locked: sessionLock.locked
            onAttemptLogin: root.submitPassword()
        }
    }

    // IPC contract: `qs ipc call lock <lock|unlock|isLocked>`.
    // unlock() bypasses PAM — recovery/test path only, never bound to keys.
    IpcHandler {
        target: "lock"

        function lock(): void {
            if (sessionLock.locked)
                return
            lockCtx.clear()
            sessionLock.locked = true
        }

        function unlock(): void {
            if (sessionLock.locked)
                sessionLock.locked = false
        }

        function isLocked(): bool {
            return sessionLock.locked
        }
    }

    // Password submit: start the PAM conversation if needed, then answer
    // the response slot. Single-prompt services need exactly one respond().
    function submitPassword(): void {
        if (!sessionLock.locked)
            return
        if (lockCtx.authInProgress)
            return
        const password = lockCtx.currentText
        if (password.length === 0)
            return
        lockCtx.clearFailure()
        root._pendingPassword = password
        if (!pam.active) {
            if (!pam.start()) {
                root._pendingPassword = ""
                lockCtx.showFailure("Authentication error, try again")
                return
            }
            lockCtx.authInProgress = true
        }
        root.maybeRespond()
    }

    function maybeRespond(): void {
        if (pam.responseRequired && root._pendingPassword !== "") {
            const password = root._pendingPassword
            root._pendingPassword = ""
            pam.respond(password)
        }
    }

    Component.onCompleted: console.log("Lockscreen config loaded")
}
