// $Id: C_hbr.cpp 1222 2026-09-16 14:00:13Z  $:

#include "iostream"
#include "ctime"
#include "../upstream/uart32.h"
#include "C_hbr.h"
//#include <math.h>

#ifdef _WIN32
        #define sleep Sleep
#endif

// send commans to clear the logic analyzer buffer OR trigger timestamp timer
uint32_t C_hbr::send_cmd(uint32_t t_command, int debug)
{
    if (debug)
    {
        logWrite("# Write CPU command 0x%08x\n", t_command);
    }
    WriteReg(1, ADDR_CONF_CMD, t_command);
    return 0;
}

uint64_t C_hbr::get_cpu_prog_timestamp(int debug)
{
    uint32_t w;
    uint64_t ts;

    w = ReadReg(4, ADDR_COMP_DATE);
    if (debug)
#ifdef CPU_LM32
        logWrite("# LM32 CPU code compiled on %04x-%02x-%02x at ", w >> 16, (w >> 8) & 0xFF, w & 0xFF);
#endif
#ifdef CPU_SW32
        logWrite("# SW32 CPU code compiled on %04x-%02x-%02x at ", w >> 16, (w >> 8) & 0xFF, w & 0xFF);
#endif
    ts = w;

    w = ReadReg(4, ADDR_COMP_TIME);
    if (debug)
        logWrite("%02x:%02x:%02x\n", w >> 16, (w >> 8) & 0xFF, w & 0xFF);
    ts <<= 32;
    ts |= w;

    return ts;
}

uint32_t C_hbr::read_imem_file(FILE *f, uint32_t *prog_data, uint32_t max_length)
{
    char linebuf[128];
    uint32_t dat;
    int  args;
    uint32_t nwords, nwords0, fillword;

#ifdef CPU_LM32
    fillword=0x00000000;
#endif
#ifdef CPU_SW32
    fillword=0x00FFFFFF;
#endif

    nwords = 0;
    nwords0 = 0;
    while ( (fgets(linebuf, 128, f)) && (nwords < max_length) )
    {
        args = sscanf(linebuf, "%x", &dat);
        if (args >= 1)
        {
            *prog_data = dat;
            if (dat != fillword) nwords0=0; else nwords0++;
            prog_data++;
            nwords++;
        }
    }
    logWrite("# Size of the block with 0x%08x at the end of the IMEM: %d of all %d words (of max %d)\n", fillword, nwords0, nwords, max_length);
    return nwords;
}

// returns the length
int32_t C_hbr::read_power_profile(FILE *f, float *time_ms, float *power, uint32_t max_length, int debug)
{
    char linebuf[128];
    int  args;
    uint32_t nwords;
    float wtime_ms_old, wtime_ms, wpower;
    float pow_min, pow_max;
    float time_min, time_max;

    nwords = 0;
    pow_min =  200;
    pow_max = -200;
    time_min = 1000;
    time_max =-1000;

    if (debug)
        logWrite("# Read the PWM waveform from a file...\n");

    wtime_ms_old = -1;
    while ( (fgets(linebuf, 128, f)) && (nwords < max_length) )
    {
        args = sscanf(linebuf, "%f %f", &wtime_ms, &wpower);
        if (linebuf[0]=='#')
        {
            if (debug)
                logWrite("%s", linebuf);
        }
        else
        if (args >= 2)
        {
            *time_ms = wtime_ms;
            if (wtime_ms <= wtime_ms_old)
            {
                logWrite("# Error: next time %0.3f not larger than previous %0.3f !\n", wtime_ms, wtime_ms_old);
                return -1;
            }
            *power   = wpower;
            if ( (wpower < -100) || (wpower > 100) )
            {
                logWrite("# Warning: power is %0.1f %% and so outside the range -100...+100 ! Will be clipped later while resampling.\n", wpower);
            }
            time_ms++;
            power++;
            nwords++;
            if (debug)
                logWrite("# %3d => Time %6.3f ms  Power %7.1f %%\n", nwords, wtime_ms, wpower);
            if (wtime_ms > time_max) time_max = wtime_ms;
            if (wtime_ms < time_min) time_min = wtime_ms;
            if (wpower   < pow_min ) pow_min  = wpower  ;
            if (wpower   > pow_max ) pow_max  = wpower  ;
            wtime_ms_old = wtime_ms;
        }
    }
    logWrite("# Read %d data points. Time[ms] from %0.3f to %0.3f, Power[%%] from %0.1f to %0.1f\n",
        nwords, time_min, time_max, pow_min, pow_max);

    return nwords;
}

