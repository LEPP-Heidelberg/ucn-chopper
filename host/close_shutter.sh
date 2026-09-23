#!/bin/bash
# Load the closing waveform and trigger it.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
set -e
HBR="$SCRIPT_DIR/hbr"
source "$SCRIPT_DIR/overheat_check.sh"


#if check_overheat; then
#    echo "!!! Overheat detected in $LOG_FILE (threshold ${THRESHOLD}C) -- disabling preserve_last, not closing" >&2
    "$HBR" --nll --set_preserve_last 3 0
#    exit 1
#fi

"$HBR" --nll --set_pwm 25600
"$HBR" --nll --read_table "$SCRIPT_DIR/waveforms/close.dat" 0 1 1 --load_table 1 0
"$HBR" --nll --set_preserve_last 3 1 
"$HBR" --nll --start 2 0 0
