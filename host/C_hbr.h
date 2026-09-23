#ifndef C_HBR_H
#define C_HBR_H

// $Id: C_hbr.h 1222 2026-09-16 14:00:13Z  $:

#include <stdio.h>   /* Standard input/output definitions, for perror() */
#include <stdint.h>
#include <stdlib.h>
#include <string.h>  /* String function definitions */
#include <unistd.h>  /* UNIX standard function definitions, for close() */
#include <fcntl.h>   /* File control definitions, for open() */
#include <signal.h>  /* ANSI C signal handling */
#include <math.h>

#include <sys/time.h>

#include "../upstream/CLogger.h"

// ADDRESS MAP

#ifdef CPU_LM32
    #define IMEM_SIZE           0x0800  // in 32-bit words
    #define ADDR_IMEM_BASE      0x0000  // the byte address is x4
    #define BIT_CONFIG_CMD_CPU_OFF       0
    #define BRIDGE_BASE_ADDR    0x800000
#endif
#ifdef CPU_SW32
    #define IMEM_SIZE           0x0400  // in 24-bit words
    #define ADDR_IMEM_BASE      0x4000  // the byte address is x4
    #define BIT_CONFIG_CMD_CPU_OFF       1
    #define BRIDGE_BASE_ADDR    0x000000
#endif

// Config & Status Register         // 0x0100 ... 0x011F
#define ADDR_CONFIG       (BRIDGE_BASE_ADDR + 0x0100) // .. 0x011F
#define ADDR_CONF_CMD       ( ADDR_CONFIG + 1)
#define BIT_CONFIG_CMD_CPU_RST       0
#define BIT_CONFIG_CMD_SFT_RST       2


#define ADDR_SMALL_MEM    (BRIDGE_BASE_ADDR + 0x0800) // .. 0x0FFF
#define ADDR_PT100_0      (ADDR_SMALL_MEM + 0x0004)
#define ADDR_ADC_BUFFER   (BRIDGE_BASE_ADDR + 0x6000) // .. 0x7FFF
#define SMALL_MEM_SIZE      0x400   // in 32-bit words
#define ADC_BUFF_SIZE     (0x1FFF-8)   // in 16-bit words
#define ADS_VREF    1.2 // V
#define VADC_ATT    40.0
#define VADC_SLOPE16    (-VADC_ATT*ADS_VREF/(1 << 15) )
#define VADC_SLOPE24    (-VADC_ATT*ADS_VREF/(1 << 23) )
#define ISHUNT          (10e-3)  // 10 mOhm
#define ISHUNT_GAIN      20      // INA299A1
#define IADC_SLOPE16    (-ADS_VREF/(ISHUNT*ISHUNT_GAIN)/(1 << 15) )
#define IADC_SLOPE24    (-ADS_VREF/(ISHUNT*ISHUNT_GAIN)/(1 << 23) )
#define IPROP_G         (212e-6) // 212 uA/A
#define IPROP_R          820     // Ohm
#define IPROP_SLOPE16    (ADS_VREF/(IPROP_G*IPROP_R)/(1 << 15) )
#define PT100_CURR       (1e-3)
#define PT100_SLOPE16    (ADS_VREF/PT100_CURR/(1 << 15) )

// https://de.wikibooks.org/wiki/Linearisierung_von_resistiven_Sensoren/_Pt100
#define PT100_TO_C(R) ( ( (-5.67e-6*R+0.0024984)*R+2.22764)*R-242.078)


#define ADDR_ADS_ADC      (BRIDGE_BASE_ADDR + 0x0400) // .. 0x041F
//#define ADDR_PSRG         (BRIDGE_BASE_ADDR + 0x2000) // .. 0x3FFF
#define ADDR_I2C          (BRIDGE_BASE_ADDR + 0x0480) // .. 0x048F
#define ADDR_DTEMP        (BRIDGE_BASE_ADDR + 0x0490) // .. 0x049F

#define ADDR_HBR_BASE     (BRIDGE_BASE_ADDR + 0x2000) // .. 0x3FFF
#define ADDR_HBR_SEQ0     ( ADDR_HBR_BASE + 0x1000)   // .. 0x17FF  RAM 2x1024 x 18
#define ADDR_HBR_SEQ1     ( ADDR_HBR_BASE + 0x1800)   // .. 0x3FFF  RAM 2x1024 x 18

