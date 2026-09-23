// $Id: C_ads131m04.h 1221 2026-09-15 15:50:25Z  $:

#ifndef ADS131M04_H
#define ADS131M04_H

#include <stdio.h>   /* Standard input/output definitions, for perror() */
#include <stdint.h>
#include <stdlib.h>
#include <string.h>  /* String function definitions */
//#include <unistd.h>  /* UNIX standard function definitions, for close() */
//#include <fcntl.h>   /* File control definitions, for open() */
//#include <signal.h>  /* ANSI C signal handling */
//#include <memory>
//#include <sys/time.h>
#include "../upstream/CLogger.h"

#define NCHIPS_ADC     2

#define N_ADC_CHANNELS           8
#define N_ADC_CHANNELS_ALL       8
#define CHIP_MASK_FULL  ( (1 << NCHIPS_ADC)-1 ) // max 4 bits

#define ADC_MAX_CODE  ((1L << 23)-1)
#define ADC_MIN_CODE  (-(1L << 23) )

// ADC Chip commands
#define ADS131_NULL            0x0000   // responce with STATUS, CRC, ADC0..3
#define ADS131_RESET           0x0011   // reset
#define ADS131_RESET_RESP      0xFF24   // responce
#define ADS131_STANDBY         0x0022   // standby
#define ADS131_WAKEUP          0x0033
#define ADS131_LOCK            0x0555
#define ADS131_UNLOCK          0x0655
#define ADS131_RREG            0xA000   // in bits 12..7 is the reg address
#define ADS131_WREG            0x6000   // in bits 12..7 is the reg address
#define ADS131_WRESP           0x4000   // in bits 12..7 is the reg address

// ADC Chip internar register addresses
#define ID_ADDRESS              0x00
#define STATUS_ADDRESS          0x01
#define MODE_ADDRESS            0x02
    #define CRC_TYPE_CCITT  0    // default
    #define CRC_TYPE_ANSI   1
#define CLOCK_ADDRESS           0x03
#define GAIN1_ADDRESS           0x04
#define RESERVED_ADDRESS        0x05
#define CFG_ADDRESS             0x06
#define THRSHLD_MSB_ADDRESS     0x07
#define THRSHLD_LSB_ADDRESS     0x08
#define CH0_CFG_ADDRESS         0x09
#define CH0_OCAL_MSB_ADDRESS    0x0A
#define CH0_OCAL_LSB_ADDRESS    0x0B
#define CH0_GCAL_MSB_ADDRESS    0x0C
#define CH0_GCAL_LSB_ADDRESS    0x0D
#define CH1_CFG_ADDRESS         0x0E
#define CH1_OCAL_MSB_ADDRESS    0x0F
#define CH1_OCAL_LSB_ADDRESS    0x10
#define CH1_GCAL_MSB_ADDRESS    0x11
#define CH1_GCAL_LSB_ADDRESS    0x12
#define CH2_CFG_ADDRESS         0x13
#define CH2_OCAL_MSB_ADDRESS    0x14
#define CH2_OCAL_LSB_ADDRESS    0x15
#define CH2_GCAL_MSB_ADDRESS    0x16
#define CH2_GCAL_LSB_ADDRESS    0x17
#define CH3_CFG_ADDRESS         0x18
#define CH3_OCAL_MSB_ADDRESS    0x19
#define CH3_OCAL_LSB_ADDRESS    0x1A
#define CH3_GCAL_MSB_ADDRESS    0x1B
#define CH3_GCAL_LSB_ADDRESS    0x1C
// here is a gap of unused addresses in this chip!
#define REGMAP_CRC_ADDRESS      0x3E

// ADC Chip internal register power up values
#define ID_DEFAULT              0x2400    // note the lower 8 bits are not defined!
#define STATUS_DEFAULT          0x0500
#define MODE_DEFAULT            0x0510
#define CLOCK_DEFAULT           0x0F0E
#define GAIN1_DEFAULT           0x0000
#define RESERVED_DEFAULT        0x0000
#define CFG_DEFAULT             0x0600
#define THRSHLD_MSB_DEFAULT     0x0000
#define THRSHLD_LSB_DEFAULT     0x0000
// 4x the same default values
#define CHx_CFG_DEFAULT         0x0000
#define CHx_OCAL_MSB_DEFAULT    0x0000
#define CHx_OCAL_LSB_DEFAULT    0x0000
#define CHx_GCAL_MSB_DEFAULT    0x8000
#define CHx_GCAL_LSB_DEFAULT    0x0000
//
#define REGMAP_CRC_DEFAULT      0x0000

