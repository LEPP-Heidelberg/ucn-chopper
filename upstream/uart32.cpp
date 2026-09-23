#include "uart32.h"

#include <cstdio>   /* Standard input/output definitions, for perror() */

// $Id: uart32.cpp 1001 2023-09-06 18:28:17Z angelov $:

uart32::~uart32() {}


int uart32::SendBurst(uint16_t psize, uint8_t ainc, uint8_t full, uint32_t saddr, uint8_t *p_Byte)
{
    void *pt;
    pt = p_Byte;
    return SendBurst(psize, ainc, full, saddr, pt, WSIZE_BYTE);
}

int uart32::SendBurst(uint16_t psize, uint8_t ainc, uint8_t full, uint32_t saddr, uint16_t *p_Word)
{
    void *pt;
    pt = p_Word;
    return SendBurst(psize, ainc, full, saddr, pt, WSIZE_WORD);
}

int uart32::SendBurst(uint16_t psize, uint8_t ainc, uint8_t full, uint32_t saddr, int16_t *p_Word)
{
    void *pt;
    pt = p_Word;
    return SendBurst(psize, ainc, full, saddr, pt, WSIZE_WORD);
}

int uart32::SendBurst24(uint16_t psize, uint8_t ainc, uint8_t full, uint32_t saddr, uint32_t *p_DWord)
{
    void *pt;
    pt = p_DWord;
    return SendBurst(psize, ainc, full, saddr, pt, WSIZE_3_BT);
}

int uart32::SendBurst24(uint16_t psize, uint8_t ainc, uint8_t full, uint32_t saddr, int32_t *p_DWord)
{
    void *pt;
    pt = p_DWord;
    return SendBurst(psize, ainc, full, saddr, pt, WSIZE_3_BT);
}

int uart32::SendBurst(uint16_t psize, uint8_t ainc, uint8_t full, uint32_t saddr, uint32_t *p_DWord)
{
    void *pt;
    pt = p_DWord;
    return SendBurst(psize, ainc, full, saddr, pt, WSIZE_DWORD);
}

int uart32::SendBurst(uint16_t psize, uint8_t ainc, uint8_t full, uint32_t saddr, int32_t *p_DWord)
{
    void *pt;
    pt = p_DWord;
    return SendBurst(psize, ainc, full, saddr, pt, WSIZE_DWORD);
}

