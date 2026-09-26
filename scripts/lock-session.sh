#!/usr/bin/env bash
# lock-session.sh — Lock the session via the native quickshell lockscreen.
#
# Rendezvous: a bare `qs ipc call lock lock` reaches exactly ONE quickshell
# instance (the default/oldest one, i.e. the main shell, which owns no `lock`
# target), so with 2+ instances running it fails with "Target not found.".
# --pid/-i selectors work but are launch-unstable, and `-c lockscreen` does
# not resolve (the root shell.qml shadows subdirs). This wrapper therefore
# fans the `lock` call out over every `quickshell` PID and succeeds when any
# instance accepts it (the `qs -p lockscreen` config owns target `lock`).
# Stateless: no PID files, no daemons, no config changes.
#
# Spawned by the CC Lock button via the shared runCmd flow:
#   ["bash", Paths.scripts + "/lock-session.sh"]
#
# Exit 0 if any instance accepted the lock call, nonzero otherwise.

set -uo pipefail

QS_BIN="${QS_BIN:-qs}"
LOCK_TARGET="${LOCK_TARGET:-lock}"
# Absolute lockscreen config dir (robust regardless of caller cwd).
LOCKSCREEN_DIR="$(cd "$(dirname "$0")/../lockscreen" >/dev/null 2>&1 && pwd)"

# Try `lock` on every quickshell instance; 0 if at least one is locked
# afterwards. `qs ipc` exits 0 even for "Target not found.", so ground truth
# is the follow-up `isLocked` round-trip, never the call exit code.
fan_out_lock() {
    local pid state
    # NB: `qs -p <config>` instances have comm `qs`, plain ones `quickshell`.
    # Short-lived `qs ipc` clients may match too — harmless, they never
    # answer `isLocked` with `true`.
    for pid in $(pgrep -x quickshell 2>/dev/null; pgrep -x qs 2>/dev/null); do
        "$QS_BIN" ipc --pid "$pid" call "$LOCK_TARGET" lock >/dev/null 2>&1
        state="$("$QS_BIN" ipc --pid "$pid" call "$LOCK_TARGET" isLocked 2>/dev/null)"
        if [ "$state" = "true" ]; then
            return 0
        fi
    done
    return 1
}

# Fast path: lockscreen already running.
if fan_out_lock; then
    exit 0
fi

# Slow path: no owner accepted it — start the lockscreen config detached
# (unless one is already coming up), then fan out again with a bound wait.
# Bracket idiom `[l]ockscreen` avoids pgrep matching its own command line.
if ! pgrep -f "[l]ockscreen" >/dev/null 2>&1; then
    setsid "$QS_BIN" -p "$LOCKSCREEN_DIR" >/dev/null 2>&1 < /dev/null &
fi

for _ in $(seq 1 25); do
    sleep 0.2
    if fan_out_lock; then
        exit 0
    fi
done

echo "lock-session.sh: no quickshell instance accepted 'lock'" >&2
exit 1