#define ADS_INP_MUX_NORM        0
#define ADS_INP_MUX_SHORT       1
#define ADS_INP_MUX_POS_T       2
#define ADS_INP_MUX_NEG_T       3

#define ADS_PGA_1               0
#define ADS_PGA_2               1
#define ADS_PGA_4               2
#define ADS_PGA_8               3
#define ADS_PGA_16              4
#define ADS_PGA_32              5
#define ADS_PGA_64              6
#define ADS_PGA_128             7

#define ADS_PWR_VER_LOW         0
#define ADS_PWR_LOW             1
#define ADS_PWR_HIGH_RES        2

#define ADS_DC_BLOCK_FILT_DIS   0
#define ADS_DC_BLOCK_FILT_FAST  1     // fastest setting, about 200Hz at 4 kS/s in high resolution mode
#define ADS_DC_BLOCK_FILT_SLOW 15     // slowest setting, about 10 mHz at 4 kS/s in high resolution mode

// in high resolution mode they correspond to sampling rates from 64 kS/s downto 250 S/s
// in low power mode they correspond to sampling rates from 32 kS/s downto 125 S/s
// in very low power mode they correspond to sampling rates from 16 kS/s downto 62.5 S/s
//                                  in high resolution mode, the rate
#define ADS_OSR__64             0x08   // 64k
#define ADS_OSR_128             0x00   // 32k
#define ADS_OSR_256             0x01   // 16k
#define ADS_OSR_512             0x02   //  8k
#define ADS_OSR_1024            0x03   //  4k (DEFAULT)
#define ADS_OSR_2048            0x04   //  2k
#define ADS_OSR_4096            0x05   //  1k
#define ADS_OSR_8192            0x06   // 500
#define ADS_OSR_16384           0x07   // 250

//                                  in high resolution mode only, the OSR
#define ADS_SRATE_64K           0x08   //  64
#define ADS_SRATE_32K           0x00   // 128
#define ADS_SRATE_16K           0x01   // 256
#define ADS_SRATE_8K            0x02   // 512
#define ADS_SRATE_4K            0x03   // 1024 (DEFAULT)
#define ADS_SRATE_2K            0x04   // 2048
#define ADS_SRATE_1K            0x05   // 4096
#define ADS_SRATE_500           0x06   // 8192
#define ADS_SRATE_250           0x07   // 16384

#define ADS_MIN_SAMPL_RATE       250   // Samples/S  -  possible with 8.192 MHz MCLK rate in high-power mode
#define ADS_MAX_SAMPL_RATE     32000   // Samples/S  /
//#define ADS_MAX_SAMPL_RATE     64000   // Samples/S  /

// Structure to build a table with all registers - addresses, names, default values, recommended values, mask with writable bits, flags
typedef struct
{
    const uint8_t reg_addr;         // SPI address
    const char *  reg_name;         // short name, without spaces
    const uint16_t init_value;      // value after power up or reset, can be unknown
    const uint16_t used_bits_msk;   // mask with writable bits, the rest are constants/read-only
    const uint8_t flags;            // see the definitions below
} ad_config_reg_type;

// possible value in the fields init_value or conf_value
//#define UNKNOWN_VALUE   0xFFFFFFFF

// possible flags in the field flags, can be OR-ed together
// 1 flags with correspondence to the real ADC chip
#define FLAG_READ_WRITE              0   //
#define FLAG_READ_ONLY               1   // all bits are read-only
// 2 flags concerning our configuration
#define FLAG_DONT_CHANGE             2   // better not to change this register
#define FLAG_DONT_CARE               4   // not important for our configuration, can be used for some SPI test

#define ADS131M04_NUM_REGS          30

// when writing: (new_value & used_bits_msk)

