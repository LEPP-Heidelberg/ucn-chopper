# HeidelbergChopper

**Porting the N219 4× H-Bridge FPGA control code into a NOMAD driver**

| | |
|---|---|
| **Status** | Draft for review |
| **Board** | Lattice XO3D / N219 4×H-Bridge |
| **Transport** | USB–UART, custom UART32 register protocol |
| **Reference driver** | `sios::Sp15000Driver` |

---

## Contents

1. [Purpose & scope](#1-purpose--scope)
2. [NOMAD driver architecture](#2-nomad-driver-architecture)
3. [What the hardware actually does](#3-what-the-hardware-actually-does)
4. [Naming & file layout](#4-naming--file-layout)
5. [Composite driver scope](#5-composite-driver-scope)
6. [Properties](#6-properties)
7. [Commands](#7-commands)
8. [Real vs. Perfect backend](#8-real-vs-perfect-backend)
9. [Open questions](#9-open-questions)
10. [Suggested build order](#10-suggested-build-order)

---

## 1. Purpose & scope

You have working, tested C++ code that drives an N219 4× H-Bridge FPGA board over a custom UART
protocol — H-bridge sequencing (`C_hbr`), a two-chip 24-bit ADC (`C_ads131m04`), 1-wire temperature
sensors (`C_dtemp`), and a dual I²C DAC (`C_dual_dac`). This document proposes how that code becomes
a single NOMAD driver, `heidelbergchopper::HeidelbergChopperDriver`, one instance per FPGA board,
exposing two output channels that can each be driven **open**, **closed**, or **chopped** from an
operator-supplied waveform file.

Section 2 is deliberately the longest: before proposing a shape for this specific driver, it lays out
how *any* NOMAD driver is put together, using the existing `sp15000` (SIOS laser interferometer)
driver as a worked, line-by-line example. Every later section refers back to the vocabulary defined
there.

---

## 2. NOMAD driver architecture

*What a NOMAD driver actually is, in terms the framework enforces on every instrument at ILL — not
just this one.*

### 2.1 The module: how NOMAD finds a driver

Every driver lives in its own directory under `src/drivers/<vendor>/<device>/`, declared by one
`Module.xml`:

```xml
<module name="sp15000">
    <driver class="sios::Sp15000Driver"/>
    <link lib="siosifm"/>
</module>
```

The `name` is the identifier an instrument configuration references to instantiate the driver;
`class` names the C++ type NOMAD constructs; an optional `<link lib>` pulls in an external vendor
library (SIOS's closed `siosifmdll`, in this example). Nothing else about build wiring is declared
per module — the driver's own `.cpp` files in that directory are picked up automatically by the
project-wide build.

### 2.2 Properties and commands: the vocabulary every driver speaks

A driver's public surface is built from exactly two primitives, both supplied by the framework's
`DeviceDriver` base class:

- **`Property<T>`** — a single named value (`int32`, `float64`, `std::string`…), registered once in
  the constructor: `nbChannels.init(this, SAVE, "nb_channels")`. The `SAVE`/`NOSAVE` flag decides
  whether NOMAD persists that value in the instrument's configuration between sessions.
- **`DynamicProperty<T>` / `DynamicArrayProperty<T>`** — the same idea, but sized per-channel at
  runtime. `sp15000` ties this resizing to its channel-count property with
  `registerRefresher(nbChannels, &Sp15000Driver::refreshNbChannelsProperty, this)`, so setting
  `nbChannels` reshapes eight other properties in one place.

Commands are declared the same way properties are, but drive behaviour instead of state. NOMAD ships
a standard lifecycle vocabulary every driver inherits (from `DriversCommands.h`):

| Command constant | Typical meaning |
|---|---|
| `INIT_COMMAND` | Open the connection, read identity/config from the device |
| `START_COMMAND` | Begin an operation (acquisition, motion, …) |
| `STOP_COMMAND` | Abort/halt whatever is running |
| `READ_COMMAND` | Pull the latest data; also re-invoked automatically while a command is in flight (2.5) |
| `STATUS_COMMAND` | Refresh health/fault properties |
| `PAUSE_COMMAND` / `RESUME_COMMAND` | Suspend / continue |

A driver adds its own on top — `sp15000` declares `MEASURE_LENGTH_COMMAND` and
`SIGNAL_QUALITY_COMMAND` as `static const std::string`s and registers them with `initCommand(...)`.
**Every** command, standard or custom, arrives through one dispatch point:

```cpp
void Sp15000Driver::execute(const std::string &aCommand) {
    Sp15000State* currentState = dynamic_cast<Sp15000State*>(getCurrentState());
    if (aCommand == driver::START_COMMAND) {
        m_state = State::BLOCK_READ;
        currentState->start();
    } else if (aCommand == MEASURE_LENGTH_COMMAND) {
        m_state = State::LENGTH_READ;
        currentState->start();
    } ...
}
```

Commands never take structured arguments of their own — a caller sets whatever `Property` values a
command needs (channel, duration, filename, …) *before* calling `execute()`. This is the pattern the
property tables in section 6 are built around.

### 2.3 Transport mixins are metadata, not I/O

A driver's second base class advertises what kind of physical connection it uses —
`driver::RS232`, `RS485`, `TCP`, `USB`, `Vme`, `Gpib` all live under `src/drivers/global/`. It's
tempting to assume this class owns byte-level read/write, but `RS232.cpp` in full is six property
registrations and nothing else:

```cpp
void RS232::init(const std::string& name) {
    DeviceDriver::init(name);
    registerParentFunction(FUNCTION);   // "rs232"
    speed.init(this, SAVE, "speed");
    nbBits.init(this, SAVE, "nbbits");
    parity.init(this, SAVE, "parity");
    bitStop.init(this, SAVE, "bitstop");
    flowControl.init(this, SAVE, "flowcontrol");
    portDeviceName.init(this, SAVE, "port_device_name");
}
```

These properties feed NOMAD's channel manager (for GUI display and, for simple ASCII instruments,
generic serial I/O elsewhere in the framework) — but a driver with its own binary protocol is free to
bypass all of it. `RealSp15000Driver::init()` does exactly that: it builds
`/dev/ttyUSB<channel-1>` from `owner()->getChannel()` and hands the path straight to the vendor SDK's
own `IfmOpenCOM()`. **This is precisely the situation HeidelbergChopper is in**: the "vendor SDK" is
the `uart32`/`C_hbr` code you already wrote, so `RealHeidelbergChopperDriver` will open the port and
hand it to `uart32` the same way, rather than routing through any generic serial helper.

> **Scope note — UART is the communications layer, and it is assumed to exist.**
> Every subsystem you've written — `C_hbr`, `C_ads131m04`, `C_dtemp`, `C_dual_dac` — is already built
> against one shared `uart32*`, not against a raw file descriptor. That object is the entire
> communications layer this driver needs: register-level primitives (`ReadByte`/`WriteByte`/
> `ReadWord`/`WriteWord`/… and `SendBurst`/`RecvBurst` for blocks), with port-opening, framing, and
> slave addressing already solved inside `uart.cpp`/`uart32.cpp`. This document treats that layer as
> **already available** and does not redesign it. The only communications-related design surface for
> `RealHeidelbergChopperDriver` is: construct one `uart32` instance bound to the port named by
> NOMAD's `portDeviceName`/`speed` properties, exactly as `hbr.cpp`'s `main()` does today, and hand
> that single pointer to all four subsystem objects — composition, not protocol work.

### 2.4 The State pattern: swapping hardware for a stand-in

Every command handler above (`start()`, `read()`, …) is declared *twice*: once as a pure-virtual
interface, once or more as a concrete implementation. The interface:

```cpp
class Sp15000State: public DriverState<Sp15000Driver> {
public:
    virtual void init() = 0;
    virtual void start() = 0;
    virtual void stop() = 0;
    virtual void read() = 0;
    virtual void readStatus() = 0;
};
```

…is implemented once by `RealSp15000Driver` (talks to the actual SIOS hardware via `Ifm*()` calls)
and once by `PerfectSp15000Driver` (fabricates a clean sine wave and random noise — no hardware
involved at all). Both are registered together in the public driver's constructor:

```cpp
registerStates(new RealSp15000Driver(this),
               new PerfectSp15000Driver(this),
               new PerfectSp15000Driver(this));
```

NOMAD's own run-mode setting (outside this repository) selects which registered state is active;
functionally, the first slot is always the hardware-facing implementation, and the rest stand in for
it. The payoff: **the same instrument configuration, GUI, and sequence script runs unmodified against
real hardware or synthetic data** — a scientist can build and rehearse an experiment sequence on a
laptop with no FPGA attached, then point it at the real board with a run-mode flag, not a code change.
`PerfectHeidelbergChopperDriver` plays the same role for this driver (section 8).

**Command flow through the layers:**

```
        NOMAD server · sequencer · GUI
      (sets Properties, calls execute(command))
                     │
                     ▼
             HeidelbergChopperDriver
   Property<T> / DynamicProperty<T> · execute() dispatch · m_state
                     │
                     ▼   dynamic_cast<HeidelbergChopperState*>(getCurrentState())
              HeidelbergChopperState
     abstract: init / open / close / chop / readStatus …
                     │
         ┌───────────┴───────────┐
         ▼                       ▼
RealHeidelbergChopperDriver   PerfectHeidelbergChopperDriver
 constructs & shares one       fabricated status / ADC /
 uart32* across C_hbr,         temperature values
 C_ads131m04, C_dtemp,
 C_dual_dac
         │                       │
         ▼                       ▼
  N219 FPGA board          no hardware
  over USB–UART ·          used for GUI &
  uart32 register          sequence development
  protocol, assumed
  available
```

### 2.5 Progress and polling: commands that take time

Not every command finishes inside `execute()`. `sp15000`'s block acquisition keeps an internal state
(`enum class State {NONE, BLOCK_READ, LENGTH_READ, QUALITY_READ}`) and relies on NOMAD re-invoking
`READ_COMMAND`/`STATUS_COMMAND` on its own while a command is outstanding — wired up once in the
constructor:

```cpp
registerSpyCommand(driver::READ_COMMAND, 2);
registerSpyCommand(driver::STATUS_COMMAND, 2);
registerObserverCommand(driver::READ_COMMAND, 200);
registerObserverCommand(driver::STATUS_COMMAND, 200);
```

Each call to the backend's `read()` checks a completion condition (`IfmValueCount(handle) >=
nbSamples()`, in the real backend) and only flips `commandProgression` to
`PROGRESSION_END_DEVICE_CONTAINER` once satisfied; until then the GUI's progress indicator reflects a
command still running. This is the mechanism to reach for if a HeidelbergChopper table upload turns
out to take long enough that it shouldn't block `execute()` (see the open question in 9.4).

### 2.6 Where a new driver plugs in

Nothing above is specific to laser interferometers or H-bridges — it is the whole contract. A new
driver is "just" another leaf directory speaking Properties, Commands, and the State pattern; the GUI
layer (an XML panel definition in a `gui/` subfolder, out of scope for this document) binds to that
same surface. Once `HeidelbergChopperDriver` exists, it is indistinguishable — to the sequencer, to
the GUI, to any script — from any other instrument already deployed at ILL.

---

## 3. What the hardware actually does

*Grounded in your own working shell scripts, not assumptions — this is what
`RealHeidelbergChopperDriver` has to reproduce faithfully.*

- The FPGA has exactly **two waveform-table RAM slots per channel** (`ADDR_SEQ_AD_RANGE_ON_x` /
  `_OFF_x`). This is a firmware/register-map limit; the driver works within it, it cannot design
  around it.
- **"ON"/"OFF" are not "open"/"close."** They are arbitrary hardware directions. `open_shutter.sh`
  loads `open.dat` into the *OFF*-labelled slot and triggers "go-to-OFF"; `close_shutter.sh` loads
  `close.dat` into the *ON*-labelled slot and triggers "go-to-ON." Physical meaning is entirely a
  function of which file was last loaded where.
- **Every real operation is load-then-trigger, every time.** No script assumes a slot already holds
  the right waveform. `close_then_test.sh` proves this is load-bearing: it reuses the *same* slot as
  `close.dat` for `good_but_bounces.dat` (a "chop"/test waveform), overwriting it, then reloads
  `close.dat` the next time a real close is needed.
- `set_preserve_last` is a safety latch toggled around motions; `overheat_check.sh` currently reads
  temperature from an *external* logger's CSV file, not from this board's own PT100 / 1-wire sensors.

> **Design consequence.** `open` / `close` / `chop` are modelled as three named waveforms per channel.
> Running any of them is one atomic driver-level operation — load, then trigger — so the "which
> waveform is currently sitting in which slot" bookkeeping that your shell scripts manage by hand
> today lives inside the driver instead, where it cannot go stale.

---

## 4. Naming & file layout

Checked against `fermichopper`, `rmcchopper`, `ttl`, and `startstop` — ILL's own in-house boards, as
opposed to vendor products like `sp15000`: directory and C++ namespace are the class name,
lower-cased, no separators; class names are PascalCase.

```
src/drivers/ill/heidelbergchopper/
    Module.xml
    HeidelbergChopperDriver.h / .cpp        namespace heidelbergchopper
    HeidelbergChopperState.h
    RealHeidelbergChopperDriver.h / .cpp
    PerfectHeidelbergChopperDriver.h / .cpp
    HeidelbergChopperDef.h
    uart.h / .cpp                            ported in verbatim from the
    uart32.h / .cpp                          FPGA project — these become
    C_hbr.h / .cpp                           source files of this module,
    C_ads131m04.h / .cpp                     the way RealSp15000Driver.cpp
    C_dtemp.h / .cpp                         is a source file of sp15000,
    C_dual_dac.h / .cpp                      not an external link lib
    dac_mcp47feb.h
    gui/                                      (later)
```

`TYPE = "heidelbergchopper"`; `Module.xml`:

```xml
<module name="heidelbergchopper">
    <driver class="heidelbergchopper::HeidelbergChopperDriver"/>
</module>
```

No `<link lib>` — unlike `sp15000` (closed vendor DLL) or `fermichopper` (`vs_can_api`), the whole
transport and protocol stack here is code you already own, so it compiles straight into the module.

---

## 5. Composite driver scope

One `HeidelbergChopperDriver` instance = one FPGA board = one serial connection, exposing all four
subsystems that share its single `uart32*`:

- 2 H-bridge output channels — the open/close/chop actuators
- the 2-chip ADS131M04 ADC subsystem
- the 1-wire temperature sensors (`C_dtemp`)
- the dual DAC (V<sub>REF</sub> / current-limit per channel)

This mirrors how `Sp15000Driver` bundles length, quality, and status measurement under one device
rather than splitting them into separate NOMAD devices that would each need their own connection.

---

## 6. Properties

*Following the pattern in 2.2 — command parameters are properties set beforehand, not arguments to
`execute()`.*

**Connection & identity · SAVE**

| Property | Type | Notes |
|---|---|---|
| `portDeviceName`, `speed`… | inherited (RS232) | `speed` = 4,000,000, per `UART_BaudRate` in your Makefile |
| `boardIdMask` | int32 | UART32 slave-select mask (`--id`); not covered by the generic RS232 mixin |
| `lowLatency` | int32 (bool) | mirrors `--nll`; on by default, per `DEF_SET_LOW_LATENCY` |

**H-bridge global configuration · SAVE, fixed at 2 channels**

| Property | Maps to |
|---|---|
| `pwmFreq` | `set_pwm_freq` |
| `decayCode`, `toffCode`, `ocpm`, `sleepN` | `set_hbr_conf_*` |
| `afbrEnable[2]`, `afbrInvert[2]`, `ocplEnable[2]`, `ocplInvert[2]` | `set_hbr_conf_ena_inv_*` |
| `slowDecay[2]`, `preserveLast[2]` | `set_hbr_sm_slow_decay`, `set_preserve_last` |
| `dacVref[2]` · float64, V | `C_dual_dac::set_dac_volt` |

**Per-channel named waveforms · SAVE — the "three files per channel" requirement**

| Property | Type |
|---|---|
| `openFile[2]`, `closeFile[2]`, `chopFile[2]` | string, file path |
| `timeStep[2]`, `timeScale[2]`, `powerScale[2]` | float64 — per-channel resample params, default 0/1/1, matching `read_table`'s CLI arguments |

**Readback · NOSAVE**

| Property | Source |
|---|---|
| `channelStatus[2]` | H-bridge fault/status bits (`ADDR_H_STAT`), translated the way `Sp15000Def` translates `IFM_STATUS_*` |
| `loadedWaveform[2]` · string | last file successfully loaded & triggered per channel — makes "what is this channel doing right now" a visible property instead of tribal knowledge |
| `pt100Temp[2]`, `dtempValues[]` | `read_temper`, `C_dtemp::get_temp` |
| ADC waveform arrays | `read_adc_buffer`, `DynamicArrayProperty` style, as `xData`/`yData` in `sp15000` |

---

## 7. Commands

Standard lifecycle: `INIT`, `START`, `STOP`, `READ`, `STATUS` (2.2). Device-specific, high-level — one
call does load-then-trigger, matching section 3 exactly:

| Command | Behaviour |
|---|---|
| `OPEN_COMMAND` | for `targetChannel`: `read_power_profile` + `resample` + `compress` on `openFile[ch]`, `hbr_upload_seq_table`, then `hbr_seq_start` using whichever ON/OFF direction that channel's "open" convention needs internally. Updates `loadedWaveform[ch]`. |
| `CLOSE_COMMAND` | same, using `closeFile[ch]` |
| `CHOP_COMMAND` | same, using `chopFile[ch]` — a one-shot drive profile, like `good_but_bounces.dat` |
| `SM_RESET_COMMAND` | `hbr_seq_reset` |
| `SET_VREF_COMMAND` | `C_dual_dac::set_dac_volt` from `dacVref[ch]` |
| `ADC_CONFIGURE_COMMAND` / `ADC_READ_COMMAND` | `C_ads131m04` configuration / read, parameters via properties |

A `targetChannel` property (0/1) selects which channel a command applies to, set before `execute()` —
the same convention as every table in section 6.

The ON/OFF slot mechanics stay entirely inside `RealHeidelbergChopperDriver`; NOMAD, the GUI, and any
sequence script only ever see `OPEN`/`CLOSE`/`CHOP` — both truer to how the hardware is actually
operated today and safer than exposing raw slot numbers.

---

## 8. Real vs. Perfect backend

Applying 2.4 directly:

- **`RealHeidelbergChopperDriver`** — `init()` replicates `hbr.cpp`'s `main()` setup (open
  `/dev/ttyUSB<channel>`, `set_slave_mask`, `set_max_wsize`/`asize`, baud 4,000,000, low-latency
  ioctl), then owns one `C_hbr`, `C_ads131m04`, `C_dtemp`, and `C_dual_dac` against that single
  `uart32`. As in 2.3, the `uart32` read/write primitives are taken as a given here — this backend's
  job is to construct that one instance and share it, not to touch how it talks to the port. Nearly
  every method body beyond that is a direct call into your existing, already-working `C_hbr` methods
  — this is wiring, not new logic.
- **`PerfectHeidelbergChopperDriver`** — fakes `channelStatus`, ADC samples, and temperatures;
  `OPEN`/`CLOSE`/`CHOP` just update `loadedWaveform[ch]` with no hardware access, so the NOMAD side
  (sequences, GUI) can be built and tested with no FPGA attached — exactly the role
  `PerfectSp15000Driver` plays today.

---

## 9. Open questions

*Flagged rather than decided — each one changes real behaviour.*

**9.1 — Overheat interlock.** `overheat_check.sh` reads an external instrument's CSV log today, not
this board's own PT100/1-wire sensors. Should the driver's own `pt100Temp`/`dtempValues` become the
interlock source — auto-clearing `preserveLast` or refusing `OPEN`/`CLOSE` above a threshold —
replacing the external log dependency?

**9.2 — Does "chop" ever auto-repeat?** This document assumes `chop` is a single triggered motion,
like `open`/`close`, with any repetition or timing owned by a higher-level NOMAD sequence. If the
driver itself should cycle open/close/chop on a timer, the command model in section 7 needs a
repeat/period property.

**9.3 — Per-channel vs. global resample parameters.** Worth confirming `timeStep`/`timeScale`/
`powerScale` actually vary per channel and file in practice, or whether one global set of three
properties is enough.

**9.4 — Synchronous or async `execute()`?** Load-then-trigger is a UART round trip. Whether it needs
the async `m_state` + polling pattern from 2.5, or can simply complete inside `execute()`, depends on
measured upload latency for your typical table sizes — not yet measured.

---

## 10. Suggested build order

1. Resolve 9.4 by timing a representative `hbr_upload_seq_table` call from the existing CLI.
2. Scaffold the module skeleton (section 4) with empty method bodies — confirms the build picks up the
   ported `uart32`/`C_hbr` sources correctly before any real logic is written.
3. Implement `RealHeidelbergChopperDriver::init()` and `STATUS`/`READ` (lowest risk: read-only,
   mirrors `hbr --status` exactly).
4. Implement `OPEN`/`CLOSE` against the two files you already trust (`open.dat`/`close.dat`),
   verifying against `open_shutter.sh`/`close_shutter.sh` behaviour on the bench.
5. Implement `CHOP`, then the ADC/DAC/temperature subsystems.
6. Write `PerfectHeidelbergChopperDriver` once the Real backend's property surface is stable — it
   should be a small fraction of the effort, as in `sp15000`.

---

*HeidelbergChopper · NOMAD driver design proposal · Draft · 2026-09-15*