// function to send a Burst of any size and word size.
int uart32::SendBurst(uint16_t psize, uint8_t ainc, uint8_t full, uint32_t saddr, void *p_Data, uint8_t wsize)
{
    int i, j, bsize;
    uint8_t *header, *header_new;
    uint8_t*  p_Bytes;
    uint16_t* p_Words;
    uint16_t  wd;
    uint32_t* p_DWords;
    uint32_t  dw;

    if (psize > BLOCK_SMALL_PROT_SIZE)
        full = 1;

    if (psize > BLOCK_MAX_PROT_SIZE)
    {
        printf("Invalid block size!!!\n");
        return 1;
    }

    full &= 1;
    ainc &= 1;
    wsize &= 3;
    psize--;
    psize &= (BLOCK_MAX_PROT_SIZE-1); // 11 b¡t
    bsize=(psize+1)*(1+wsize);  // byte size same as packet size or x2, x3, x4

    if ( (bsize <= SHORT_BUFF_LEN) || (wsize==WSIZE_3_BT) )
        header_new = new uint8_t[bsize+8];
    else
        header_new = new uint8_t[8];

    header = header_new;

    p_Bytes =(uint8_t*) p_Data;


    if(DEBUG_UART32)
        printf("SendBurst, Word size %d, packet_size-1 %d, bytes %d, start address 0x%06x, autoincrement %d, full %d\n", wsize+1, psize, bsize, saddr, ainc, full);

    j=0;

    if (slave_mask > 0)
        header[j++] = slave_mask & 0xFF;

    //        full trans?      auto incr?     block size 2..0       word size-1  r1/w0
    header[j++]=(full << 7) | (ainc << 6) | ( (psize & 0x7) << 3) | (wsize << 1) | 0 ;

    if (full)
    {
        header[j++] = psize >> 3;
    }

    header[j++] = saddr & 0xFF;

    if (full)
    {
        header[j++] = (saddr >>  8) & 0xFF;
        if (max_asize > MAX_ASIZE_SMALL)
            header[j++] = (saddr >> 16) & 0xFF;
    }

    if(DEBUG_UART32)
    {
        printf("# The size of the header is %d bytes\n", j);
        printf("# SendBurst : send the header of %d bytes ", j);
        for (i=0; i<j; i++) printf(" 0x%02x", header[i]);
        printf("\n");
    }

    if ( (bsize <= SHORT_BUFF_LEN) || (wsize==WSIZE_3_BT) )
    {   // copy the data bytes to the array
        switch (wsize)
        {
            case WSIZE_WORD:
                p_Words = (uint16_t*) p_Data;
                break;
            case WSIZE_3_BT:
            case WSIZE_DWORD:
                p_DWords = (uint32_t*) p_Data;
                break;
            default:
                break;
        }
        // psize is already decremented by 1, therefore the loop is from 0 to incl. psize!!!
        for (i=0; i<=psize; i++)
            switch (wsize)
            {
                case WSIZE_BYTE:
                    header[j++]=*p_Bytes++;
                    break;
                case WSIZE_WORD:
                    wd=*p_Words++;
                    header[j++]=wd & 0xFF;
                    header[j++]=wd >> 8;
                    break;
                case WSIZE_3_BT:
                    dw=*p_DWords++;
                    header[j++]=dw & 0xFF;
                    dw >>= 8;
                    header[j++]=dw & 0xFF;
                    dw >>= 8;
                    header[j++]=dw & 0xFF;
                    break;
                case WSIZE_DWORD:
                    dw=*p_DWords++;
                    header[j++]=dw & 0xFF;
                    dw >>= 8;
                    header[j++]=dw & 0xFF;
                    dw >>= 8;
                    header[j++]=dw & 0xFF;
                    dw >>= 8;
                    header[j++]=dw;
                    break;
                default:
                    break;
            }
    }
    //ClearReadBuff();
    // here we have to send the header evntually larger block(s) (when 24-bit data)
    while (j > BLOCK_MAX_SIZE)
    {
        // in small pieces
        WriteBuffer(header, BLOCK_MAX_SIZE);
        header += BLOCK_MAX_SIZE;
        j      -= BLOCK_MAX_SIZE;
        if(DEBUG_UART32)
            printf("# Send a large packet %d, remaining bytes %d\n", BLOCK_MAX_SIZE, j);
    }

    // send the rest of the data if anything left (in case of 24-bit data)
    if (j > 0)
    {
        WriteBuffer(header, j);
        if(DEBUG_UART32)
            printf("# Send the rest %d bytes\n", j);
    }
    delete [] header_new;
    // exit if all data were sent
    if ( (bsize <= SHORT_BUFF_LEN) || (wsize==WSIZE_3_BT) )
    {
        if(DEBUG_UART32)
            printf("# The packet was short %d, now exit\n", bsize);
        return 0;
    }

    // here we have to send larger block(s) directly using the pointer to the input data
    while (bsize > BLOCK_MAX_SIZE)
    {
        // in small pieces
        WriteBuffer(p_Bytes, BLOCK_MAX_SIZE);
        p_Bytes += BLOCK_MAX_SIZE;
        bsize   -= BLOCK_MAX_SIZE;
    }

    // here we send the rest of the data directly using the pointer to the input data
    if (bsize > 0)
        WriteBuffer(p_Bytes, bsize);

    return 0; // finished
}

int uart32::RecvBurst(uint16_t psize, uint8_t ainc, uint8_t full, uint32_t saddr, uint8_t *p_Byte)
{
    void *pt;
    pt = p_Byte;
    return RecvBurst(psize, ainc, full, saddr, pt, WSIZE_BYTE);
}

int uart32::RecvBurst(uint16_t psize, uint8_t ainc, uint8_t full, uint32_t saddr, uint16_t *p_Word)
{
    void *pt;
    pt = p_Word;
    return RecvBurst(psize, ainc, full, saddr, pt, WSIZE_WORD);
}

int uart32::RecvBurst(uint16_t psize, uint8_t ainc, uint8_t full, uint32_t saddr, int16_t *p_Word)
{
    void *pt;
    pt = p_Word;
    return RecvBurst(psize, ainc, full, saddr, pt, WSIZE_WORD);
}

