// $Id: C_dual_dac.cpp 1222 2026-09-16 14:00:13Z  $:

#include "iostream"
#include "ctime"
#include "../upstream/uart32.h"
#include "C_dual_dac.h"
#include "dac_mcp47feb.h"
//#include <math.h>

#ifdef _WIN32
        #define sleep Sleep
#endif

C_dual_dac::~C_dual_dac()
{
}

C_dual_dac::C_dual_dac(uart32* p_uart32, uint32_t new_base_addr, uint8_t new_debug)
{
    m_uart32 = p_uart32;
    debug = new_debug;
    base_addr = new_base_addr;
    i2c_timeout = 0;
}

// I2C functions

// write 1-4 bytes
uint32_t C_dual_dac::i2c_write(int slv_addr, int nbytes, uint32_t wdata, int debug)
{
    uint32_t wbuf[2];

    if (debug)
    {
        logWrite("# Start I2C master at address 0x%08x: write %d bytes 0x%08x to slave 0x%02x\n", base_addr, nbytes, wdata, slv_addr);
    }

    nbytes--;
    nbytes &= 3;

    wbuf[0] = wdata;
    wbuf[1] = (slv_addr & 0xFE) | (I2C_CMD_NULL << I2C_BIT_CMD) | (nbytes << I2C_BIT_LEN1);

    m_uart32->SendBurst(2, 1, 1, base_addr, wbuf);

    return 0;
}

// write up to 4 bytes, repeated start & read up to 4 bytes
uint32_t C_dual_dac::i2c_write_read(int slv_addr, int nwbytes, uint32_t wdata, int nrbytes, int debug)
{
    uint32_t wbuf[2];

    if (debug)
    {
        logWrite("# Start I2C master at address 0x%08x: write %d bytes 0x%08x to slave 0x%02x, then read %d bytes\n", base_addr, nwbytes, wdata, slv_addr, nrbytes);
    }

    nwbytes--;
    nrbytes--;
    nwbytes &= 3;
    nrbytes &= 3;

    wbuf[0] = wdata;
    wbuf[1] = (slv_addr & 0xFE) | (I2C_CMD_RSTRT << I2C_BIT_CMD) | (nwbytes << I2C_BIT_LEN1) | (nrbytes << I2C_BIT_LEN2);

    m_uart32->SendBurst(2, 1, 1, base_addr, wbuf);

    return 0;
}

uint32_t C_dual_dac::i2c_reset(int debug)
{
    if (debug)
    {
        logWrite("# Reset I2C master at address 0x%08x\n", base_addr);
    }

    WriteReg(4, I2C_OFFS_CMD_STA, I2C_MSK_RESET);

    return 0;
}

// read 1-4 bytes
uint32_t C_dual_dac::i2c_read(int slv_addr, int nbytes, int debug)
{
    uint32_t wbuf;

    if (debug)
    {
        logWrite("# Start I2C master at address 0x%08x: read %d bytes from slave 0x%02x\n", base_addr, nbytes, slv_addr);
    }

    nbytes--;
    nbytes &= 3;

    wbuf = (slv_addr | 0x01) | (I2C_CMD_NULL << I2C_BIT_CMD) | (nbytes << I2C_BIT_LEN1);
    WriteReg(4, I2C_OFFS_CMD_STA, wbuf);

    return 0;
}


// wait until i2c master is ready, return 1 in case of timeout
uint32_t C_dual_dac::i2c_wait_rdy(int debug)
{
    uint32_t status, cnt;

    cnt = 100; // may be too high, one status read takes about 1 ms
    do
    {
        status = ReadReg(4, I2C_OFFS_CMD_STA);
        cnt--;
    } while ( ( (status & I2C_MSK_SMS_BUSY) != 0) && (cnt > 0) );

    if (debug)
    {
        logWrite("# Wait until I2C master at address 0x%08x ready, status is 0x%08x ...", base_addr, status);
        logWrite("# SM Busy %d, I2C timeout %d, StateM %d, StateS %d, Len1 %d, Len2 %d, Cmd %d, SA 0x%02x\n", (status >> 28) & 1,
            (status >> I2C_BIT_TIMEOUT) & 1,
            (status >> 20) & 0xF,
            (status >> 16) & 0xF,
            (status >> 12) & 0x3,
            (status >> 14) & 0x3,
            (status >>  8) & 0x7,
            (status >>  0) & 0xFF);
        if (cnt == 0) logWrite(" Timeout!\n");
        else
                      logWrite(" Done (cnt=%d).\n", cnt);
    }
    i2c_timeout = ( (status >> I2C_BIT_TIMEOUT) & 1);
    return (cnt == 0) | i2c_timeout;
}

