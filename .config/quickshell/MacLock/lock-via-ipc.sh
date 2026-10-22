#!/bin/sh
# Lock the session with the IPC-capable MacLock instance.
#
# Why this wrapper exists:
#  - Quickshell's WlSessionLock aborts (qFatal) if a second lock is requested
#    while one is already active. Serialize every invocation with flock so a
#    double press / two keybinds can never start two lockers.
#  - If MacLock dies while the compositor still holds the session lock,
#    Hyprland shows its "lockscreen app died" failsafe. This wrapper keeps
#    supervising while the session is locked and starts a fresh MacLock that
#    takes the orphaned lock over (misc:allow_session_lock_restore = true).
#  - Output goes to ~/.cache/maclock.log (appended, not truncated) so a crash
#    on another machine leaves a usable log.
set -u

MACLOCK_CONFIG="$HOME/.config/quickshell/MacLock"
MACLOCK_LOG="$HOME/.cache/maclock.log"
MACLOCK_LOCKFILE="${XDG_RUNTIME_DIR:-/tmp}/maclock.lock"
MAX_RESTARTS=3

log() {
    printf '%s [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$$" "$*" >>"$MACLOCK_LOG"
}

mkdir -p "$(dirname "$MACLOCK_LOG")"
# Keep the log bounded.
if [ -f "$MACLOCK_LOG" ] && [ "$(wc -c <"$MACLOCK_LOG")" -gt 1048576 ]; then
    mv -f "$MACLOCK_LOG" "$MACLOCK_LOG.old"
fi

# One launcher at a time: a double press must not create two session locks.
exec 9>"$MACLOCK_LOCKFILE"
if ! flock -n 9; then
    exit 0
fi

get_state() {
    qs -p "$MACLOCK_CONFIG" ipc call lockscreen state 2>/dev/null || true
}

lock_now() {
    qs -p "$MACLOCK_CONFIG" ipc call lockscreen lock 2>/dev/null || true
}

maclock_pid() {
    qs list 2>/dev/null | awk -v cfg="$MACLOCK_CONFIG/shell.qml" '
        /^Instance / { pid = "" }
        /Process ID:/ { pid = $3 }
        /Config path:/ { if (index($0, cfg) > 0) { print pid; exit } }
    '
}

# Hyprland exposes an active ext-session-lock as "LOCK" in a monitor's
# solitaryBlockedBy list. Read the JSON so a workspace/monitor name can't
# produce a false positive.
session_locked() {
    hyprctl -j monitors 2>/dev/null |
        jq -e 'any(.[]; (.solitaryBlockedBy // []) | index("LOCK"))' >/dev/null 2>&1
}

# setsid detaches the daemon from Hyprland's process group so it survives after
# hl.dsp.exec_cmd returns. 9>&- keeps the flock out of the child.
start_daemon() {
    setsid env MACLOCK_DAEMON=1 qs -n -p "$MACLOCK_CONFIG" >>"$MACLOCK_LOG" 2>&1 9>&- &
    sleep 0.2
}

wait_for_ipc() {
    tries=0
    while [ "$tries" -lt 60 ]; do
        case "$(get_state)" in
            ready|busy|stopping) return 0 ;;
        esac
        # Give a slow first launch a little grace before declaring it dead.
        if [ "$tries" -gt 5 ] && [ -z "$(maclock_pid)" ]; then
            return 1
        fi
        sleep 0.1
        tries=$((tries + 1))
    done
    return 1
}

QS_VERSION=$(qs --version 2>/dev/null | awk '{print $2}')
log "lock requested (quickshell ${QS_VERSION:-unknown})"
# Quickshell < 0.3.2 can abort with qFatal while creating a session lock,
# stranding the session on Hyprland's "lockscreen app died" screen.
if [ -n "$QS_VERSION" ] &&
   [ "$(printf '%s\n' 0.3.2 "$QS_VERSION" | sort -V | head -n 1)" != "0.3.2" ]; then
    log "WARNING: quickshell $QS_VERSION predates the session-lock crash fix in 0.3.2; upgrade quickshell."
fi

case "$(get_state)" in
    ready)
        lock_now
        ;;
    busy)
        # Already locked or currently entering the lock.
        log "already busy; exiting"
        exit 0
        ;;
    stopping)
        # Unlock animation finished, but the prior WlSessionLock process is
        # still exiting. Wait for it so we don't race into a reentrant lock.
        tries=0
        state=stopping
        while [ "$state" = "stopping" ] && [ "$tries" -lt 60 ]; do
            sleep 0.1
            state=$(get_state)
            tries=$((tries + 1))
        done
        if [ "$state" = "stopping" ]; then
            log "previous instance still shutting down; giving up"
            printf '%s\n' 'MacLock is still shutting down; try the lock key again in a moment.' >&2
            exit 1
        fi
        [ "$state" = "ready" ] && lock_now
        ;;
    *)
        start_daemon
        if ! wait_for_ipc; then
            log "IPC did not become ready"
            printf '%s\n' 'MacLock IPC did not become ready. Check ~/.cache/maclock.log.' >&2
            exit 1
        fi
        case "$(get_state)" in
            ready) lock_now ;;
            busy) log "became busy while starting; exiting"; exit 0 ;;
        esac
        ;;
esac

# Make sure the lock actually engaged before supervising it.
tries=0
while [ "$tries" -lt 50 ]; do
    session_locked && break
    sleep 0.1
    tries=$((tries + 1))
done
if ! session_locked; then
    log "lock did not engage (MacLock may have crashed); see log above"
    exit 1
fi

pid=$(maclock_pid)
log "locked; supervising pid ${pid:-unknown}"
restarts=0

# While the compositor is locked, make sure a live MacLock owns the UI.
# Normal unlock exits this loop; a crash is recovered without a reboot.
takeovers=0
while session_locked; do
    pid=$(maclock_pid)
    state=$(get_state)

    if [ -n "$pid" ] && [ "$state" = "busy" ]; then
        sleep 1
        continue
    fi

    if [ -n "$pid" ] && [ "$state" = "ready" ]; then
        # Quickshell's crash handler can restart the daemon after a crash, but
        # the new instance starts unlocked while the compositor still holds the
        # old lock. Ask it to take the orphaned lock over.
        takeovers=$((takeovers + 1))
        log "MacLock is alive but unlocked while session is locked (takeover $takeovers/$MAX_RESTARTS)"
        if [ "$takeovers" -gt "$MAX_RESTARTS" ]; then
            log "giving up after $MAX_RESTARTS takeover attempts"
            exit 1
        fi
        lock_now
        sleep 1
        continue
    fi

    if [ -z "$pid" ]; then
        # Normal unlock tears the lock down just before MacLock quits. Give
        # that a moment so we don't "recover" a session the user just opened.
        sleep 1
        session_locked || break
        [ -n "$(maclock_pid)" ] && continue

        restarts=$((restarts + 1))
        log "MacLock process vanished while session is locked (restart $restarts/$MAX_RESTARTS)"
        if [ "$restarts" -gt "$MAX_RESTARTS" ]; then
            log "giving up after $MAX_RESTARTS restarts"
            exit 1
        fi
        sleep 0.5
        start_daemon
        if ! wait_for_ipc; then
            log "restart: IPC did not become ready"
            sleep 1
            continue
        fi
        case "$(get_state)" in
            ready) lock_now ;;
            busy) : ;;
        esac
        sleep 1
        continue
    fi

    # Process exists but IPC is not answering yet; give it a moment.
    sleep 1
done

log "session unlocked; supervisor exiting"
exit 0