// offset 0..15 - configuration registers of the H-bridge
#define ADDR_HBR_CONF     ( ADDR_HBR_BASE + 0x0000)
// or write the bit position in bits 7..4 and the 1 or 2 bits in pos 0 or 1..0
#define ADDR_HBR_CONF_BIT ( ADDR_HBR_BASE + 0x0001)

    // TOFF conf    off-time in us
    // 0            7
    // 1            16
    // 2            24
    // 3            32
    #define HBR_BIT_TOFF       0  // 2 bits
    // decay pin        decay mode
    //  0           Slow decay (brake or high-side re-circulation)
    //  1           Smart tune dynamic decay
    //  2,3         Mixed decay: 30% fast
    #define HBR_BIT_DECAY      2 // 2 bits
    // Single H-Bridge Mode (MODE1 = 1), or Dual H-Bridge Mode (MODE1 = 0)
    // The MODE2 pin has to be grounded to select PH/EN interface.
    // To select PWM interface, keep MODE2 pin floating or connect the MODE2 pin to DVDD.
    #define HBR_BIT_MODE       4  // 2 bits

    // When the OCPM pin is logic low, the device has latch-off type recovery - which means once the OCP
    // condition is removed, normal operation resumes after applying an nSLEEP reset pulse or a power cycling.
    //
    // When the OCPM pin is logic high, normal operation resumes automatically (driver operation and nFAULT
    // released) after the tRETRY time has elapsed and the fault condition is removed.
    #define HBR_BIT_OCPM       6  // 1 bit

    // turn all outputs off
    #define HBR_BIT_SLEEP_N    7  // 1 bit

    #define HBR_BIT_ENA_OPCPL  8  // 2 bits
    #define HBR_BIT_ENA_AFBR  10  // 2 bits
    #define HBR_BIT_INV_OPCPL 12  // 2 bits
    #define HBR_BIT_INV_AFBR  14  // 2 bits
    #define HBR_BIT_SL_DEC_SM 16  // 2 bits
    #define HBR_BIT_REM_LAST  18  // 2 bits


// status, still not well defined
#define ADDR_H_STAT         ( ADDR_HBR_BASE + 0x0002)
    #define STA_BIT_FAULT   0  // fault_n pin
    #define STA_BIT_BUSY0   2  // busy0..1
    #define STA_BIT_N_RAM   4  // 4 bits, address bits in RAM for one channel
    #define STA_BIT_CTRL    8  // 2 bits
    #define STA_BIT_LSW    16  // 2 bits


    // divide system clock 48*2^10 to get
    // code:      0    1      2      3      4      5      6      7
    // PWM Freq 4800, 8000, 9600, 16000, 19200, 24000, 32000, 48000
//const uint16_t PWM_FREQ[8] = { 4800, 8000, 9600, 16000, 19200, 24000, 32000, 48000};
const uint16_t PWM_FREQ[8] = { 4000, 6400, 8000, 12800, 16000, 25600, 32000, 64000};
#define R_PT_REF 99.858 // Ohm
const float slope_pt[2] = { R_PT_REF/100.52, R_PT_REF/101.11};
#define ADDR_PWM_FREQ_DIV   ( ADDR_HBR_BASE + 0x0003)

// single shot: on/off (the 2 IN outputs to H-bridge)
//  17..16  2 bits for the state (IN of HBR)
//  15.. 8  8 bits for duration in PWM periods
//   7.. 0  8 bits for power
#define ADDR_H_OUTP_1     ( ADDR_HBR_BASE + 0x0004)
#define ADDR_H_OUTP_2     ( ADDR_HBR_BASE + 0x0005)

// bits 0, 1 - go to ON  at shutter 1, 2
// bits 2, 3 - go to OFF at shutter 1, 2
// bits 4, 5 - reset the sequence state machines at ch 1, 2
// write 1 in the corresponding bit, will be cleared automatically.
#define ADDR_START_ON_OFF ( ADDR_HBR_BASE + 0x0007)
    #define SM_BIT_STO0   6
    #define SM_BIT_STO1   7
        #define SM_MASK_ANY_STORE   ( (1 << SM_BIT_STO0) | (1 << SM_BIT_STO1) )
    #define SM_BIT_AMSK   8 // 8 bits


