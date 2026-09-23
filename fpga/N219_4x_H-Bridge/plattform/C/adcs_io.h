// $Id: adcs_io.h 1216 2026-09-02 16:57:27Z  $:

#ifndef _ADCS_IO
#define _ADCS_IO

#include "system_conf.h"
#include "../C/my_types.h"

#define DTMP_BASE_ADDRESS    (SLAVE_PASSTHRU_BASE_ADDRESS + 0x0490*4)    //   16

#define ADS_BASE_ADDRESS     (SLAVE_PASSTHRU_BASE_ADDRESS + 0x0400*4)    //   16

// The flags in the status register
#define ADDR_ADC_FLG  (ADC_BASE_ADDRESS + 0x0005*4)
    #define BIT_FLAGS_BUSY      1
    #define BIT_FLAGS_SYNC      2  // sync/reset in progress
    #define BIT_FLAGS_SYNC2     3  // -/
    #define BIT_FLAGS_NEW_SMP   4  // set when a new ADC sample is available, first channel of all ADC chips was read
                                   // but as the SPI is faster than the CPU & UART, the CPU can start reading and sending data!
    #define BIT_FLAGS_NO_NEW_S  5  // no new sample, the inverted of bit 4
    #define BIT_FLAGS_RECV_AD   6  //  9.. 6, address of the received data, 0 when ready
    #define BIT_FLAGS_SEND_AD  10  // 11..10, address of the sent data, 0 when ready
    #define BIT_FLAGS_DRDY     12  // data ready, inverted, of all 6 ADC chips (17..12)
    #define BIT_FLAGS_DRDY_RE  16  // was a rising edge of DRDY after SYNC was activ
// The flags with _NEW_ can be cleared by writing to any ADC data address
    #define MSK_FLAGS_NEW_SMP   (1 << BIT_FLAGS_NEW_SMP)  // set when a new sample is available

#define N_FADC_CH  8
#define FADC_FULL_MASK  ( (1 << N_FADC_CH) - 1)

// timer running at 32 kHz, automatically cleared after sync/reset command and
// when writing here anything
#define ADDR_ADC_TIMER   (ADC_BASE_ADDRESS + 0x000E*4)
// automatically latched timer with new ADC data
#define ADDR_ADC_TIMER_L (ADC_BASE_ADDRESS + 0x000F*4)

// ADC data read in the last SPI command, 24-bit, at this address for ch0 of ADC0
// add 4 for each next ADC channel (offset 4x 16..63 for ADC channels 0..47)
#define ADDR_ADC_DATA (ADC_BASE_ADDRESS + 0x0010*4)

// send the fast ADC data with bit set in the adc_mask
void send_adc24b_dat(uint32_t adc_mask0_31, uint32_t adc_mask32_47);
void send_adc16b_dat(uint32_t adc_mask0_31, uint32_t adc_mask32_47);

// send the slow ADC & status data with bit set in the adc_mask
void send_sadc_dat(uint32_t adc_mask);

// clear the new flags
void     clr_adc_flags();
// get the flags for new data
uint32_t get_adc_flags();
// get the timer running at 32 kHz
uint32_t send_adc_timer();
// clear the timer
void clr_adc_timer();

// board temperaeture sensors are at 16 & 17
#define SADC_TMP_BRD_CH     16
// total number of slow ADC & status channels 20
#define N_SADC_CH            4
// mask in bits 0..15 for the slow ADC channels to be sent, 16..17 - board temperature sensors, 18 - FPGA temperature sensor, 19 - relay
#define SADC_FULL_MASK  ( (1 << N_SADC_CH) - 1)

// global variable, used in main.c
//extern uint32_t relay_status;

// read the fast ADC data (src=0..3 for input, MI output, MIN, MAX), up to 12 channels
void fadc_rd(uint32_t adc_mask, uint32_t *ad_dat);

// up to 4 channels
void sadc_rd(uint32_t adc_mask, uint16_t *ad_dat);

// send the fast ADC data with bit set in the adc_mask
void send_fadc_dat(uint32_t adc_mask, uint32_t *ad_dat);

// send the slow ADC & status data with bit set in the adc_mask
void send_sadc_dat(uint32_t adc_mask, uint16_t *ad_dat);

// clear the new flags with set bit in clr_mask
void     clr_adcb_flags(uint32_t clr_mask);
// get the flags for new data
uint32_t get_adcb_flags();
// get the number of samples up to now
uint32_t get_adcb_nsamples();
// start (1) or stop (0) the sample counter
void start_stop_sampl_counter(int st_stop);
// get the timer running at 32 kHz
uint32_t get_adcb_timer();
// clear the timer
void clr_adcb_timer();

#endif

