#!/usr/bin/env python3
"""Plot an ADC buffer file produced by `hbr --get_adc_buff` (defaults to the
most recently written one).

File format (see C_hbr::read_adc_buffer() in C_hbr.cpp): one line per sample,
    <sample#> <ch0> <ch1> ... <ch7>
where each <chN> is either the literal "-" (channel not captured this run) or
one/two numeric fields depending on channel type:
    ch % 4 == 0  ->  H-Voltage                    (1 field,  V)
    ch % 4 == 1  ->  H-Current, bidirectional      (1 field,  A)
    ch % 4 == 2  ->  H-bridge-Current, unidirectional (1 field, A)
    ch % 4 == 3  ->  PT100                         (2 fields, resistance Ohm + temperature C)
Values are already scaled to V/A, with ~2-3% error (more on the last
channel); the bidirectional H-Current channel is probably sign-inverted,
see --invert-ch1.

The sample# in column 1 is the raw sample count; divide by the sampling
rate in kS/s (--srate) to get time in ms.

The buffer file itself doesn't record which channels were active, so the ADC
mask used for that capture must be supplied with --mask. Default is 0x70,
the mask segmented_test.sh/close_shutter.sh arm for H-bridge 2 via
`--start 2 ...` (voltage/current/current on channels 4-6).
"""
import argparse
import glob
import os
import sys

CHANNEL_KINDS = {
    0: ("voltage", ["H-Voltage (V)"]),
    1: ("i_shunt", ["H-Current, bidir (A)"]),
    2: ("i_prop", ["H-bridge-I, unidir (A)"]),
    3: ("pt100", ["PT100 R (Ohm)", "PT100 T (C)"]),
}


def find_latest_file(directory, pattern):
    matches = glob.glob(os.path.join(directory, pattern))
    if not matches:
        raise FileNotFoundError(f"no files matching '{pattern}' in {directory}")
    return max(matches, key=os.path.getmtime)


def channel_layout(mask):
    """Active channels in capture order: list of (channel_index, labels)."""
    layout = []
    for ch in range(8):
        if mask & (1 << ch):
            _, labels = CHANNEL_KINDS[ch % 4]
            layout.append((ch, labels))
    return layout


def parse_buffer_file(path, mask):
    layout = channel_layout(mask)
    columns = {(ch, label): [] for ch, labels in layout for label in labels}
    samples = []

    with open(path) as f:
        for lineno, line in enumerate(f, 1):
            tok = line.split()
            if not tok:
                continue
            samples.append(int(tok[0]))
            pos = 1
            for ch, labels in layout:
                if pos >= len(tok):
                    raise ValueError(
                        f"{path}:{lineno}: line has fewer fields than --mask "
                        f"0x{mask:02x} expects; wrong mask for this file?"
                    )
                if tok[pos] == "-":
                    for label in labels:
                        columns[(ch, label)].append(float("nan"))
                    pos += 1
                else:
                    for label in labels:
                        columns[(ch, label)].append(float(tok[pos]))
                        pos += 1
    return samples, columns


def main():
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    ap.add_argument(
        "file", nargs="?",
        help="ADC buffer file to plot (default: most recently written match "
             "of --pattern in --dir)",
    )
    ap.add_argument(
        "--dir", default="/home/thepworth/chopper",
        help="directory to search when no file is given (default: %(default)s)",
    )
    ap.add_argument(
        "--pattern", default="*_adc_run*.txt",
        help="glob pattern used to find the latest file (default: %(default)s)",
    )
    ap.add_argument(
        "--mask", default="0x70",
        help="ADC channel mask (hex or dec) active for this capture, default: "
             "%(default)s (H-bridge 2: voltage/I-shunt/I-prop on ch 4-6)",
    )
    ap.add_argument(
        "--current-only", action="store_true",
        help="plot only the current channels (H-Current/H-bridge-I)",
    )
    ap.add_argument(
        "--srate", type=float, default=None,
        help="sampling rate in kS/s; if given, x-axis is time in ms "
             "(sample# / srate) instead of the raw sample number",
    )
    ap.add_argument(
        "--invert-ch1", action="store_true",
        help="flip the sign of the bidirectional H-Current channel "
             "(ch %% 4 == 1); it's reportedly inverted in hardware",
    )
    ap.add_argument("-o", "--out", help="output image path (default: <input file>.png)")
    ap.add_argument(
        "--no-show", dest="show", action="store_false",
        help="don't open an interactive window, just save the PNG",
    )
    args = ap.parse_args()

    try:
        path = args.file or find_latest_file(args.dir, args.pattern)
    except FileNotFoundError as e:
        sys.exit(f"error: {e}")

    mask = int(args.mask, 0)

    try:
        samples, columns = parse_buffer_file(path, mask)
    except ValueError as e:
        sys.exit(f"error: {e}")

    if not columns:
        sys.exit(f"error: mask 0x{mask:02x} selects no channels")

    if args.current_only:
        columns = {k: v for k, v in columns.items() if k[1].endswith("(A)")}
        if not columns:
            sys.exit("error: --current-only given but --mask has no current channels")

    if args.invert_ch1:
        for (ch, label), values in columns.items():
            if ch % 4 == 1:
                columns[(ch, label)] = [-v for v in values]

    x = samples
    xlabel = "Sample"
    if args.srate:
        x = [s / args.srate for s in samples]
        xlabel = "Time (ms)"

    if args.show and not os.environ.get("DISPLAY"):
        print("warning: no DISPLAY found, saving only", file=sys.stderr)
        args.show = False

    if not args.show:
        import matplotlib
        matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    fig, ax = plt.subplots(figsize=(10, 6))
    for (ch, label), values in columns.items():
        ax.plot(x, values, label=f"ch{ch} {label}")
    ax.set_xlabel(xlabel)
    ax.set_ylabel("Value")
    ax.set_title(os.path.basename(path))
    ax.grid(True)
    ax.legend()

    out = args.out or (path + ".png")
    fig.savefig(out, dpi=150)
    print(f"plotted {path} -> {out}")

    if args.show:
        plt.show()


if __name__ == "__main__":
    main()