// returns the length
// tstep = 0 or negative means use the last PWM period
// tscale < 1 means the PWM period is shorter and generate more points
// tscale > 1 means the PWM period is longer and generate less points
// pscale > 1 means the power will be increased but clipped to the max possible values
// pscale < 1 means the power will be decreased
int32_t C_hbr::resample_power_profile(float tstep, float tscale, float pscale, float *time_ms, float *power, uint32_t flength, int16_t *ipower, int debug)
{   // pointer in the float table and in the integer table
    int fpoint, ipoint;
    float ntime, stime, tbeg, tend, fp;
    FILE *fout;

    if (debug)
    {
        logWrite("# RESAMPLE\n");
        fout = fopen("res_wave.dat", "w");
        fprintf(fout, "# idx | normal_time [ms] | scaled_time [ms] | integer_power [%d .. %d]\n", MIN_INT_POWER, MAX_INT_POWER);
    }

    fpoint = 0;

    ipoint = 0;

    if (last_pwm_freq <= 0)
        hbr_rep_pwm();

    if (tstep <= 1e-3) // not specified
    {
        logWrite("# Using the last PWM frequency %d Hz!\n", last_pwm_freq);
        // timestep in ms
        tstep = 1000.0/last_pwm_freq;
    }

    do
    {
        ntime = (tstep/2 + ipoint*tstep);
        stime = ntime;
        tbeg = tscale*time_ms[fpoint] ;
        tend = tscale*time_ms[fpoint+1] ;
        if ( (stime >= tbeg) && (stime <= tend ) )
        // inside the interval - interpolate
        {   // linear interpolation
            fp = pscale*( (power[fpoint+1]-power[fpoint])/(tend-tbeg)*(stime-tbeg) + power[fpoint]);
            fp *= 0.01*MAX_INT_POWER; // from % to the integer range

            // convert to integer with rounding
            if (fp>0) fp += 0.5;
            if (fp<0) fp -= 0.5;
            // to integer
            ipower[ipoint] = (int) fp;

            // clip to the max power
            if (ipower[ipoint] > MAX_INT_POWER) ipower[ipoint] = MAX_INT_POWER;
            if (ipower[ipoint] < MIN_INT_POWER) ipower[ipoint] = MIN_INT_POWER;
            if (debug)
                fprintf(fout, "%3d  %6.3f %6.3f %4d\n", ipoint, ntime, stime, ipower[ipoint] );

            logWrite("# %3d => Time %6.3f ms  Power %4d\n", ipoint, ntime, ipower[ipoint] );
            ipoint++;
        }
        else
            fpoint++;

    } while ( (fpoint < (flength-1)) && (ipoint < UNCOMPR_LENGTH ) );
    logWrite("# %d data points\n", ipoint);

    if (debug)
        fclose(fout);

    return ipoint;
}

// returns the length of the compressed table
int32_t C_hbr::compress_power_profile(uint32_t ilength, int16_t *ipower, uint32_t* tbl_data, int debug)
{
    int ipoint, opoint;
    int h_state, rep;
    uint32_t wtable, wpower;

    if (debug)
        logWrite("# COMPRESS\n# input idx, output idx, h-state, repetitions-1, power\n");
    ipoint=0;  // pointer to the input table
    opoint=0;  // pointer to the output table
    do
    {   // clear the number of repetitions
        rep = 0;
        // select the H-state according to the sign of the power
        if (ipower[ipoint] < 0)
        {
            h_state = 2;
            // power remains always non-negative
            wpower  = -ipower[ipoint];
        }
        else
        {
            h_state = 1;
            wpower  = ipower[ipoint];
        }
        wtable  = h_state << SEQ_TABLE_POS_OUT;
        wtable |= (wpower << SEQ_TABLE_POS_PWR);
        while ( (ipoint < (ilength-1) ) && (ipower[ipoint+1] == ipower[ipoint]) && (rep < MAX_REP) )
        {
            rep++;
            ipoint++;
        }
        if (debug)
            logWrite("# %3d  %3d  %d  %3d  %3d\n", ipoint, opoint, h_state, rep, wpower);

        tbl_data[opoint] = wtable | (rep << SEQ_TABLE_POS_DUR);
        ipoint++;
        opoint++;
    } while ( (ipoint < ilength ) && (opoint < SEQ_LENGTH) );

    return opoint;
}

// write 8-bit data to the shared memory
int32_t C_hbr::set_sh_mem(uint32_t msize, uint32_t baddr, uint8_t *sh_mem, uint8_t ainc)
{
    uint16_t csize;

    do
    {
        if (msize > BLOCK_MAX_SIZE)
            csize = BLOCK_MAX_SIZE;
        else
            csize = msize;
        m_uart32->SendBurst(csize, ainc, 1, baddr, sh_mem);
        msize -= csize;
        if (ainc)
            baddr += csize;
        sh_mem+= csize;
    } while (msize > 0);
    return 0;
}

// write 16-bit data to the shared memory
int32_t C_hbr::set_sh_mem(uint32_t msize, uint32_t baddr, uint16_t *sh_mem, uint8_t ainc)
{
    uint16_t csize;

    do
    {
        if (msize > BLOCK_MAX_SIZE)
            csize = BLOCK_MAX_SIZE;
        else
            csize = msize;
        m_uart32->SendBurst(csize, ainc, 1, baddr, sh_mem);
        msize -= csize;
        if (ainc)
            baddr += csize;
        sh_mem+= csize;
    } while (msize > 0);
    return 0;
}

// write 24-bit data to the shared memory
int32_t C_hbr::set_sh_mem24(uint32_t msize, uint32_t baddr, uint32_t *sh_mem, uint8_t ainc)
{
    uint16_t csize;

    do
    {
        if (msize > BLOCK_MAX_SIZE)
            csize = BLOCK_MAX_SIZE;
        else
            csize = msize;
        m_uart32->SendBurst24(csize, ainc, 1, baddr, sh_mem);
        msize -= csize;
        if (ainc)
            baddr += csize;
        sh_mem+= csize;
    } while (msize > 0);
    return 0;
}

