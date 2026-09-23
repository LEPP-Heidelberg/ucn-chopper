# 02 · Raw UART32 probe (no C++)

**Date:** 2026-09-23
**Goal:** be able to check the link to the FPGA at byte level, without `hbr` or any of the
C++ classes, so that "is the connection alive?" can be answered independently of the
software stack.

## What was added

`operation_scripts/uart_probe.sh` — a pure shell script using `stty` and shell redirection:

```bash
cd operation_scripts
./uart_probe.sh status              # a few known registers at once
./uart_probe.sh read  0x2003        # PWM frequency code (1 byte)
./uart_probe.sh read  0x0808 4      # CPU build stamp (4 bytes)
./uart_probe.sh write 0x2003 5      # set PWM code 5 (25.6 kHz)
DEV=/dev/ttyUSB0 ./uart_probe.sh status     # optical link
```

*(Originally added under `host/tools/`; moved to `operation_scripts/` to match the folder
reorganisation — it is an operator-facing diagnostic, like `read_temps.sh`, and it has no
path dependencies of its own.)*

It builds the UART32 packet by hand:

```
[slave_mask] [cmd] [len_hi] [addr_lo] [addr_mid] [addr_hi]  → then read N reply bytes
cmd = 0x80 (full) | 0x40 (auto-increment) | (nbytes-1)<<1 | 1 for read / 0 for write
```

A read is one 6-byte header out and exactly N bytes back. Writes get no acknowledgement,
which is a property of the protocol, not of this script.

## Why it is useful

- It separates "cable, port, baud rate, FPGA alive" from "our software works".
- It is the smallest possible demonstration of the protocol, so it doubles as documentation.
- It gives an independent check for the NOMAD serial layer later: the same registers read
  through NOMAD must give the same values.

## Verified

The packets it generates were compared against the recorded traces in `docs/nomad.html` §3.3,
which came from running the real `uart32` code:

| Call | Expected | Generated |
|---|---|---|
| read `0x2003`, 1 byte | `01 C1 00 03 20 00` | same |
| read `0x2000`, 3 bytes | `01 C5 00 00 20 00` | same |
| read `0x0808`, 4 bytes | `01 C7 00 08 08 00` | same |
| write `0x2003`, 1 byte | `01 C0 00 03 20 00` + data | same |

Two bugs in the first draft were caught this way: shell command substitution silently drops
NUL bytes (losing the `len_hi` byte), and the escaping produced literal text instead of
bytes. Both fixed by building the byte string with `printf '\\x%02X'` and emitting it with
`printf '%b'`.

**Not yet run against the board**: the USB device disappeared from WSL between the earlier
successful read and writing this tool, so `/dev/ttyACM0` no longer exists. To re-attach, in
Windows PowerShell (as administrator):

```powershell
usbipd list
usbipd attach --wsl --busid <BUSID>
```

Then `ls /dev/ttyACM0` in WSL, and run `operation_scripts/uart_probe.sh status`.

## Reference values seen earlier on this board

From `hbr --rd_reg` while the link was up, for comparison when the probe first runs:

| Register | Value | Meaning |
|---|---|---|
| `0x2003` | `0x04` | PWM frequency code 4 = 16 kHz |
| `0x0808` | `0x20260916` | CPU firmware build date, 2026-09-16 |