// start address in 31..16 and number of PWM periods in 15..0 for input 1 when turning shutter on
#define ADDR_SEQ_AD_RANGE_ON_1  ( ADDR_HBR_BASE + 0x0008)
// start address in 31..16 and number of PWM periods in 15..0 for input 1 when turning shutter off
#define ADDR_SEQ_AD_RANGE_OFF_1 ( ADDR_HBR_BASE + 0x0009)
// start address in 31..16 and number of PWM periods in 15..0 for input 2 when turning shutter on
#define ADDR_SEQ_AD_RANGE_ON_2  ( ADDR_HBR_BASE + 0x000A)
// start address in 31..16 and number of PWM periods in 15..0 for input 2 when turning shutter off
#define ADDR_SEQ_AD_RANGE_OFF_2 ( ADDR_HBR_BASE + 0x000B)

#define UNCOMPR_LENGTH  (1 << 16)
#define SEQ_LENGTH      2048        // must be 2^N !
#define SEQ_LEN_MASK    (SEQ_LENGTH - 1)

// current pointer to the table and state machine states of both channels
#define ADDR_SEQ_STATUS         ( ADDR_HBR_BASE + 0x000C)

// structure of the RAM block with the sequence
// width 18 bits (to use more effectively the EBRs)
//  17..16  2 bits for the state (IN of HBR)
//  15.. 8  8 bits for duration in PWM periods
//   7.. 0  8 bits for power
// bit positions inside the RAM Table
#define SEQ_TABLE_POS_PWR    0
#define SEQ_TABLE_WDT_PWR    8
#define SEQ_TABLE_POS_DUR   ( SEQ_TABLE_POS_PWR + SEQ_TABLE_WDT_PWR )
#define SEQ_TABLE_WDT_DUR    8
#define SEQ_TABLE_POS_OUT   ( SEQ_TABLE_POS_DUR + SEQ_TABLE_WDT_DUR )
#define SEQ_TABLE_WIDTH     ( SEQ_TABLE_WDT_PWR + SEQ_TABLE_WDT_DUR + 2 )
    #define PWR_MASK ( (1 << SEQ_TABLE_WDT_PWR) - 1)
    #define DUR_MASK ( (1 << SEQ_TABLE_WDT_DUR) - 1)
#define MAX_REP         ( (1 << SEQ_TABLE_WDT_DUR) - 1)

// for all designs using LM32 CPU of lattice, in the small shared memory
#define ADDR_COMP_DATE    (ADDR_SMALL_MEM + 8)
#define ADDR_COMP_TIME    (ADDR_SMALL_MEM + 9)

#define DEF_DEBUG           0

#define MAX_INT_POWER       ((1 << SEQ_TABLE_WDT_PWR) - 1)
#define MIN_INT_POWER       (-MAX_INT_POWER)


class C_hbr : public CLogger
{
protected:
    uint8_t last_status;
    int32_t last_pwm_freq;

    uint8_t debug;
    uart32* m_uart32;

public:
    C_hbr(uint8_t new_debug, uart32* p_uart32)
    {
        m_uart32 = p_uart32;
        debug = new_debug;
        last_pwm_freq = -1; // unknown
    }

    uint32_t send_cmd(uint32_t t_command, int debug = DEF_DEBUG);
    uint64_t get_cpu_prog_timestamp(int debug = DEF_DEBUG);