// write 32-bit data to the shared memory
int32_t C_hbr::set_sh_mem(uint32_t msize, uint32_t baddr, uint32_t *sh_mem, uint8_t ainc)
{
    uint16_t csize;

    do
    {
        if (msize > BLOCK_MAX_SIZE)
            csize = BLOCK_MAX_SIZE;
        else
            csize = msize;
        m_uart32->SendBurst(csize, ainc, 1, baddr, sh_mem);
        msize -= csize;
        if (ainc)
            baddr += csize;
        sh_mem+= csize;
    } while (msize > 0);
    return 0;
}

// read 8-bit data from the shared memory
int32_t C_hbr::get_sh_mem(uint32_t msize, uint32_t baddr, uint8_t *sh_mem, uint8_t ainc)
{
    uint16_t csize;

    do
    {
        if (msize > BLOCK_MAX_SIZE)
            csize = BLOCK_MAX_SIZE;
        else
            csize = msize;
        m_uart32->RecvBurst(csize, ainc, 1, baddr, sh_mem);
        msize -= csize;
        if (ainc)
            baddr += csize;
        sh_mem+= csize;
    } while (msize > 0);
    return 0;
}

// read 16-bit data from the shared memory
int32_t C_hbr::get_sh_mem(uint32_t msize, uint32_t baddr, uint16_t *sh_mem, uint8_t ainc)
{
    uint16_t csize;

    do
    {
        if (msize > BLOCK_MAX_SIZE)
            csize = BLOCK_MAX_SIZE;
        else
            csize = msize;
        m_uart32->RecvBurst(csize, ainc, 1, baddr, sh_mem);
        msize -= csize;
        if (ainc)
            baddr += csize;
        sh_mem+= csize;
    } while (msize > 0);
    return 0;
}

// read 24-bit data from the shared memory
int32_t C_hbr::get_sh_mem24(uint32_t msize, uint32_t baddr, uint32_t *sh_mem, uint8_t ainc)
{
    uint16_t csize;

    do
    {
        if (msize > BLOCK_MAX_SIZE)
            csize = BLOCK_MAX_SIZE;
        else
            csize = msize;
        m_uart32->RecvBurst24(csize, ainc, 1, baddr, sh_mem);
        msize -= csize;
        if (ainc)
            baddr += csize;
        sh_mem+= csize;
    } while (msize > 0);
    return 0;
}

// read 32-bit data from the shared memory
int32_t C_hbr::get_sh_mem(uint32_t msize, uint32_t baddr, uint32_t *sh_mem, uint8_t ainc)
{
    uint16_t csize;

    do
    {
        if (msize > BLOCK_MAX_SIZE)
            csize = BLOCK_MAX_SIZE;
        else
            csize = msize;
        m_uart32->RecvBurst(csize, ainc, 1, baddr, sh_mem);
        msize -= csize;
        if (ainc)
            baddr += csize;
        sh_mem+= csize;
    } while (msize > 0);
    return 0;
}

int C_hbr::set_hbr_conf_decay(uint8_t decay_code, int debug)
{
    decay_code &= 3; // 0..3
    WriteReg(2, ADDR_HBR_CONF_BIT, (HBR_BIT_DECAY << 4) | decay_code);
    if (debug)
    {
        uint32_t dw = ReadReg(2, ADDR_HBR_CONF);
        logWrite("# Setting HBR DECAY parameter to %d, read back %d\n", decay_code, (dw >> HBR_BIT_DECAY) & 3);
        switch (decay_code)
        {
            case 0: logWrite("#\t Slow decay (brake or high-side re-circulation)\n"); break;
            case 1: logWrite("#\t Smart tune dynamic decay\n"); break;
            case 2:
            case 3: logWrite("#\t Mixed decay: 30%% fast\n"); break;
        }
    }
    return 0;
}

int C_hbr::set_hbr_conf_toff(uint8_t toff_code, int debug)
{
    int off_time;
    toff_code &= 3; // 0..3
    WriteReg(2, ADDR_HBR_CONF_BIT, (HBR_BIT_TOFF << 4) | toff_code);
    if (debug)
    {
        uint32_t dw = ReadReg(2, ADDR_HBR_CONF);
        off_time = 8+8*toff_code;
        if (toff_code == 0) off_time--;
        logWrite("# Setting HBR TOFF parameter to %d, read back %d, off-time in us: %d\n", toff_code, (dw >> HBR_BIT_TOFF) & 3, off_time);
    }
    return 0;
}

int C_hbr::set_hbr_conf_mode(uint8_t mode1, uint8_t mode2, int debug)
{
    mode1 &= 1;
    mode2 &= 1;

    WriteReg(2, ADDR_HBR_CONF_BIT, (HBR_BIT_MODE << 4) | (mode2 << 1) | mode1);
    if (debug)
    {
        uint32_t dw = ReadReg(2, ADDR_HBR_CONF);
        dw >>= HBR_BIT_MODE;
        dw &= 3;
        logWrite("# Setting HBR MODE1|2 parameters to %d | %d, read back mode1=%d, mode2=%d\n", mode1, mode2, dw & 1, dw >> 1 );
    }
    return 0;
}

