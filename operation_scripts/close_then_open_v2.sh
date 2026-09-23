#!/bin/bash
# v2: same as close_then_open.sh, but forces the H-bridge sequencer state
# machine back to idle (--sm_reset) before every trigger.
#
# Why: in hbr_sm.vhd, the "go ON"/"go OFF" triggers behind --start are only
# sampled while the FSM is in its idle state (busy='0'); a trigger that
# arrives while it's still mid-sequence is silently dropped, with no error
# and no retry. If that ever happens, the mechanism just stays wherever it
# last successfully completed -- which looks exactly like "gets to open and
# stays there". --sm_reset forces hbr_sm back to idle unconditionally
# (reset_sm='1' overrides the FSM's current state), so as long as it runs
# before each trigger, that trigger is guaranteed to land while idle.
#
# Usage: ./close_then_open_v2.sh <count>
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
set -e
PROJ_DIR="$SCRIPT_DIR"          # the scripts live here; hbr is in $REPO_ROOT/host
HBR="$REPO_ROOT/host/hbr"
CYCLE_GAP=0.8

count="$1"
if [ -z "$count" ] || ! [[ "$count" =~ ^[0-9]+$ ]] || [ "$count" -lt 1 ]; then
    echo "usage: $0 <count>" >&2
    exit 1
fi

for ((i = 1; i <= count; i++)); do
    echo "=== cycle $i/$count: closing ==="
    "$HBR" --nll --sm_reset 3
    "$PROJ_DIR/close_shutter.sh"
    sleep "$CYCLE_GAP"

    echo "=== cycle $i/$count: opening ==="
    "$HBR" --nll --sm_reset 3
    "$PROJ_DIR/open_shutter.sh"
    sleep "$CYCLE_GAP"
done
