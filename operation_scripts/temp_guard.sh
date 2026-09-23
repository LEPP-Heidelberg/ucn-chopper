#!/bin/bash
# Temperature interlock for the UCN chopper, using the board's own sensors.
#
# Reads the two Pt100 sensors (and the two 1-wire sensors, for the log) through hbr,
# converts the raw ADC codes to degrees Celsius, appends a line to a CSV log, and:
#
#   * exits 0 if every sensor is below the threshold          -> safe to move the shutter
#   * exits 1 if any sensor is at or above it                 -> caller must not move
#   * exits 2 if the board could not be read                  -> treated as unsafe
#
# On a trip (and on a read failure with STRICT=1) it puts the H-bridges to sleep:
# preserve-last off, then SLEEP_n = 0, which removes drive current from both channels.
#
# Usage:
#   ./temp_guard.sh check                 # one-shot check, the default
#   ./temp_guard.sh monitor [interval_s]  # keep checking until it trips or is interrupted
#   ./temp_guard.sh status                # print temperatures, never trips, exit 0
#   ./temp_guard.sh sleep                 # put the bridges to sleep now (manual panic switch)
#
#   ./temp_guard.sh check && ./open_shutter.sh      # use it as a guard before a move
#
# Environment:
#   DEV        serial device            (default /dev/ttyACM0; /dev/ttyUSB0 = optical link)
#   THRESHOLD  trip temperature in C    (default 60)
#   LOG_FILE   CSV log                  (default <repo>/logs/temperature_YYYYMMDD.csv)
#   INTERVAL   monitor period in s      (default 10)
#   SLEEP_ON_TRIP  1 = sleep on trip    (default 1; set 0 to only warn)
#   STRICT     1 = a read failure also puts the bridges to sleep (default 0)
#
# Conversions follow C_hbr.h / C_hbr::read_temper:
#   Pt100:  R = slope_pt[i] * (VREF/I/2^15) * signed_code,  T from the Pt100 polynomial
#   1-wire: bit 11 is the sign, magnitude/16 = degrees (NOT two's complement)
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

HBR=${HBR:-$REPO_ROOT/host/hbr}
DEV=${DEV:-/dev/ttyACM0}
THRESHOLD=${THRESHOLD:-60}
INTERVAL=${INTERVAL:-10}
SLEEP_ON_TRIP=${SLEEP_ON_TRIP:-1}
STRICT=${STRICT:-0}
LOG_FILE=${LOG_FILE:-$REPO_ROOT/logs/temperature_$(date +%Y%m%d).csv}

# register addresses (CPU_SW32 build; see docs/CODE_MAP.md section 5)
ADDR_PT100_0=0x0804
ADDR_PT100_1=0x0805
ADDR_DTEMP_0=0x0490
ADDR_DTEMP_1=0x0491

die() { echo "temp_guard: $*" >&2; exit 2; }

[ -x "$HBR" ] || die "hbr not found at $HBR (build it: cd $REPO_ROOT/host && make hbr)"

log_line() {   # log_line <state> <pt0> <pt1> <dt0> <dt1> <note>
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null
    if [ ! -f "$LOG_FILE" ]; then
        echo 'timestamp,state,pt100_0_c,pt100_1_c,dtemp_top_c,dtemp_bottom_c,threshold_c,"note"' > "$LOG_FILE"
    fi
    printf '%s,%s,%s,%s,%s,%s,%s,"%s"\n' \
        "$(date -Is)" "$1" "$2" "$3" "$4" "$5" "$THRESHOLD" "$6" >> "$LOG_FILE"
}

bridges_to_sleep() {
    echo "temp_guard: putting the H-bridges to sleep (preserve-last off, SLEEP_n = 0)" >&2
    "$HBR" --nll --dev "$DEV" --set_preserve_last 3 0 >/dev/null 2>&1
    "$HBR" --nll --dev "$DEV" --hbr_sleep_n 0       >/dev/null 2>&1
}