// Note: for all registers except for the last one the address is equal to the position in this table!!!
const ad_config_reg_type all_ad_regs[ADS131M04_NUM_REGS] = {
// Addr                   Name             Reset value       writable bits    Access flags                                                                                                                                 Conf Value
{ ID_ADDRESS           ,  "ID"            , ID_DEFAULT            , 0x0000, FLAG_READ_ONLY },  // the lower 8 bits are not defined!                                                                                              ID_DEFAULT ,
{ STATUS_ADDRESS       ,  "STATUS"        , STATUS_DEFAULT        , 0x0000, FLAG_READ_ONLY },  // response to the NULL command                                                                                                   STATUS_DEFAULT ,
{ MODE_ADDRESS         ,  "MODE"          , MODE_DEFAULT          , 0x3F1F, FLAG_READ_WRITE},  //                                                                                                                                0x0114 ,
{ CLOCK_ADDRESS        ,  "CLOCK"         , CLOCK_DEFAULT         , 0x0FFF, FLAG_READ_WRITE},  // for 4 kS, high-resolution, all channels enabled                                                                                0x0F0E ,
{ GAIN1_ADDRESS        ,  "GAIN1"         , GAIN1_DEFAULT         , 0x7777, FLAG_READ_WRITE},  // Gain 0..7 is 1..128 set in the 4 nibbles                                                                                       0x0000 ,
{ RESERVED_ADDRESS     ,  "RESERVED"      , RESERVED_DEFAULT      , 0x0000, FLAG_DONT_CHANGE}, //                                                                                                                                RESERVED_DEFAULT ,
{ CFG_ADDRESS          ,  "CFG"           , CFG_DEFAULT           , 0x1FFF, FLAG_READ_WRITE }, // chopper, current detection mode - not needed, off                                                                              CFG_DEFAULT ,
                                                                                               //
{ THRSHLD_MSB_ADDRESS  ,  "THRSHLD_MSB"   , THRSHLD_MSB_DEFAULT   , 0xFFFF, FLAG_DONT_CARE},   // this register can be used for I/O tests, full 16-bit don't care for our application!                                           THRSHLD_MSB_DEFAULT,
{ THRSHLD_LSB_ADDRESS  ,  "THRSHLD_LSB"   , THRSHLD_LSB_DEFAULT   , 0xFF0F, FLAG_READ_WRITE},  // important - the lower 4 bits must be 0, otherwise high-pass filter (no DC component)!                                          THRSHLD_LSB_DEFAULT,
                                                                                               //
{ CH0_CFG_ADDRESS      ,  "CH0_CFG"       , CHx_CFG_DEFAULT       , 0xFFC7, FLAG_READ_WRITE},  // bit 2 is DC block disable - must be 1, 15..6 is phase, better to be 0, bits 1..0: 0 normal, 1 short, 2 +test, 3 -test          0x0004 ,
{ CH0_OCAL_MSB_ADDRESS ,  "CH0_OCAL_MSB"  , CHx_OCAL_MSB_DEFAULT  , 0xFFFF, FLAG_READ_WRITE},  // offset calibration 23..8                                                                                                       CHx_OCAL_MSB_DEFAULT,
{ CH0_OCAL_LSB_ADDRESS ,  "CH0_OCAL_LSB"  , CHx_OCAL_LSB_DEFAULT  , 0xFF00, FLAG_READ_WRITE},  // offset calibration  7..0                                                                                                       CHx_OCAL_LSB_DEFAULT,
{ CH0_GCAL_MSB_ADDRESS ,  "CH0_GCAL_MSB"  , CHx_GCAL_MSB_DEFAULT  , 0xFFFF, FLAG_READ_WRITE},  // gain calibration 23..8                                                                                                         CHx_GCAL_MSB_DEFAULT,
{ CH0_GCAL_LSB_ADDRESS ,  "CH0_GCAL_LSB"  , CHx_GCAL_LSB_DEFAULT  , 0xFF00, FLAG_READ_WRITE},  // gain calibration  7..0                                                                                                         CHx_GCAL_LSB_DEFAULT,
                                                                                               //
{ CH1_CFG_ADDRESS      ,  "CH1_CFG"       , CHx_CFG_DEFAULT       , 0xFFC7, FLAG_READ_WRITE},  // bit 2 is DC block disable - must be 1, 15..6 is phase, better to be 0, bits 1..0: 0 normal, 1 short, 2 +test, 3 -test          0x0004 ,
{ CH1_OCAL_MSB_ADDRESS ,  "CH1_OCAL_MSB"  , CHx_OCAL_MSB_DEFAULT  , 0xFFFF, FLAG_READ_WRITE},  // offset calibration 23..8                                                                                                       CHx_OCAL_MSB_DEFAULT,
{ CH1_OCAL_LSB_ADDRESS ,  "CH1_OCAL_LSB"  , CHx_OCAL_LSB_DEFAULT  , 0xFF00, FLAG_READ_WRITE},  // offset calibration  7..0                                                                                                       CHx_OCAL_LSB_DEFAULT,
{ CH1_GCAL_MSB_ADDRESS ,  "CH1_GCAL_MSB"  , CHx_GCAL_MSB_DEFAULT  , 0xFFFF, FLAG_READ_WRITE},  // gain calibration 23..8                                                                                                         CHx_GCAL_MSB_DEFAULT,
{ CH1_GCAL_LSB_ADDRESS ,  "CH1_GCAL_LSB"  , CHx_GCAL_LSB_DEFAULT  , 0xFF00, FLAG_READ_WRITE},  // gain calibration  7..0                                                                                                         CHx_GCAL_LSB_DEFAULT,
                                                                                               //
{ CH2_CFG_ADDRESS      ,  "CH2_CFG"       , CHx_CFG_DEFAULT       , 0xFFC7, FLAG_READ_WRITE},  // bit 2 is DC block disable - must be 1, 15..6 is phase, better to be 0, bits 1..0: 0 normal, 1 short, 2 +test, 3 -test          0x0004 ,
{ CH2_OCAL_MSB_ADDRESS ,  "CH2_OCAL_MSB"  , CHx_OCAL_MSB_DEFAULT  , 0xFFFF, FLAG_READ_WRITE},  // offset calibration 23..8                                                                                                       CHx_OCAL_MSB_DEFAULT,
{ CH2_OCAL_LSB_ADDRESS ,  "CH2_OCAL_LSB"  , CHx_OCAL_LSB_DEFAULT  , 0xFF00, FLAG_READ_WRITE},  // offset calibration  7..0                                                                                                       CHx_OCAL_LSB_DEFAULT,
{ CH2_GCAL_MSB_ADDRESS ,  "CH2_GCAL_MSB"  , CHx_GCAL_MSB_DEFAULT  , 0xFFFF, FLAG_READ_WRITE},  // gain calibration 23..8                                                                                                         CHx_GCAL_MSB_DEFAULT,
{ CH2_GCAL_LSB_ADDRESS ,  "CH2_GCAL_LSB"  , CHx_GCAL_LSB_DEFAULT  , 0xFF00, FLAG_READ_WRITE},  // gain calibration  7..0                                                                                                         CHx_GCAL_LSB_DEFAULT,
                                                                                               //
{ CH3_CFG_ADDRESS      ,  "CH3_CFG"       , CHx_CFG_DEFAULT       , 0xFFC7, FLAG_READ_WRITE},  // bit 2 is DC block disable - must be 1, 15..6 is phase, better to be 0, bits 1..0: 0 normal, 1 short, 2 +test, 3 -test          0x0004 ,
{ CH3_OCAL_MSB_ADDRESS ,  "CH3_OCAL_MSB"  , CHx_OCAL_MSB_DEFAULT  , 0xFFFF, FLAG_READ_WRITE},  // offset calibration 23..8                                                                                                       CHx_OCAL_MSB_DEFAULT,
{ CH3_OCAL_LSB_ADDRESS ,  "CH3_OCAL_LSB"  , CHx_OCAL_LSB_DEFAULT  , 0xFF00, FLAG_READ_WRITE},  // offset calibration  7..0                                                                                                       CHx_OCAL_LSB_DEFAULT,
{ CH3_GCAL_MSB_ADDRESS ,  "CH3_GCAL_MSB"  , CHx_GCAL_MSB_DEFAULT  , 0xFFFF, FLAG_READ_WRITE},  // gain calibration 23..8                                                                                                         CHx_GCAL_MSB_DEFAULT,
{ CH3_GCAL_LSB_ADDRESS ,  "CH3_GCAL_LSB"  , CHx_GCAL_LSB_DEFAULT  , 0xFF00, FLAG_READ_WRITE},  // gain calibration  7..0                                                                                                         CHx_GCAL_LSB_DEFAULT,
// here is a gap of unused addresses in this chip!                                             //
{ REGMAP_CRC_ADDRESS   ,  "REGMAP_CRC"    , REGMAP_CRC_DEFAULT    , 0x0000, FLAG_READ_ONLY}};  //                                                                                                                                REGMAP_CRC_DEFAULT,

