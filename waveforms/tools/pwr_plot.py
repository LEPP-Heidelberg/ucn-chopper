#!/usr/bin/env python3
"""
Python equivalent of pwr_plot.plt (gnuplot script).

Original gnuplot:
    reset
    set xrange [0:*]
    set yrange [-110:+110]
    set grid x
    set grid y
    set xlabel "Time, ms"
    set ylabel "Power, %"
    plot "simpl_wave.dat" with lines, \
         "res_wave.dat" u 2:(column(4)*100/255) with points, \
         "res_wave.dat" u 3:(column(4)*100/255) with points
"""

import numpy as np
import matplotlib.pyplot as plt

# --- Load data ------------------------------------------------------------
# simpl_wave.dat: default gnuplot "with lines" uses column 1 as x, column 2 as y
simpl = np.loadtxt("simpl_wave.dat")
simpl_x, simpl_y = simpl[:, 0], simpl[:, 1]

# res_wave.dat: gnuplot columns are 1-indexed, so column 2 -> index 1,
# column 3 -> index 2, column 4 -> index 3
res = np.loadtxt("res_wave.dat")
res_x1, res_x2, res_col4 = res[:, 1], res[:, 2], res[:, 3]
res_y = res_col4 * 100 / 255

# --- Plot -------------------------------------------------------------
fig, ax = plt.subplots()

ax.plot(simpl_x, simpl_y, linestyle="-", label="simpl_wave.dat")
ax.plot(res_x1, res_y, linestyle="None", marker="o", label="res_wave.dat (col 2)")
ax.plot(res_x2, res_y, linestyle="None", marker="o", label="res_wave.dat (col 3)")

ax.set_xlim(left=0)          # set xrange [0:*]
ax.set_ylim(-110, 110)       # set yrange [-110:+110]
ax.grid(True, axis="both")   # set grid x / set grid y

ax.set_xlabel("Time, ms")
ax.set_ylabel("Power, %")
ax.legend()

plt.tight_layout()
plt.savefig("pwr_plot.png", dpi=150)
plt.show()