# reads the four sensors in one hbr call; echoes "pt0 pt1 dt0 dt1" in degrees C,
# or nothing at all if the board did not answer properly
read_temperatures() {
    local raw
    raw=$("$HBR" --nll --dev "$DEV" \
            --rd_reg 2 $((ADDR_PT100_0)) --rd_reg 2 $((ADDR_PT100_1)) \
            --rd_reg 2 $((ADDR_DTEMP_0)) --rd_reg 2 $((ADDR_DTEMP_1)) 2>&1)

    # hbr hides read timeouts and prints this instead of failing (see docs/CODE_MAP.md section 10)
    if grep -q "ReadBuffer" <<<"$raw"; then return 1; fi

    local codes
    mapfile -t codes < <(grep -E '^0x[0-9a-fA-F]+$' <<<"$raw")
    [ "${#codes[@]}" -eq 4 ] || return 1

    awk -v p0="${codes[0]}" -v p1="${codes[1]}" -v d0="${codes[2]}" -v d1="${codes[3]}" '
        function pt100(code, slope,   r) {
            if (code >= 32768) code -= 65536                 # sign-extend 16 bit
            r = slope * (1.2 / 1e-3 / 32768) * code          # ADC code -> ohms
            if (r <= 0) return "nan"                         # open circuit / no answer
            return ((-5.67e-6 * r + 0.0024984) * r + 2.22764) * r - 242.078
        }
        function dtemp(v,   m) {
            m = v % 2048                                     # bits 10..0 = magnitude
            return ((int(v / 2048) % 2) ? -m : m) / 16       # bit 11 = sign
        }
        BEGIN {
            printf "%.2f %.2f %.2f %.2f\n",
                   pt100(strtonum(p0), 99.858/100.52),
                   pt100(strtonum(p1), 99.858/101.11),
                   dtemp(strtonum(d0)), dtemp(strtonum(d1))
        }'
}

# plausibility: a Pt100 reading outside this range means a broken sensor or a bad read,
# not a real temperature
sane() { awk -v t="$1" 'BEGIN { exit !(t == t + 0 && t > -50 && t < 300) }'; }

do_check() {                       # 0 = safe, 1 = too hot, 2 = unreadable
    local temps pt0 pt1 dt0 dt1
    temps=$(read_temperatures) || {
        echo "temp_guard: could not read the board on $DEV" >&2
        log_line "ERROR" "" "" "" "" "no answer from the board"
        [ "$STRICT" = 1 ] && bridges_to_sleep
        return 2
    }
    read -r pt0 pt1 dt0 dt1 <<<"$temps"

    if ! sane "$pt0" || ! sane "$pt1"; then
        echo "temp_guard: implausible Pt100 readings ($pt0, $pt1 C) - sensor or link fault" >&2
        log_line "ERROR" "$pt0" "$pt1" "$dt0" "$dt1" "implausible reading"
        [ "$STRICT" = 1 ] && bridges_to_sleep
        return 2
    fi

    local hot
    hot=$(awk -v a="$pt0" -v b="$pt1" -v th="$THRESHOLD" 'BEGIN { print (a >= th || b >= th) ? 1 : 0 }')
    if [ "$hot" = 1 ]; then
        echo "temp_guard: OVER THRESHOLD - Pt100 ${pt0} C / ${pt1} C, limit ${THRESHOLD} C" >&2
        if [ "$SLEEP_ON_TRIP" = 1 ]; then
            bridges_to_sleep
            log_line "TRIP" "$pt0" "$pt1" "$dt0" "$dt1" "over threshold; bridges asleep"
        else
            log_line "TRIP" "$pt0" "$pt1" "$dt0" "$dt1" "over threshold; SLEEP_ON_TRIP=0"
        fi
        return 1
    fi

    printf 'temp_guard: OK  Pt100 %s C / %s C   1-wire %s C / %s C   (limit %s C)\n' \
        "$pt0" "$pt1" "$dt0" "$dt1" "$THRESHOLD"
    log_line "OK" "$pt0" "$pt1" "$dt0" "$dt1" ""
    return 0
}

case "${1:-check}" in
    check)
        do_check
        ;;
    status)
        THRESHOLD=100000 SLEEP_ON_TRIP=0 do_check
        exit 0
        ;;
    monitor)
        [ $# -ge 2 ] && INTERVAL=$2
        echo "temp_guard: monitoring every ${INTERVAL}s, limit ${THRESHOLD} C, log $LOG_FILE"
        while true; do
            do_check; rc=$?
            [ "$rc" -eq 1 ] && { echo "temp_guard: tripped, stopping"; exit 1; }
            [ "$rc" -eq 2 ] && [ "$STRICT" = 1 ] && { echo "temp_guard: read failure, stopping"; exit 2; }
            sleep "$INTERVAL"
        done
        ;;
    sleep)
        bridges_to_sleep
        log_line "MANUAL" "" "" "" "" "bridges put to sleep by hand"
        ;;
    *)
        sed -n '2,32p' "$0" | sed 's/^# \?//'
        exit 2
        ;;
esac
