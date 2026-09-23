#!/usr/bin/env python3
"""
Generate a table waveform, print the table entries it produces, and plot it.
Pure local generation -- nothing here talks to the board.

Two shapes so far:
  parabola  -- 0 -> peak -> 0 over N PWM periods (one continuous phase);
               --bipolar repeats the same parabola on the opposite state
               right after it returns to 0 (0->peak->0->[-peak]->0)
  exp_pulse -- bipolar soft-start/exponential pulse, ported from a numpy AWG
               script: instant jump to soft_start_pct, exponential creep
               toward the peak, instant drop to zero, optional mirrored
               negative pulse, then idle for the rest of the period at
               target_freq_hz.

The printed lines are "#tag cum idx state dur power" -- the same format
hbr_create_seq_table()'s own debug dump uses, and what plot_hbr_table.py
reads directly. tag/cum/idx are debug-only labels -- never part of the
18-bit word that actually gets uploaded (state/dur/power are the entire
payload) -- but they're what makes the *Python-side* phase breakdown
readable, so each shape tags its own distinct phases rather than dumping
everything under one generic label.

Getting any of this onto the actual board still needs the --load_table_file
C++ addition (not implemented yet -- see project notes); nothing here talks
to the board.

Usage:
    ./gen_table.py --shape parabola --peak 200 --periods 100 --save parabola.png
    ./gen_table.py --shape exp_pulse --target-freq 2.0 --t-rise 0.02 \\
        --soft-start 0.33 --tau 0.1 --pwm-freq 4800 --save pulse.png
"""
import argparse
import math

# The board's PWM frequency is not free-form -- it's one of 8 fixed presets
# selected by a 3-bit code (see SRC/SHUTTER/hbr_gen_pkg.vhd / hbr --set_pwm).
BOARD_PWM_FREQUENCIES = (4800, 8000, 9600, 16000, 19200, 24000, 32000, 48000)

# Each channel's sequence RAM is 1024 entries (SEQ_LENGTH in C_hbr.h), but
# hbr_create_seq_table() splits it into two independently-triggered 512-entry
# halves -- one for the "turn on" sequence, one for "turn off" (see
# C_hbr.cpp:hbr_seq_table_range, seq_beg = SEQ_LENGTH*seq_nr/2). They are not
# chained in hardware, so any single continuous waveform (e.g. --bipolar) has
# to fit in one 512-entry half.
MAX_TABLE_ENTRIES = 512


def gen_parabola(peak, periods, state, t0_offset=0, tag='g'):
    """power(t) = peak * (1 - ((t - periods/2) / (periods/2))^2), t=0..periods-1"""
    steps = []
    half = periods / 2.0
    for t in range(periods):
        frac = (t - half) / half
        power = round(peak * (1 - frac * frac))
        power = max(0, min(255, power))
        steps.append(dict(t0=t + t0_offset, t1=t + t0_offset + 1, state=state, power=power, tag=tag))
    return steps


def gen_bipolar_parabola(peak, periods, state):
    """0 -> peak -> 0 on `state`, immediately followed by 0 -> peak -> 0 on the
    opposite state (1<->2) -- i.e. the same parabola mirrored in sign, back to back."""
    other_state = 2 if state == 1 else 1
    pos = gen_parabola(peak, periods, state, t0_offset=0, tag='g+')
    neg = gen_parabola(peak, periods, other_state, t0_offset=periods, tag='g-')
    return pos + neg