// get the result of the last read transaction, you should wait before for the master to be ready!
uint32_t C_dual_dac::i2c_get_rdata(int debug)
{
    uint32_t rbuf[2], len, cmd;

    // offset 0 is read data, offset 1 is status
    m_uart32->RecvBurst(2, 1, 1, base_addr + I2C_OFFS_RDAT, rbuf);

    cmd = (rbuf[1] >> I2C_BIT_CMD) & 7; // 3 bits

    if (cmd == I2C_CMD_RSTRT)   // repeated start, the length is the lenght of the second part of the transaction
        len = (rbuf[1] >> I2C_BIT_LEN2) & 3;
    else                        // normal read, the length is the lenght of the first part of the transaction
        len = (rbuf[1] >> I2C_BIT_LEN1) & 3;
//    dmask = 0xFFFFFFFF;         // full mask for 32 bits
//    dmask >>= 8*(3-len);        // shift the mask right depending on the length, here len is from 0 to 3

    len++;                      // now is from 1 to 4

    if (debug)
    {
        logWrite("# I2C master with base address 0x%08x received %d bytes ", base_addr, len);
        if (len > 3) logWrite(" 0x%02x", (rbuf[0] >> 24)        );
        if (len > 2) logWrite(" 0x%02x", (rbuf[0] >> 16) & 0xFF );
        if (len > 1) logWrite(" 0x%02x", (rbuf[0] >>  8) & 0xFF );
        logWrite(             " 0x%02x\n",rbuf[0]        & 0xFF );
    }
    return rbuf[0]; // & dmask;
}

// MCP47FEB21 & MCP47FEB22 functions

// chip_nr is 0 - hysteresis & threshold (in MCP47FEB22), 1 - HV (in MCP47FEB21)
// dac_rg  is 0..0x0F for volatile and 0x10..0x1F for non-volatile registers
// ch      is 0..7
uint32_t C_dual_dac::i2c_read_dac_rg(uint32_t dac_rg, int debug)
{
    uint32_t wdata, rdata;

    dac_rg &= 0x1F;

    wdata =  (dac_rg << 3) | 6;
    i2c_write_read(I2C_SLAVE_DUAL_DAC, 1, wdata, 2, debug >> 1);
    i2c_timeout = i2c_wait_rdy(0);
    rdata = i2c_get_rdata(debug);
    if (debug)
    {
        logWrite("# Read from DAC register 0x%02x, wdata 0x%02x => 0x%04x\n", dac_rg, wdata, rdata);
    }
    return rdata;
}

// dac_rg   0..0x0F for volatile and 0x10..0x1F for non-volatile registers
// wdata    write data, only 2 bytes will be used
// wait     flag to wait until the transaction is done
uint32_t C_dual_dac::i2c_write_dac_rg(uint32_t dac_rg, uint32_t wdata, int wait, int debug)
{
    dac_rg &= 0x1F;

    i2c_reset(debug);

    wdata &= 0xFFFF;
    wdata |=  ((dac_rg << 3) | 0) << 16;
    i2c_write(I2C_SLAVE_DUAL_DAC, 3, wdata, debug);
    if (debug)
    {
        logWrite("# I2C-write: Command 0x%02x, WriteDat 0x%04x\n", wdata >> 16, wdata & 0xFFFF);
    }
    if (wait)
    {
        i2c_wait_rdy(0);
        if (dac_rg & MCP47FEB_NV_MEM) // writing to non-volatile memory takes up to 16 ms
            usleep(20000);
    }
    return 0;
}

float C_dual_dac::dac_ref(int dac_ref_rg_bits, int debug)
{
    float vref;
    dac_ref_rg_bits &= 3;
    switch (dac_ref_rg_bits)
    {
        case DAC_VREF_VDD: vref=3.3; break;
        case DAC_VREF_INT: vref=MCP47FEB_VREF; break;
        case DAC_VREF_IN_UNB:
        case DAC_VREF_IN_BUF: vref=3.3;
    }
    if (debug)
        logWrite("# DAC Vref=%0.3f\n", vref);
    return vref;
}

