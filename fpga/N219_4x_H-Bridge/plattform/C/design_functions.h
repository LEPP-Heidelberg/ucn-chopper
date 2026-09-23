// $Id: design_functions.h 1216 2026-09-02 16:57:27Z  $:

// The addresses in the FPGA design are of 32-bit data, even if some IO devices have smaller interface
// (16 or 8 bit). The addresses in the LM32 are always byte addresses, therefore the
// FPGA design addresses should be multiplied by 4!

// The FPGA design I/O space can be reached through the CPU via a bridge, residing
// in a window from
// SLAVE_PASSTHRU_BASE_ADDRESS to SLAVE_PASSTHRU_BASE_ADDRESS + 0x3FFFF
// as the FPGA I/O address is 16-bit
//
// Note that when accessing the FPGA I/O space through the UART interface, the
// bridge lies at another offset and the addresses are 32-bit data word addresses
// (don't multiply by 4!)
//
#include "my_types.h"
#include "DateTime.h"

//                                                                      //  size, 32-bit words
#define CNF_BASE_ADDRESS    (SLAVE_PASSTHRU_BASE_ADDRESS + 0x0100*4)    // 0x0100

// 1..0 : tx mux for the enabled tx ports
//                0 - config data only
//                1 - config & ADC data
//                2 - ADC data only
//                3 - echo
#define ADDR_UART_SEL       (CNF_BASE_ADDRESS + 0x0000*4)

// r/w: bits 31..0 are in pairs the "colour" of leds 15..0, 0 - off, 1..3 - different predefined colours
// (only for the LEDs with software control)
#define ADDR_LED            (CNF_BASE_ADDRESS + 0x0002*4)
// r/w: bits 15.. 0 are blink off (0) or on (1) (only for the LEDs with software control)
// r/w: bits 31..16 are hardware control (0) or software control (1)
#define ADDR_LED_BLINK      (CNF_BASE_ADDRESS + 0x0003*4)

// when reading - the current timer running at the system clock
#define CNF_TIMER           (CNF_BASE_ADDRESS + 0x0004*4)
// when writing:
    #define BIT_CNF_TIMER_CLR   0
    #define BIT_CNF_TIMER_RUN   1
    #define BIT_CNF_TIMER_LAT0  2
    #define BIT_CNF_TIMER_LAT1  3
    #define BIT_CNF_TIMER_LAT2  4
// the latched values of the timer
#define CNF_TIMER_L0 (CNF_BASE_ADDRESS + 0x0005*4)
#define CNF_TIMER_L1 (CNF_BASE_ADDRESS + 0x0006*4)
#define CNF_TIMER_L2 (CNF_BASE_ADDRESS + 0x0007*4)

// CRC checker on FPGA config
#define ADDR_CONFIG_CHIP_CRC (CNF_BASE_ADDRESS +  0x0011*4)
#define BIT_CHIP_CRC_ENA    0   // enable checking, must be pulsed 0->1->0 once to init the circuit
#define BIT_CHIP_CRC_START  1   // start building the CRC, automatically cleared
#define BIT_CHIP_CRC_FRERR  2   // force CRC error, automatically cleared
// status bits
#define BIT_CHIP_CRC_DONE   4   // check done when 1
#define BIT_CHIP_CRC_RUN    5   // check in progress when 1
#define BIT_CHIP_CRC_ERR    6   // error when 1!





#define I2C_BASE_ADDRESS    (SLAVE_PASSTHRU_BASE_ADDRESS + 0x0480*4)    //   16
// in I2C master:
    // write 1-4 byte words here, MSByte will be sent as first
    #define I2C_OFFS_WDAT     (0*4)
    // depending on the number of bytes to be sent:
    //                                       Bits in WDAT output buffer
    // n bytes     first byte to be sent        second byte     third byte      fourth byte
    //    4             31..24                  23..16          15..8           7..0
    //    3             23..16                  15..8           7..0
    //    2             15..8                   7..0
    //    1              7..0

    #define I2C_OFFS_CMD_STA  (1*4)
    // Bit 16 - reset the I2C master, in this case the other bits will be ignored. Otherwise when Bit16=0:
    // Bit 0: R/Wn, Bits 7..1 - slave addr, Bits 10..8 command, Bits 13..12/15..14 - length-1 of the first/second part

        // when writing
        #define I2C_BIT_RESET   16
        #define I2C_MSK_RESET  (1 << I2C_BIT_RESET)
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

        #define I2C_BIT_LEN1    12
        #define I2C_BIT_LEN2    14
        // when reading: bits 15..0 the same meaning
        // Bits 23..29, 19..16 - state of the two state machines, 0 and 0 mean idle
        // Bit 26/25 are latched/direct timeout
        // Bit 28 is 0 when the master is idle and 1 when busy

        #define I2C_BIT_TIMEOUT  26
        #define I2C_BIT_SM_BUSY  28    // state machine status, 1 for busy
        #define I2C_MSK_SM_BUSY  (1L << I2C_BIT_SM_BUSY)
        #define I2C_MSK_SMS_BUSY  (0xFFL << 16)

    #define I2C_OFFS_RDAT     (2*4)  // read the received bytes, MSByte is the first one

#define I2C_TIMEOUT         1000;

#define I2C_SLAVE_DUAL_DAC  0xC2
// internal register addresses
#define MCP47FEB_OFFS_NV       0x10 // add 0x10 to the address of volatile reg to get the address of the corresponding non-volatile reg

