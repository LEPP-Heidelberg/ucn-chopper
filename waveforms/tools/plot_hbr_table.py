#!/usr/bin/env python3
"""
Plot the waveform shape produced by `hbr --create_table`.

Usage:
    ./hbr --create_table <args...>              | ./plot_hbr_table.py
    ./hbr --create_table <args...> --load_table 0 1 | ./plot_hbr_table.py --pwm-freq 4800
    ./plot_hbr_table.py saved_dump.txt --save waveform.png

Reads the "#r/#p/#f/#n/#r2/#b8/#b ..." debug lines that hbr_create_seq_table()
prints (stdin by default, or a file given as the first argument), reconstructs
the step waveform, and plots power vs. time.

--pwm-freq sets the *actual playback* PWM rate (Hz) used for the real-time axis
and phase table; it defaults to 4800, the board's power-on default. This is
independent of the frequency argument you passed to --create_table, which only
affects the shape's timing math -- if the two don't match, this script's real-time
numbers are what will actually happen on the board, not what --create_table's
input ms values implied.
"""
import sys
import re
import argparse

LINE_RE = re.compile(r'^#(\w+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s*$')

PHASE_NAMES = {
    'r': 'Rise', 'p': 'Plateau', 'f': 'Fall', 'n': 'Neg. hold',
    'r2': 'Return', 'b8': 'Background', 'b': 'Background',
}


def parse(lines):
    steps = []
    for line in lines:
        m = LINE_RE.match(line.strip())
        if not m:
            continue
        tag, cum, idx, state, dur, power = m.groups()
        cum, state, dur, power = int(cum), int(state), int(dur), int(power)
        length = dur + 1
        signed_power = power if state == 1 else -power
        steps.append(dict(tag=tag, t0=cum, t1=cum + length,
                           state=state, power=signed_power))
    return steps


def phases_from_steps(steps):
    phases = []
    cur_name, cur_start = None, None
    for s in steps:
        name = PHASE_NAMES.get(s['tag'], s['tag'])
        if name != cur_name:
            if cur_name is not None:
                phases.append((cur_name, cur_start, s['t0']))
            cur_name, cur_start = name, s['t0']
    if steps:
        phases.append((cur_name, cur_start, steps[-1]['t1']))
    return phases


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                  formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('infile', nargs='?', help='file with the debug dump (default: stdin)')
    ap.add_argument('--pwm-freq', type=float, default=4800.0,
                     help='actual playback PWM frequency in Hz (default: 4800, the board power-on default)')
    ap.add_argument('--save', metavar='FILE', help='save PNG instead of/in addition to showing it')
    ap.add_argument('--no-show', action='store_true', help="don't open an interactive window")
    args = ap.parse_args()

    text = open(args.infile) if args.infile else sys.stdin
    steps = parse(text)
    if not steps:
        sys.exit("No '#r/#p/#f/#n/#r2/#b8/#b ...' lines found in the input. "
                 "Pipe the output of `hbr --create_table ...` in, or pass it as a file.")

    total = steps[-1]['t1']
    phases = phases_from_steps(steps)

    import matplotlib
    if args.no_show or not args.save is None and args.no_show:
        matplotlib.use('Agg')
    import matplotlib.pyplot as plt

    fig, ax = plt.subplots(figsize=(10, 4.2))

    # step waveform, colored by direction (state 1 = blue/forward, state 2 = red/reverse)
    pos_color, neg_color = '#2a78d6', '#e34948'
    for s in steps:
        color = pos_color if s['state'] == 1 else neg_color
        ax.hlines(s['power'], s['t0'], s['t1'], color=color, linewidth=2, zorder=3)
    # vertical connectors between consecutive steps
    for a, b in zip(steps, steps[1:]):
        ax.vlines(a['t1'], a['power'], b['power'],
                   color=(pos_color if b['state'] == 1 else neg_color),
                   linewidth=1, zorder=2, alpha=0.6)

    ax.axhline(0, color='#b7bcb2', linewidth=1, zorder=1)
    ax.set_xlim(0, total)
    ax.set_ylim(-270, 290)
    ax.set_xlabel('PWM periods')
    ax.set_ylabel('power (signed by direction, 0-255)')
    ax.set_title(f'{total} PWM periods, {len(steps)} table entries  '
                 f'({total/args.pwm_freq*1000:.1f} ms @ {args.pwm_freq:g} Hz)')

    from matplotlib.patches import Patch
    ax.legend(handles=[Patch(color=pos_color, label='state 1 (fwd)'),
                        Patch(color=neg_color, label='state 2 (rev)')],
               loc='upper right', frameon=False, fontsize=9)

    fig.tight_layout()

    # phase table on stdout
    print(f"{'phase':<12}{'periods':>16}{'duration':>10}"
          f"{'ms @ ' + str(args.pwm_freq) + 'Hz':>16}")
    for name, t0, t1 in phases:
        dur = t1 - t0
        print(f"{name:<12}{t0:>7}-{t1:<8}{dur:>10}{dur/args.pwm_freq*1000:>16.2f}")
    print(f"{'total':<12}{'0-' + str(total):<15}{total:>10}"
          f"{total/args.pwm_freq*1000:>16.2f}")

    if args.save:
        fig.savefig(args.save, dpi=150)
        print(f"\nSaved to {args.save}")
    if not args.no_show:
        try:
            plt.show()
        except Exception as e:
            print(f"\n(couldn't open a display window: {e}; use --save FILE.png instead)")


if __name__ == '__main__':
    main()