#define GCOR_DEFAULT      0x800000

typedef struct
{
    const uint16_t srate;
    const uint16_t  osr;
    const uint16_t  gc_dly;
} ads131_sampl_rate_sett_type;


#define ADS131_NUMBER_OF_SRATES 25
#define MAX_CHOP_SRATE_IDX      20
const ads131_sampl_rate_sett_type ads131_all_sampl_rate_sett[ADS131_NUMBER_OF_SRATES] = {
// Srate | OSR in CLOCK[4:2], TBM(osr bit 3) in bit5 | GC_Code in bits CFG[12:8]
{   50,    ADS_SRATE_250,      14*2+1 },
{   63,    ADS_SRATE_250,      13*2+1 }, // 62.5
{  100,    ADS_SRATE_500,      13*2+1 },
{  125,    ADS_SRATE_500,      12*2+1 },
{  200,    ADS_SRATE_1K,       12*2+1 },
{  250,    ADS_SRATE_1K ,      11*2+1 },
{  250,    ADS_SRATE_250,           0 },
{  400,    ADS_SRATE_2K,       11*2+1 },
{  500,    ADS_SRATE_2K,       10*2+1 },
{  500,    ADS_SRATE_500,           0 },
{  800,    ADS_SRATE_4K,       10*2+1 },
{ 1000,    ADS_SRATE_4K,        9*2+1 },
{ 1000,    ADS_SRATE_1K,            0 },
{ 1600,    ADS_SRATE_8K,        9*2+1 },
{ 2000,    ADS_SRATE_8K,        8*2+1 },
{ 2000,    ADS_SRATE_2K,            0 },
{ 3200,    ADS_SRATE_16K,       8*2+1 },
{ 4000,    ADS_SRATE_16K,       7*2+1 },
{ 4000,    ADS_SRATE_4K,            0 },
{ 6400,    ADS_SRATE_32K,       7*2+1 },
{ 8000,    ADS_SRATE_32K,       6*2+1 },
{ 8000,    ADS_SRATE_8K,            0 },
{16000,    ADS_SRATE_16K,           0 },
{32000,    ADS_SRATE_32K,           0 },
{64000,    ADS_SRATE_64K,           0 }};
// add if necessary 64kS/s combined with glob chopper mode