int uart32::RecvBurst24(uint16_t psize, uint8_t ainc, uint8_t full, uint32_t saddr, uint32_t *p_DWord)
{
    void *pt;
    pt = p_DWord;
    return RecvBurst(psize, ainc, full, saddr, pt, WSIZE_3_BT);
}

int uart32::RecvBurst24(uint16_t psize, uint8_t ainc, uint8_t full, uint32_t saddr, int32_t *p_DWord)
{
    int i, e;
    void *pt;
    pt = p_DWord;
    e = RecvBurst(psize, ainc, full, saddr, pt, WSIZE_3_BT);
    for (i=0; i<psize; i++) // now sign extension from 24 to 32 bits
    {
        if ( ( *p_DWord >> 23) & 1) *p_DWord |= 0xFF000000;
        p_DWord++;
    }
    return e;
}

int uart32::RecvBurst(uint16_t psize, uint8_t ainc, uint8_t full, uint32_t saddr, uint32_t *p_DWord)
{
    void *pt;
    pt = p_DWord;
    return RecvBurst(psize, ainc, full, saddr, pt, WSIZE_DWORD);
}

int uart32::RecvBurst(uint16_t psize, uint8_t ainc, uint8_t full, uint32_t saddr, int32_t *p_DWord)
{
    void *pt;
    pt = p_DWord;
    return RecvBurst(psize, ainc, full, saddr, pt, WSIZE_DWORD);
}

int uart32::RecvBurst(uint16_t psize, uint8_t ainc, uint8_t full, uint32_t saddr, void *p_Data, uint8_t wsize)
{
    int j, bsize, i;

    uint8_t *header, *header_new;
    uint8_t *p_Bytes, *p_Bytes_new;
    uint32_t  dw[3];

    if (psize > BLOCK_SMALL_PROT_SIZE)
        full = 1;

    if (psize > BLOCK_MAX_PROT_SIZE)
    {
        printf("Invalid block size!!!\n");
        return 1;
    }


    full &= 1;
    ainc &= 1;
    wsize &= 3;
    psize--;
    psize &= (BLOCK_MAX_PROT_SIZE-1) ; // 11 b¡t
    bsize=(psize+1)*(1+wsize);  // byte size same as packet size or x2, x3, x4

    if(DEBUG_UART32)
        printf("RecvBurst, Word size %d, packet_size-1 %d, bytes %d, start address 0x%06x, autoincrement %d, full %d\n", wsize+1, psize, bsize, saddr, ainc, full);

    // memory for the header, there are 5 bytes in the header, but we take 8
    header_new = new uint8_t[8];
    header = header_new;
    if (wsize==WSIZE_3_BT)
    {
        // + memory for the received data in case of 24-bit data words in a local buffer
        p_Bytes_new = new uint8_t[bsize];
        p_Bytes = p_Bytes_new;
    }
    else
        // use directly the return data in case of 8, 16, 32 bit data words
        p_Bytes =(uint8_t*) p_Data;


    j=0;

    if (slave_mask > 0)
        header[j++] = slave_mask & 0xFF;

    //        full trans?      auto incr?     block size 2..0       word size-1  r1/w0
    header[j++]=(full << 7) | (ainc << 6) | ( (psize & 0x7) << 3) | (wsize << 1) | 1 ;

    if (full)
    {
        header[j++] = psize >> 3;
    }

    header[j++] = saddr & 0xFF;

    if (full)
    {
        header[j++] = (saddr >>  8) & 0xFF;
        if (max_asize > MAX_ASIZE_SMALL)
            header[j++] = (saddr >> 16) & 0xFF;
    }

    //ClearReadBuff();
    // send the header
    if(DEBUG_UART32)
    {
        printf("# RecvBurst : send the header of %d bytes ", j);
        for (i=0; i<j; i++) printf(" 0x%02x", header[i]);
        printf("\n");
    }

    WriteBuffer(header, j);
    delete [] header_new;

    // here we have to receive several large block(s)
    while (bsize > BLOCK_MAX_SIZE)
    {
        // in pieces of limited size
        ReadBuffer(p_Bytes, BLOCK_MAX_SIZE);
        p_Bytes += BLOCK_MAX_SIZE;
        bsize   -= BLOCK_MAX_SIZE;
    }

    // receive the rest
    if (bsize > 0)
        ReadBuffer(p_Bytes, bsize);

    if (wsize == WSIZE_3_BT)
    {
        p_Bytes  = p_Bytes_new;
        uint32_t* p_DWords = (uint32_t*) p_Data;
        // now convert back the bytes into 24-bit words
        for (j=0; j<=psize; j++)
        {
            dw[0] = *p_Bytes++;
            dw[1] = *p_Bytes++;
            dw[2] = *p_Bytes++;
            dw[2] <<= 8;
            dw[2] |= dw[1];
            dw[2] <<= 8;
            dw[2] |= dw[0];
            *p_DWords++ = dw[2];
        }
        delete [] p_Bytes_new;
    }

    return 0;
}

