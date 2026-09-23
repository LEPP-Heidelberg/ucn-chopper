#ifndef C_DUAL_DAC_H
#define C_DUAL_DAC_H

// $Id: C_dual_dac.h 1218 2026-09-07 14:30:56Z  $:

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
#include "dac_mcp47feb.h"

// Within the I2C master:
    // write 1-4 byte words here, LSByte will be sent as last
    #define I2C_OFFS_WDAT     0

    #define I2C_OFFS_CMD_STA  1  // offset 3 is the same
        // when writing
        // Bit 16 - reset the I2C master, in this case the other bits will be ignored. Otherwise when Bit16=0:
        #define I2C_BIT_RESET   16
        #define I2C_MSK_RESET  (1 << I2C_BIT_RESET)
        // Bit 0: R/Wn, Bits 7..1 - slave addr
        // Bits 10..8 command
        #define I2C_BIT_CMD      8    // 10..8
          #define I2C_CMD_NULL   0  // use for normal only write or only read commands
          #define I2C_CMD_RSTRT  7  // use for write, repeated start and read
          // normally not used directly
          #define I2C_CMD_STOP   1
          #define I2C_CMD_START  2
          #define I2C_CMD_GETA   3
          #define I2C_CMD_GIVA   4
          #define I2C_CMD_PUTB   5
          #define I2C_CMD_GETB   6

        // Bits 13..12/15..14 - length-1 of the first/second part
        #define I2C_BIT_LEN1    12
        #define I2C_BIT_LEN2    14

        // when reading: bits 15..0 the same meaning as when writing
        // Bits 23..20, 19..16 - state of the two state machines, 0 and 0 is idle
        // Bit 26/25 are latched/direct timeout
        // Bit 28 is 1 when the master is idle and 0 when busy

        #define I2C_BIT_TIMEOUT  26
        #define I2C_BIT_SM_BUSY  28    // state machine status, must be 1 for idle
        #define I2C_MSK_SM_BUSY  (1L << I2C_BIT_SM_BUSY)
        // mask to check if the state machines are busy
        #define I2C_MSK_SMS_BUSY  (0xFFL << 16)

    #define I2C_OFFS_RDAT     2  // read the received bytes, LSByte is the last one

#define DEF_DAC_DEBUG           0


// *************************************
// DACs in the discriminator boards
//   *************************************

#define DAC_USED_REF           DAC_VREF_IN_UNB

// V control:
#define DAC2V_SLOPE(ref)    (ref/DAC_MAX_CODE)
#define DAC2V_OFFSET        0
#define DAC2V(x, ref)       (DAC2V_SLOPE(ref)*x + DAC2V_OFFSET)

#define SWAP_CH0_CH1        1


class C_dual_dac : public CLogger
{
protected:
    uint32_t base_addr;
    uint8_t  last_status;
    uint8_t debug;
    uart32* m_uart32;
    int i2c_timeout;

public:
    C_dual_dac(uart32* p_uart32, uint32_t new_base_addr, uint8_t new_debug = 0) ;

    ~C_dual_dac();

    int last_i2c_timeout()
    {
        return i2c_timeout;
    }

    // calculate the DAC value for the V
    uint16_t v_to_dac(float vin, int dac_ref_rg_bits, int debug = DEF_DAC_DEBUG);
    // calculate the voltage from the DAC
    float dac_to_v(uint16_t dac, int dac_ref_rg_bits, int debug = DEF_DAC_DEBUG);
    // init the DAC reference source register, 0..3 means VDD, int, external unbuffered/buffered, s. dac_mcp47feb.h for details)
    int init_dac_ref(int used_ref, int write2eep, int debug = DEF_DAC_DEBUG);
    // get the voltage reference from the settings bits
    float dac_ref(int dac_ref_rg_bits, int debug = DEF_DAC_DEBUG);
    // set the DAC 0|1 with 12-bit integer value
    int set_dac(int ch, int dac, int write2eep, int debug = DEF_DAC_DEBUG);
    // set the
    int set_dac_volt(int ch, float volt, int dac_ref_rg_bits, int write2eep, int debug = DEF_DAC_DEBUG);
    uint32_t get_dacs(int debug = DEF_DAC_DEBUG);

protected:
    // dac_rg   0..0x0F for volatile and 0x10..0x1F for non-volatile registers
    // wdata    write data, only 2 bytes will be used
    // wait     flag to wait until the transaction is done
    uint32_t i2c_write_dac_rg(uint32_t dac_rg, uint32_t wdata, int wait, int debug = DEF_DAC_DEBUG);
    uint32_t i2c_read_dac_rg( uint32_t dac_rg, int debug = DEF_DAC_DEBUG);

    // len is 1..4, write to a single configuration register 1 to 4 bytes
    uint8_t  WriteReg(uint8_t len, uint32_t addr, uint32_t wdata);
    uint32_t ReadReg( uint8_t len, uint32_t addr);

    // I2C
    uint32_t i2c_reset(                                           int debug = DEF_DAC_DEBUG);
    // write don't wait until the transaction is ready! for nbytes=2, write first wdata >> 8, then wdata & 0xFF
    uint32_t i2c_write(int slv_addr, int nbytes, uint32_t wdata, int debug = DEF_DAC_DEBUG);
    // read & write_read don't wait until the transaction is ready!
    uint32_t i2c_read( int slv_addr, int nbytes,                 int debug = DEF_DAC_DEBUG);
    // write - repeated start - read
    uint32_t i2c_write_read(int slv_addr, int nwbytes, uint32_t wdata, int nrbytes, int debug = DEF_DAC_DEBUG);
    // wait until i2c master is ready, return 1 in case of timeout
    uint32_t i2c_wait_rdy( int debug = DEF_DAC_DEBUG);
    // get the result of the last read transaction, you should wait before for the master to be ready!
    uint32_t i2c_get_rdata(int debug = DEF_DAC_DEBUG);
};

#endif /* C_DUAL_DAC_H */
