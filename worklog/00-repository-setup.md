# 00 · Repository setup

**Date:** 2026-09-23
**Goal:** put the working chopper code, and the upstream files it is built from, into
`github.com/LEPP-Heidelberg/ucn-chopper`, so that every later change is recorded.

## Where the code came from

| Source | Path on the bench PC |
|---|---|
| Chopper host code, scripts | `~/chopper/Lattice_XO2_UART/PROJECTS/N219_4x_H-Bridge/C/` |
| Shared upstream C++ | `~/chopper/Lattice_XO2_UART/C/` |
| Live waveform files | `~/chopper/*.dat` |
| Bench multimeter logger | `~/chopper/hmc8012_log_resistance.py` |

That tree is a **Subversion working copy** of
`http://hwstar.physi.uni-heidelberg.de/svn/Lattice_XO2_UART` at revision 1214, maintained in
Heidelberg. Before copying, `svn status` showed:

- **unmodified from SVN:** all the device classes (`C_hbr`, `C_ads131m04`, `C_dual_dac`,
  `C_dtemp`, `C_simpl_stat`, `dac_mcp47feb.h`) and everything in `Lattice_XO2_UART/C/`;
- **modified locally:** `Makefile` and `hbr.cpp`;
- **not in SVN at all:** every shell script, the Python tools, the `.dat` waveforms, and
  the documentation.

The SVN working copy is left untouched and stays the reference for upstream updates.
**Work now happens in this repository.**

## What was copied

```
host/                C_hbr, C_ads131m04, C_dual_dac, C_dtemp, C_simpl_stat,
                     dac_mcp47feb.h, hbr.cpp, Makefile, 12 shell scripts, stop
host/tools/          gen_open_close_table.py, gen_smooth_table.py, gen_table.py,
                     plot_adc_buffer.py, plot_hbr_table.py, pwr_plot.py/.plt,
                     hmc8012_log_resistance.py
host/waveforms/      open.dat, close.dat, good_but_bounces.dat, test_waveform.dat,
                     test_waveform_segmented.dat, test_waveform_square.dat
host/waveforms/legacy/  rect_wave.dat, simpl_wave.dat, open.dat (older variant),
                     rising_falling_edge_tables.txt
upstream/            uart.h/.cpp, uart32.h/.cpp, CLogger.h/.cpp,
                     one_xo3d_fpga8_32.h/.cpp, xo3d_fpga8_32.cpp
docs/                CODE_MAP.md, index.html, nomad.html
```

56 files, about 760 KB.

**Note on `open.dat` / `close.dat`:** the scripts used the copies in `~/chopper`, not the
ones inside the project folder. The `~/chopper` versions are therefore the live ones and
are now in `host/waveforms/`; the older project copy of `open.dat` (4 % move, 400 ms) is
kept in `host/waveforms/legacy/` for reference.

## What was deliberately left out

| Left out | Why |
|---|---|
| `*.o`, `hbr`, `xo3d_fpga8_32` | Build output; rebuilt with `make` |
| `pgm/*.bin` (FPGA bitstreams) | Not source. Also only the v0 prototype images are present locally, while the `Makefile` names v1 files that do not exist here |
| `SRC/`, `COMPILE/`, `SIM/`, `diamond/`, `plattform/` (VHDL and Lattice project) | FPGA design, maintained in SVN. The local copy is known to be **older than the design flashed on the board** |
| `C.zip`, `*.png`, `*.log`, `res_wave.dat` | Backups, plots and generated output |
| Other projects in the SVN tree | Not part of the chopper |

If the FPGA sources are wanted here later, they should come from a fresh SVN checkout, not
from this tree.

## What was changed, and why

Only what the move to a new layout required:

1. **Include paths** in 9 files (`C_hbr`, `C_ads131m04`, `C_dual_dac`, `C_dtemp` headers and
   sources, `hbr.cpp`): `#include "../../../C/uart32.h"` → `"../upstream/uart32.h"`, likewise
   for `CLogger.h`.
2. **`host/Makefile`**: `prefix=../../../C` → `prefix=../upstream`; the `TABLE_RISING` /
   `TABLE_FALLING` defaults now point at `waveforms/legacy/rect_wave.dat`.
3. **Shell scripts** (11 files): the hard-coded
   `/home/thepworth/chopper/Lattice_XO2_UART/PROJECTS/N219_4x_H-Bridge/C` paths, and the
   `/home/thepworth/chopper/*.dat` waveform paths, were replaced by paths relative to the
   script itself:

   ```bash
   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   HBR="$SCRIPT_DIR/hbr"
   "$HBR" --nll --read_table "$SCRIPT_DIR/waveforms/open.dat" 0 1 1 --load_table 1 1
   ```

   The repository can now be cloned anywhere. `overheat_check.sh` still defaults to
   `LOG_DIR=/home/thepworth/chopper` for the multimeter CSV logs, since those are data
   written outside the repository; it can be overridden with `LOG_DIR=…`.

**No functional change was made to any C++ code in this step.**

## How it was verified

| Check | Result |
|---|---|
| `make hbr` in the new layout | builds, produces `host/hbr` |
| `make xo3d_fpga8_32` | builds |
| `bash -n` on all 12 scripts + `stop` | all parse |
| `./hbr` usage output vs the old binary | identical apart from the program's own path |

Not yet verified against hardware: the board was not connected during this step. The first
bench run from the new location should be `./initialize_fpga.sh` followed by
`./read_temps.sh`.

## Repository conventions from here on

- One file per step in `worklog/`, numbered, saying **what changed, why, and how it was
  verified**.
- Commits reference the worklog entry they belong to.
- `docs/CODE_MAP.md`, `docs/index.html` and `docs/nomad.html` are kept up to date as the
  code changes; if a change contradicts them, the documents get updated in the same commit.

## Known issues carried over (not fixed here)

Listed in `docs/CODE_MAP.md` §10. The ones that matter for the NOMAD port:

- `uart::ReadBuffer` hides timeouts: with no board attached, `hbr --rd_reg` prints
  `ReadBuffer : r_now is 0, requested 1` and then reports `0x00` as if it were a real
  reading. Confirmed again during this step by pointing `hbr` at `/dev/null`.
- Out-of-bounds read in `C_ads131m04::hw_rd_all_regs`.
- Misplaced brace in `C_ads131m04::hw_wr_all_regs` (the response check runs once, after the
  loop, instead of per register).
- `prepare_all_regs` has different parameter orders in the header and the source.

## Next step

`01-…`: the byte-recording test harness moved into the repository, so that later changes to
the serial layer can be checked against known-good byte traces.
