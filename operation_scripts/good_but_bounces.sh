#!/bin/bash
# Close the shutter, wait 2 seconds, then load and trigger the test waveform,
# preserving the waveform's final value afterward.
#
# A temperature log file must be supplied via --log-file; the script refuses
# to run without one instead of silently disabling the overheat check.
#
# Usage: ./close_then_test.sh --log-file <path> [--threshold 60] [--count N]
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
set -e
PROJ_DIR="$SCRIPT_DIR"          # the scripts live here; hbr is in $REPO_ROOT/host
HBR="$REPO_ROOT/host/hbr"

LOG_FILE=""
COUNT=1
while [[ $# -gt 0 ]]; do
    case "$1" in
        --log-file)  LOG_FILE="$2";  shift 2 ;;
        --threshold) THRESHOLD="$2"; shift 2 ;;
        --count)     COUNT="$2";     shift 2 ;;
        *) echo "unexpected argument: $1" >&2; exit 1 ;;
    esac
done

if [ -z "$LOG_FILE" ]; then
    echo "usage: $0 --log-file <path> [--threshold C] [--count N]" >&2
    exit 1
fi

if [ ! -f "$LOG_FILE" ]; then
    echo "error: log file not found: $LOG_FILE" >&2
    exit 1
fi

if ! [[ "$COUNT" =~ ^[0-9]+$ ]] || [ "$COUNT" -lt 1 ]; then
    echo "error: --count must be a positive integer" >&2
    exit 1
fi

source "$PROJ_DIR/overheat_check.sh"

for ((i = 1; i <= COUNT; i++)); do
    echo "=== run $i/$COUNT ==="

    "$PROJ_DIR/close_shutter.sh"
    sleep 2

    if check_overheat; then
        echo "!!! Overheat detected in $LOG_FILE (threshold ${THRESHOLD}C) -- disabling preserve_last, not sending test waveform" >&2
        "$HBR" --nll --set_preserve_last 3 0
        exit 1
    fi

    "$HBR" --nll --set_pwm 24000
    "$HBR" --nll --read_table "$REPO_ROOT/waveforms/good_but_bounces.dat" 0 1 1 --load_table 1 1
    "$HBR" --nll --set_preserve_last 3 1
    "$HBR" --nll --start 2 0 1
done
