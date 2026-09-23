// $Id: C_ads131m04.cpp 1222 2026-09-16 14:00:13Z  $:
//#include <unistd.h>  /* UNIX standard function definitions, usleep */
#include "../upstream/uart32.h"
#include "C_ads131m04.h"

C_ads131m04::C_ads131m04(uart32* p_uart32, uint32_t new_base_addr, uint8_t init)
{
    m_uart32 = p_uart32;
    base_addr = new_base_addr;
    load_reset();
    clear_adc_backgr();
    last_chip_mask = CHIP_MASK_FULL;
}

C_ads131m04::~C_ads131m04()
{
}

    // load the registers with the power up values
int C_ads131m04::load_reset()
{
    int chip, rg;
    for (chip=0; chip<NCHIPS_ADC; chip++)
        for (rg=0; rg<ADS131M04_NUM_REGS; rg++)
        {
            reg_data[chip][rg] = all_ad_regs[rg].init_value;
            reg_flag[chip][rg] = REG_RESET;
        }
    return 0;
}

    // copy a bit slice from src[pos_high-pos_low..0] to dst[pos_high..pos_low]
uint16_t C_ads131m04::cp_bit_slice(uint16_t src, uint16_t dst, uint8_t pos_high, uint8_t pos_low)
{
    uint32_t msk, neg;

    msk = 1L << (pos_high+1);
    msk--;
    neg = 1L <<  pos_low    ;
    neg--;

    msk ^= neg;  // selected bits
    neg = ~msk;  // the not selected bits

    return ( ( (src << pos_low) & msk) | (dst & neg) ) & 0xFFFF;
}

    // Functions on complete ADC chips
    // set the sampling rate in the selected ADC chips, the osr_code is from 0 to 7 for OSR=128, 256, ... 8192, 16384
int C_ads131m04::set_osr(uint8_t chip_mask, uint8_t osr_code)
{
    int chip;

    osr_code &= 0xF;
    last_chip_mask = chip_mask & CHIP_MASK_FULL;

    for (chip=0; chip<NCHIPS_ADC; chip++)
    {
        if (chip_mask & 1)
        {
            reg_data[chip][CLOCK_ADDRESS] = cp_bit_slice(osr_code, reg_data[chip][CLOCK_ADDRESS], 5, 2);
            reg_flag[chip][CLOCK_ADDRESS] = REG_CHANGED;
        }
        chip_mask >>= 1;
    }
    return 0;
}

// set the global chopper settings in CFG register
// Bits 12..9 GC_DLY, bit 8 GC_EN
int C_ads131m04::set_gc(uint8_t chip_mask, uint8_t gc_code)
{
    int chip;

    gc_code &= 0x1F;
    last_chip_mask = chip_mask & CHIP_MASK_FULL;

    for (chip=0; chip<NCHIPS_ADC; chip++)
    {
        if (chip_mask & 1)
        {
            reg_data[chip][CFG_ADDRESS] = cp_bit_slice(gc_code, reg_data[chip][CFG_ADDRESS], 12, 8);
            reg_flag[chip][CFG_ADDRESS] = REG_CHANGED;
        }
        chip_mask >>= 1;
    }
    return 0;
}

    // set the power mode, 0..2(3) for very-low, low, high-resolution
int C_ads131m04::set_pwr(uint8_t chip_mask, uint8_t pwr_code)
{
    int chip;

    last_chip_mask = chip_mask & CHIP_MASK_FULL;
    for (chip=0; chip<NCHIPS_ADC; chip++)
    {
        if (chip_mask & 1)
        {
            reg_data[chip][CLOCK_ADDRESS] = cp_bit_slice(pwr_code, reg_data[chip][CLOCK_ADDRESS], 1, 0);
            reg_flag[chip][CLOCK_ADDRESS] = REG_CHANGED;
        }
        chip_mask >>= 1;
    }
    return 0;
}

// enable the CRC-16 at the SPI input data in the ADS Chip
int C_ads131m04::set_rx_crc(uint8_t rx_crc, uint8_t crc_type_ansi)
{
    int chip;

    rx_crc   &= 1;
    crc_type_ansi &= 1;

    crc_type_ansi |= rx_crc << 1;

    for (chip=0; chip<NCHIPS_ADC; chip++)
    {
        reg_data[chip][MODE_ADDRESS] = cp_bit_slice(crc_type_ansi, reg_data[chip][MODE_ADDRESS], 12, 11);
        reg_flag[chip][MODE_ADDRESS] = REG_CHANGED;
    }
    return 0;
}

int C_ads131m04::set_16_24b(uint8_t wlen)  // 0 - 16 bit, 1 - 24 bit, 2 - 32 bit LSB zero padding, 3 - MSB sign ext.
{
    int chip;

    wlen   &= 3;
    switch(wlen)
    {
        case 0: logWrite("# ADS131: switch to 16-bit data\n"); break;
        case 1: logWrite("# ADS131: switch to 24-bit data\n"); break;
        case 2: logWrite("# ADS131: switch to 32-bit data, LSB zero padding\n"); break;
        case 3: logWrite("# ADS131: switch to 32-bit data, MSB sign ext.\n"); break;
    }

    for (chip=0; chip<NCHIPS_ADC; chip++)
    {
        reg_data[chip][MODE_ADDRESS] = cp_bit_slice(wlen, reg_data[chip][MODE_ADDRESS], 9, 8);
        reg_flag[chip][MODE_ADDRESS] = REG_CHANGED;
    }
    return 0;
}

    // Functions on single ADC channels

