# 03 · Follow-up after the folder reorganisation

**Date:** 2026-09-23
**Context:** the repository was reorganised (commits *reorganizing waveforms and scripting*
and *move waveform tools*): the shell scripts moved from `host/` to `operation_scripts/`,
the waveform files from `host/waveforms/` to a top-level `waveforms/`, and the Python
helpers to `waveforms/tools/`.

## Problem

The scripts locate things relative to themselves:

```bash
HBR="$SCRIPT_DIR/hbr"
"$HBR" --nll --read_table "$SCRIPT_DIR/waveforms/open.dat" …
```

After the move, `$SCRIPT_DIR` is `operation_scripts/`, so they looked for
`operation_scripts/hbr` and `operation_scripts/waveforms/open.dat`. Neither exists: `hbr`
is built in `host/`, and the waveforms are now at the repository root. **All 11 scripts were
broken.**

## Change

Each script now derives the repository root and addresses the other folders from there:

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HBR="$REPO_ROOT/host/hbr"
"$HBR" --nll --read_table "$REPO_ROOT/waveforms/open.dat" …
```

Sibling scripts (`close_shutter.sh` calling `overheat_check.sh`, and the cycle scripts
calling open/close) still use `$SCRIPT_DIR`, which is correct: they live in the same folder.

## Verified

- No `SCRIPT_DIR/hbr`, `SCRIPT_DIR/waveforms` or `PROJ_DIR/hbr` references remain.
- `bash -n` on all 11 scripts: they parse.
- The paths they build exist: `host/hbr` and `waveforms/{open,close}.dat`.
- Behaviour check without hardware:

  ```
  $ DEV=/dev/definitely-not-here ./initialize_fpga.sh
  error: /dev/definitely-not-here not found (board not connected / not attached in WSL?)
  ```

  It reaches its own device check instead of failing earlier on a missing file, which is
  what the fix was for.

README updated to the new layout, including that the scripts are run from
`operation_scripts/` and that `hbr` must be built first.

## Also moved

`uart_probe.sh` (worklog 02) was added under `host/tools/` before the reorganisation. It is
an operator-facing diagnostic rather than a build or waveform tool, so it now sits in
`operation_scripts/` next to `read_temps.sh`. It has no path dependencies of its own — only
the `DEV`, `BAUD` and `ID` environment variables — so the move needed no code change.
`host/tools/` is now empty and gone; the Python helpers live in `waveforms/tools/`.

Earlier worklog entries describe the layout as it was at the time they were written; paths
in them are not updated retrospectively. This entry is the record of the move.

## Note

This is the cost of locating files by path: moving a folder breaks it silently. The scripts
now depend only on their position *relative to the repository root*, so moving the whole
repository is still fine, but moving `operation_scripts/` deeper would need the `..` changed.
