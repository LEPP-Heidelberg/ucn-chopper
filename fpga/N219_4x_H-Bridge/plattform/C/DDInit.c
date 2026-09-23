#include "DDStructs.h"

/*
 * THIS DDINIT.C IN THE PROJECT FOLDER OVERRIDES
 * THE DEFAULT/AUTO-GENERATED DDINIT.C (for managed
 * projects).
 *
 *
 * DDINIT.C contains implementation of LatticeDDInit
 * that is called from crt0ram.S (auto-generated for
 * managed make projects).  This function contains
 * initialization routines for device-drivers before
 * invoking main(), providing a place holder for
 * preparing the hardware for user's main application.
 *
 * 
 * For LEDTest, there does not need to be elaborate
 * device-driver initialization since all the application
 * does is blink the LEDs (GPIO output).  So, this
 * overrides default LatticeDDInit implementation.
 *
 */
#ifdef __cplusplus
extern "C"
{
#endif /* __cplusplus */

void LatticeDDInit(void)
{

    /* NOTE: IF YOU INTEND TO USE LM32 JTAG 
     * AS STANDARD INPUT/OUTPUT (i.e. printf),
     * UNCOMMENT THE CODE BELOW
     */
#if 0
    /* initialize LM32 instance of lm32_top */
    LatticeMico32Init(&lm32_top_LM32);
#endif

    /* NOTE: IF YOU HAVE A UART NAMED "uart"
     * AND WANT TO USE IT FOR STDIO (i.e. printf),
     * UNCOMMENT THE CODE BELOW;
     * If your uart instance is not "uart", refer
     * to DDStructs.h, or DDStructs.c or the pregenerated
     * DDInit.c to identify the structure instance name. 
     */
#if 0
    /* initialize uart instance of uart_core */
    MicoUartInit(&uart_core_uart);
#endif


    /* NOTE: IF YOU HAVE A TIMER NAMED "timer"
     * AND INTEND TO USE IT, UNCOMMENT THE CODE BELOW.
     * If your timer instance is not "timer", refer
     * to DDStructs.h, or DDStructs.c or the pregenerated
     * DDInit.c to identify the structure instance name.
     */
#if 0
    /* initialize timer instance of timer */
    MicoTimerInit(&timer_timer);
#endif

    /* ADD ANY OTHER INITIALIZATION CODE IN HERE */
    
    /* invoke application's main routine*/
    main();
}

#ifdef __cplusplus
};
#endif /* __cplusplus */

