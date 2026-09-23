#!/usr/bin/env python3
"""
Generate a smoothed (S-curve) pulse waveform in the same table format hbr uses,
and plot it. Pure local generation -- nothing here talks to the board.

Unlike `hbr --create_table` (straight-line ramps that meet the flat sections
at a sharp corner -- a discontinuous acceleration), this uses a smoothstep
blend (3x^2 - 2x^3) for the rise and fall, so the slope eases to zero right
where it meets the flat/hold regions. The waveform starts and ends at 0 --
no lingering "background" offset.

Usage:
    ./gen_smooth_table.py --peak 0.8 --rise-ms 1.5 --hold-ms 3.0 --fall-ms 1.5 \
        --pwm-freq 4800 --save smooth.png

    # emit the same "#tag cum idx state dur power" lines plot_hbr_table.py reads,
    # e.g. to diff against a --create_table dump:
    ./gen_smooth_table.py --peak 0.8 --rise-ms 1.5 --hold-ms 3.0 --fall-ms 1.5 --emit
"""
import argparse


def smoothstep(x):
    x = max(0.0, min(1.0, x))
    return 3 * x * x - 2 * x * x * x


def gen_steps(peak, state, rise_p, hold_p, fall_p):
    """peak: 0..1 fraction of full scale. *_p: durations in PWM periods (ints)."""
    steps = []
    t = 0
    for i in range(rise_p):
        frac = (i + 1) / rise_p
        power = round(peak * 255 * smoothstep(frac))
        steps.append(dict(t0=t, t1=t + 1, state=state, power=power))
        t += 1
    for i in range(hold_p):
        power = round(peak * 255)
        steps.append(dict(t0=t, t1=t + 1, state=state, power=power))
        t += 1
    for i in range(fall_p):
        frac = (i + 1) / fall_p
        power = round(peak * 255 * (1 - smoothstep(frac)))
        steps.append(dict(t0=t, t1=t + 1, state=state, power=power))
        t += 1
    return steps


def compress(steps):
    """merge consecutive same-power steps into single table entries (dur field, max 256 periods each)."""
    entries = []
    i = 0
    while i < len(steps):
        p = steps[i]['power']
        s = steps[i]['state']
        t0 = steps[i]['t0']
        j = i
        while j + 1 < len(steps) and steps[j + 1]['power'] == p and steps[j + 1]['state'] == s \
                and (steps[j + 1]['t1'] - t0) <= 256:
            j += 1
        t1 = steps[j]['t1']
        entries.append(dict(t0=t0, t1=t1, state=s, power=p))
        i = j + 1
    return entries


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                  formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--peak', type=float, default=0.8, help='peak amplitude, 0..1 fraction of full scale (default 0.8)')
    ap.add_argument('--state', type=int, default=1, choices=[1, 2], help='drive direction (default 1)')
    ap.add_argument('--rise-ms', type=float, default=1.5)
    ap.add_argument('--hold-ms', type=float, default=3.0)
    ap.add_argument('--fall-ms', type=float, default=1.5)
    ap.add_argument('--pwm-freq', type=float, default=4800.0, help='Hz, for the ms -> PWM-period conversion (default 4800, board default)')
    ap.add_argument('--emit', action='store_true', help='print as "#s ..." lines (same format plot_hbr_table.py reads) instead of plotting')
    ap.add_argument('--save', metavar='FILE')
    ap.add_argument('--no-show', action='store_true')
    args = ap.parse_args()

    rise_p = max(1, round(args.rise_ms / 1000 * args.pwm_freq))
    hold_p = max(1, round(args.hold_ms / 1000 * args.pwm_freq))
    fall_p = max(1, round(args.fall_ms / 1000 * args.pwm_freq))

    steps = gen_steps(args.peak, args.state, rise_p, hold_p, fall_p)
    entries = compress(steps)
    total = steps[-1]['t1']

    if args.emit:
        for i, e in enumerate(entries):
            dur = (e['t1'] - e['t0']) - 1
            print(f"#s {e['t0']:5d} {i:4d} {e['state']} {dur:4d} {e['power']:5d}")
        print(f"# PWM length {total}, table length {len(entries)}")
        return

    import matplotlib
    if args.no_show:
        matplotlib.use('Agg')
    import matplotlib.pyplot as plt

    fig, ax = plt.subplots(figsize=(10, 4.2))
    color = '#2a78d6' if args.state == 1 else '#e34948'
    xs = [s['t0'] for s in steps] + [steps[-1]['t1']]
    ys = [s['power'] for s in steps] + [steps[-1]['power']]
    # draw as a proper step curve but the ramps are already fine-grained (1 period/step)
    ax.plot(xs, ys, color=color, linewidth=2, drawstyle='steps-post')
    ax.axhline(0, color='#b7bcb2', linewidth=1, zorder=1)
    ax.set_xlim(0, total)
    ax.set_ylim(-20, 280)
    ax.set_xlabel('PWM periods')
    ax.set_ylabel('power (0-255)')
    ax.set_title(f'{total} PWM periods, {len(entries)} table entries  '
                 f'({total/args.pwm_freq*1000:.1f} ms @ {args.pwm_freq:g} Hz)')
    fig.tight_layout()

    print(f"rise {rise_p}p / hold {hold_p}p / fall {fall_p}p  =  {total} periods total, "
          f"{len(entries)} table entries after compression")

    if args.save:
        fig.savefig(args.save, dpi=150)
        print(f"Saved to {args.save}")
    if not args.no_show:
        try:
            plt.show()
        except Exception as e:
            print(f"(no display: {e}; use --save FILE.png)")


if __name__ == '__main__':
    main()