// 32-bit data words configuration offsets in FPGA SPI master
#define OFFS_CMD_WR             0   // always necessary - the lower 16-bits are the command (see above)
                                    // the 2 bits 16+BIT_RESET and 16+BIT_START when set have the same meaning as
                                    // in the CMD_SM register, but enable to start the SPI command immediately with
                                    // writing to this register, instead of writing to CMD_SM later.
#define BIT_CMD_WMASK          20
#define BIT_CMD_WMASK_ENA      18   // when this bit is set, the spi mask will be updated from bits BIT_CMD_WMASK+3..BIT_CMD_WMASK

#define OFFS_WREG               1   // for ADS131_WREG command only, the 2 command bits 16+BIT_RESET and 16+BIT_START
                                    // are avaliable (s. above) to start the operation when no CRC used

#define OFFS_CRC_WR             2   // normally not used, the 2 bits 16+BIT_RESET and 16+BIT_START available.

#define OFFS_AUTO_READ          3

    #define BIT_AUTO_RD         0   // bit 0, when 1 - read the new samples automatically, when 0 - don't read
                                    // in order to configure the ADCs and set when taking data

// Note, the next two command bits listed below are usable at this address, so it is possible to set the auto flag,
//       send sync_n to the ADCs and clear the new sample flag with only 1 write.
//  #define BIT_SYNC            3   // send SYNC  command to the ADCs via the SYNC_N line (short pulse)
//  #define BIT_CLR_NEW_SAMPLE  4   // write here 1 to clear the new sample flag
    #define BIT_AUTO_CRC        1   // auto handle CRC to the ADC
    #define BIT_DATA16          2   // when 1 - operate in 16-bit mode instead of 24-bit
                                    // 1) configure in 24-bit mode, as the ADC boots so
                                    // 2) verify the configuration
                                    // 3) change the WLENGTH bits in MODE register to 00
                                    // 4) turn ON auto read and switch to 16-bit mode by setting in this
                                    // register bits 0 and 2 + optionally bit 1.