float C_dual_dac::dac_to_v(uint16_t dac, int dac_ref_rg_bits, int debug)
{
    float v, vref;
    vref = dac_ref(dac_ref_rg_bits, debug);
    v = DAC2V(dac, vref);
    if (debug)
        logWrite("# DAC_code = 0x%03x, DAC_Ref=%0.3f => V = %0.3f\n", dac, vref, v);
    return v;
}

// calculate the DAC value for the HV
uint16_t C_dual_dac::v_to_dac(float vin, int dac_ref_rg_bits, int debug)
{
    int dac;
    double v, vref;
    vref = dac_ref(dac_ref_rg_bits, debug);

    v = vin - DAC2V_OFFSET;
    v  = v/DAC2V_SLOPE(vref);
    dac = (int) (v + 0.5);
    if (dac <    0) dac =    0;
    if (dac > DAC_MAX_CODE) dac = DAC_MAX_CODE;
    if (debug)
        logWrite("# Requested V %0.3f V, DAC code %d or 0x%03x, expected V %0.3f\n", vin, dac, dac, dac_to_v(dac, dac_ref_rg_bits, 0) );
    return dac;
}

int C_dual_dac::init_dac_ref(int used_ref, int write2eep, int debug)
{
    if (write2eep)
        write2eep = MCP47FEB_NV_MEM;
    else
        write2eep = 0;

    used_ref &= 3;
    used_ref |= (used_ref << 2); // for both DACs same reference
    i2c_write_dac_rg(MCP47FEB_RG_VREF | write2eep, used_ref, 1, debug);
    if (last_i2c_timeout())
    {
        logWrite("# I2C timeout, probably DAC not present!\n");
        return -1;
    }
    return 0;
}


int C_dual_dac::set_dac(int ch, int dac, int write2eep, int debug)
{
    if (write2eep)
        write2eep = MCP47FEB_NV_MEM;
    else
        write2eep = 0;

    ch &= 1;
    if (SWAP_CH0_CH1) ch = 1-ch;
    i2c_write_dac_rg(MCP47FEB_RG_DAC0 | write2eep | ch, dac, 1, debug);
    if (last_i2c_timeout())
    {
        logWrite("# I2C timeout writing to DAC!\n");
        return -1;
    }
    return 0;
}

int C_dual_dac::set_dac_volt(int ch, float volt, int dac_ref_rg_bits, int write2eep, int debug)
{
    uint16_t dac;
    dac = v_to_dac(volt, dac_ref_rg_bits, debug);
    return set_dac(ch, dac, write2eep, debug);
}

uint32_t C_dual_dac::get_dacs(int debug)
{
    uint16_t dac[2], rg_ref;
    if (debug)
        rg_ref = i2c_read_dac_rg( MCP47FEB_RG_VREF, debug >> 1);

    for (int i=0; i<2; i++)
    {
        dac[i] = i2c_read_dac_rg( MCP47FEB_RG_DAC0+i, debug >> 1);
        if (debug)
        {
            logWrite("# H-bridge ch %d, VREF ", 1-i);
            dac_to_v(dac[i], rg_ref, debug);
            rg_ref >>= 2;
        }
    }
    return dac[0] | (dac[1] << 16);
}

uint8_t  C_dual_dac::WriteReg(uint8_t len, uint32_t addr, uint32_t wdata)
{
    addr += base_addr;
    switch (len)
    {
        case 1: { m_uart32->WriteByte(  addr, wdata &     0xFF); break; }
        case 2: { m_uart32->WriteWord(  addr, wdata &   0xFFFF); break; }
        case 3: { m_uart32->Write3Bytes(addr, wdata & 0xFFFFFF); break; }
        case 4: { m_uart32->WriteDWord( addr, wdata           ); break; }
        default:
        {
            logWrite("Illegal register length %d (must be from 1 to 4)!\n", len);
            return 1;
        }
    }
    return 0;
}

uint32_t C_dual_dac::ReadReg(uint8_t len, uint32_t addr)
{
    addr += base_addr;
    switch (len)
    {
        case 1: return m_uart32->ReadByte(  addr);
        case 2: return m_uart32->ReadWord(  addr); //, WSIZE_BYTE);
        case 3: return m_uart32->Read3Bytes(addr); //, WSIZE_BYTE);
        case 4: return m_uart32->ReadDWord( addr); //, WSIZE_BYTE);
        default:
        {
            logWrite("Illegal register length %d (must be from 1 to 4)!\n", len);
            return 0;
        }
    }
    return 0;
}
