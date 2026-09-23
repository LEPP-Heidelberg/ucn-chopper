// $Id: dac_mcp47feb.h 1216 2026-09-02 16:57:27Z  $:

#ifndef DAC_MCP47FEB_H
#define DAC_MCP47FEB_H

// MCP47FEB DAC with EEPROM
// All registers are 16-bit
// Reg 0x00/0x01 : Volatile DAC0/1        -
// Reg 0x10/0x11 : Non-volatile DAC0/1    - upper 4 bits are don't care, read as '0'
// Reg 0x08 : VREF
// Reg 0x18 : Non-volatile VREF
// Reg 0x09 : power-down control
// Reg 0x0A : Gain & Status
// Reg 0x1A : NV Gain

// ch0 - hysteresis, ch1 - threshold
#define I2C_SLAVE_DUAL_DAC  0xC0
// internal register addresses
#define MCP47FEB_OFFS_NV       0x10 // add 0x10 to the address of volatile reg to get the address of the corresponding non-volatile reg

#define MCP47FEB_RG_DAC0       0x00 // DAC in lower 12-bits
#define MCP47FEB_RG_DAC1       0x01
#define MCP47FEB_NV_MEM        0x10

#define MCP47FEB_VREF      (2*1.22) // internal reference 1.22 (multiplied by 2 internally) in Volt
                                    // we use external VREF for both DACs : 1010 => 0x0A
#define MCP47FEB_RG_VREF       0x08 // VR1[3:2] and VR0[1:0]: 3/2 - VREF pin (inp) buffered/unbuffered, 1 - internal REF, 0 - VDD
#define DAC_VREF_VDD              0
#define DAC_VREF_INT              1
#define DAC_VREF_IN_UNB           2
#define DAC_VREF_IN_BUF           3


                                    // we need 0 (default)
#define MCP47FEB_RG_PWR_DN     0x09 // PD1[3:2] and PD0[1:0]: 3..1: Powered down - OUT open(3), OUT 100kOhm(2), OUT 1kOhm(1); 0 - normal operation

                                    // we need 0 for GAIN=1 (default)
#define MCP47FEB_RG_GAIN       0x0A // GAIN1[9] and GAIN0[8]: 0/1 for Gain=1/2, POR[7] - status, was a power up reset, EEWA[6] - status, EEPROM write cycle

// two DAC chips on the board, 0 for hysteresis & threshold (2 DACs), 1 for HV (1 DAC)

#define DAC_NBITS       12
#define DAC_MAX_CODE    ((1 << 12) - 1)

#define DAC_VREF        3.3         // V, external

#endif