// reorder the ADC data, as the ADC numbering on the board is
//  Chip        0           1            2
// Chip Ch  3 2 1 0     3 2 1 0     0 1  2  3
// PCB  Ch  0 1 2 3     4 5 6 7     9 8 10 11
// ch 10 measures the leakage current as voltage drop across 10k
// ch 11 is just shorted, can be used to test the long term stability of the ADC chip
int C_ads131m04::channel2chip_ch(int pcb_ch)
{
    int chip, adc_ch;

    if ( (pcb_ch < 0) || (pcb_ch >= N_ADC_CHANNELS_ALL) )
    {
        logWrite("# Invalid ch nr %d in channel2chip_ch !\n", pcb_ch);
        return -1;
    }
// Reorder the ADC channels, check if necessary and how!!!
    chip = pcb_ch >> 2;
    adc_ch = pcb_ch - 4*chip;

    if (chip   < 2) adc_ch = 3 - adc_ch; // invert the order: 0 1 2 3 => 3 2 1 0
    else
    if (adc_ch < 2) adc_ch = 1 - adc_ch; // swap 8 and 9, don't change 10 and 11

    return adc_ch;
}

int C_ads131m04::channel2chip(int pcb_ch)
{
    if ( (pcb_ch < 0) || (pcb_ch >= N_ADC_CHANNELS_ALL) )
    {
        logWrite("# Invalid ch nr %d in channel2chip !\n", pcb_ch);
        return -1;
    }

    return pcb_ch >> 2;
}

    // 4 channels/chip
int C_ads131m04::set_adc_ena(uint16_t adc_mask)
{
    int chip, adc_ch;

    for (int ch=0; ch < N_ADC_CHANNELS_ALL ; ch++)
    {
        chip   = channel2chip(ch);
        adc_ch = channel2chip_ch(ch);
        reg_data[chip][CLOCK_ADDRESS] = cp_bit_slice(adc_mask & 1, reg_data[chip][CLOCK_ADDRESS], 8+adc_ch, 8+adc_ch);
        reg_flag[chip][CLOCK_ADDRESS] = REG_CHANGED;
        adc_mask >>= 1; // now shift the mask
    }
    return 0;
}

    // set in the selected ADC channels the gain : 1, 2, 4, 8, ... 128
    // this function can be called many times (with different adc_mask)
int C_ads131m04::set_pga(uint16_t adc_mask, uint8_t gain_code)
{
    int chip, adc_ch;

    for (int ch=0; ch < N_ADC_CHANNELS_ALL ; ch++)
    {
        if (adc_mask & 1)
        {
            chip   = channel2chip(ch);
            adc_ch = channel2chip_ch(ch);
            reg_data[chip][GAIN1_ADDRESS] = cp_bit_slice(gain_code, reg_data[chip][GAIN1_ADDRESS], 4*adc_ch+2, 4*adc_ch);
            reg_flag[chip][GAIN1_ADDRESS] = REG_CHANGED;
        }
        adc_mask >>= 1; // now shift the mask
    }
    return 0;
}


// dump the offset correction from the register settings
int C_ads131m04::print_offs_cal()
{
    for (int chip=0; chip<3; chip++)
        for (int ch=0; ch<4; ch++)
            printf("# chip %d, ch %d, msb 0x%04x  lsb 0x%04x\n", chip, ch, reg_data[chip][CH0_OCAL_MSB_ADDRESS+5*ch] , reg_data[chip][CH0_OCAL_LSB_ADDRESS+5*ch] );
    return 0;
}

// set the offset calibration in the register (offline)
int C_ads131m04::set_offs_cal(uint8_t adc_ch, uint32_t offs)
{
    int chip;

    chip = channel2chip(adc_ch);

    adc_ch = channel2chip_ch(adc_ch);

    // 16 MSBits 23..8 to a 16-bit register
    reg_data[chip][CH0_OCAL_MSB_ADDRESS+5*adc_ch] =  offs >> 8;
    reg_flag[chip][CH0_OCAL_MSB_ADDRESS+5*adc_ch] =  REG_CHANGED;
    // 8 LSBits, but shifted to bits 15..8
    reg_data[chip][CH0_OCAL_LSB_ADDRESS+5*adc_ch] = (offs & 0xFF) << 8;
    reg_flag[chip][CH0_OCAL_LSB_ADDRESS+5*adc_ch] =  REG_CHANGED;

    return 0;
}


// set in individual channel the gain correction
int C_ads131m04::set_gain_cal(uint8_t adc_ch, uint32_t gain)
{
    int chip;

    chip = channel2chip(adc_ch);

    adc_ch = channel2chip_ch(adc_ch);
//    logWrite("# Set chip %d, adc_ch %d, gain cal 0x%06x of 0x%06x = %0.3f\n", chip, adc_ch, gain, GCOR_DEFAULT, 1.0*gain/GCOR_DEFAULT);

    reg_data[chip][CH0_GCAL_MSB_ADDRESS+5*adc_ch] =  gain >> 8;
    reg_flag[chip][CH0_GCAL_MSB_ADDRESS+5*adc_ch] =  REG_CHANGED;
    reg_data[chip][CH0_GCAL_LSB_ADDRESS+5*adc_ch] = (gain & 0xFF) << 8;
    reg_flag[chip][CH0_GCAL_LSB_ADDRESS+5*adc_ch] =  REG_CHANGED;

    return 0;
}

    // 0 - normal operation, 1 - shorted, 2 - +test, 3 - -test
    //     the possible values are defined in the header file as ADS_INP_MUX_ NORM/SHORT/POS_T/NEG_T
    //     Note: the precision of the test voltages is not good, in the order of 0.5% of the full range!
int C_ads131m04::set_inp_mux(uint16_t adc_mask, uint8_t mux_code)
{
    int chip, adc_ch, reg_addr;

    for (int ch=0; ch < N_ADC_CHANNELS_ALL ; ch++)
    {
        if (adc_mask & 1)
        {
            chip   = channel2chip(ch);
            adc_ch = channel2chip_ch(ch);
            reg_addr = CH0_CFG_ADDRESS+5*adc_ch;
            reg_data[chip][reg_addr] = cp_bit_slice(mux_code, reg_data[chip][reg_addr], 1, 0);
            reg_flag[chip][reg_addr] = REG_CHANGED;
        }
        adc_mask >>= 1; // now shift the mask
    }

    return 0;
}