int C_hbr::set_hbr_conf_ocpm(uint8_t ocpm, int debug)
{
    ocpm &= 1;

    WriteReg(2, ADDR_HBR_CONF_BIT, (HBR_BIT_OCPM << 4) | ocpm);
    if (debug)
    {
        uint32_t dw = ReadReg(2, ADDR_HBR_CONF);
        dw >>= HBR_BIT_OCPM;
        dw &= 1;
        logWrite("# Setting HBR OCPM parameter to %d, read back %d\n", ocpm, dw );
    }
    return 0;
}

int C_hbr::set_hbr_conf_sleep_n(uint8_t sleep_n, int debug)
{
    sleep_n &= 1;

    WriteReg(2, ADDR_HBR_CONF_BIT, (HBR_BIT_SLEEP_N << 4) | sleep_n);
    if (debug)
    {
        uint32_t dw = ReadReg(2, ADDR_HBR_CONF);
        dw >>= HBR_BIT_SLEEP_N;
        dw &= 1;
        logWrite("# Setting HBR SLEEP_n parameter to %d, read back %d\n", sleep_n, dw );
    }
    return 0;
}

int C_hbr::set_hbr_sm_slow_decay(int ch_mask, int slow_decay, int debug)
{
    ch_mask &= 3;
    slow_decay &= 1;

    for (int ch=0; ch<2; ch++)
    {
        if (ch_mask & 1)
            WriteReg(2, ADDR_HBR_CONF_BIT, ((HBR_BIT_SL_DEC_SM+ch) << 4) | slow_decay);
        ch_mask >>= 1;
    }
    if (debug)
    {
        uint32_t dw = ReadReg(3, ADDR_HBR_CONF);
        dw >>= HBR_BIT_SL_DEC_SM;
        dw &= 3;
        logWrite("# Slow decay (SM) in channels 0 and 1 set to %d, %d\n", dw & 1, dw >> 1 );
    }
    return 0;
}

int C_hbr::set_preserve_last(int ch_mask, int preserve, int debug)
{
    ch_mask &= 3;
    preserve &= 1;

    for (int ch=0; ch<2; ch++)
    {
        if (ch_mask & 1)
            WriteReg(2, ADDR_HBR_CONF_BIT, ((HBR_BIT_REM_LAST+ch) << 4) | preserve);
        ch_mask >>= 1;
    }
    if (debug)
    {
        uint32_t dw = ReadReg(3, ADDR_HBR_CONF);
        dw >>= HBR_BIT_REM_LAST;
        dw &= 3;
        logWrite("# Preserve last PWM state (SM) in channels 0 and 1 set to %d, %d\n", dw & 1, dw >> 1 );
    }
    return 0;
}

int C_hbr::set_hbr_conf_ena_inv_afbr(uint8_t ch, uint8_t ena, uint8_t inv, int debug)
{
    ch &= 1;
    ena &= 1;
    inv &= 1;

    WriteReg(2, ADDR_HBR_CONF_BIT, ( (HBR_BIT_ENA_AFBR+ch) << 4) | ena);
    WriteReg(2, ADDR_HBR_CONF_BIT, ( (HBR_BIT_INV_AFBR+ch) << 4) | inv);
    if (debug)
    {
        uint32_t dw = ReadReg(2, ADDR_HBR_CONF);
        logWrite("# Setting AFBR control input %d: enable %d, invert %d, read back enable %d, invert %d\n", ch, ena, inv,
            (dw >> (HBR_BIT_ENA_AFBR+ch)) & 1,
            (dw >> (HBR_BIT_INV_AFBR+ch)) & 1 );
    }
    return 0;
}

int C_hbr::set_hbr_conf_ena_inv_ocpl(uint8_t ch, uint8_t ena, uint8_t inv, int debug)
{
    ch &= 1;
    ena &= 1;
    inv &= 1;

    WriteReg(2, ADDR_HBR_CONF_BIT, ( (HBR_BIT_ENA_OPCPL+ch) << 4) | ena);
    WriteReg(2, ADDR_HBR_CONF_BIT, ( (HBR_BIT_INV_OPCPL+ch) << 4) | inv);
    if (debug)
    {
        uint32_t dw = ReadReg(2, ADDR_HBR_CONF);
        logWrite("# Setting OCPL control input %d: enable %d, invert %d, read back enable %d, invert %d\n", ch, ena, inv,
            (dw >> (HBR_BIT_ENA_OPCPL+ch)) & 1,
            (dw >> (HBR_BIT_INV_OPCPL+ch)) & 1 );
    }
    return 0;
}

