# Shared overheat-detection helper. Meant to be `source`d, not run directly.
#
# Auto-detects the newest resistance_log_*.csv written by
# hmc8012_log_resistance.py (unless $LOG_FILE is already set by the caller),
# and defines check_overheat(), which looks at that CSV's 4th column
# (temperature_c): returns true (0) if that field is the literal string
# OVERHEAT, or a numeric value above $THRESHOLD; false (1) otherwise, or if
# no log file was found.
LOG_DIR="${LOG_DIR:-/home/thepworth/chopper}"
THRESHOLD="${THRESHOLD:-60}"

if [ -z "$LOG_FILE" ]; then
    LOG_FILE=$(ls -t "$LOG_DIR"/resistance_log_*.csv 2>/dev/null | head -1)
fi

if [ -z "$LOG_FILE" ] || [ ! -f "$LOG_FILE" ]; then
    echo "warning: no temperature log found (looked for $LOG_DIR/resistance_log_*.csv) -- overheat check disabled" >&2
    LOG_FILE=""
fi

check_overheat() {
    [ -z "$LOG_FILE" ] && return 1
    local last_temp
    last_temp=$(tail -n 1 "$LOG_FILE" | awk -F',' '{print $4}')
    [ -z "$last_temp" ] && return 1
    [ "$last_temp" = "OVERHEAT" ] && return 0
    awk -v t="$last_temp" -v th="$THRESHOLD" 'BEGIN { exit !(t+0 > th+0) }'
}