// 0 - DC and AC, 1 - AC only
int C_ads131m04::set_dc_block_ch(uint16_t adc_mask, uint8_t dc_block)
{
    int chip, adc_ch, reg_addr;

    dc_block &= 1;
    dc_block = 1 - dc_block;

    for (int ch=0; ch < N_ADC_CHANNELS_ALL ; ch++)
    {
        if (adc_mask & 1)
        {
            chip   = channel2chip(ch);
            adc_ch = channel2chip_ch(ch);
            reg_addr = CH0_CFG_ADDRESS+5*adc_ch;
            reg_data[chip][reg_addr] = cp_bit_slice(dc_block, reg_data[chip][reg_addr], 2, 2);
            reg_flag[chip][reg_addr] = REG_CHANGED;
        }
        adc_mask >>= 1; // now shift the mask
    }

    return 0;
}

    // filter settings 0..15, defined in the header file as ADS_DC_BLOCK_FILT_, 0 is for disable
int C_ads131m04::set_dc_block_flt(uint8_t chip_mask, uint8_t dc_block_filter)
{
    int chip;

    dc_block_filter &= 0xF; // only 4 bits

    last_chip_mask = chip_mask & CHIP_MASK_FULL;

    for (chip=0; chip<NCHIPS_ADC; chip++)
    {
        if (chip_mask & 1)
        {
            reg_data[chip][THRSHLD_LSB_ADDRESS] = cp_bit_slice(dc_block_filter, reg_data[chip][THRSHLD_LSB_ADDRESS], 3, 0);
            reg_flag[chip][THRSHLD_LSB_ADDRESS] = REG_CHANGED;
        }
        chip_mask >>= 1;
    }
    return 0;
}
    // the new 64 kS/s is still not implemented!
    // convert the OSR setting 0..7 to sampling rate in case of high-resolution power mode
int C_ads131m04::osr_to_sampling_rate(uint8_t osr_setting, uint8_t gc_setting) // 0..7
{
    int gc_dly;

    if ( (gc_setting & 1) == 0)
    {
        if (osr_setting < 8)
        {
        osr_setting &= 7;
        return ADS_MAX_SAMPL_RATE >> osr_setting;
        }
        else
        return ADS_MAX_SAMPL_RATE << 1;
    }

    gc_dly = gc_setting >> 1;
    return ((int) 128)*ADS_MAX_SAMPL_RATE / ( (2L << gc_dly) + 3*(128L << osr_setting) );
}

    // convert the desired gain to next (lower) possible gain, only in the range 1, 2, 4!
    // in our design we don't want to use higher gains and they are blocked here.
int C_ads131m04::gain_to_gain_code(int8_t gain)
{
    if (gain < 0) gain = -gain;
    if (gain >= 4) return ADS_PGA_4;
    if (gain >= 2) return ADS_PGA_2;
    return ADS_PGA_1;
}

    // the new 64 kS/s is still not implemented!
    // convert the desired sampling rate in S/s the next (lower) possible rate
int C_ads131m04::sampling_rate_to_osr(uint16_t ads131_sr, uint16_t ads131_gchop)
{
    int i;
//  if (ads131_sr > 32000)
//  {
//      // use 64k
//
//  }

    ads131_gchop &= 1;
    i = 0;
    do
    {
        if ( (ads131_gchop == (ads131_all_sampl_rate_sett[i].gc_dly & 1) ) && (ads131_sr <= ads131_all_sampl_rate_sett[i].srate)  ) break;
        if ( (i < MAX_CHOP_SRATE_IDX) || ( (ads131_gchop==0) && (i < (ADS131_NUMBER_OF_SRATES-1) ) ) ) i++;
        else break;
    } while (1);
    return ads131_all_sampl_rate_sett[i].osr | (ads131_all_sampl_rate_sett[i].gc_dly << 8);
}

    // negative gains (-1, -2, ... -128) mean gain and not gain code and will be converted to gain code (0..7)
    // sampling rate > 7 mean sampling rate in S/s and will be converted to OSR code 0..7.
    // else the sampling rate will be interpreted as OSR directly

// !!! Mapping between ADC Chips & Channels to global Channels in the SPI Interface
// Chip           0                1               2
// Channel  3   2   1   0    3   2   1   0   1   0   2   3
// G.Ch     0   1   2   3    4   5   6   7   8   9  10   11
int C_ads131m04::prepare_all_regs(uint16_t sampling_rate, int gc_flag,
                                int8_t gain_adc,
                                uint8_t inp_mux, uint8_t do_offs_cr, uint8_t shift_r,
                                uint8_t chip_mask, uint8_t ldebug)
{
    chip_mask &= CHIP_MASK_FULL;
    last_chip_mask = chip_mask;
    do_offs_cr &= 1;
    if (shift_r > 16) shift_r = 16;

    // all ADC channels 4*NCHIPS_ADC
    uint16_t all_ch_mask       = (1L << (4*NCHIPS_ADC)) - 1;

    uint16_t osr;

    if (sampling_rate > 8) // rate, not code
    {
        osr = sampling_rate_to_osr(sampling_rate, gc_flag & 1);
        gc_flag = osr >> 8;
        osr &= 0x1F;
    }
    else
    {   // code for OSR and GC
        osr = sampling_rate & 0xF;
        sampling_rate = osr_to_sampling_rate(osr, gc_flag);
    }

    if (gain_adc < 0) gain_adc = gain_to_gain_code(gain_adc);

    inp_mux &= 3;

    if (ldebug)
    {
        logWrite("# Chip Mask is 0x%01x\n", chip_mask);
        logWrite("# ADC Mask with all channels is 0x%04x\n", all_ch_mask & 0xFFFF);
        logWrite("# Requested/selected sampling rates are %d / %d, OSR is %d, GC is %d\n", sampling_rate, osr_to_sampling_rate(osr), osr, gc_flag);
        logWrite("# Gain code %d\n",
            gain_adc);
        logWrite("#   =>  Gain is %d\n",
            1 << gain_adc);
        logWrite("# Input mux code is %d => ", inp_mux);
        switch (inp_mux)
        {
            case ADS_INP_MUX_NORM  : logWrite( "Normal operation\n"); break;
            case ADS_INP_MUX_SHORT : logWrite( "Shorted inputs\n"); break;
            case ADS_INP_MUX_POS_T : logWrite( "Inputs at +2/15 (%+5.2f%%) of VREF\n",  100.0*2/15); break;
            case ADS_INP_MUX_NEG_T : logWrite( "Inputs at -2/15 (%+5.2f%%) of VREF\n", -100.0*2/15);
        }
    }

    load_reset();
    // set the power mode
    set_pwr(chip_mask, ADS_PWR_HIGH_RES);
    // set the over sampling ratio for 1kS/s
    set_osr(chip_mask, osr);
    // set the global chopper
    set_gc(chip_mask, gc_flag);
    // enable all channels
    set_adc_ena(all_ch_mask);
    // set the PGA to 1
    set_pga(all_ch_mask, gain_adc);

    // switch the input mux in the ADC to the inputs, note that the precision of the test signal 2/15 (13.3%) of the full range is not good!
    // We got 12.8% instead of 13.3%, this was reported in the TI forum too.
    set_inp_mux(all_ch_mask, inp_mux);
    // all channels measure DC signals, turn DC block channelwise off
    set_dc_block_ch(all_ch_mask, 0);
    // global setting of the DC block filter
    set_dc_block_flt(chip_mask, ADS_DC_BLOCK_FILT_DIS);
    set_rx_crc(USE_CRC_IN_ADS, USED_CRC_TYPE);
    // program the last loaded offset into the offset cal register
//    offs_non_zero=0;
    for (int ch=0; ch < N_ADC_CHANNELS_ALL ; ch++)
    {

        if (do_offs_cr)
            set_offs_cal(ch, offs_cal[ch]);

        if (shift_r)
            set_gain_cal(ch, GCOR_DEFAULT >> shift_r);
    }
    // offset correction is applied first on the 24-bit data from ADC
    // then the gain correction is applied. Therefore to determine the offset
    // correction, the measurement should be done without gain correction - gain=1 !
    // Only when configuring with offset correction, the gain correction can
    // by applied
//  if (offs_non_zero)
//      // leakage current channel with only 20 bits
//      set_gain_cal(ch_leak_curr, GCOR_DEFAULT >> 4);
    return 0;
}

