// $Id: C_dtemp.h 1208 2026-08-08 16:11:40Z  $:
#ifndef DTEMP_H
#define DTEMP_H

// $Id: C_dtemp.h 1208 2026-08-08 16:11:40Z  $:

#include <stdio.h>   /* Standard input/output definitions, for perror() */
#include <stdint.h>
#include <stdlib.h>
#include <string.h>  /* String function definitions */
#include "../upstream/CLogger.h"

// DS18B20 compatible sensors, up to 8.
// The resolution is set in hardware to 12-bit.
// The sensor programmable internal thresholds are not used!

// read-only
#define OFFS_DTEMP_TEMP         0   // 0..Nsensors-1 measured temperature, 12-bit, 16*T[C]
                                    // negative temperatures: bit 11 is 1, T=-(bits 10..0)/16
                                    // positive temperatures: bit 11 is 0, T= (bits 10..0)/16
                                    // when the resolution is < 12 bits, the corresponding LSBits are 0!
// read-write
#define OFFS_DTEMP_THRESH      10   // 12-bit r/w threshold for alarm (actually 11-bit unsigned!), not used now
// read-only
#define OFFS_DTEMP_ALARM       11   // mask with the sensors, where the temp > threshold
#define BIT_DTEMP_ALARM_LAT     0   // latched mask with alarm flags, cleared when writing anything to any register
#define BIT_DTEMP_ALARM         8   // actual alarm flags

#define OFFS_DTEMP_PRESENCE     9   // mask with the found sensors (bits 7..0) and expected number of sensors (bits 11.8)
#define BIT_DTEMP_PRES_NSENS   12   // 4 bit with the number of sensors in the FPGA design

#define OFFS_DTEMP_CONFIG       8   // resolution (bits 1..0), auto-start 2, manual start 3
#define BIT_DTEMP_CNF_RES       0
#define BIT_DTEMP_CNF_AUTO      2
#define BIT_DTEMP_CNF_START     3
#define TRES_12_BIT     3
#define TRES_11_BIT     2
#define TRES_10_BIT     1
#define TRES_9_BIT      0


#define DTEMP_STEPS_IN_GRAD    16   // for 12-bit resolution

#define DEBUG_DTEMP             1

class C_dtemp : public CLogger
{
protected:
    // pointer to the UART interface
    uart32* m_uart32;
    // base address of the SPI master in the FPGA design
    uint32_t base_addr;
    int16_t last_threshold; // implement later, if necessary
    uint16_t last_alarm;    // alarm flags of up to 8 temperature sensors
    uint8_t last_res_auto;  // resolution & auto read flag
    uint16_t last_presence; // presence flags of up to 8 temperature sensors
    uint16_t last_temp[8];  // last read temperature of up to 8 temperature sensors
public:
    // set the pointer to the UART device, the base address in FPGA design
    C_dtemp(uart32* p_uart32, uint32_t new_base_addr);
    ~C_dtemp();
    uint16_t set_res_auto(uint8_t new_res);
    uint16_t set_res_trigg(uint8_t new_res);
    int16_t set_threshold(int16_t new_thresh);
    float set_threshold(float new_thresh_C);
    int16_t get_threshold();
    float get_threshold_C();
    uint16_t get_alarm_mask();
    uint16_t get_presence_mask();
    uint16_t get_temp(int16_t *rd_temp, uint8_t nsensors, int ldebug = 0);
    uint16_t rep_temp();
};

#endif // DTEMP_H
