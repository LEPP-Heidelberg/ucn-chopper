// $Id: C_simpl_stat.h 1210 2026-08-13 09:32:42Z  $:
#ifndef C_SIMPL_STAT_H
#define C_SIMPL_STAT_H

// $Id: C_simpl_stat.h 1210 2026-08-13 09:32:42Z  $:

//#include <stdio.h>   /* Standard input/output definitions, for perror() */
#include <stdint.h>

// Simple class for statistics with 24-bit signed integer data.

class C_simpl_stat
{
protected:
    int64_t sum_x;
    int64_t sum_x2;
    uint32_t n;
    int mean_valid, sdev_valid;
    double mean;
    double sdev;
    int32_t min;
    int32_t max;

public:
    C_simpl_stat();
    ~C_simpl_stat();
    void init();
    // add new data point
    int add(int32_t new_x);
    // get the number of points up to now
    uint32_t get_npoints();
    // get the min up to now
    int32_t get_min();
    // get the max up to now
    int32_t get_max();
    // get the mean value up to now <x[i]>
    double get_mean();
    // get the rms around the mean value <(x[i]-xmean)**2>
    double get_rms();
};
#endif // C_SIMPL_STAT_H