int C_ads131m04::load_adc_backgr(int32_t* adc_data)
{
    // load the measured offset to be used later
    for (int i = 0; i < N_ADC_CHANNELS_ALL ; i++)
        offs_cal[i] = adc_data[i];
    return 0;
}

int C_ads131m04::clear_adc_backgr()
{
    // clear the offsets, used to initialize the class, of before a measurement
    for (int i = 0; i < N_ADC_CHANNELS_ALL ; i++)
        offs_cal[i] = 0;
    return 0;
}

int C_ads131m04::print_table(FILE *f, uint8_t chip, uint8_t with_read, uint8_t only_marked)
{
    int rg, marked, non_reset, rd_error, print_it;

    fprintf(f, "# ADDR     NAME       RESET_VALUE  CALC_VALUE");
    if (with_read)
        fprintf(f, "  READ_VALUE");
    fprintf(f, "  FLAGS (*: CALC != RESET");
    if (with_read)
        fprintf(f, ", d: CALC != READ");
    fprintf(f, ")\n");
    for (rg=0; rg < ADS131M04_NUM_REGS; rg++)
    {
        non_reset = (all_ad_regs[rg].init_value != reg_data[chip][rg]) && ( (all_ad_regs[rg].flags & FLAG_READ_ONLY) != FLAG_READ_ONLY);
        rd_error  = (reg_data[chip][rg] != reg_data_rd[chip][rg]) && ( (all_ad_regs[rg].flags & FLAG_READ_ONLY) != FLAG_READ_ONLY) && (with_read);
        marked    = (non_reset) || (rd_error);
        print_it  = (marked) || (only_marked==0) ;

        if (print_it)
            fprintf(f, "# %02x %15s   0x%04x       0x%04x",
                            all_ad_regs[rg].reg_addr, all_ad_regs[rg].reg_name, all_ad_regs[rg].init_value,
                            reg_data[chip][rg]);

        if (non_reset)
            fprintf(f, " *");
        else
            if (only_marked==0) fprintf(f, "  ");

        if ( print_it )
        {
            if (with_read)
                fprintf(f, "     0x%04x", reg_data_rd[chip][rg]);
            if ( rd_error )
                fprintf(f, " d");
            fprintf(f, "\n");
        }
    }
    return 0;

}

#ifdef SOFT_CRC

//*****************************************************************************
//
//! Calculates the 16-bit CRC for the selected CRC polynomial.
//!
//! \fn uint16_t calculateCRC(const uint8_t dataBytes[], uint8_t numberBytes, uint16_t initialValue)
//!
//! \param dataBytes[] pointer to first element in the data byte array
//! \param numberBytes number of bytes to be used in CRC calculation
//! \param initialValue the seed value (or partial crc calculation), use 0xFFFF when beginning a new CRC computation
//!
//! NOTE: This calculation is shown as an example and is not optimized for speed.
//!
//! \return 16-bit calculated CRC word
//
//*****************************************************************************
uint16_t C_ads131m04::calculateCRC(const uint16_t dataWords[], uint8_t numberWords, uint16_t initialValue)
{
    uint8_t db[6], idx=0;

    // the first byte to be sent
    db[idx++] = dataWords[0] >> 8;
    // the next byte
    db[idx++] = dataWords[0] & 0xFF;
    // and the last byte of the first 24-bit word, here are all bits 0, but it is
    // necessary to calculate the CRC on all sent bits!
    db[idx++] = 0;
    // when writing a register, a second 24-bit word is sent
    if (numberWords > 1)
    {
        db[idx++] = dataWords[1] >> 8;
        db[idx++] = dataWords[1] & 0xFF;
        db[idx++] = 0;
    }
    // we don't have other cases! Only one or two 24-bit words when sending.
    return calculateCRC(db, idx, initialValue);
}