uint32_t C_hbr::get_hbr_conf(int debug)
{
    uint32_t dw = ReadReg(3, ADDR_HBR_CONF);

    if (debug)
    {
        logWrite("# HBR parameter read:\n");
        logWrite("# \tDECAY parameter %d\n", (dw >> HBR_BIT_DECAY) & 3);
        logWrite("# \tTOFF  parameter %d\n", (dw >> HBR_BIT_TOFF ) & 3);
        logWrite("# \tMODE1|2 parameters: mode1=%d, mode2=%d\n", (dw >> HBR_BIT_MODE) & 1, (dw >> (HBR_BIT_MODE+1)) & 1 );
        logWrite("# \tOCPM parameter %d\n", (dw >> HBR_BIT_OCPM) & 1 );
        logWrite("# \tSLEEP_n parameter %d\n", (dw >> HBR_BIT_SLEEP_N) & 1 );
        for (int ch=0; ch<2; ch++)
        {
            logWrite("# Ch%d, Slow decay (SM) parameter %d, preserve last PWM state %d\n", ch,
                (dw >> (HBR_BIT_SL_DEC_SM+ch) ) & 1,
                (dw >> (HBR_BIT_REM_LAST +ch) ) & 1 );
            logWrite("# AFBR control input %d: enable %d, invert %d\n", ch,
                (dw >> (HBR_BIT_ENA_AFBR+ch)) & 1,
                (dw >> (HBR_BIT_INV_AFBR+ch)) & 1 );

            logWrite("# OCPL control input %d: enable %d, invert %d\n", ch,
                (dw >> (HBR_BIT_ENA_OPCPL+ch)) & 1,
                (dw >> (HBR_BIT_INV_OPCPL+ch)) & 1 );
        }
        dw = ReadReg(3, ADDR_H_STAT);
        logWrite("# RAM size for one H-bridge channel %d\n", 1 << ((dw >> STA_BIT_N_RAM) & 0xF) );
        logWrite("# Inputs: ");
        for (int i=0; i<2; i++)
        {
            logWrite(" ctrl_%d=%d", i, (dw >> (STA_BIT_CTRL+i) ) & 1);
        }
        for (int i=0; i<4; i++)
        {
            logWrite(" lsw_%d=%d", i, (dw >> (STA_BIT_LSW+i) ) & 1);
        }
        logWrite("\n");
    }
    return dw;
}

// either code 0..7 or frequency 4800..48000 Hz
int C_hbr::set_pwm_freq(uint16_t new_pwm_freq, int debug)
{
    uint32_t freq_code = 0, freq;

    if (new_pwm_freq < 8)
    {
        freq_code = new_pwm_freq;
        freq = PWM_FREQ[freq_code];
    }
    else
    {
        for (int i=0; i<8; i++)
            if (new_pwm_freq >= PWM_FREQ[i]) freq_code = i;

        freq = PWM_FREQ[freq_code];
        if (new_pwm_freq != freq)
        {
            logWrite("# Requested frequency %d Hz, selected %d Hz!\n", new_pwm_freq, freq);
            logWrite("# Possible frequencies are: ");
            for (int i=0; i<8; i++)
                logWrite(" %d,", PWM_FREQ[i]);
            logWrite(" try again or accept the selected one!\n");
        }
    }

    WriteReg(1, ADDR_PWM_FREQ_DIV, freq_code);
    if (debug)
    {
        uint32_t dw = ReadReg(1, ADDR_PWM_FREQ_DIV);
        dw &= 7;
        logWrite("# Setting PWM frequency to %d Hz, read back %d Hz\n", freq, PWM_FREQ[dw] );
    }
    last_pwm_freq = freq;
    return freq;
}

//  ch=0, 1
//  hbr_state 0..3, 0-off, 3-brake, 1, 2 - on forw/back
//  duration 1..256 PWM periods
//  power   - 0 (off) to 255 (max)
int C_hbr::single_shot(int ch, int hbr_state, int duration, int power, int debug)
{
    uint32_t dw;

    ch &= 1;
    hbr_state &= 3;
    duration--;
    duration &= DUR_MASK;
    power    &= PWR_MASK;
    dw = hbr_state;
    dw <<= SEQ_TABLE_WDT_DUR;
    dw |= duration;
    dw <<= SEQ_TABLE_WDT_PWR;
    dw |= power;
    WriteReg(3, ADDR_H_OUTP_1+ch, dw);
    if (debug)
        logWrite("# Single shot on ch%d, power=%d, duration=%d, state=%d\n", ch, power, duration+1, hbr_state);
    // add later status, wait until finished?
    return 0;
}

// bits 0, 1 - go to ON at shutter 1, 2; bits 2, 3 - go to OFF at shutter 1, 2.
// write 1 in the corresponding bit, will be cleared automatically.
int C_hbr::hbr_seq_start(int ch_mask, int seq_ch1, int seq_ch2, int debug)
{
    uint32_t dw = 0;

    ch_mask &= 3;
    seq_ch1 &= 1;
    seq_ch2 &= 1;

    if (ch_mask & 1)
    {
        if (seq_ch1) dw |= 1;
        else         dw |= 1 << 2;
        dw |= 1 << SM_BIT_STO0;
        if (debug)
            logWrite("# Start sequence on ch 1 to state %d\n", seq_ch1);
        dw |= 0x07 << SM_BIT_AMSK; // all ADCs used for this H-bridge
    }
    if (ch_mask & 2)
    {
        if (seq_ch2) dw |= 2;
        else         dw |= 2 << 2;
        dw |= 1 << SM_BIT_STO1;
        if (debug)
            logWrite("# Start sequence on ch 2 to state %d\n", seq_ch2);
        dw |= 0x70 << SM_BIT_AMSK; // all ADCs used for this H-bridge
    }
//    dw |= 0x77 << SM_BIT_AMSK;

    logWrite("# Start with 0x%04x\n", dw);
    WriteReg(2, ADDR_START_ON_OFF, dw);
    for (int i=0; i<100; i++)
    {
        dw = ReadReg(2, ADDR_START_ON_OFF);
        logWrite("%3d => 0x%04x\n", i, dw );
        if ( (dw & ( (1 << SM_BIT_STO1) |  (1 << SM_BIT_STO0) ) ) == 0) break;
    }

    return 0;
}

