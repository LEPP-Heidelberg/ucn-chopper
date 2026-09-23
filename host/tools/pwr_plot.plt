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