// this function copied from the example code of TI
uint16_t C_ads131m04::calculateCRC(const uint8_t dataBytes[], uint8_t numberBytes, uint16_t initialValue)
{
    int         bitIndex, byteIndex;
    bool        dataMSb;        // Most significant bit of data byte
    bool        crcMSb;         // Most significant bit of crc byte


//   * Initial value of crc register
//   * NOTE: The ADS131M0x defaults to 0xFFFF,
//   * but can be set at function call to continue an on-going calculation

    uint16_t crc = initialValue;
//
    #if USED_CRC_TYPE==CRC_CCITT
//  CCITT CRC polynomial = x^16 + x^12 + x^5 + 1
    const uint16_t poly = 0x1021;
    #else
//  ANSI CRC polynomial = x^16 + x^15 + x^2 + 1
    const uint16_t poly = 0x8005;
    #endif

    //
    // CRC algorithm
    //

    // Loop through all bytes in the dataBytes[] array
    for (byteIndex = 0; byteIndex < numberBytes; byteIndex++)
    {
        // Point to MSb in byte
        bitIndex = 0x80u;

        // Loop through all bits in the current byte
        while (bitIndex > 0)
        {
            // Check MSB's of data and crc
            dataMSb = (bool) (dataBytes[byteIndex] & bitIndex);
            crcMSb  = (bool) (crc & 0x8000u);

            crc <<= 1;              /* Left shift CRC register */

            // Check if XOR operation of MSBs results in additional XOR operations
            if (dataMSb ^ crcMSb)
                crc ^= poly;        /* XOR crc with polynomial */

            /* Shift MSb pointer to the next data bit */
            bitIndex >>= 1;
        }
    }
    return crc;
}
#endif  // SOFT_CRC

    // Functions operating with the hardware, begin with hw_!

    // send reset or sync command on the sync line to the ADCs
    // - when wait_rdy not 0 wait until the sync line is inactive, return code is 0 for ok and 1 for timeout
int C_ads131m04::hw_sm_cmd(uint8_t bit_code, uint32_t wait_rdy, uint8_t chip_mask )
{
    uint32_t w;
    w = bit_code;
    chip_mask &= CHIP_MASK_FULL;
    last_chip_mask = chip_mask;

    if (chip_mask != 0)
    {
        w |= 1L << BIT_CMD_WMASK_ENA;
        w |= (uint32_t) chip_mask << BIT_CMD_WMASK;
    }
    // start a reset over the sync_n line
    m_uart32->WriteAuto(OFFS_CMD_SM+base_addr, w);
    // if not required to wait until read -> exit
    if (wait_rdy == 0) return 0;
    // check if the sync_n line is inactive
    return hw_wt_spi_rdy(wait_rdy);
}

int C_ads131m04::hw_wt_spi_rdy(uint32_t flag_mask, uint16_t timeout)
{
    uint32_t sta;
    if (flag_mask==0) flag_mask = (1 << BIT_STA_BUSY) | (1 << BIT_STA_SYNC) ;
    // check if the spi state machine is idle
    do
    {
       sta = m_uart32->ReadDWord(OFFS_STA_SM+base_addr);
       timeout--;
    } while ( (sta & flag_mask) && (timeout > 0) );
    sta = m_uart32->ReadDWord(OFFS_CRC_WR+base_addr);
//  if ( ( (sta >> BIT_STA_CRC_0_INP) & last_chip_mask) != last_chip_mask )
//      logWrite("# CRC is 0 on the SPI return data from these ADC chips: 0x%1x\n", (sta >> BIT_STA_CRC_0_INP) & CHIP_MASK_FULL);
    // when timeout, return an error code
    if (timeout == 0) return 1;
    // no timeout, return 0
    return 0;
}

int C_ads131m04::hw_adc_reset(uint8_t wait_rdy, uint8_t chip_mask)
{
    chip_mask &= CHIP_MASK_FULL;
    if (chip_mask == 0) chip_mask = last_chip_mask;
    last_chip_mask = chip_mask;

    uint32_t w=0;

    if (wait_rdy)                  // wait until the sync line is inactive and one DRDY_n rising edge happend on all ADC chips
    {
        w = chip_mask;             // mask with all chips
        w <<= BIT_STA_DRDY_RE_N;   // here we get 1 for each chip when no rising edge came after sync/reset
        w |= 1 << BIT_STA_SYNC;    // this bit is 1 when sync/reset line is active (=0)
    }
    //               command to send,  wait condition, chip mask
    return hw_sm_cmd(1 << BIT_RESET_SYNC, wait_rdy, chip_mask);
}

int C_ads131m04::hw_adc_sync(uint8_t wait_rdy, uint8_t chip_mask)
{
    uint32_t w=0;

    chip_mask &= CHIP_MASK_FULL;
    if (chip_mask == 0) chip_mask = last_chip_mask;
    last_chip_mask = chip_mask;

    if (wait_rdy)                  // wait until the sync line is inactive and one DRDY_n rising edge happend on all ADC chips
    {
        w = chip_mask;             // mask with all chips
        w <<= BIT_STA_DRDY_RE_N;   // here we get 1 for each chip when no rising edge came after sync/reset
        w |= 1 << BIT_STA_SYNC;    // this bit is 1 when sync/reset line is active (=0)
    }
    return hw_sm_cmd(1 << BIT_SYNC, w, chip_mask);
}

// reset the SPI master
int C_ads131m04::hw_spi_reset()
{
    return hw_sm_cmd(1 << BIT_RESET, 0);
}

int C_ads131m04::hw_spi_clr_new_sample()
{
    return hw_sm_cmd(1 << BIT_CLR_NEW_SAMPLE, 0);
}

