// $Id: C_simpl_stat.cpp 1210 2026-08-13 09:32:42Z  $:
#include "C_simpl_stat.h"
#include <math.h>

C_simpl_stat::C_simpl_stat()
{
    init();
}

C_simpl_stat::~C_simpl_stat()
{
}

void C_simpl_stat::init()
{
    sum_x=0;
    sum_x2=0;
    n=0;
    min=0x7FFFFFFF;
    max=-min;
    mean=0;
    sdev=0;
    mean_valid=0;
    sdev_valid=0;
}

int C_simpl_stat::add(int32_t new_x)
{
    int64_t i64;

    sum_x += new_x;
    i64 = new_x;
    sum_x2 += i64*i64;
    if (new_x > max) max=new_x;
    if (new_x < min) min=new_x;
    n++;
    mean_valid=0;
    sdev_valid=0;
    return n;
}

    // get the number of points up to now
uint32_t C_simpl_stat::get_npoints()
{
    return n;
}

int32_t C_simpl_stat::get_min()
{
    return min;
}

int32_t C_simpl_stat::get_max()
{
    return max;
}

double C_simpl_stat::get_mean()
{
    if (mean_valid==0)
    {
        mean=1.0*sum_x/n;
        mean_valid=1;
    }
    return mean;
}

double C_simpl_stat::get_rms()
{
    int64_t w;
    // sdev=sqrt( (sum(x[i]-xmean)**2)/n )=
    //      sqrt( (sum(x[i]**2)-n*xmean**2)/n )=
    if (sdev_valid==0)
    {
        w = sum_x*sum_x/n;
        w = sum_x2 - w;
        sdev=1.0*w/n;
        sdev=sqrt(sdev);
        sdev_valid=1;
    }
    return sdev;
}