// bits 0, 1 - go to ON  at shutter 1, 2
// bits 2, 3 - go to OFF at shutter 1, 2
// bits 4, 5 - reset the sequence state machines at ch 1, 2
// write 1 in the corresponding bit, will be cleared automatically.
int C_hbr::hbr_seq_reset(int ch_mask, int debug)
{
    ch_mask &= 3;
    WriteReg(1, ADDR_START_ON_OFF, ch_mask << 4);
    if (debug)
    {
        if (ch_mask & 1)
            logWrite("# Reset the sequence state machine of ch 0\n");
        if (ch_mask & 2)
            logWrite("# Reset the sequence state machine of ch 1\n");
    }
    return 0;
}

// ch = 0, 1
// seq_nr = 0, 1
// seq_beg = 0..1023
// seq_len = 1..1024
// Note: the table for one channel is physically one memory block, used for both directions!
//       so it is not fixed which part is used for which direction!
//       BUT the two channels have different memory blocks!
int C_hbr::hbr_seq_table_range(int ch, int seq_nr, int seq_beg, int seq_len, int debug)
{
    uint32_t dw = 0;

    ch      &= 1;
    seq_nr  &= 1;

    seq_beg &= SEQ_LEN_MASK;
    seq_len--;
    seq_len &= SEQ_LEN_MASK;
    dw = seq_len;
    dw <<= 16;
    dw |= seq_beg;
    if (debug)
        logWrite("# Set table for ch%d, sequence %d: start at %d, length %d\n", ch, seq_nr, seq_beg, seq_len+1);

    WriteReg(4, ADDR_SEQ_AD_RANGE_ON_1 + 2*ch + seq_nr, dw);

    return 0;
}

int C_hbr::hbr_rep_pwm()
{
    uint32_t fcode;

    fcode = ReadReg(1, ADDR_PWM_FREQ_DIV);
    fcode &= 7;
    last_pwm_freq = PWM_FREQ[fcode];
    logWrite("# PWM frequency read back %d Hz\n", last_pwm_freq );
    return last_pwm_freq;
}

int C_hbr::hbr_rep_seq_table()
{
    uint32_t len, sta;

    uint32_t dw[4];

    m_uart32->RecvBurst(4, 1, 1, ADDR_SEQ_AD_RANGE_ON_1, dw);
    for (int i=0; i<4; i++)
    {
        len = (dw[i] >> 16) + 1;
        sta =  dw[i] & 0xFFFF;

        if (len < 2)
            logWrite("# Table for ch%d, sequence %d: disabled!\n", ((i >> 1) & 1) +1, i & 1);
        else
            logWrite("# Table for ch%d, sequence %d: length %d, start at offset %d\n", ((i >> 1) & 1) +1, i & 1, len, sta );
    }
    return 0;
}

