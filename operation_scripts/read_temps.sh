#!/bin/bash
# Read all temperature sensors with raw register reads (hbr --rd_reg) and print
# them to the terminal. Same reads that `hbr --status` does internally, but the
# conversion is done here. Read-only, nothing is written to the board.
#
#   Pt100 x2       C_hbr::read_temper():   2 bytes at ADDR_PT100_0 + 0/1
#                  signed 16-bit ADC code -> R = slope_pt*PT100_SLOPE16*code -> PT100_TO_C(R)
#   1-wire DS18B20 C_dtemp::get_temp():    2 bytes at ADDR_DTEMP + 0/1 (top / bottom of H-bridge)
#                  bit 11 = sign, bits 10..0 = magnitude, T = value/16 (NOT two's complement)
#   presence mask  C_dtemp::get_presence_mask(): ADDR_DTEMP + 9
#
# Addresses are BRIDGE_BASE_ADDR-relative (C_hbr.h): 0x000000 for CPU_SW32
# (the Makefile default), 0x800000 for CPU_LM32 -> `BASE=0x800000 ./read_temps.sh`.
#
# Usage: ./read_temps.sh [--time]
#   --time  also measure how long the Pt100 readout takes (see time_pt100 below)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
set -e

DEV=${DEV:-/dev/ttyACM0}   # USB-CDC link; /dev/ttyUSB0 for the optical link
BASE=${BASE:-0x000000}
TIME_PT100=0
[ "$1" = "--time" ] && TIME_PT100=1
HBR=${HBR:-$REPO_ROOT/host/hbr}

ADDR_PT100_0=$((BASE + 0x0800 + 0x0004))
ADDR_DTEMP=$((BASE + 0x0490))

if [ ! -e "$DEV" ]; then
    echo "error: $DEV not found (board not connected / not attached in WSL?)" >&2
    exit 1
fi

# one hbr call, one hex line per --rd_reg, in order:
# pt100[0] pt100[1] dtemp[0] dtemp[1] presence
mapfile -t raw < <(
    "$HBR" --nll --dev "$DEV" \
        --rd_reg 2 $((ADDR_PT100_0))     --rd_reg 2 $((ADDR_PT100_0 + 1)) \
        --rd_reg 2 $((ADDR_DTEMP))       --rd_reg 2 $((ADDR_DTEMP + 1)) \
        --rd_reg 2 $((ADDR_DTEMP + 9)) | grep -E '^0x[0-9a-fA-F]+$'
)

if [ "${#raw[@]}" -ne 5 ]; then
    echo "error: expected 5 register values from hbr, got ${#raw[@]}" >&2
    exit 1
fi

# constants from C_hbr.h: R_PT_REF 99.858, slope_pt = {R_PT_REF/100.52, R_PT_REF/101.11},
# PT100_SLOPE16 = ADS_VREF/PT100_CURR/2^15 = 1.2/1e-3/32768
awk -v p0="${raw[0]}" -v p1="${raw[1]}" -v d0="${raw[2]}" -v d1="${raw[3]}" -v pres="${raw[4]}" '
function hex(s) { return strtonum(s) }
function pt100(code, slope,    r) {
    if (code >= 32768) code -= 65536          # sign-extend 16 bit
    r = slope * (1.2/1e-3/32768) * code
    return sprintf("%7.2f Ohm  %7.2f C", r, ((-5.67e-6*r + 0.0024984)*r + 2.22764)*r - 242.078)
}
function dtemp(v,    m) {
    m = v % 2048                              # bits 10..0
    return sprintf("%6.2f C", ((int(v/2048) % 2) ? -m : m) / 16)
}
BEGIN {
    printf "Pt100 0 (raw 0x%04x): %s\n", hex(p0), pt100(hex(p0), 99.858/100.52)
    printf "Pt100 1 (raw 0x%04x): %s\n", hex(p1), pt100(hex(p1), 99.858/101.11)
    printf "1-wire 0, top    of H-bridge (raw 0x%03x): %s\n", hex(d0), dtemp(hex(d0))
    printf "1-wire 1, bottom of H-bridge (raw 0x%03x): %s\n", hex(d1), dtemp(hex(d1))
    printf "1-wire presence mask 0x%02x, sensors expected by FPGA design: %d\n", hex(pres) % 256, int(hex(pres)/4096) % 16
}'

# --- timing of the Pt100 readout ---------------------------------------------
# One `hbr` call includes process start and opening the serial port, which would
# swamp the read itself. So time two calls with a different number of Pt100 read
# pairs (2 x `--rd_reg 2`, exactly what C_hbr::read_temper() does) and take the
# slope: (t_long - t_short) / (pairs_long - pairs_short) = time per readout.
time_pt100() {
    local pairs=$1 args=() i t0 t1
    for ((i = 0; i < pairs; i++)); do
        args+=(--rd_reg 2 $((ADDR_PT100_0)) --rd_reg 2 $((ADDR_PT100_0 + 1)))
    done
    t0=$(date +%s%N)
    "$HBR" --nll --dev "$DEV" "${args[@]}" > /dev/null
    t1=$(date +%s%N)
    echo $((t1 - t0))   # ns
}

if [ "$TIME_PT100" = 1 ]; then
    N_SHORT=1
    N_LONG=101
    t_short=$(time_pt100 $N_SHORT)
    t_long=$(time_pt100 $N_LONG)
    awk -v ts="$t_short" -v tl="$t_long" -v ns="$N_SHORT" -v nl="$N_LONG" 'BEGIN {
        per = (tl - ts) / (nl - ns)      # ns per readout (2 register reads)
        printf "\nPt100 readout timing (%d vs %d readouts per hbr call):\n", ns, nl
        printf "  hbr call, %3d readout : %8.1f ms  (includes hbr start + port open)\n", ns, ts/1e6
        printf "  hbr call, %3d readouts: %8.1f ms\n", nl, tl/1e6
        printf "  per Pt100 readout (2 reads): %8.3f ms\n", per/1e6
        printf "  per single register read   : %8.3f ms\n", per/2e6
        printf "  overhead (start + port open): %7.1f ms\n", (ts - per*ns)/1e6
    }'
fi
