# ucn-chopper

*Chopper code and control interfacing.*

Host software for the **UCN chopper**: a Lattice MachXO3D FPGA on an N219 4×H-Bridge board
that drives two H-bridge motor channels (shutter open / close), with two ADS131M04 ADCs,
a dual I²C DAC for the current limit, and Pt100 / DS18B20 temperature sensors.
The host talks to the board over USB-UART with the UART32 register protocol.

The goal of this repository is to take that working bench code and turn it into a
**NOMAD driver and controller** for use at the ILL.

The code was branched off from the subversion of the PI on 22.09.2026, so if changes appear there, they will have to merge appropriately.

## Layout

| Path | Contents |
|---|---|
| `host/` | The chopper code and its `Makefile`: `C_hbr`, `C_ads131m04`, `C_dual_dac`, `C_dtemp`, `C_simpl_stat`, and the `hbr` command-line tool |
| `operation_scripts/` | Day-to-day operation: bring-up, open, close, temperatures, test cycles, and `uart_probe.sh` (raw UART32 connection test, no C++ involved) |
| `waveforms/` | PWL waveform files the scripts load (`open.dat`, `close.dat`, test shapes); `legacy/` and `experiments/` hold older and one-off ones |
| `waveforms/tools/` | Python helpers: waveform generators, plotting, the bench multimeter logger |
| `upstream/` | Shared code from the Heidelberg SVN repository that the chopper code is built from: `uart`, `uart32`, `CLogger`, `one_xo3d_fpga8_32`, and the `xo3d_fpga8_32` flash tool |
| `docs/` | `CODE_MAP.md` (full map of the code and the FPGA register map) and two browsable pages: `index.html` (code map) and `nomad.html` (the NOMAD port plan) |
| `docs/reference/` | Bench outputs kept as reference (plots, `fstatus`/init logs) and the earlier NOMAD design draft |
| `worklog/` | One short document per step of the work, saying what changed and why |

## Build

```bash
cd host
make hbr              # the main tool
make xo3d_fpga8_32    # FPGA flash / status tool (optional)
```

Requires `g++` only. The board is reached at `/dev/ttyACM0` (USB-CDC) or `/dev/ttyUSB0`
(optical link) at 4 Mbit/s.

## Everyday use

```bash
cd operation_scripts
./initialize_fpga.sh          # after every power-cycle or FPGA refresh
./open_shutter.sh             # load the opening waveform and trigger it
./close_shutter.sh
./read_temps.sh               # Pt100 + DS18B20, read-only
../host/stop                  # release the hold current

DEV=/dev/ttyUSB0 ./initialize_fpga.sh    # same, over the optical link

./uart_probe.sh status                   # raw connection test: UART32 with stty and shell
                                         # only, no hbr and no C++ involved
```

The scripts locate `hbr` and the waveform files from the repository root, which they work
out from their own path, so the repository can be cloned anywhere. `hbr` must be built
first (`cd host && make hbr`).

## Documentation

Open `docs/index.html` and `docs/nomad.html` in a browser, or serve them locally:

```bash
python3 -m http.server 8765 --bind 127.0.0.1 --directory docs
# then browse http://localhost:8765/
```

- **`docs/index.html`** — how the code fits together, the UART32 protocol, the FPGA
  register map, every function and the bus traffic it causes, and known issues.
- **`docs/nomad.html`** — the plan for the NOMAD port: conventions from `nomad-modules`,
  a worked example (`sp15000`), the communications layer, the driver design, which
  settings live where, and a step-by-step roadmap.

## Origin of the code

`host/` and `upstream/` come from the Heidelberg SVN repository
`http://hwstar.physi.uni-heidelberg.de/svn/Lattice_XO2_UART` (revision 1214), where the
FPGA design and the shared C++ classes are maintained. The device classes and the
upstream files are unmodified apart from include paths; the scripts, waveform files and
Python tools are new here. See `worklog/00-repository-setup.md` for exactly what was
copied and changed.

### Scope

This repository holds the **host software only**: what you need on a computer to operate a
chopper whose FPGA is already programmed. The FPGA design (VHDL, Lattice project, CPU
firmware) and the bitstreams stay in the Heidelberg SVN repository, where they are
maintained.

`docs/CODE_MAP.md` documents the FPGA register map as the host code sees it, and quotes the
VHDL where it explains behaviour. Those quotes came from an SVN copy that is **older than
the design flashed on the board**, so the C headers in `host/` are authoritative for
addresses.

Flashing and FPGA status still work from here: `upstream/xo3d_fpga8_32.cpp` builds the
`xo3d_fpga8_32` tool (`make fstatus`, `make refresh`). The `make prog_w` / `prog_g` targets
additionally need bitstream files, which are not kept here.
