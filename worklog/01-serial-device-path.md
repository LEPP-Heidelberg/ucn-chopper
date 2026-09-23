# 01 · Fix the serial device path in the bring-up script

**Date:** 2026-09-23
**Symptom:** `./initialize_fpga.sh` failed claiming the device path did not exist, although
`/dev/ttyACM0` was present.

## Cause

Line 13 of `initialize_fpga.sh` had two faults:

```bash
DEV= /dev/ttyAMC0
```

1. **A space after `=`.** In bash that assigns an *empty* `DEV` for the duration of one
   command and then tries to execute `/dev/ttyAMC0` as that command. With `set -e` the
   script exits immediately.
2. **`ttyAMC0` instead of `ttyACM0`** — the letters transposed.

So the script never had a device name; the error had nothing to do with the board.

`close_shutter_test.sh` had a related staleness: `DEV=/dev/ttyUSB0`, the optical link, while
the board is currently on the USB-CDC link.

## Change

Both scripts now take the device from the environment, with the USB-CDC link as default:

```bash
DEV=${DEV:-/dev/ttyACM0}   # USB-CDC link; use DEV=/dev/ttyUSB0 for the optical link
```

Run against the optical link with `DEV=/dev/ttyUSB0 ./initialize_fpga.sh`.

## Verified

- `bash -n` on both scripts: no syntax errors.
- Read-only link test against the board, which needs no configuration write:

  ```
  $ ./hbr --nll --dev /dev/ttyACM0 --rd_reg 1 0x2003 --rd_reg 4 0x0808
  0x04          # PWM frequency code 4 = 16 kHz
  0x20260916    # CPU firmware build stamp, 2026-09-16
  ```

  Both are plausible values, so the UART32 link and the FPGA are responding.

Not verified here: the full bring-up (`./initialize_fpga.sh`), which writes the H-bridge and
ADC configuration and enables the bridges.

## Note for later

This is the failure mode the code map warns about, seen from the other side: when a path is
wrong the script fails loudly, but when the *board* stops answering, `uart::ReadBuffer` hides
the timeout and `hbr` prints a plausible-looking value anyway. Worth remembering when the
serial layer is rewritten for NOMAD (`docs/nomad.html` §3).
