#!/bin/bash
# TEST VARIANT of close_shutter.sh.
#
# Diagnostic purpose: register readback (--hbr_rep) after a normal
# init -> close_shutter run shows DECAY/TOFF/slow_decay/preserve_last/
# AFBR-OCPL-enable/PWM-frequency all differing from what initialize_fpga.sh
# set and verified moments earlier -- confirmed stable across repeated
# reads, so it's real hardware state, not a flaky read. Something about
# running the triggered sequence (--start) leaves this config unreliable,
# not just "doesn't survive an FPGA reconfig" as initialize_fpga.sh's
# comment warns.
#
# This script re-applies the full hbr_conf config (same values as the
# Makefile's hbr_conf target) immediately before loading the table and
# triggering --start, instead of trusting whatever initialize_fpga.sh set
# earlier to still be in effect. Then it dumps --hbr_rep both right before
# and right after the start trigger so you can see exactly what the
# hardware reports at each step, and compare against physical movement.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
set -e
HBR="$SCRIPT_DIR/hbr"
DEV=/dev/ttyUSB0
source "$SCRIPT_DIR/overheat_check.sh"

if check_overheat; then
    echo "!!! Overheat detected in $LOG_FILE (threshold ${THRESHOLD}C) -- disabling preserve_last, not closing" >&2
    "$HBR" --nll --set_preserve_last 3 0
    exit 1
fi

echo "=== full config re-apply (mirrors make hbr_conf) ==="
"$HBR" --nll --dev "$DEV" --set_pwm 24000 \
    --ctrl_in_afbr 0 0 0 --ctrl_in_afbr 1 0 0 \
    --ctrl_in_ocpl 0 1 0 --ctrl_in_ocpl 1 1 0 \
    --hbr_decay 0 --hbr_toff 0 \
    --set_slow_dec_sm 3 1 --set_preserve_last 3 1 \
    --hbr_sleep_n 1 --sm_reset 3

echo "=== config readback BEFORE loading table / triggering start ==="
"$HBR" --nll --hbr_rep

echo "=== load table and trigger start ==="
"$HBR" --nll --read_table "$SCRIPT_DIR/waveforms/close.dat" 0 1 1 --load_table 1 1
"$HBR" --nll --set_preserve_last 3 1
"$HBR" --nll --start 2 0 1

echo "=== config readback AFTER start ==="
"$HBR" --nll --hbr_rep