#define OFFS_ADC_MSK            4   // which ADC chips are enabled, which ADC chip is selected for Period & Freq measurement
    #define BIT_MASK            0   // Mask with the enabled for the SPI ADC chips in bits 3..0, default all set
    #define BIT_SEL             4   // Select one of the up to 4 ADC chips for DRDY_n timing measurement, default 0
// writing here will set the busy xMET_BUSY flags below

#define OFFS_CMD_SM             5   // commands to the SPI master state machine
    #define BIT_RESET           0   // reset the SPI master, auto cleared
    #define BIT_START           1   // start the SPI transaction, program at least CMD_WR before, auto cleared
    #define BIT_RESET_SYNC      2   // send RESET command to the ADCs via the SYNC_N line (long pulse)
    #define BIT_SYNC            3   // send SYNC  command to the ADCs via the SYNC_N line (short pulse)
    #define BIT_CLR_NEW_SAMPLE  4   // write here 1 to clear the new sample flag

#define OFFS_STA_SM            OFFS_CMD_SM
    #define BIT_STA_BUSY           1    // 1 when the SPI master is busy
    #define BIT_STA_SYNC           2    // 1 when the sync_n line is active (low)
    #define BIT_STA_SYNC2          3    // 1 when the sync_n line is active (low) ( same as above)
    #define BIT_STA_NEW_SAMPLE     4    // new sample flag, set when new sample available, to clear see above
    #define BIT_STA_NO_NEW_SAMPLE  5    // no new sample flag, cleared when new sample available, to set see above
    #define BIT_STA_RECV_AD        6    //  7.. 5 : address to store the received data, from the SPI state machine to the IO block
    #define BIT_STA_SEND_AD        9    //  9.. 8 : address of the sent data, from the SPI state machine to the IO block
                                        // Note: both addresses should be 0 when the SPI master is inactive (not busy)
    #define BIT_STA_DRDY          12    // 15..12 : drdy inverted of all ADCs
    #define BIT_STA_DRDY_RE_N     16    // 19..16 : no rising edge on drdy_n after sync/reset
    #define BIT_STA_PMET_BUSY     20    // the period measurement is not ready, after changing ADDR_ADC_MSK
    #define BIT_STA_FMET_BUSY     21    // the frequency measurement is not ready, after changing ADDR_ADC_MSK
    #define BIT_STA_CRC_0_INP     24    // up to 4 bits, CRC on the SPI input data is 0


#define OFFS_P_METER            6 // the last period of the DRDY pulses in system ADC clocks (4*8.192 MHz), about 16 ms max => 16 bits
#define OFFS_F_METER            7 // the frequency of the DRDY pulses, 16-bit 32 kHz max
// the MSBit in both _METER is 1 when the measurement is still in progress
// writing to any of the _METER addresses will set the busy xMET_BUSY flags above


// non-ADC data from the ADCs
#define OFFS_RD_RESP            8 // responce, up to 4 dwords from up to 4 ADC chips

#define OFFS_RD_CRC            12 // returned CRC, up to 4 dwords from up to 4 ADC chips

// ADC data from the first ADC chip, N ADC chips up to 16+4*N-1
#define OFFS_RD_ADC            16 // 4 ADC data from each ADC chip, up to 4x4 dwords
// writing to any of this address will clear the new sample flag (and set the no new sample flag)

#define REG_UNKNOWN             1
#define REG_RESET               2
#define REG_CHANGED             4
#define REG_UPDATED             8
#define REG_ANY              0xFF

#define DEBUG_WR_REG            0
#define DEBUG_RD_REG            0

//#define SOFT_CRC       1             // enable creating and sending the CRC to the SPI master
#define AUTO_CRC       1               // use the hardware CRC generator, the eventually in software generated CRC will be ignored
#define USE_CRC_IN_ADS  1
#define USED_CRC_TYPE   CRC_TYPE_CCITT