    int set_hbr_conf_decay(uint8_t decay_code, int debug = DEF_DEBUG);
    int set_hbr_conf_toff( uint8_t toff_code , int debug = DEF_DEBUG);
    int set_hbr_conf_mode(uint8_t mode1, uint8_t mode2, int debug = DEF_DEBUG);
    int set_hbr_conf_ocpm(uint8_t ocpm, int debug = DEF_DEBUG);
    int set_hbr_conf_sleep_n(uint8_t sleep_n, int debug = DEF_DEBUG);
    int set_hbr_conf_ena_inv_afbr(uint8_t ch, uint8_t ena, uint8_t inv, int debug = DEF_DEBUG);
    int set_hbr_conf_ena_inv_ocpl(uint8_t ch, uint8_t ena, uint8_t inv, int debug = DEF_DEBUG);
    int set_hbr_sm_slow_decay(int ch_mask, int slow_decay, int debug = DEF_DEBUG);
    int set_preserve_last(int ch_mask, int preserve, int debug = DEF_DEBUG);
    uint32_t get_hbr_conf(int debug = DEF_DEBUG);
    // either code 0..7 or frequency 4800..48000 Hz
    int set_pwm_freq(uint16_t new_pwm_freq, int debug = DEF_DEBUG);
    //  ch=0, 1
    //  hbr_state 0..3, 0-off, 3-brake, 1, 2 - on forw/back
    //  duration 1..256 PWM periods
    //  power   - 0 (off) to 255 (max)
    int single_shot(int ch, int hbr_state, int duration, int power, int debug = DEF_DEBUG);

    // bits 0, 1 - go to ON at shutter 1, 2; bits 2, 3 - go to OFF at shutter 1, 2.
    // write 1 in the corresponding bit, will be cleared automatically.
    int hbr_seq_start(int ch_mask, int seq_ch1, int seq_ch2, int debug = DEF_DEBUG);
    int hbr_seq_reset(int ch_mask, int debug = DEF_DEBUG);

    // ch = 0, 1
    // seq_nr = 0, 1
    // seq_beg = 0..511
    // seq_len = 1..512
    // Note: the table for one channel is physically one memory block, used for both directions!
    //       so it is not fixed which part is used for which direction!
    //       BUT the two channels have different memory blocks!
    int hbr_seq_table_range(int ch, int seq_nr, int seq_beg, int seq_len, int debug = DEF_DEBUG);
    int hbr_rep_seq_table();
    int hbr_rep_pwm();
    int32_t read_power_profile(FILE *f, float *time_ms, float *power, uint32_t max_length, int debug = 0);
    int32_t resample_power_profile(float tstep, float tscale, float pscale, float *time_ms, float *power, uint32_t flength, int16_t *ipower, int debug = 0);
    int32_t compress_power_profile(uint32_t ilength, int16_t *ipower, uint32_t* tbl_data, int debug = 0);
    int hbr_create_seq_table(  // all times in ms
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
        int debug = DEF_DEBUG);

    int hbr_upload_seq_table(
        int ch, // channel 0 or 1
        int re, // rising edge 1 or 0, 1 in the first table half, 0 in the second table half
        int tbl_len, // length, number of entries, not number of PWM periods!
        uint32_t* tbl_data, // integer data to load to the table:
        // bits 17..16 - state, bits 15..8 - duration, bits 7..0 - power
        // return the length of the table
        int debug = DEF_DEBUG);


//    int      read_adc_data(int32_t* adc_data);

    int32_t get_sh_mem(uint32_t msize, uint32_t baddr, uint8_t *sh_mem, uint8_t ainc);
    int32_t get_sh_mem(uint32_t msize, uint32_t baddr, uint16_t *sh_mem, uint8_t ainc);
    int32_t get_sh_mem24(uint32_t msize, uint32_t baddr, uint32_t *sh_mem, uint8_t ainc);
    int32_t get_sh_mem(uint32_t msize, uint32_t baddr, uint32_t *sh_mem, uint8_t ainc);
    int32_t set_sh_mem(  uint32_t msize, uint32_t baddr, uint8_t  *sh_mem, uint8_t ainc=1);
    int32_t set_sh_mem(  uint32_t msize, uint32_t baddr, uint16_t *sh_mem, uint8_t ainc=1);
    int32_t set_sh_mem24(uint32_t msize, uint32_t baddr, uint32_t *sh_mem, uint8_t ainc=1);
    int32_t set_sh_mem(  uint32_t msize, uint32_t baddr, uint32_t *sh_mem, uint8_t ainc=1);
    uint32_t read_imem_file(FILE *f, uint32_t *prog_data, uint32_t max_length);

    int read_adc_buffer(FILE *fout);
    uint32_t read_temper(int debug = 0);

protected:
    // len is 1..4, write to a single configuration register 1 to 4 bytes
    uint8_t  WriteReg(uint8_t len, uint32_t addr, uint32_t wdata);
    uint32_t ReadReg( uint8_t len, uint32_t addr);
};

#endif /* C_HBR_H */