// very bad, quick & durty!!!
int C_hbr::hbr_create_seq_table(
    // all times in ms
    int       h_state,
    uint32_t  pwm_freq, // pwm frequency in Hz
    float rt, float ap, // rt - rise time, ap - amplitude positive
    float wt, float ft, // wt - width with ap, ft - fall time to an
    float an, float wn, // an - amplitude negative, wn - width negative
    float r2, float bp, // r2 - second rise time to bp, bp - background power
    float wb,           // wb - width with background
    uint32_t* tbl_data, // integer data to load to the table:
    // bits 17..16 - state, bits 15..8 - duration, bits 7..0 - power
    // return the length of the table
    int debug)
{
    int len=0, pwm_len=0, wi, dur, pwi;

    float ts, dp, pw;
//    uint32_t t; // table entry
    int f_state;

    h_state &= 3;
    if (ap >  1) ap= 1;
    if (an >  1) an= 1;
    if (an < -1) an=-1;
    if (bp < -1) bp=-1;
    if (bp >  1) bp= 1;

    ts = 1000.0/pwm_freq;   // timestep (PWM Period) in ms

    if (rt > ts)
    {
        dp = ts/rt*ap;
        wi=1;
        pw=dp*wi;
        dur=0;
        do
        {
            pwi = (int) (pw*255);
            if (pwi > 255) pwi=255;
            if (pwi <   0) pwi = 0;
            tbl_data[len]=(h_state << 16) | (dur << 8) | pwi ;
            if (debug)
                logWrite("#r  %4d  %3d %d  %3d   %3d\n", pwm_len, len, h_state, dur, pwi);
            pwm_len++;
            len++;
            wi++;
            pw=dp*wi;
        } while (pw < ap);
    }

    wi = (int) (wt/ts);
    while (wi > 256)
    {
        dur = 255;
        pwi = (int) (ap*255);
        if (pwi > 255) pwi=255;
        if (pwi <   0) pwi = 0;
        tbl_data[len]=(h_state << 16) | (dur << 8) | pwi ;
        if (debug)
            logWrite("#p8 %4d  %3d %d  %3d   %3d\n", pwm_len, len, h_state, dur, pwi);
        wi -= 256;
        pwm_len += 256;
        len++;
    }
    if (wi > 0)
    {
        pwi = (int) (ap*255);
        if (pwi > 255) pwi=255;
        if (pwi <   0) pwi = 0;
        wi--;
        tbl_data[len]=(h_state << 16) | (wi << 8) | pwi;
        if (debug)
            logWrite("#p  %4d  %3d %d  %3d   %3d\n", pwm_len, len, h_state, wi, pwi);
        wi++;
        pwm_len += wi;
        len++;
    }

    if (ft > ts)
    {
        dp = ts/ft*(an-ap);
        wi=1;
        pw=ap+dp*wi;
        dur=0;
        do
        {
            pwi = (int) (pw*255);
            if (pwi > 255) pwi=255;
            if (pwi <   0) pwi = -pwi;
            if (pwi > 255) pwi=255;

            f_state = h_state;
            if (pw < 0) f_state ^= 3;
            tbl_data[len]=(f_state << 16) | (dur << 8) | pwi ;
            if (debug)
                logWrite("#f  %4d  %3d %d  %3d   %3d\n", pwm_len, len, f_state, dur, pwi);
            pwm_len++;
            len++;
            wi++;
            pw=ap+dp*wi;
        } while (pw > an);
    }

    wi = (int) (wn/ts);
    while (wi > 256)
    {
        dur = 255;
        pwi = (int) (an*255);
        if (pwi > 255) pwi=255;
        if (pwi <   0) pwi = -pwi;
        if (pwi > 255) pwi=255;
        f_state = h_state;
        if (an < 0) f_state ^= 3;
        tbl_data[len]=(f_state << 16) | (dur << 8) | pwi ;
        if (debug)
            logWrite("#n8 %4d  %3d %d  %3d   %3d\n", pwm_len, len, f_state, dur, pwi);
        wi -= 256;
        pwm_len += 256;
        len++;
    }
    if (wi > 0)
    {
        pwi = (int) (an*255);
        wi--;
        if (pwi <   0) pwi = -pwi;
        if (pwi > 255) pwi=255;
        f_state = h_state;
        if (an < 0) f_state ^= 3;
        tbl_data[len]=(f_state << 16) | (wi << 8) | pwi ;
        if (debug)
            logWrite("#n  %4d  %3d %d  %3d   %3d\n", pwm_len, len, f_state, wi, pwi);
        wi++;
        pwm_len += wi;
        len++;
    }


    if (r2 > ts)
    {
        dp = ts/r2*(bp-an);
        wi=1;
        pw=an+dp*wi;
        dur=0;
        do
        {
            pwi = (int) (pw*255);
            if (pwi > 255) pwi=255;
            if (pwi <   0) pwi = -pwi;
            if (pwi > 255) pwi=255;

            f_state = h_state;
            if (pw < 0) f_state ^= 3;
            tbl_data[len]=(f_state << 16) | (dur << 8) | pwi ;
            if (debug)
                logWrite("#r2 %4d  %3d %d  %3d   %3d\n", pwm_len, len, f_state, dur, pwi);
            pwm_len++;
            len++;
            wi++;
            pw=an+dp*wi;
        } while (pw < bp);
    }

    wi = (int) (wb/ts);
    while (wi > 256)
    {
        dur = 255;
        pwi = (int) (bp*255);
        if (pwi > 255) pwi=255;
        if (pwi <   0) pwi = -pwi;
        if (pwi > 255) pwi=255;
        f_state = h_state;
        if (bp < 0) f_state ^= 3;
        tbl_data[len]=(f_state << 16) | (dur << 8) | pwi ;
        if (debug)
            logWrite("#b8 %4d  %3d %d  %3d   %3d\n", pwm_len, len, f_state, dur, pwi);
        wi -= 256;
        pwm_len += 256;
        len++;
    }
    if (wi > 0)
    {
        pwi = (int) (bp*255);
        wi--;
        if (pwi <   0) pwi = -pwi;
        if (pwi > 255) pwi=255;
        f_state = h_state;
        if (bp < 0) f_state ^= 3;
        tbl_data[len]=(f_state << 16) | (wi << 8) | pwi ;
        if (debug)
            logWrite("#b  %4d  %3d %d  %3d   %3d\n", pwm_len, len, f_state, wi, pwi);
        wi++;
        pwm_len += wi;
        len++;
    }


    logWrite("# PWM length %d, table length %d\n", pwm_len, len );

    return len;
}

