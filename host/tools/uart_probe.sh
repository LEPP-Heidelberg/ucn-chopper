#!/bin/bash
# Raw UART32 register read/write, using nothing but stty and shell redirection.
#
# This is a connection test that bypasses hbr and all the C++ classes: it builds the
# UART32 packet by hand, sends it, and shows the bytes that come back. If this works,
# the cable, the port settings and the FPGA's UART32 slave are all fine, and any problem
# is in the software above.
#
# Usage:
#   ./uart_probe.sh read  <addr> [nbytes]   # nbytes 1..4, default 1
#   ./uart_probe.sh write <addr> <value> [nbytes]
#   ./uart_probe.sh status                  # a few known registers at once
#
# Environment: DEV (default /dev/ttyACM0), BAUD (default 4000000), ID (slave mask, default 1)
#
# Examples:
#   ./uart_probe.sh read 0x2003        # PWM frequency code  -> expect 0x00..0x07
#   ./uart_probe.sh read 0x0808 4      # CPU build stamp     -> e.g. 0x20260916
#   ./uart_probe.sh read 0x2002 3      # H-bridge status
#   ./uart_probe.sh status
#
# Packet format (see docs/CODE_MAP.md §3):
#   [slave_mask] [cmd] [len_hi] [addr_lo] [addr_mid] [addr_hi]  then the reply bytes
#   cmd = full(0x80) | ainc(0x40) | ((nwords-1)&7)<<3 | (nbytes-1)<<1 | r/w
set -u

DEV=${DEV:-/dev/ttyACM0}
BAUD=${BAUD:-4000000}
ID=${ID:-1}

die() { echo "error: $*" >&2; exit 1; }

[ -e "$DEV" ] || die "$DEV does not exist (board unplugged, or not attached to WSL?)"
[ -r "$DEV" ] && [ -w "$DEV" ] || die "no read/write permission on $DEV (are you in the 'dialout' group?)"

configure_port() {
    stty -F "$DEV" "$BAUD" raw -echo -echoe -echok -crtscts min 0 time 10 \
        || die "stty failed: does this port support $BAUD baud?"
}

# emit_bytes <b0> <b1> ...   writes the given byte values to stdout as raw bytes
emit_bytes() {
    local esc
    esc=$(printf '\\x%02X' "$@")     # text such as \x01\x C1 ... (no NUL bytes, so safe in $( ))
    printf '%b' "$esc"
}

# send_header <fd-target> <addr> <nbytes> <rw>   (rw: 1 = read, 0 = write)
# packet: slave_mask, cmd, len_hi, addr_lo, addr_mid, addr_hi
header_bytes() {
    local addr=$1 nbytes=$2 rw=$3
    local cmd=$(( 0x80 | 0x40 | ((nbytes - 1) << 1) | rw ))
    emit_bytes "$ID" "$cmd" 0 $(( addr & 0xFF )) $(( (addr >> 8) & 0xFF )) $(( (addr >> 16) & 0xFF ))
}

do_read() {
    local addr=$1 nbytes=${2:-1}
    [ "$nbytes" -ge 1 ] && [ "$nbytes" -le 4 ] || die "nbytes must be 1..4"
    configure_port
    exec 3<>"$DEV" || die "cannot open $DEV"
    header_bytes "$addr" "$nbytes" 1 >&3
    local hex
    hex=$(head -c "$nbytes" <&3 | xxd -p)
    exec 3<&-
    if [ -z "$hex" ]; then
        echo "no reply within ~1 s (FPGA not answering, wrong baud rate, or wrong port)"
        return 1
    fi
    # bytes arrive least-significant first
    local le="" i
    for (( i = ${#hex} - 2; i >= 0; i -= 2 )); do le="$le${hex:$i:2}"; done
    printf "addr 0x%06X  raw %-8s  value 0x%s  (%d)\n" "$addr" "$hex" "$le" "0x$le"
}

do_write() {
    local addr=$1 value=$2 nbytes=${3:-1}
    [ "$nbytes" -ge 1 ] && [ "$nbytes" -le 4 ] || die "nbytes must be 1..4"
    configure_port
    exec 3<>"$DEV" || die "cannot open $DEV"
    header_bytes "$addr" "$nbytes" 0 >&3
    local i
    for (( i = 0; i < nbytes; i++ )); do
        emit_bytes $(( (value >> (8 * i)) & 0xFF )) >&3
    done
    exec 3<&-
    printf "wrote 0x%0*X to addr 0x%06X (no reply expected: UART32 writes are not acknowledged)\n" \
        $(( nbytes * 2 )) "$value" "$addr"
}

do_status() {
    echo "device $DEV at $BAUD baud, board id $ID"
    echo
    printf "PWM frequency code   "; do_read 0x2003 1
    printf "H-bridge config      "; do_read 0x2000 3
    printf "H-bridge status      "; do_read 0x2002 3
    printf "CPU build date       "; do_read 0x0808 4
    printf "CPU build time       "; do_read 0x0809 4
    printf "Pt100 ch0 raw        "; do_read 0x0804 2
    printf "1-wire presence      "; do_read 0x0499 2
}

case "${1:-}" in
    read)   shift; [ $# -ge 1 ] || die "usage: $0 read <addr> [nbytes]";        do_read  $(( $1 )) "${2:-1}" ;;
    write)  shift; [ $# -ge 2 ] || die "usage: $0 write <addr> <value> [nbytes]"; do_write $(( $1 )) $(( $2 )) "${3:-1}" ;;
    status) do_status ;;
    *) sed -n '2,25p' "$0" | sed 's/^# \?//' ; exit 1 ;;
esac
