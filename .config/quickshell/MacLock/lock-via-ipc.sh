#!/bin/sh
# Each WlSessionLock instance is used once. Start a fresh IPC-capable instance per lock.
set -u

MACLOCK_CONFIG="$HOME/.config/quickshell/MacLock"
MACLOCK_LOG="$HOME/.cache/maclock.log"

get_state() {
    qs -p "$MACLOCK_CONFIG" ipc call lockscreen state 2>/dev/null || true
}

lock_now() {
    exec qs -p "$MACLOCK_CONFIG" ipc call lockscreen lock
}

state=$(get_state)
case "$state" in
    ready)
        lock_now
        ;;
    busy)
        # Already locked or currently entering the lock; don't start a competing locker.
        exit 0
        ;;
    stopping)
        # Unlock animation completed, but the prior WlSessionLock process is still exiting.
        tries=0
        while [ "$state" = "stopping" ] && [ "$tries" -lt 60 ]; do
            sleep 0.1
            state=$(get_state)
            tries=$((tries + 1))
        done
        if [ "$state" = "stopping" ]; then
            printf '%s\n' 'MacLock is still shutting down; try the lock key again in a moment.' >&2
            exit 1
        fi
        ;;
esac

# No live IPC endpoint: create a new instance, wait for it, then request the lock.
# setsid detaches the daemon from Hyprland's process group so it survives after
# hl.dsp.exec_cmd returns (otherwise Hyprland may kill the backgrounded qs process,
# releasing the session lock immediately).
mkdir -p "$(dirname "$MACLOCK_LOG")"
setsid env MACLOCK_DAEMON=1 qs -p "$MACLOCK_CONFIG" >"$MACLOCK_LOG" 2>&1 &
daemon_pid=$!
tries=0
while [ "$tries" -lt 60 ]; do
    state=$(get_state)
    case "$state" in
        ready) lock_now ;;
        busy) exit 0 ;;
    esac
    if ! kill -0 "$daemon_pid" 2>/dev/null; then
        break
    fi
    sleep 0.1
    tries=$((tries + 1))
done

printf '%s\n' 'MacLock IPC did not become ready. Check that Quickshell can load the MacLock config.' >&2
exit 1
