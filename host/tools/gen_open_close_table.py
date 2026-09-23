#!/usr/bin/env python3
"""
Generate a "hold at a small constant power, then taper down to an even
smaller hold" PWL waveform for one edge (open or close) of a shutter/coil
H-bridge channel, in the plain time_ms/power_pct text format hbr's
--read_table consumes (see simpl_wave.dat for reference).

Shape: flat at --move for --move-ms, then ease down (smoothstep, so no
sharp corner) to --hold over --taper-ms, then flat at --hold.

This file only needs to cover the move + taper -- it does NOT need to be
long enough to cover however long you actually want the final hold to
last. For that, --set_preserve_last must be enabled on the board (ch_mask,
1) so the driver keeps outputting the table's last value indefinitely once
the table finishes, instead of stopping after ~256 PWM periods (the max a
single table entry can span).

Sign convention (matches this project's H-bridge wiring, per hbr_seq_start /
ADDR_START_ON_OFF "go to ON/OFF at shutter"):
    close -> negative power
    open  -> positive power

Usage:
    ./gen_open_close_table.py --direction close --move 20 --hold 1 \\
        --move-ms 50 --taper-ms 10 -o close.dat
    ./gen_open_close_table.py --direction open  --move 20 --hold 1 \\
        --move-ms 50 --taper-ms 10 -o open.dat

Then, on the board:
    ./hbr --read_table close.dat 0 1 1 --load_table <ch> 0   # falling edge
    ./hbr --read_table open.dat  0 1 1 --load_table <ch> 1   # rising edge
    ./hbr --set_preserve_last 3 1                            # keep holding forever
"""
import argparse


def smoothstep(x):
    x = max(0.0, min(1.0, x))
    return 3 * x * x - 2 * x * x * x


def build_profile(move, hold, move_ms, taper_ms, n=40):
    """move/hold are signed (%). Returns [(time_ms, power_pct), ...],
    strictly increasing in time."""
    pts = [(0.0, move), (move_ms, move)]
    for i in range(1, n + 1):
        frac = i / n
        pts.append((move_ms + frac * taper_ms, move + (hold - move) * smoothstep(frac)))
    pts.append((move_ms + taper_ms + 1.0, hold))
    return pts


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--direction', choices=['open', 'close'], required=True)
    ap.add_argument('--move', type=float, default=20.0, help='constant power while moving, %% magnitude 0..100 (default 20)')
    ap.add_argument('--hold', type=float, default=1.0, help='final holding power, %% magnitude 0..100 (default 1)')
    ap.add_argument('--move-ms', type=float, default=50.0, help='duration held at --move (default 50, must be > 0)')
    ap.add_argument('--taper-ms', type=float, default=10.0, help='time to ease from --move down to --hold (default 10)')
    ap.add_argument('-o', '--output', required=True)
    args = ap.parse_args()

    sign = -1.0 if args.direction == 'close' else 1.0
    move = sign * args.move
    hold = sign * args.hold
    pts = build_profile(move, hold, args.move_ms, args.taper_ms)

    with open(args.output, 'w') as f:
        f.write("# PWL\n")
        f.write(f"# direction={args.direction}  move={move:.1f}%  hold={hold:.1f}%  "
                f"move_ms={args.move_ms}ms  taper={args.taper_ms}ms\n")
        f.write("# time in ms           power in % (-100...+100)\n")
        for t, p in pts:
            f.write(f"{t:<22.4f} {p:.2f}\n")

    print(f"Wrote {len(pts)} points to {args.output}  "
          f"({move:.1f}% for {args.move_ms} ms, then taper to {hold:.1f}% over {args.taper_ms} ms)")
    print("Reminder: enable ./hbr --set_preserve_last 3 1 so the hold value "
          "persists after the table finishes.")


if __name__ == '__main__':
    main()
