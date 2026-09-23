#!/bin/bash
# Repeatedly close, sleep, then open the shutter, N times -- unless the
# temperature log shows an overheat condition, in which case preserve_last
# is disabled and the script stops running further cycles.
#
# Usage: ./close_then_open.sh <count> [--threshold 60] [--log-file path]
#
# close_shutter.sh/open_shutter.sh each already refuse to actuate (and
# disable preserve_last) if they detect overheat at the moment they start --
# see overheat_check.sh. This script additionally runs that same check in a
# background loop in parallel with the cycles, polling once a second, so an
# overheat that develops during the sleep gap between actions is caught
# immediately rather than only at the start of the next action.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
set -e
PROJ_DIR="$SCRIPT_DIR"
HBR="$PROJ_DIR/hbr"
POLL_INTERVAL=1
CYCLE_GAP=0.8

LOG_FILE=""
count=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --threshold) THRESHOLD="$2"; shift 2 ;;
        --log-file)  LOG_FILE="$2";  shift 2 ;;
        *)
            if [ -z "$count" ]; then count="$1"; shift
            else echo "unexpected argument: $1" >&2; exit 1; fi
            ;;
    esac
done

if [ -z "$count" ] || ! [[ "$count" =~ ^[0-9]+$ ]] || [ "$count" -lt 1 ]; then
    echo "usage: $0 <count> [--threshold C] [--log-file path]" >&2
    exit 1
fi

source "$PROJ_DIR/overheat_check.sh"

OVERHEAT_FLAG="/tmp/close_then_open_overheat_flag_$$"

monitor() {
    while [ ! -f "$OVERHEAT_FLAG" ]; do
        if check_overheat; then
            echo "!!! Overheat detected in $LOG_FILE (threshold ${THRESHOLD}C) -- disabling preserve_last" >&2
            "$HBR" --nll --set_preserve_last 3 0
            touch "$OVERHEAT_FLAG"
            break
        fi
        sleep "$POLL_INTERVAL"
    done
}

if [ -n "$LOG_FILE" ]; then
    monitor &
    MONITOR_PID=$!
    trap '[ -n "$MONITOR_PID" ] && kill "$MONITOR_PID" 2>/dev/null; rm -f "$OVERHEAT_FLAG"' EXIT
fi

stop_if_overheated() {
    if [ -f "$OVERHEAT_FLAG" ]; then
        echo "Stopping: overheat condition detected, preserve_last disabled." >&2
        exit 1
    fi
}

for ((i = 1; i <= count; i++)); do
    stop_if_overheated
    echo "=== cycle $i/$count: closing ==="
    "$PROJ_DIR/close_shutter.sh"
    sleep "$CYCLE_GAP"

    stop_if_overheated
    echo "=== cycle $i/$count: opening ==="
    "$PROJ_DIR/open_shutter.sh"
    sleep "$CYCLE_GAP"
done
