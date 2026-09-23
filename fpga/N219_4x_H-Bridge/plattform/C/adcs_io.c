// $Id: adcs_io.c 1216 2026-09-02 16:57:27Z  $:

#include "pm_adcs.h"
#include "adcs_io.h"
#include "uart_send.h"

//#define SEND_TEST_PATT  1

void send_adc24b_dat(uint32_t adc_mask)
{
    volatile uint32_t *p_adc_dat;
#ifdef SEND_TEST_PATT
    volatile uint32_t tdat;
#endif

#ifdef SEND_TEST_PATT
    tdat = 0xADC000;
#else
    p_adc_dat = (volatile uint32_t*) ADDR_ADC_DATA;
#endif

    while (adc_mask)
    {
#ifdef SEND_TEST_PATT
        if (adc_mask & 1) send_24word(tdat);
        tdat++;
#else
        if (adc_mask & 1) send_24word(*p_adc_dat);
        p_adc_dat++;
#endif

        adc_mask >>= 1;
    }

    return;
}

void send_adc16b_dat(uint32_t adc_mask)
{
    volatile uint32_t *p_adc_dat;
#ifdef SEND_TEST_PATT
    volatile uint32_t tdat;
#endif

#ifdef SEND_TEST_PATT
    tdat = 0xAD00;
#else
    p_adc_dat = (volatile uint32_t*) ADDR_ADC_DATA;
#endif

    while (adc_mask)
    {
#ifdef SEND_TEST_PATT
        if (adc_mask & 1) send_word(tdat);
        tdat++;
#else
        if (adc_mask & 1) send_word(*p_adc_dat);
        p_adc_dat++;
#endif
        adc_mask >>= 1;
    }
    return;
}

void send_sadc_dat(uint32_t sadc_mask)
{
    volatile uint32_t *p_sadc_dat;

    p_sadc_dat = (volatile uint32_t*) DTMP_BASE_ADDRESS;

    while (sadc_mask)
    {
        if (sadc_mask & 1) send_word(*p_sadc_dat);
        p_sadc_dat++;
        sadc_mask >>= 1;
    }
    return;
}

void clr_adc_flags(void)
{
    IO_WRITE(ADDR_ADC_DATA, 0);
    return;
}

uint32_t get_adc_flags()
{
    return IO_READ(ADDR_ADC_FLG);
}

uint32_t send_adc_timer()
{
    uint32_t pkt_tms;
    pkt_tms = IO_READ(ADDR_ADC_TIMER_L);
    send_24word(pkt_tms);   // 3 bytes
    return;
}

void clr_adc_timer()
{
    IO_WRITE(ADDR_ADC_TIMER_L, 0);
    return;
}