class C_ads131m04 : public CLogger
{
protected:
    // buffer for the prepared configuration
    uint16_t reg_data[NCHIPS_ADC][ADS131M04_NUM_REGS];
    // flags for the registers, see above REG_xxx
    uint8_t  reg_flag[NCHIPS_ADC][ADS131M04_NUM_REGS];
    // pointer to the UART interface
    uart32* m_uart32;
    // base address of the SPI master in the FPGA design
    uint32_t base_addr;
    uint32_t last_chip_mask;
    // buffer for the read register
    uint16_t reg_data_rd[NCHIPS_ADC][ADS131M04_NUM_REGS];

    int32_t offs_cal[N_ADC_CHANNELS_ALL];

public:
    // set the pointer to the UART device, the base address in FPGA design, init is still not used
    C_ads131m04(uart32* p_uart32, uint32_t new_base_addr, uint8_t init=0);
    ~C_ads131m04();

    // copy a bit slice from src[pos_high-pos_low..0] to dst[pos_high..pos_low]
    uint16_t cp_bit_slice(uint16_t src, uint16_t dst, uint8_t pos_high, uint8_t pos_low);
    // converts the PCB channel nr. to internal channel of the ADC chip
    int channel2chip_ch(int pcb_ch);
    // returns the ADC chip (0..2) from the channel nr.
    int channel2chip(int pcb_ch);
    int print_offs_cal();

    // Functions operating only on the array in this class, no hardware access!!! All they begin with set_, load_ and print_
    // load the registers with the power up values
    int load_reset();
//    int load_recomm();

    // Functions on complete ADC chips
    // set the sampling rate in the selected ADC chips, the osr_code is from 0 to 7 for OSR=128, 256, ... 8192, 16384
    int set_osr(uint8_t chip_mask, uint8_t osr_code);
    // set the gc settings
    int set_gc(uint8_t chip_mask, uint8_t gc_code);
    // set the power mode, 0..2(3) for very-low, low, high-resolution
    int set_pwr(uint8_t chip_mask, uint8_t pwr_code);

    int set_rx_crc(uint8_t rx_crc, uint8_t crc_type);
    // Functions on single ADC channels
    // 4 channels/chip
    int set_adc_ena(uint16_t adc_mask);
    // set in the selected ADC channels the gain in PGA: 1, 2, 4, 8, ... 128
    // this function can be called many times (with different adc_mask)
    int set_pga(uint16_t adc_mask, uint8_t gain_code);
    // set in individual channel the offset and the gain correction
    int set_offs_cal(uint8_t adc_ch, uint32_t offs);
    int set_gain_cal(uint8_t adc_ch, uint32_t gain);
    // 0 - normal operation, 1 - shorted, 2 - +test, 3 - -test
    //     the possible values are defined above as ADS_INP_MUX_ NORM/SHORT/POS_T/NEG_T
    //     Note: the precision of the test voltages is not good, in the order of 0.5% of the full range!
    int set_inp_mux(uint16_t adc_mask, uint8_t mux_code);
    // 0 - DC and AC, 1 - AC only
    int set_dc_block_ch(uint16_t adc_mask, uint8_t dc_block);
    // filter settings 0..15, defined above as ADS_DC_BLOCK_FILT_, 0 is for disable
    int set_dc_block_flt(uint8_t chip_mask, uint8_t dc_block_filter);
    // convert the OSR setting 0..7 to sampling rate in case of high-resolution power mode
    int osr_to_sampling_rate(uint8_t osr_setting, uint8_t gc_setting = 0);
    // convert the desired sampling rate in S/s the next (lower) possible rate
    // OSR code in bits 2..0, GC code in bits 12..8
    int sampling_rate_to_osr(uint16_t ads131_sr, uint16_t ads131_gchop = 0);
    // convert the desired gain to next (lower) possible gain, only in the range 1, 2, 4!
    // in our design we don't want to use higher gains and they are blocked here.
    int gain_to_gain_code(int8_t gain);
    int set_16_24b(uint8_t wlen);  // 0 - 16 bit, 1 - 24 bit, 2 - 32 bit LSB zero padding, 3 - MSB sign ext.

    int clear_adc_backgr();
    int load_adc_backgr(int32_t* adc_data);

    // negative gains (-1, -2, ... -128) mean gain and not gain code and will be converted to gain code (0..7)
    // sampling rate > 7 mean sampling rate in S/s and will be converted to OSR code 0..7.
    // else the sampling rate will be interpreted as OSR directly
    int prepare_all_regs(uint16_t sampling_rate, int gc_flag, int8_t gain_adc,
                         uint8_t inp_mux, uint8_t chip_mask, uint8_t do_offs_cr, uint8_t shift_r, uint8_t ldebug);
    int print_table(FILE *f, uint8_t chip, uint8_t with_read=0, uint8_t only_marked=0);

