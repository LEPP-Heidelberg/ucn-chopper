// $Id: main.c 1216 2026-09-02 16:57:27Z  $:

/**************************************************************
 * This example exercises LEDs on LatticeMico32 Development   *
 * board.                                                     *
 *                                                            *
 * The implementation in this file is targeted for a size     *
 * smaller than the LEDTest template implementation.  To      *
 * achieve this, the default LatticeDDInit function is over-  *
 * ridden by providing a DDInit.c in the project.             *
 *                                                            *
 * Unlike LEDTest, f/printf functions are non-functional in   *
 * LEDTest_small_size                                         *
 *                                                            *
 *                                                            *
 *------------------------------------------------------------*
 * PREREQUISITES:                                             *
 *                                                            *
 * - GPIO with 8-bit output named LED connected to the        *
 *   board's LED pins.                                        *
 *                                                            *
 * - NOTE: IF YOU INTEND TO USE PRINTF, PLEASE MAKE CHANGES TO*
 *   DDINIT.C                                                 *
 *                                                            *
 **************************************************************/
#include "MicoUtils.h"
//#include "system_conf.h"

// Our definitions of the integer types like int8_t, uint8_t etc.
// correspond to stdint.h (not found here)
//#include "my_types.h"
//
// common constants & functions for the whole design
#include "design_functions.h"

int main(void)
{
    uint32_t loop_cnt, led_cnt, led_bln_cnf;

    loop_cnt = 0;
    led_cnt  = 0xAAAAAAAA;
    led_bln_cnf = 1;
    led_bln_cnf <<= 31; // soft control only of the last LED

    fill_date_time();

    i2c_reset();

    MicoSleepMilliSecs(1);

    /* scroll the LEDs, every 100 msecs forever */
    while(1)
    {
//        MicoSleepMilliSecs(1);
        if ( (loop_cnt & 0x3FFFF) == 0x3FFFF)
        {
            led_cnt = ~led_cnt;
            set_led(led_cnt, 0x80000000);
        }
        loop_cnt++;
//      MicoSleepMilliSecs(200);
    }

    /* all done */
    return(0);
}