int C_hbr::hbr_upload_seq_table(
    int ch, // channel 0 or 1
    int re, // rising edge 1 or 0, 1 in the first table half, 0 in the second table half
    int tbl_len, // length, number of entries, not number of PWM periods!
    uint32_t* tbl_data, // integer data to load to the table:
    // bits 17..16 - state, bits 15..8 - duration, bits 7..0 - power
    // return the length of the table
    int debug)
{
 //   logWrite("# PWM frequency read back %d Hz\n", PWM_FREQ[fcode] );
    int seq_nr, seq_beg, baddr;
    ch &= 1;
    if (ch)
        baddr = ADDR_HBR_SEQ1;
    else
        baddr = ADDR_HBR_SEQ0;

    seq_nr = 1-(re & 1);
    seq_beg = SEQ_LENGTH*seq_nr/2; // in the middle or at the beginning
    hbr_seq_table_range(ch, seq_nr, seq_beg, tbl_len, debug);

    if (debug)
        logWrite("# For ch%d, sequence %d write table at address 0x%04x and length to %d\n", ch, seq_nr, baddr + seq_beg, tbl_len);
    set_sh_mem24(tbl_len, baddr + seq_beg, tbl_data, 1);

    return 0;
}

uint8_t  C_hbr::WriteReg(uint8_t len, uint32_t addr, uint32_t wdata)
{
    switch (len)
    {
        case 1: { m_uart32->WriteByte(  addr, wdata &     0xFF); break; }
        case 2: { m_uart32->WriteWord(  addr, wdata &   0xFFFF); break; }
        case 3: { m_uart32->Write3Bytes(addr, wdata & 0xFFFFFF); break; }
        case 4: { m_uart32->WriteDWord( addr, wdata           ); break; }
        default:
        {
            logWrite("Illegal register length %d (must be from 1 to 4)!\n", len);
            return 1;
        }
    }
    return 0;
}

uint32_t C_hbr::ReadReg(uint8_t len, uint32_t addr)
{
    switch (len)
    {
        case 1: return m_uart32->ReadByte(  addr);
        case 2: return m_uart32->ReadWord(  addr); //, WSIZE_BYTE);
        case 3: return m_uart32->Read3Bytes(addr); //, WSIZE_BYTE);
        case 4: return m_uart32->ReadDWord( addr); //, WSIZE_BYTE);
        default:
        {
            logWrite("Illegal register length %d (must be from 1 to 4)!\n", len);
            return 0;
        }
    }
    return 0;
}


uint32_t C_hbr::read_temper(int debug)
{
    uint32_t pt100w[2];
    float r;

    for (int i=0; i<2; i++)
    {
        pt100w[i] = ReadReg(2, ADDR_PT100_0 + i);
        if (pt100w[i] & (1 << 15) )
            pt100w[i] |= 0xFFFF0000;
        r = slope_pt[i]*PT100_SLOPE16*((int32_t) pt100w[i]);
        if (debug)
            logWrite("# Pt100 resistance %d and temperature are %7.2f %7.2f\n", i, r, PT100_TO_C(r) );
    }
    return (pt100w[1] << 16) | (pt100w[0] & 0xFFFF);
}

int C_hbr::read_adc_buffer(FILE *fout)
{
    uint16_t adc_buff[ADC_BUFF_SIZE];
    uint32_t adc_mask, asample, wrk_mask, nsample;
    int nch;
    float r;

    adc_mask = (ReadReg(2, ADDR_START_ON_OFF) >> SM_BIT_AMSK) & 0xFF;

    get_sh_mem(ADC_BUFF_SIZE, ADDR_ADC_BUFFER, adc_buff, 1);
    wrk_mask = adc_mask;
    nsample = 0;
    asample = 0;
    nch = 0;
    for (int adc_ch=0; adc_ch < 8; adc_ch++)
    {
        if (wrk_mask & 1) nch++;
        wrk_mask >>= 1;
    }

    wrk_mask = adc_mask;
    if (nch == 0) return -1;

    do
    {
        fprintf(fout, "%4d", nsample);
//        printf("# %4d %6d ", nsample, asample);
        for (int adc_ch=0; adc_ch < 8; adc_ch++)
        {
            if (wrk_mask & 1)
            {
//                printf(" 0x%04x", adc_buff[asample]);
                switch (adc_ch & 3)
                {
                    case 0: fprintf(fout, " %7.2f", VADC_SLOPE16*((int16_t) adc_buff[asample++])); break;
                    case 1: fprintf(fout, " %7.3f", IADC_SLOPE16*((int16_t) adc_buff[asample++])); break;
                    case 2: fprintf(fout, " %7.3f", IPROP_SLOPE16*((int16_t) adc_buff[asample++])); break;
                    case 3: r = slope_pt[adc_ch >> 2]*PT100_SLOPE16*((int16_t) adc_buff[asample++]);
                            fprintf(fout, " %7.2f", r ); break;
//                            fprintf(fout, " %7.2f %7.2f", r, PT100_TO_C(r) ); break;
                }
            }
            else
            {
                fprintf(fout, "    -    ");
            }
            wrk_mask >>= 1;
        }
        fprintf(fout, "\n");
//        printf("\n");
        wrk_mask = adc_mask;
        nsample++;
    } while (asample < (ADC_BUFF_SIZE-8) );
    fclose(fout);
    logWrite("# %d samples read, ADC mask was 0x%02x, %d active channels\n", nsample, adc_mask, nch);
    return nsample;
}

