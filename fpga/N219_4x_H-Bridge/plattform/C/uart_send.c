// $Id: uart_send.c 1216 2026-09-02 16:57:27Z  $:

#include "uart_send.h"
#include "../C/my_types.h"

// register doesn't bring anything more, probably the compiler anyway uses register
// using int instead of uint8_t brings some speedup
// using void instead of int as function return brings some speedup

void send_ascii(uint32_t a)
{
    IO_WRITE(TXD_ASCII, a);
    return;
}

void send_byte(uint32_t a)
{   // the UART TX uses only bits 7..0
    IO_WRITE(TXD_BYTE, a);
    return;
}

void send_word(uint32_t dat)
{
    send_byte(dat >>  8);
    send_byte(dat >>  0);
    return;
}

void send_24word(uint32_t dat)
{
    send_byte(dat >> 16);
    send_byte(dat >>  8);
    send_byte(dat >>  0);
    return;
}

void send_dword(uint32_t dat)
{
    send_byte(dat >> 24);
    send_byte(dat >> 16);
    send_byte(dat >>  8);
    send_byte(dat >>  0);
    return;
}

void send_txd_ini()
{
    // write 0 to this register clears the state machine & FIFO
    // and turns off the turbo mode (is anyway not awaylable in this design)
    IO_WRITE(TXD_STA, 0);
    return;
}

// only for debugging
uint32_t get_txd_crc8()
{
    return IO_READ(TXD_CRC8_INI);
}

void send_crc8_init()
{
    // write here anything to initialize the CRC8 register
    IO_WRITE(TXD_CRC8_INI, 0);
    return;
}

void send_crc8()
{
    // write here anything to send the accumulated CRC8 checksum
    IO_WRITE(TXD_CRC8, 0);
    return;
}

int wait_txd_rdy()
{
    uint32_t sta;

    do
    {
        sta = IO_READ(TXD_STA);
    } while (sta & TXD_MSK_STA_NEMPTY);
    // eventually return timeout?
    return 0;
}