    // Functions operating with the hardware, begin with hw_!
    #ifdef SOFT_CRC
    uint16_t calculateCRC(const uint8_t dataBytes[], uint8_t numberBytes, uint16_t initialValue);
    uint16_t calculateCRC(const uint16_t dataWords[], uint8_t numberWords, uint16_t initialValue);
    #endif
    // send reset or sync command on the sync line to the ADCs
    // - when wait_rdy not 0 wait until the sync line is inactive, return code is 0 for ok and 1 for timeout
    int hw_sm_cmd(uint8_t bit_code, uint32_t wait_rdy, uint8_t chip_mask=CHIP_MASK_FULL);
    int hw_adc_reset(uint8_t wait_rdy, uint8_t chip_mask=CHIP_MASK_FULL);
    int hw_adc_sync(uint8_t wait_rdy, uint8_t chip_mask=CHIP_MASK_FULL);
    // reset the SPI master
    int hw_spi_reset();
    int hw_wt_spi_rdy(uint32_t flag_mask, uint16_t timeout=1000);
    int hw_spi_clr_new_sample();

    // set or clear the auto read flag in the SPI master
    // - when 1 - read automatically the new samples by sending the NULL command when DRDY_n goes low,
    //            ! configuration not possible in this mode !
    // - when 0 - single SPI transactions mode
    // possible to send a sync command to the ADCs and to clear the flag for new ADC data
    int hw_auto_read(int auto_read, int auto_crc, int sync, int data16, int clr_new, uint8_t chip_mask=CHIP_MASK_FULL);


    // set the mask for the active ADC chips for subsequent SPI transactions and
    // select one of the drdy_n pin for debugging
    int hw_chip_mask(uint8_t spi_mask, uint8_t drdy_sel);
    int hw_chip_mask(uint8_t spi_mask);

    int hw_send_cmd(uint16_t cmd, uint8_t chip_mask);
    // write to a single register in the ADC chip(s), return code is 0 for ok and 1 for timeout
    int hw_wr_reg(uint16_t reg_addr, uint16_t reg_data, uint8_t chip_mask=CHIP_MASK_FULL);

    // read from a single register in the ADC chip(s), return code is 0 for ok and 1 for timeout
    // the result is in an array reg_data with NCHIPS_ADC words.
    // The result comes always after the second I/O access to the chip,
    //  if dual_start = 1, two read transactions will be done and the results reg_data are from the second read.
    //  if dual_start =2, 3 the dual start is done and as long as the result is the status of the chip (instead
    //  of the expected register content), the reading will be repeatet up to 10 times
    int hw_rd_reg(uint16_t reg_addr, uint16_t* reg_data, uint8_t chip_mask, int dual_start=0);
    // read only once, so get the result of the previous SPI transaction! Equivalent to the long function above with dual_start=0
    int hw_rd_reg_single(uint16_t reg_addr, uint16_t* reg_data, uint8_t chip_mask);

    // If chip within 0..NCHIPS_ADC-1, the selected ADC chip for the measurement will be set
    // otherwise the measurement will be done with the last chip set.
    // It will be waited for about 1-2 seconds in order to get the frequency (number of conversion in one second!)
    // returns period in
    uint64_t hw_get_freq_per(uint8_t chip, uint8_t ldebug=0);
    // this function returns only and is therefore faster (don't need to wait 1-2 seconds!)
    uint32_t hw_get_per(uint8_t chip, uint8_t ldebug=0);

    // read the ADC data, 4*NCHIPS_ADC signed 24-bit words (sign extended in hardware to 32 bit)
    // return code is 0 for ok and 1 for timeout
    int hw_rd_adc(int32_t* adc_data);
    int hw_wr_all_regs(uint8_t reg_status, uint8_t chip_mask=CHIP_MASK_FULL);
    int hw_update_all_regs(); // same as wr_all_regs, with reg_status=REG_CHANGED, chip_mask=CHIP_MASK_FULL
    int hw_rd_all_regs(uint8_t chip_mask, uint8_t safe_mode=0);
};
//
#endif // ADS131M04_H