// set or clear the auto read flag in the SPI master
// - when 1 - read automatically the new samples by sending the NULL command when DRDY_n goes low,
//            ! configuration not possible in this mode !
// - when 0 - single SPI transactions mode
int C_ads131m04::hw_auto_read(int auto_read, int auto_crc, int sync, int data16, int clr_new, uint8_t chip_mask)
{
    uint32_t w;
    auto_read &= 1;
    auto_crc &= 1;
    sync &= 1;
    data16 &= 1;
    clr_new &= 1;
    w = (auto_read << BIT_AUTO_RD) | (auto_crc << BIT_AUTO_CRC) |(sync << BIT_SYNC) | (data16 << BIT_DATA16) | (clr_new << BIT_CLR_NEW_SAMPLE);
    chip_mask &= CHIP_MASK_FULL;
    if (chip_mask != 0)
    {
        w |= 1L << BIT_CMD_WMASK_ENA;
        w |= (uint32_t) chip_mask << BIT_CMD_WMASK;
    }
    else
        logWrite("# ADC chip mask set to 0 !\n");
    return m_uart32->WriteDWord(OFFS_AUTO_READ+base_addr, w);
}


  // set the mask for the active ADC chips for subsequent SPI transactions and
  // select one of the drdy_n pin for debugging
int C_ads131m04::hw_chip_mask(uint8_t spi_mask, uint8_t drdy_sel)
{
    uint8_t rd;
    spi_mask &= CHIP_MASK_FULL;
    if (drdy_sel >= NCHIPS_ADC) drdy_sel = 0; // 0..NCHIPS_ADC-1
    m_uart32->WriteByte(OFFS_ADC_MSK+base_addr, (spi_mask << BIT_MASK) | (drdy_sel << BIT_SEL) );
    rd = m_uart32->ReadByte(OFFS_ADC_MSK+base_addr);
    logWrite("# SPI MASK set/read %d/%d, DRDY select %d/%d\n", spi_mask, (rd >> BIT_MASK) & CHIP_MASK_FULL, drdy_sel, (rd >> BIT_SEL) & 3);
    return 0;
}
    // another possibility to set the mask, without changing the chip selected for DRDY_n debugging
int C_ads131m04::hw_chip_mask(uint8_t spi_mask)
{
    uint32_t w;

    spi_mask &= CHIP_MASK_FULL;
    last_chip_mask = spi_mask;
    w = ADS131_NULL;                // some command, it doesn't matter actually, as it will be not executed at the end
    w |= 1L << BIT_CMD_WMASK_ENA;   // this bit tells, that the mask will be set
    w |= (uint32_t) spi_mask << BIT_CMD_WMASK; // and here is the new mask

    // don't start the SPI null transaction, just set the chip mask
    m_uart32->WriteDWord( OFFS_CMD_WR+base_addr, w);
    return 0;
}


int C_ads131m04::hw_send_cmd(uint16_t cmd, uint8_t chip_mask)
{
    uint32_t wdat;
    wdat = cmd;
    chip_mask &= CHIP_MASK_FULL;
    last_chip_mask = chip_mask;
    if (chip_mask != 0)
    {
        wdat |= 1L << BIT_CMD_WMASK_ENA;
        wdat |= (uint32_t) chip_mask << BIT_CMD_WMASK;
    }
    wdat |= (1L << (16 + BIT_START) );
    if (DEBUG_WR_REG)
        logWrite( "# Sending command 0x%04x\n", cmd);
    hw_wt_spi_rdy(1 << BIT_STA_BUSY);
    return m_uart32->WriteDWord(OFFS_CMD_WR+base_addr, wdat);
}

    // write to a single register in the ADC chip(s), return code is 0 for ok and 1 for timeout
int C_ads131m04::hw_wr_reg(uint16_t reg_addr, uint16_t reg_data, uint8_t chip_mask)
{
   #ifdef SOFT_CRC
    uint32_t wdat[3];
    uint16_t wreg[2];
   #else
    uint32_t wdat[2];
   #endif

    reg_addr &= 0x3F;   // reg address is 6-bit
    wdat[0] = ADS131_WREG | (reg_addr << 7);
   #ifdef SOFT_CRC
    wreg[0] = wdat[0];
   #endif
    chip_mask &= CHIP_MASK_FULL;
    last_chip_mask = chip_mask;
    if (chip_mask != 0)
    {
        wdat[0] |= 1L << BIT_CMD_WMASK_ENA;
        wdat[0] |= (uint32_t) chip_mask << BIT_CMD_WMASK;
    }


   #ifdef SOFT_CRC
    wreg[1] = reg_data;
    wdat[1] = reg_data;
    wdat[2] = calculateCRC(wreg, 2, 0xFFFF) | (1L << (16 + BIT_START) );
   #else
    wdat[1] = reg_data | (1L << (16 + BIT_START) );
    #endif

    if (DEBUG_WR_REG)
       #ifdef SOFT_CRC
        logWrite( "# Write register addr 0x%02x data 0x%04x to chips 0x%1x, wdat0=0x%06x, wdat1=0x%06x crc=0x%04x\n",
                                        reg_addr, reg_data,       chip_mask, wdat[0],      wdat[1],    wdat[2] & 0xFFFF);
       #else
        logWrite( "# Write register addr 0x%02x data 0x%04x to chips 0x%1x, wdat0=0x%06x, wdat1=0x%06x\n", reg_addr, reg_data, chip_mask, wdat[0], wdat[1]);
       #endif
    // 2 words, ainc=1, full=1, start_addr, pointer to data
    hw_wt_spi_rdy(1 << BIT_STA_BUSY);
   #ifdef SOFT_CRC
    return m_uart32->SendBurst(3, 1, 1, OFFS_CMD_WR+base_addr, wdat );
   #else
    return m_uart32->SendBurst(2, 1, 1, OFFS_CMD_WR+base_addr, wdat );
   #endif
}

    // read from a single register in the ADC chip(s), return code is 0 for ok and 1 for timeout
    // the result is in an array reg_data with NCHIPS_ADC words.
    // The result comes always after the second I/O access to the chip,
    //  if dual_start = 1, two read transactions will be done and the results reg_data are from the second read.
    //  if dual_start =2, 3 the dual start is done and as long as the result is the status of the chip (instead
    //  of the expected register content), the reading will be repeatet up to 10 times
