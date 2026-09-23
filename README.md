# ucn-chopper

*Chopper code and control interfacing.*

Host software for the **UCN chopper**: a Lattice MachXO3D FPGA on an N219 4×H-Bridge board
that drives two H-bridge motor channels (shutter open / close), with two ADS131M04 ADCs,
a dual I²C DAC for the current limit, and Pt100 / DS18B20 temperature sensors.
The host talks to the board over USB-UART with the UART32 register protocol.

The goal of this repository is to take that working bench code and turn it into a
**NOMAD driver and controller** for use at the ILL.

## Layout

| Path | Contents |
|---|---|
| `host/` | The chopper code: `C_hbr`, `C_ads131m04`, `C_dual_dac`, `C_dtemp`, `C_simpl_stat`, the `hbr` command-line tool, `Makefile`, and the bench shell scripts |
| `host/tools/` | Python helpers: waveform generators, plotting, the bench multimeter logger |
| `host/waveforms/` | PWL waveform files used by the scripts (`open.dat`, `close.dat`, test shapes); `legacy/` holds older ones |
| `host/pgm/` | FPGA bitstreams used by `make prog_w` / `prog_g` (v0 prototype images) |
| `upstream/` | Shared code from the Heidelberg SVN repository that the chopper code is built from: `uart`, `uart32`, `CLogger`, `one_xo3d_fpga8_32`, and the `xo3d_fpga8_32` flash tool |
| `fpga/` | The FPGA design, for reference: `N219_4x_H-Bridge/` (VHDL, Lattice project, simulation, LM32 CPU firmware) and `shared-SRC/` (the shared cores the design pulls in) |
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
cd host
./initialize_fpga.sh          # after every power-cycle or FPGA refresh
./open_shutter.sh             # load the opening waveform and trigger it
./close_shutter.sh
./read_temps.sh               # Pt100 + DS18B20, read-only
./stop                        # release the hold current
```

The scripts find `hbr` and the waveform files relative to their own location, so the
repository can be cloned anywhere.

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

`host/`, `upstream/` and `fpga/` come from the Heidelberg SVN repository
`http://hwstar.physi.uni-heidelberg.de/svn/Lattice_XO2_UART` (revision 1214), where the
FPGA design and the shared C++ classes are maintained. The device classes and the
upstream files are unmodified apart from include paths; the scripts, waveform files and
Python tools are new here. See `worklog/00-repository-setup.md` for exactly what was
copied and changed.

> **The `fpga/` copy is a snapshot, and it is older than the design flashed on the board.**
> It still has the H-bridge block at `0x1000` and 1024-entry sequence RAMs, while the board
> uses `0x2000` and 2048 entries. Take addresses and register layouts from the C headers in
> `host/`, not from the VHDL. For FPGA work, take a fresh SVN checkout.