uint8_t uart32::ReadByte(uint32_t saddr)
{
    uint8_t mybyte;

    RecvBurst(1, 1, 1, saddr, &mybyte);

    return mybyte;
}

uint16_t uart32::ReadWord(uint32_t saddr, uint8_t use_wsize)
{
    uint16_t res;

    if (use_wsize >= WSIZE_DEFAULT) use_wsize=max_wsize;

    if (use_wsize > WSIZE_BYTE)
        RecvBurst(1, 1, 1, saddr, &res);
    else
    {
        uint8_t res8[2];
        RecvBurst(2, 1, 1, saddr, res8);
        res = res8[1];
        res <<= 8;
        res |= res8[0];
    }

    return res;
}

uint32_t uart32::Read3Bytes(uint32_t saddr, uint8_t use_wsize)
{
    uint32_t res;

    if (use_wsize >= WSIZE_DEFAULT) use_wsize=max_wsize;
    switch (use_wsize)
    {
        case WSIZE_BYTE:
            uint8_t  res8[4];
            RecvBurst(3, 1, 1, saddr, res8);
            res = res8[2];
            res <<= 8;
            res |= res8[1];
            res <<= 8;
            res |= res8[0];
            break;
        case WSIZE_WORD:
            uint16_t res16[2];
            RecvBurst(2, 1, 1, saddr, res16);
            res = res16[1];
            res <<= 16;
            res |= res16[0];
            break;
        case WSIZE_3_BT:
        case WSIZE_DWORD:
            RecvBurst24(1, 1, 1, saddr, &res);
    }

    return res;
}

uint32_t uart32::ReadDWord(uint32_t saddr, uint8_t use_wsize)
{
    uint32_t res;
    if (use_wsize >= WSIZE_DEFAULT) use_wsize=max_wsize;
    switch (use_wsize)
    {
        case WSIZE_BYTE:
            uint8_t  res8[4];
            RecvBurst(4, 1, 1, saddr, res8);
            res = res8[3];
            res <<= 8;
            res |= res8[2];
            res <<= 8;
            res |= res8[1];
            res <<= 8;
            res |= res8[0];
            break;
        case WSIZE_WORD:
            uint16_t res16[2];
            RecvBurst(2, 1, 1, saddr, res16);
            res = res16[1];
            res <<= 16;
            res |= res16[0];
            break;
        case WSIZE_3_BT:
        case WSIZE_DWORD:
            RecvBurst(1, 1, 1, saddr, &res);
    }

    return res;
}

int uart32::WriteByte(uint32_t saddr, uint8_t wdata)
{
    if(DEBUG_UART32)
        printf("write byte, internal address=0x%06x, data=0x%02x\n", saddr, wdata);

    return SendBurst(1, 1, 1, saddr, &wdata);
}

int uart32::WriteWord(uint32_t saddr, uint16_t wdata, uint8_t use_wsize)
{
    if (use_wsize >= WSIZE_DEFAULT) use_wsize=max_wsize;

    if(DEBUG_UART32)
        printf("write word, internal address=0x%06x, data=0x%04x\n", saddr, wdata);

    if (use_wsize > WSIZE_BYTE)
        return SendBurst(1, 1, 1, saddr, &wdata);
    else
    {
        uint8_t bt[2];
        bt[0] = wdata & 0xFF;
        bt[1] = wdata >> 8;
        return SendBurst(2, 1, 1, saddr, bt);
    }

}