int C_ads131m04::hw_rd_reg(uint16_t reg_addr, uint16_t* reg_data, uint8_t chip_mask, int dual_start)
{
    uint32_t w[3], reg_buff[NCHIPS_ADC];
    int chip, repeat, repet, safe_mode;

    safe_mode = (dual_start >> 1) & 1;
    dual_start &= 1;
    dual_start |= safe_mode;    // in safe mode dual start is ON
    reg_addr &= 0x3F;           // reg address is 6-bit
    chip_mask &= CHIP_MASK_FULL;
    last_chip_mask = chip_mask;

   #ifdef SOFT_CRC
    uint16_t w16;
    w16 = ADS131_RREG | (reg_addr << 7);
    w[0] = w16;
   #else
    w[0] = ADS131_RREG | (reg_addr << 7) | (1L << (16 + BIT_START) );
   #endif

    if (chip_mask != 0) // set the mask if different from 0
    {
        w[0] |= 1L << BIT_CMD_WMASK_ENA;
        w[0] |= (uint32_t) chip_mask << BIT_CMD_WMASK;
    }
   #ifdef SOFT_CRC
    w[1] = 0;
    w[2] = calculateCRC(&w16, 1, 0xFFFF) | (1L << (16 + BIT_START) );
   #endif

    if (DEBUG_RD_REG)
       #ifdef SOFT_CRC
        logWrite( "# Read register addr 0x%02x chip mask 0x%1x, wdat0=0x%06x, crc=0x%04x\n", reg_addr, chip_mask, w[0], w[2] & 0xFFFF);
       #else
        logWrite( "# Read register addr 0x%02x chip mask 0x%1x, wdat0=0x%06x\n", reg_addr, chip_mask, w[0]);
       #endif

    repet=10; // max repetitions, when the return value is the status
    repeat=0; // repeat flag is 0 at the beginning
    do
    {
        // start the SPI read transaction
       #ifdef SOFT_CRC
        m_uart32->SendBurst(3, 1, 1, OFFS_CMD_WR+base_addr, w );
       #else
        m_uart32->SendBurst(1, 1, 1, OFFS_CMD_WR+base_addr, w );
       #endif
        // wait until the SPI master is not more busy
        hw_wt_spi_rdy(1 << BIT_STA_BUSY);
        // in dual start mode, trigger a second SPI read with the same parameters, don't read the responce
        if ((dual_start) && (repeat==0))
        {
            // start the SPI read transaction
           #ifdef SOFT_CRC
            m_uart32->SendBurst(3, 1, 1, OFFS_CMD_WR+base_addr, w );
           #else
            m_uart32->SendBurst(1, 1, 1, OFFS_CMD_WR+base_addr, w );
           #endif
            // wait until the SPI master is not more busy
            hw_wt_spi_rdy(1 << BIT_STA_BUSY);
        }
        // get the responce from the last SPI read
        m_uart32->RecvBurst(NCHIPS_ADC, 1, 1, OFFS_RD_RESP+base_addr, reg_buff );
        repeat=0; // clear the repeat flag
        for (chip=0; chip<NCHIPS_ADC; chip++)
        {   // copy the responce (bits 23..8) to the output result (16-bit/ADC channel)
            reg_data[chip]=reg_buff[chip] >> 8;
            // when the result corresponds to the status, set the repeat flag
            if ( ( (reg_data[chip]==0x050f) || (reg_data[chip]==0x0500)) && (reg_addr != STATUS_ADDRESS)) repeat=1;
        }
        repet--; // decrement the repetition counter
    } while ( (safe_mode) && (repet > 0) && (repeat) ); // exit the loop when not in safe mode, too many repetitions or no need to repeat again
    return 0;
}

int C_ads131m04::hw_rd_reg_single(uint16_t reg_addr, uint16_t* reg_data, uint8_t chip_mask)
{
    uint32_t w, reg_buff[NCHIPS_ADC];
    int chip;

    reg_addr &= 0x3F;           // reg address is 6-bit
    chip_mask &= CHIP_MASK_FULL;
    last_chip_mask = chip_mask;
    w = ADS131_RREG | (1L << (16 + BIT_START) ) | (reg_addr << 7);
    if (chip_mask != 0)         // set the mask if different from 0
    {
        w |= 1L << BIT_CMD_WMASK_ENA;
        w |= (uint32_t) chip_mask << BIT_CMD_WMASK;
    }

    // start the SPI read transaction
    m_uart32->WriteDWord( OFFS_CMD_WR+base_addr, w);
    // wait until the SPI master is not more busy
    hw_wt_spi_rdy(1 << BIT_STA_BUSY);
    // get the responce from the last SPI read
    m_uart32->RecvBurst(NCHIPS_ADC, 1, 1, OFFS_RD_RESP+base_addr, reg_buff );
    for (chip=0; chip<NCHIPS_ADC; chip++)
        // copy the responce (bits 23..8) to the output result (16-bit/ADC channel)
        reg_data[chip]=reg_buff[chip] >> 8;
    return 0;
}

    // read the ADC data, 4*NCHIPS_ADC signed 24-bit words (sign extended in hardware to 32 bit)
    // return code is 0 for ok and 1 for timeout
int C_ads131m04::hw_rd_adc(int32_t* adc_data)
{
    uint32_t *pu32;
    // convert the pointer to signed 32-bit integer to a pointer
    pu32 = (uint32_t*) adc_data;
    hw_wt_spi_rdy(1 << BIT_STA_NO_NEW_SAMPLE);
    m_uart32->WriteByte( OFFS_RD_ADC+base_addr, 1 ); // clear the new flag
    return m_uart32->RecvBurst(4*NCHIPS_ADC, 1, 1, OFFS_RD_ADC+base_addr, pu32 );
}

int C_ads131m04::hw_update_all_regs()
{
    return hw_wr_all_regs(REG_CHANGED);
}

uint64_t C_ads131m04::hw_get_freq_per(uint8_t chip, uint8_t ldebug)
{
    uint32_t met[2];
    if (chip < NCHIPS_ADC)
        m_uart32->WriteByte(OFFS_P_METER+base_addr, chip << BIT_SEL );

    hw_wt_spi_rdy((1L << BIT_STA_PMET_BUSY) | (1L << BIT_STA_FMET_BUSY), 10000);

    m_uart32->RecvBurst(2, 1, 1, OFFS_P_METER+base_addr, met );
    if (ldebug)
        logWrite( "# Read period %d, frequency %d\n", met[0], met[1]);
    return met[0] | ((uint64_t) met[1] << 32);
}

