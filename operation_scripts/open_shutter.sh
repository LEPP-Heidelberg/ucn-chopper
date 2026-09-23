#!/bin/bash
# Load the opening waveform and trigger it.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
set -e
HBR="$REPO_ROOT/host/hbr"
source "$SCRIPT_DIR/overheat_check.sh"

if check_overheat; then
    echo "!!! Overheat detected in $LOG_FILE (threshold ${THRESHOLD}C) -- disabling preserve_last, not opening" >&2
    "$HBR" --nll --set_preserve_last 3 0
    exit 1
fi

"$HBR" --nll --set_pwm 25600
"$HBR" --nll --read_table "$REPO_ROOT/waveforms/open.dat" 0 1 1 --load_table 1 1
"$HBR" --nll --set_preserve_last 3 1
"$HBR" --nll --start 2 0 1
