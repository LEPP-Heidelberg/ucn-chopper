#ifndef __UART32_H__
#define __UART32_H__

// $Id: uart32.h 1096 2024-07-19 13:03:33Z angelov $:
//#define _ZYNQ

#include <stdint.h>
#include <string>

//#include "uart.h"

#ifdef _WIN32
        #include "uart_win.h"
#else
        #ifdef _ZYNQ
                #include "uart_zynq.h"
        #else
                #include "uart.h"
        #endif
#endif


#define BLOCK_MAX_SIZE        1024    // in bytes, for windows 2048 was too much!
#define BLOCK_MAX_PROT_SIZE   2048    // in words, can be bytes, 16-, 24-, 32-bit words
#define BLOCK_SMALL_PROT_SIZE    8    // in words, small packets can be send in short addressing mode

//#define SHORT_BUFF_LEN      256     // in bytes, when the data paket is not larger,
#define SHORT_BUFF_LEN      8     // in bytes, when the data paket is not larger,
                                    // will be sent at once with the protocol data

#define WSIZE_BYTE          0
#define WSIZE_WORD          1
#define WSIZE_3_BT          2
#define WSIZE_DWORD         3
#define WSIZE_DEFAULT       4

#define MAX_ASIZE_SMALL    16       // bits
#define MAX_ASIZE_LARGE    24

#define DEBUG_UART32    0
#define SLV_MASK_PIPE_LEN   16

class uart32 : public uart
{
private:
    int slave_mask;
    int max_wsize;  // max word size, WSIZE_BYTE, WSIZE_WORD or WSIZE_DWORD for 1, 2, 4 bytes in the data word
    int max_asize;  // max address size, 16 or 24 bit
    int smask_wp;
    int slave_mask_pipe[SLV_MASK_PIPE_LEN];
public:
    uart32(std::string device, uint32_t brate) : uart(device.c_str(), brate)
    {
        slave_mask = -1;
        smask_wp = 0;
        max_wsize  = WSIZE_DWORD;
        max_asize  = MAX_ASIZE_LARGE;
    };

    ~uart32();

    int set_slave_mask(int smask);
    int push_slave_mask(int smask);
    int pop_slave_mask();
    int get_slave_mask();

    int set_max_wsize(int wsize);
    int set_max_asize(int asize);
    int get_max_wsize();
    int get_max_asize();

    // write a burst of 1 to 2048 words
    int SendBurst( uint16_t psize, uint8_t ainc, uint8_t full, uint32_t saddr, void    *p_Data, uint8_t wsize);
    int SendBurst( uint16_t psize, uint8_t ainc, uint8_t full, uint32_t saddr, uint8_t *p_Byte);
    int SendBurst( uint16_t psize, uint8_t ainc, uint8_t full, uint32_t saddr, uint16_t *p_Word);
    int SendBurst( uint16_t psize, uint8_t ainc, uint8_t full, uint32_t saddr, int16_t *p_Word);
    int SendBurst24(uint16_t psize, uint8_t ainc, uint8_t full, uint32_t saddr, uint32_t *p_DWord);
    int SendBurst24(uint16_t psize, uint8_t ainc, uint8_t full, uint32_t saddr, int32_t *p_DWord);
    int SendBurst( uint16_t psize, uint8_t ainc, uint8_t full, uint32_t saddr, uint32_t *p_DWord);
    int SendBurst( uint16_t psize, uint8_t ainc, uint8_t full, uint32_t saddr, int32_t *p_DWord);
    // read a burst of 1 to 2048 words
    int RecvBurst(uint16_t psize, uint8_t ainc, uint8_t full, uint32_t saddr, void *p_Data, uint8_t wsize);
    int RecvBurst(uint16_t psize, uint8_t ainc, uint8_t full, uint32_t saddr, uint8_t *p_Byte);
    int RecvBurst(uint16_t psize, uint8_t ainc, uint8_t full, uint32_t saddr, uint16_t *p_Word);
    int RecvBurst(uint16_t psize, uint8_t ainc, uint8_t full, uint32_t saddr, int16_t *p_Word);
    int RecvBurst24(uint16_t psize, uint8_t ainc, uint8_t full, uint32_t saddr, uint32_t *p_DWord);
    int RecvBurst24(uint16_t psize, uint8_t ainc, uint8_t full, uint32_t saddr, int32_t *p_DWord);
    int RecvBurst(uint16_t psize, uint8_t ainc, uint8_t full, uint32_t saddr, uint32_t *p_DWord);
    int RecvBurst(uint16_t psize, uint8_t ainc, uint8_t full, uint32_t saddr, int32_t *p_DWord);
    // read a single data word of 1..4 bytes
    uint8_t  ReadByte(  uint32_t saddr);
    uint16_t ReadWord(  uint32_t saddr, uint8_t use_wsize=WSIZE_DEFAULT);
    uint32_t Read3Bytes(uint32_t saddr, uint8_t use_wsize=WSIZE_DEFAULT);
    uint32_t ReadDWord( uint32_t saddr, uint8_t use_wsize=WSIZE_DEFAULT);
        // write a single data word of 1..4 bytes
    int WriteByte(  uint32_t saddr, uint8_t  wdata);
    int WriteWord(  uint32_t saddr, uint16_t wdata, uint8_t use_wsize=WSIZE_DEFAULT);
    int Write3Bytes(uint32_t saddr, uint32_t wdata, uint8_t use_wsize=WSIZE_DEFAULT);
    int WriteDWord( uint32_t saddr, uint32_t wdata, uint8_t use_wsize=WSIZE_DEFAULT);
        // Use automatically one of the 4 functions above, depending on the data size.
    int WriteAuto(  uint32_t saddr, uint32_t wdata);

};

#endif /* __UART32_H__ */