uint32_t C_ads131m04::hw_get_per(uint8_t chip, uint8_t ldebug)
{
    uint32_t met;
    if (chip < NCHIPS_ADC)
        m_uart32->WriteByte(OFFS_P_METER+base_addr, chip << BIT_SEL );

    hw_wt_spi_rdy((1L << BIT_STA_PMET_BUSY), 100);

    met=m_uart32->ReadDWord(OFFS_P_METER+base_addr);
    if (ldebug)
        logWrite( "# Read period %d\n", met);
    return met;
}

int C_ads131m04::hw_rd_all_regs(uint8_t chip_mask, uint8_t safe_mode)
{
    uint16_t reg_buff[NCHIPS_ADC];
    int chip, rg;

    chip_mask &= CHIP_MASK_FULL;
    if (chip_mask==0) return 1;

    for (rg=0; rg<ADS131M04_NUM_REGS; rg++)
    {
        if ( (rg==0) && (safe_mode==0) ) // make the first read, the result will be discarded!
            hw_rd_reg(all_ad_regs[rg].reg_addr, reg_buff, chip_mask, 0);
        // request read from the next register, get the result of the previous read!
        if (safe_mode)
            hw_rd_reg(all_ad_regs[rg].reg_addr, reg_buff, chip_mask, 3);
        else
            hw_rd_reg(all_ad_regs[rg+1].reg_addr, reg_buff, chip_mask, 0);
        for (chip=0; chip<NCHIPS_ADC; chip++)
            if ( (chip_mask >> chip) & 1)
                reg_data_rd[chip][rg] = reg_buff[chip];
    }
    return 0;
}

int C_ads131m04::hw_wr_all_regs(uint8_t reg_status, uint8_t chip_mask)
{
    int chip, rg, broadcast, chip_ref, write_msk, write_cnt, check_resp[NCHIPS_ADC];
    uint32_t reg_buff[NCHIPS_ADC];
    uint16_t reg_resp[NCHIPS_ADC], exp_resp[NCHIPS_ADC];

    chip_mask &= CHIP_MASK_FULL;
    if (chip_mask==0) return 1;

    // don't check the responce to the frist frame!
    for (chip=0; chip<NCHIPS_ADC; chip++)
        check_resp[chip]=0;

    for (rg=0; rg<ADS131M04_NUM_REGS; rg++)
        if (all_ad_regs[rg].flags==FLAG_READ_WRITE)
        {
            write_msk=0;
            write_cnt=0;
            chip_ref=-1;
            for (chip=0; chip<NCHIPS_ADC; chip++)
                // reg_status is normally REG_CHANGED (write only to the changed registers) or REG_ANY (write to all independent on the status)
                if ( (reg_flag[chip][rg] & reg_status) && ( (chip_mask >> chip) & 1) )
                {
                    write_msk |= (1 << chip);
                    write_cnt++;
                    if (chip_ref < 0) chip_ref=chip;
                    reg_flag[chip][rg] = REG_UPDATED;
                }
            if (write_cnt==0) continue; // exit the loop, nothing to do for this register
            // now write_msk contains the chips, which should be modified, chip_ref is the first of them
            broadcast=1;
            if (write_cnt > 1)
                for (chip=0; chip<NCHIPS_ADC; chip++)
                    // check if all register data are identical, so that broadcast write can be used
                    if ( (reg_data[chip_ref][rg] != reg_data[chip][rg]) && ((write_msk >> chip) & 1) )
                    {
                        broadcast=0;
                        break;
                    }
            // when broadcast=1, we can write to all chips in chip_mask the same register content
            if (broadcast)
            {
                if (DEBUG_WR_REG)
                    logWrite( "# Broadcast wr mask 0x%x addr 0x%02x data 0x%04x\n", write_msk, all_ad_regs[rg].reg_addr, reg_data[chip_ref][rg]);
                hw_wr_reg(all_ad_regs[rg].reg_addr, reg_data[chip_ref][rg], write_msk);

                // read the responce data, corresponding to the previous frame!
                m_uart32->RecvBurst(NCHIPS_ADC, 1, 1, OFFS_RD_RESP+base_addr, reg_buff );
                for (chip=0; chip<NCHIPS_ADC; chip++)
                    if ((write_msk >> chip) & 1)
                        reg_resp[chip] =reg_buff[chip] >> 8;
            }
            else
            // when broadcast=0, we will write individually to each chip in chip_mask the unique register content, even if two chips have the same content
            for (chip=0; chip<NCHIPS_ADC; chip++)
                if ( (write_msk >> chip) & 1)
                {
                    if (DEBUG_WR_REG)
                        logWrite( "# Single chip %d wr, addr 0x%02x data 0x%04x\n", chip, all_ad_regs[rg].reg_addr, reg_data[chip][rg]);
                    hw_wr_reg(all_ad_regs[rg].reg_addr, reg_data[chip][rg], 1 << chip);
                    // read the responce data, corresponding to the previous frame!
                    reg_resp[chip] =m_uart32->ReadDWord(OFFS_RD_RESP+base_addr+chip) >> 8;
                    }

                }
            for (chip=0; chip<NCHIPS_ADC; chip++)
                if ( (write_msk >> chip) & 1)
                {
                    // compare the expected reponce data corresponding to the previous frame to the actuals, only if the respoce data are valid (not the first frame)
                    if ( (exp_resp[chip] != reg_resp[chip]) && (check_resp[chip]) )
                        logWrite( "# The SPI responce 0x%04x (reg 0x%02x) different from the expected one 0x%04x\n", reg_resp[chip], (reg_resp[chip] >> 7) & 0x3F, exp_resp[chip]);
                    exp_resp[chip]=ADS131_WRESP | (all_ad_regs[rg].reg_addr << 7);
                    check_resp[chip]=1; // check the responce to the next frame
                }
    return 0;
}