#define MCP47FEB_RG_DAC0       0x00 // DAC in lower 12-bits
#define MCP47FEB_RG_DAC1       0x01
#define MCP47FEB_NV_MEM        0x10

#define MCP47FEB_RG_VREF       0x08 // VR1[3:2] and VR0[1:0]: 3/2 - VREF pin (inp) buffered/unbuffered, 1 - internal REF, 0 - VDD
#define DAC_VREF_INI           0x0005

                                    // we need 0 (default)
#define MCP47FEB_RG_PWR_DN     0x09 // PD1[3:2] and PD0[1:0]: 3..1: Powered down - OUT open(3), OUT 100kOhm(2), OUT 1kOhm(1); 0 - normal operation

                                    // we need 0 for GAIN=1 (default)
#define MCP47FEB_RG_GAIN       0x0A // GAIN1[9] and GAIN0[8]: 0/1 for Gain=1/2, POR[7] - status, was a power up reset, EEWA[6] - status, EEPROM write cycle

#define DAC_NBITS       12
#define DAC_MAX_CODE    ((1 << 12) - 1)







#define TXD_BASE_ADDRESS    (SLAVE_PASSTHRU_BASE_ADDRESS + 0x04C0*4)    //    8
// write here - send one byte as hex-text, first bits 7..4, then bits 3..0 (as ASCII char '0'..'9', 'A'..'F')
// read - the last sent byte as text
#define TXD_ASCII    (TXD_BASE_ADDRESS + 0)

// write here - send one byte, read - the last sent byte
#define TXD_BYTE     (TXD_BASE_ADDRESS + 3*4)

// write here - init the CRC8 register, read here - the accumulated CRC8
#define TXD_CRC8_INI (TXD_BASE_ADDRESS + 6*4)
// write here - send the accumulated CRC8, read - the last sent byte
#define TXD_CRC8     (TXD_BASE_ADDRESS + 7*4)

// write here - send the nibble in bits 3..0 as hex-text (char '0'..'9', 'A'..'F')
#define TXD_NIBBLE_L (TXD_BASE_ADDRESS + 1*4)
// write here - send the nibble in bits 7..4 as hex-text (char '0'..'9', 'A'..'F')
#define TXD_NIBBLE_H (TXD_BASE_ADDRESS + 2*4)

// write here - bit 0 is the turbo bit (if in hardware enabled)
// any write clears the FIFO
#define TXD_STA      (TXD_BASE_ADDRESS + 4*4)
#define TXD_BIT_CNF_TURBO   0      //  r/w
#define TXD_BIT_STA_FULL    1      //  r
#define TXD_BIT_STA_AFULL   2      //  r
#define TXD_MSK_STA_AFULL   (1 << TXD_BIT_STA_AFULL)       //  r
#define TXD_BIT_STA_NEMPTY  3      //  r
#define TXD_MSK_STA_NEMPTY  (1 << TXD_BIT_STA_NEMPTY)      //  r
#define TXD_BIT_STA_SIZE    4      //  r, in bits 7..4 is the number of address bits in the TX FIFO

#define ASCII_LF  0x0A
#define FIFO_DEPTH 1024




#define HBR_BASE_ADDRESS    (SLAVE_PASSTHRU_BASE_ADDRESS + 0x1000*4)    // 0x1000




// shared memory, 256 words x 32 bit
#define SMEM_BASE_ADDRESS   (SLAVE_PASSTHRU_BASE_ADDRESS + 0x0200*4)    // 0x0200
#define PSRG_BASE_ADDRESS   (SLAVE_PASSTHRU_BASE_ADDRESS + 0x2000*4)    // 0x2000

// addresses in shared memory to store the compilation date & time of the LM32 C program
#define COMP_DATE           (SMEM_BASE_ADDRESS + 0x08*4) // 4 bytes, BCD yyyymmdd
#define COMP_TIME           (SMEM_BASE_ADDRESS + 0x09*4) // 3 bytes  BCD 00hhmmss














// reset the state machines in the I2C master
void i2c_reset(void);
// start an i2c write, 1 to 4 bytes
void     i2c_start_write(uint32_t slv_addr, int nwbytes, uint32_t wdata);
// start an i2c read, 1 to 4 bytes
void     i2c_start_read(uint32_t slv_addr, int nrbytes);
// start an i2c write with 1 to 4 bytes, then after repeated start a read with 1 to 4 bytes
void     i2c_start_write_read(uint32_t slv_addr, int nwbytes, uint32_t wdata, int nrbytes);
// check if the corresponding I2C master is not busy, return 1 when ready and 0 when busy
int      i2c_check_rdy(void);
// wait until the I2C master is ready, returns 1 when timeout, otherwise 0
int      i2c_wait_rdy(void);
// get the already received data
// if necessary to wait - use i2c_check_rdy() or i2c_wait_rdy() functions above!
uint32_t i2c_get_read(void);


// turn on/off the software LED
void set_led(uint32_t a, uint32_t blink);
//
// read the 4-bit DIP switch
//uint32_t get_dip_sw();
//
// Timer in FPGA design, send a command (see the .h file for details)
void timer_cmd(uint32_t tmr_cmd);
// read the timer, 0 is the current time (eventually running)
// 1..3 are the 3 latches 0..2 (see the header file)
uint32_t timer_rd(uint32_t ch);

// start the CRC check of the FPGA configuration
void start_fpga_crc_check();

// get the FPGA CRC check result bytes
uint32_t get_fpga_crc_check();
