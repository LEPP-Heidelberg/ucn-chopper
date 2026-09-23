// $Id: uart_send.h 1216 2026-09-02 16:57:27Z  $:

#ifndef _UART_SEND
#define _UART_SEND

#include "system_conf.h"
#include "../C/my_types.h"

#define TXD_BASE_ADDRESS  (SLAVE_PASSTHRU_BASE_ADDRESS + 0x0080*4)

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
#define TXD_BIT_STA_NEMPTY  3      //  r
#define TXD_MSK_STA_NEMPTY  (1 << TXD_BIT_STA_NEMPTY)      //  r
#define TXD_BIT_STA_SIZE    4      //  r, in bits 7..4 is the number of address bits in the TX FIFO

#define ASCII_LF  0x0A

// UART functions

// init - clear the FIFO
void send_txd_ini();

// send the byte in a as ASCII text
void send_ascii(uint32_t a);

// these functions call the software CRC if enabled
// send a single byte
void send_byte(uint32_t a);
// send two bytes, first the MSByte, then the LSByte
void send_word(uint32_t dat);
// send 3 bytes
void send_24word(uint32_t dat);
// send 4 bytes
void send_dword(uint32_t dat);
// wait until the UART FIFO is empty
int wait_txd_rdy();

// initialize the CRC8 register
void send_crc8_init();
// send the CRC8 register
void send_crc8();
// read the accumulated in hardware CRC8
uint32_t get_txd_crc8();

#endif
