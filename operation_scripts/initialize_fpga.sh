#!/bin/bash
# Run after every power-cycle or `make refresh`: none of the HBR config,
# control-input routing, or ADC config survive an FPGA reconfiguration, so
# everything needed is re-applied directly here (mirrors the Makefile's
# hbr_conf, adc_conf and hbr_rep targets) -- no `make` call required.
#
# Without the adc_conf step, the ADS131M04 is never put into auto-read
# streaming mode, so `hbr --get_adc_buff` silently returns an empty/flat
# capture no matter what waveform you send.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
set -e

DEV=${DEV:-/dev/ttyACM0}   # USB-CDC link; use DEV=/dev/ttyUSB0 for the optical link
PROJ_DIR="$SCRIPT_DIR"          # the scripts live here; hbr is in $REPO_ROOT/host
HBR="$REPO_ROOT/host/hbr"

# same defaults as the Makefile's hbr_conf target
PWM_FREQ=25600
HBR_DECAY=2
HBR_TOFF=0
SLOW_DECAY="3 0"
PRESERVE_LAST="3 0"
# AFBR control inputs (NIM trigger in): both channels enabled, no invert
AFBR_CH0="0 1 0"
AFBR_CH1="1 1 0"
OCPL_CH0="0 1 0"
OCPL_CH1="1 1 0"

# same defaults as the Makefile's adc_conf target
ADS_SRATE=64000
ADS_GC=0
ADS_MUX=0
ADS_SHR=0
ADS_16BIT=1

if [ ! -e "$DEV" ]; then
    echo "error: $DEV not found (board not connected / not attached in WSL?)" >&2
    exit 1
fi

# --- hbr_conf ---
"$HBR" --nll --dev "$DEV" --set_pwm "$PWM_FREQ" \
    --ctrl_in_afbr $AFBR_CH0 --ctrl_in_afbr $AFBR_CH1 \
    --ctrl_in_ocpl $OCPL_CH0 --ctrl_in_ocpl $OCPL_CH1 \
    --hbr_decay "$HBR_DECAY" --hbr_toff "$HBR_TOFF" \
    --set_slow_dec_sm $SLOW_DECAY --set_preserve_last $PRESERVE_LAST \
    --hbr_sleep_n 1 --sm_reset 3

# --- adc_conf ---
"$HBR" --nll --adc_chip_mask 3 0 --adc_auto_read 0 1 0
sleep 1
"$HBR" --nll --adc_conf "$ADS_SRATE" "$ADS_GC" "$ADS_MUX" "$ADS_SHR" --adc_16 "$ADS_16BIT" --adc_auto_read 1 1 1 --adc_get_freq_per

# --- hbr_rep + status ---
"$HBR" --nll --hbr_rep --status