def gen_exp_pulse(target_freq_hz, t_rise, t_plateau, t_gap, soft_start_pct, tau,
                   include_negative, pwm_freq, state_pos=1, state_neg=2):
    """
    Port of the numpy soft-start/exponential AWG waveform: same phase
    boundaries and formulas, just sampled on the board's PWM-period grid
    (1 sample/period) instead of an arbitrary num_points, and quantized to
    a signed state (1/2) + 0-255 power instead of a continuous +-1 voltage.
    """
    T_period = 1.0 / target_freq_hz
    t_pos_pulse = t_rise + t_plateau
    t_total_active = (t_pos_pulse + t_gap + t_pos_pulse) if include_negative else t_pos_pulse
    if t_total_active > T_period:
        raise ValueError(f"active duration {t_total_active}s exceeds period {T_period}s")

    total_periods = round(T_period * pwm_freq)
    t0 = 0.0
    t1 = t0 + t_rise
    t2 = t1 + t_plateau
    t3 = t2 + t_gap
    t4 = t3 + t_rise
    t5 = t4 + t_plateau

    def phase_at(t_sec):
        if t0 <= t_sec < t1:
            return 'pos_rise'
        if t1 <= t_sec < t2:
            return 'pos_plateau'
        if include_negative and t3 <= t_sec < t4:
            return 'neg_rise'
        if include_negative and t4 <= t_sec < t5:
            return 'neg_plateau'
        return 'idle'

    def voltage_at(t_sec, phase):
        if phase == 'pos_rise':
            return soft_start_pct + (1.0 - soft_start_pct) * (1.0 - math.exp(-(t_sec - t0) / tau))
        if phase == 'pos_plateau':
            return 1.0
        if phase == 'neg_rise':
            return -soft_start_pct - (1.0 - soft_start_pct) * (1.0 - math.exp(-(t_sec - t3) / tau))
        if phase == 'neg_plateau':
            return -1.0
        return 0.0

    raw = []
    for k in range(total_periods):
        t_sec = k / pwm_freq
        phase = phase_at(t_sec)
        raw.append(voltage_at(t_sec, phase))

    peak_abs = max(abs(v) for v in raw) or 1.0

    steps = []
    for k in range(total_periods):
        t_sec = k / pwm_freq
        phase = phase_at(t_sec)
        v = raw[k] / peak_abs
        v = max(-1.0, min(1.0, v))
        state = state_neg if v < 0 else state_pos
        power = round(abs(v) * 255)
        steps.append(dict(t0=k, t1=k + 1, state=state, power=power, tag=phase))
    return steps