int uart32::Write3Bytes(uint32_t saddr, uint32_t wdata, uint8_t use_wsize)
{
    if (use_wsize >= WSIZE_DEFAULT) use_wsize=max_wsize;

    if(DEBUG_UART32)
        printf("write 24-bit word, internal address=0x%06x, data=0x%06x\n", saddr, wdata);

    switch (use_wsize)
    {
        case WSIZE_3_BT:
        case WSIZE_DWORD:
            return SendBurst24(1, 1, 1, saddr, &wdata);

        case WSIZE_WORD:
            uint16_t w[2];
            w[0] = wdata & 0xFFFF;
            wdata >>= 16;
            w[1] = wdata & 0xFF;
            return SendBurst(2, 1, 1, saddr, w);

        case WSIZE_BYTE:
            uint8_t bt[4];
            bt[0] = wdata & 0xFF;
            wdata >>= 8;
            bt[1] = wdata & 0xFF;
            wdata >>= 8;
            bt[2] = wdata & 0xFF;
            return SendBurst(3, 1, 1, saddr, bt);
    }
    return 0;
}

int uart32::WriteDWord(uint32_t saddr, uint32_t wdata, uint8_t use_wsize)
{
    if(DEBUG_UART32)
        printf("write word, internal address=0x%06x, data=0x%08x\n", saddr, wdata);

    if (use_wsize >= WSIZE_DEFAULT) use_wsize=max_wsize;

    switch (use_wsize)
    {
        case WSIZE_3_BT:
        case WSIZE_DWORD:
            return SendBurst(1, 1, 1, saddr, &wdata);

        case WSIZE_WORD:
            uint16_t w[2];
            w[0] = wdata & 0xFFFF;
            wdata >>= 16;
            w[1] = wdata & 0xFF;
            return SendBurst(2, 1, 1, saddr, w);

        case WSIZE_BYTE:
            uint8_t bt[4];
            bt[0] = wdata & 0xFF;
            wdata >>= 8;
            bt[1] = wdata & 0xFF;
            wdata >>= 8;
            bt[2] = wdata & 0xFF;
            wdata >>= 8;
            bt[3] = wdata & 0xFF;
            return SendBurst(4, 1, 1, saddr, bt);
    }
    return 0;
}

int uart32::WriteAuto(uint32_t saddr, uint32_t wdata)
{
        if (wdata >> 24) return WriteDWord( saddr, wdata);
        if (wdata >> 16) return Write3Bytes(saddr, wdata);
        if (wdata >>  8) return WriteWord(  saddr, wdata);
        return WriteByte(saddr, wdata);
}


int uart32::push_slave_mask(int smask)
{
    if (smask_wp < SLV_MASK_PIPE_LEN)
    {
        slave_mask_pipe[smask_wp++] = slave_mask;
        slave_mask = smask;
    }
    else
        printf("# Error! Overflow in push_slave_mask! Old mask %d, new mask %d, wpointer %d\n",
            slave_mask, smask, smask_wp);
    return slave_mask;
}

int uart32::pop_slave_mask()
{
    if (smask_wp > 0)
    {
        slave_mask = slave_mask_pipe[--smask_wp];
    }
    else
        printf("# Error! Overflow in pop_slave_mask! Old mask %d, wpointer %d\n",
            slave_mask, smask_wp);
    return slave_mask;
}

int uart32::set_slave_mask(int smask)
{
    slave_mask = smask;
    return slave_mask;
}

int uart32::get_slave_mask()
{
    return slave_mask;
}

int uart32::set_max_wsize(int wsize)
{
    wsize = (wsize-1)/8;
    max_wsize = wsize & 3;
    if (max_wsize == WSIZE_3_BT) max_wsize = WSIZE_DWORD;
    return wsize;
}

int uart32::get_max_wsize()
{
    return max_wsize;
}

int uart32::set_max_asize(int asize)
{
    if (asize > MAX_ASIZE_SMALL)
        asize = MAX_ASIZE_LARGE;
    else
        asize = MAX_ASIZE_SMALL;

    max_asize = asize;

    return asize;
}

int uart32::get_max_asize()
{
    return max_asize;
}

/* END OF uart32 CLASS */