def compress(steps):
    """merge consecutive steps with same (state, power, tag) into table entries
    (max 256 periods each -- a phase boundary or a state/power change both end a run)."""
    entries = []
    i = 0
    while i < len(steps):
        p, s, tag = steps[i]['power'], steps[i]['state'], steps[i]['tag']
        t0 = steps[i]['t0']
        j = i
        while j + 1 < len(steps) and steps[j + 1]['power'] == p and steps[j + 1]['state'] == s \
                and steps[j + 1]['tag'] == tag and (steps[j + 1]['t1'] - t0) <= 256:
            j += 1
        entries.append(dict(t0=t0, t1=steps[j]['t1'], state=s, power=p, tag=tag))
        i = j + 1
    return entries


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                  formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--shape', choices=['parabola', 'exp_pulse'], default='parabola')
    # parabola params
    ap.add_argument('--peak', type=int, default=200, help='[parabola] peak power, 0-255')
    ap.add_argument('--periods', type=int, default=100, help='[parabola] total PWM periods')
    ap.add_argument('--duration-ms', type=float, default=None,
                     help='[parabola] total duration in ms -- overrides --periods, computed as '
                          'duration_ms/1000 * --pwm-freq, so raising --pwm-freq gives more (smoother) '
                          'periods for the same real-time envelope')
    ap.add_argument('--state', type=int, default=1, choices=[1, 2], help='[parabola] direction')
    ap.add_argument('--bipolar', action='store_true',
                     help='[parabola] after returning to 0, repeat the same parabola on the opposite state')
    # exp_pulse params (mirror the original numpy script's names)
    ap.add_argument('--target-freq', type=float, default=2.0, help='[exp_pulse] repetition rate, Hz')
    ap.add_argument('--t-rise', type=float, default=0.02, help='[exp_pulse] rise duration, s')
    ap.add_argument('--t-plateau', type=float, default=0.0, help='[exp_pulse] plateau duration, s')
    ap.add_argument('--t-gap', type=float, default=0.0, help='[exp_pulse] gap between +/- pulses, s')
    ap.add_argument('--soft-start', type=float, default=0.33, help='[exp_pulse] initial jump, 0-1 fraction')
    ap.add_argument('--tau', type=float, default=0.1, help='[exp_pulse] exponential time constant, s')
    ap.add_argument('--no-negative', action='store_true', help="[exp_pulse] positive pulse only")
    ap.add_argument('--pwm-freq', type=float, default=4800.0,
                     help='PWM rate, Hz, used to sample onto the board\'s period grid (default 4800, board '
                          f'default). Board only accepts one of {BOARD_PWM_FREQUENCIES} (hbr --set_pwm rounds '
                          'down to the nearest one), so pick from that list for the periods here to match real time.')
    ap.add_argument('--save', metavar='FILE')
    ap.add_argument('--no-show', action='store_true')
    args = ap.parse_args()

    if args.shape == 'parabola':
        if args.peak > 255 or args.peak < 0:
            raise SystemExit(f"--peak must be 0-255, got {args.peak}")

        periods = args.periods
        if args.duration_ms is not None:
            if args.pwm_freq not in BOARD_PWM_FREQUENCIES:
                print(f"# note: --pwm-freq {args.pwm_freq:g} isn't one of the board's fixed rates "
                      f"{BOARD_PWM_FREQUENCIES} -- hbr --set_pwm would round down to the nearest one, "
                      "so real time on the board would drift from what's computed here")
            periods = max(2, round(args.duration_ms / 1000.0 * args.pwm_freq))
            print(f"# --duration-ms {args.duration_ms:g} @ {args.pwm_freq:g} Hz -> {periods} periods")

        if args.bipolar:
            steps = gen_bipolar_parabola(args.peak, periods, args.state)
            title = f'Bipolar parabola: peak {args.peak}, {periods}x2 PWM periods'
        else:
            steps = gen_parabola(args.peak, periods, args.state)
            title = f'Parabola: peak {args.peak}, {periods} PWM periods'
        if args.duration_ms is not None:
            title += f'  ({args.duration_ms:g} ms @ {args.pwm_freq:g} Hz)'
    else:
        steps = gen_exp_pulse(args.target_freq, args.t_rise, args.t_plateau, args.t_gap,
                               args.soft_start, args.tau, not args.no_negative, args.pwm_freq)
        title = (f'Exp pulse: {args.target_freq:g} Hz, rise {args.t_rise*1000:g} ms, '
                 f'soft-start {args.soft_start:g}, tau {args.tau*1000:g} ms')

    entries = compress(steps)
    total = steps[-1]['t1']

    print(f"# {len(steps)} raw samples -> {len(entries)} table entries after compression")
    if len(entries) > MAX_TABLE_ENTRIES:
        print(f"# WARNING: {len(entries)} entries exceeds the board's {MAX_TABLE_ENTRIES}-entry sequence "
              f"limit (each continuous on/off sequence gets half of the 1024-deep per-channel table) -- "
              "this won't fit as a single sequence; lower --periods/--duration-ms or --pwm-freq")
    for idx, e in enumerate(entries):
        dur = (e['t1'] - e['t0']) - 1  # stored value is periods-1, matches hardware field
        print(f"#{e['tag']:<11s}{e['t0']:6d} {idx:4d} {e['state']} {dur:4d} {e['power']:5d}")
    print()

    import matplotlib
    if args.no_show:
        matplotlib.use('Agg')
    import matplotlib.pyplot as plt

    fig, ax = plt.subplots(figsize=(10, 4.2))
    xs, ys, cs = [], [], []
    for s in steps:
        color = '#2a78d6' if s['state'] == 1 else '#e34948'
        xs += [s['t0'], s['t1']]
        ys += [s['power'], s['power']]
    # two-color plot: draw per-state runs so pos/neg read distinctly
    run_x, run_y, run_state = [], [], None
    for s in steps + [None]:
        if s is None or s['state'] != run_state:
            if run_x:
                color = '#2a78d6' if run_state == 1 else '#e34948'
                ax.plot(run_x, run_y, color=color, linewidth=2, drawstyle='steps-post')
            if s is not None:
                run_x, run_y, run_state = [s['t0']], [s['power'] if s['state'] == 1 else -s['power']], s['state']
        else:
            run_x.append(s['t1'])
            run_y.append(s['power'] if s['state'] == 1 else -s['power'])

    ax.axhline(0, color='#b7bcb2', linewidth=1, zorder=1)
    ax.set_xlim(0, total)
    ymax = max(280, max(s['power'] for s in steps) + 20)
    ax.set_ylim(-ymax, ymax)
    ax.set_xlabel('PWM periods')
    ax.set_ylabel('power (signed by direction, 0-255)')
    ax.set_title(f'{title}  ({len(entries)} table entries)')
    fig.tight_layout()

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
