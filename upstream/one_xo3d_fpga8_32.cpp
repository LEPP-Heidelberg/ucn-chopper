// $Id: one_xo3d_fpga8_32.cpp 1212 2026-08-21 14:35:39Z  $:

#include "iostream"
#include "ctime"
#include "uart32.h"
#include "one_xo3d_fpga8_32.h"
#include <math.h>
#include <memory>

#include <cstring>  /* String function definitions */
#include <unistd.h>  /* UNIX standard function definitions, for close() */


one_xo3d_fpga8_32::one_xo3d_fpga8_32(uint8_t new_debug, uart32* p_uart32, uint32_t new_wb_base, uint32_t new_cfg_base)
{
    m_uart32 = p_uart32;
    debug = new_debug;
    fpga_size = 0; // unknown
    ufm_pages[0] = 0;
    ufm_pages[1] = 0;
    ufm_pages[2] = 0;
    ufm_pages[3] = 0;
    cfg_pages = 0;
    wb_base = new_wb_base;
    cfg_base = new_cfg_base;
    last_dev_id = 0;
}

one_xo3d_fpga8_32::~one_xo3d_fpga8_32() {}

void one_xo3d_fpga8_32::Debug(bool enable)
{
    debug = enable;
}

// EFB

int32_t  one_xo3d_fpga8_32::write_wb(uint8_t wb_addr, uint8_t wb_data)
{
    if(debug)
        logWrite("writing to addr 0x%02x data 0x%02x\n", wb_addr, wb_data);

//    return m_uart32->WriteByte(wb_base + (uint32_t) wb_addr, wb_data);
    return WriteReg(1, wb_base + (uint32_t) wb_addr, wb_data);
}

int32_t  one_xo3d_fpga8_32::write_wb(uint8_t wb_addr, uint8_t nbytes, uint8_t *wb_data)
{
    if(debug)
        logWrite("writing a burst of %d bytes to addr 0x%02x\n", nbytes, wb_addr);

    return m_uart32->SendBurst(nbytes, 0, 1, wb_base + (uint32_t) wb_addr, wb_data);
}

uint8_t  one_xo3d_fpga8_32::read_wb(uint8_t wb_addr)
{
//    return m_uart32->ReadByte(wb_base + (uint32_t) wb_addr);
    return ReadReg(1, wb_base + (uint32_t) wb_addr);
}

uint8_t  one_xo3d_fpga8_32::read_wb(uint8_t wb_addr, uint8_t nbytes, uint8_t *rd_data)
{
    return m_uart32->RecvBurst(nbytes, 0, 1, wb_base + (uint32_t) wb_addr, rd_data);
}


// MachXO3D-4300 0x01 2E 20 43
// MachXO3D-9400 0x21 2E 30 43

uint8_t one_xo3d_fpga8_32::check_dev_id(uint32_t dev_id, char *s)
{
    strcpy(s, "");

    if ( (dev_id != DEV_ID_MachXO3D_4300) && (dev_id != DEV_ID_MachXO3D_9400) )
    {
        sprintf(s, "The device ID 0x%08x differs from the expected 0x%08x or 0x%08x\n", dev_id, DEV_ID_MachXO3D_4300, DEV_ID_MachXO3D_9400);
        return 1;
    }
    else
        return 0;
}

uint32_t one_xo3d_fpga8_32::print_dev_id(uint32_t dev_id, char *s)
{
    if (check_dev_id(dev_id, s))
    {
        logWrite("%s\n", s);
        return 1;
    }

    switch (dev_id)
    {
        case DEV_ID_MachXO3D_4300 :
        {
            strcpy(s, "MachXO3D-4300");
            fpga_size = 4300;
            break;
        }
        case DEV_ID_MachXO3D_9400 :
        {
            strcpy(s, "MachXO3D-9400");
            fpga_size = 9400;
            break;
        }
    }
    return 0;
}

uint32_t one_xo3d_fpga8_32::pages_in_dev(uint8_t code_sec)
{
    return pages_in_dev(read_dev_id(), code_sec);
}

uint32_t one_xo3d_fpga8_32::pages_in_dev(uint32_t dev_id, uint8_t code_sec)
{
    char s[512];

    if (check_dev_id(dev_id, s))
    {
        logWrite("%s\n",s);
        return 0;
    }

    // independent on the device size
    ufm_pages[2] = XO3D_UFM2_PAGES;
    ufm_pages[3] = XO3D_UFM3_PAGES;

    switch (dev_id)
    {
        case DEV_ID_MachXO3D_4300 :
        {
            fpga_size = 4300;
            cfg_pages = XO3D_CFG_PAGES_4300;
            ufm_pages[0] = XO3D_UFM0_PAGES_4300;
            ufm_pages[1] = ufm_pages[0];
            break;
        }
        case DEV_ID_MachXO3D_9400 :
        {
            fpga_size =  9400;
            cfg_pages    = XO3D_CFG_PAGES_9400;
            ufm_pages[0] = XO3D_UFM0_PAGES_9400;
            ufm_pages[1] = ufm_pages[0];
            break;
        }
    }
    if (code_sec <= CODE_CFG1) return cfg_pages;
    else
    if (code_sec <= CODE_UFM3) return ufm_pages[code_sec - CODE_UFM0];
    else
    return 0;
}

uint8_t one_xo3d_fpga8_32::wb_reset()
{
    uint8_t my_bytes[2];

    my_bytes[0] = 0x40; // set the reset bit 6
    my_bytes[1] = 0x00; // clear the reset bit
    write_wb(WB_CFGCR, 2, my_bytes);

    return 0;
}

uint32_t one_xo3d_fpga8_32::wb_cnf_read(uint8_t cmd_code, uint32_t cmd_operand, uint8_t recv_length)
{
    uint32_t longw;
    uint8_t my_bytes[4], j;

    longw = 0;

    write_wb(WB_CFGCR, CFGCR_START_FRAME);  // start frame

    my_bytes[0] = cmd_code;
    my_bytes[1] = (cmd_operand >> 16) & 0xFF;
    my_bytes[2] = (cmd_operand >>  8) & 0xFF;
    my_bytes[3] =  cmd_operand        & 0xFF;

    write_wb(WB_CFGTXDR, 4, my_bytes);

    // read 4 bytes
    if (recv_length > 4)
        recv_length = 4;
    if (recv_length < 1)
        recv_length = 1;

    read_wb(WB_CFGRXDR, recv_length, my_bytes);

    j = 0;
    if (recv_length > 3)
        longw |= my_bytes[j++] << 24;
    if (recv_length > 2)
        longw |= my_bytes[j++] << 16;
    if (recv_length > 1)
        longw |= my_bytes[j++] <<  8;

    longw |= my_bytes[j++] <<  0;

    write_wb(WB_CFGCR, CFGCR_STOP_FRAME);  // stop frame

    return longw;
}

uint8_t one_xo3d_fpga8_32::wb_cnf_read(uint8_t cmd_code, uint32_t cmd_operand, uint32_t recv_length, uint8_t *recv_data)
{
    uint32_t i;
    uint8_t send_data[8];

    write_wb(WB_CFGCR, CFGCR_START_FRAME);  // start frame

    i = 0;
    send_data[i++] = cmd_code;
    send_data[i++] = (cmd_operand >> 16) & 0xFF;
    send_data[i++] = (cmd_operand >>  8) & 0xFF;
    send_data[i++] =  cmd_operand        & 0xFF;
    write_wb(WB_CFGTXDR, 4, send_data);

    if ( ( (cmd_code == READ_FLASH) || (cmd_code == READ_UFM) ) && ( (cmd_operand & 0x3FFF) > 1) ) // read flash and more than one page
    {
        //logWrite("Skip one page\n");
        read_wb(WB_CFGRXDR, 16, recv_data);
    }
    if ( (cmd_code == READ_FLASH) || (cmd_code == READ_UFM) ) // read flash
    {
        recv_length >>= 4; // convert to number of pages, 1 page = 16 bytes
        // read the bytes
        for (i = 0; i < recv_length; i++)
        {
            read_wb(WB_CFGRXDR, 16, recv_data);
            recv_data += 16;
        }
    }
    else
//    if (recv_length == 8)
        read_wb(WB_CFGRXDR, recv_length, recv_data);

    write_wb(WB_CFGCR, CFGCR_STOP_FRAME);  // stop frame

    return 0;
}

uint32_t one_xo3d_fpga8_32::read_dev_id()
{
    if (last_dev_id == 0)
        last_dev_id = wb_cnf_read(READ_DEV_ID, 0x000000, 4);
    return last_dev_id;
}

uint32_t one_xo3d_fpga8_32::read_user_code_sram()
{
    return wb_cnf_read(READ_USR_CODE, 0x000000, 4);
}

uint8_t one_xo3d_fpga8_32::read_trace_id(uint8_t *trid)
{
    return wb_cnf_read(READ_TRACE_ID, 0x000000, 8, trid);
}


// return only the two bytes if the other bytes are as expected
uint16_t one_xo3d_fpga8_32::read_trace_id_short()
{
    uint8_t trid[8];
    wb_cnf_read(READ_TRACE_ID, 0x000000, 8, trid);
    if ( (trid[1] == 0x44) && (trid[2] == 0x30) && (trid[3] == 0x46) && (trid[4] == 0x55) && (trid[5] == 0x14) )
        return (trid[6] << 8) | trid[7];
    else
        return 0xFFFF;
}

uint32_t one_xo3d_fpga8_32::read_trace_id_dw()
{
    uint8_t trid[8];
    uint32_t tr;

    wb_cnf_read(READ_TRACE_ID, 0x000000, 8, trid);
    tr = trid[4]; // ^ trid[0]; // don't use trid[0], as it is programmable!
    tr <<= 8;
    tr |= trid[5] ^ trid[1];
    tr <<= 8;
    tr |= trid[6] ^ trid[2];
    tr <<= 8;
    tr |= trid[7] ^ trid[3];
    return tr;
}

uint8_t one_xo3d_fpga8_32::read_feature_row(uint8_t *frow)
{
    wb_cfg_enable();
    wb_cnf_read(READ_FEATURE_ROW, 0x000000, 8, frow);
    wb_cfg_disable();
    return 0;
}

uint8_t one_xo3d_fpga8_32::wb_cnf_write(uint8_t cmd_code, uint32_t cmd_operand, uint8_t send_length, uint32_t send_data)
{
    uint8_t i, j, operand_length = 3;
    uint8_t my_bytes[8];
    write_wb(WB_CFGCR, CFGCR_START_FRAME); // start frame

    j = 0;
    my_bytes[j++] = cmd_code;

    if ( (cmd_code == ISC_DISABLE) || (cmd_code == REFRESH) )
        operand_length = 2;

    if (operand_length == 3)
        my_bytes[j++] = (cmd_operand >> 16) & 0xFF;
    my_bytes[j++] = (cmd_operand >> 8) & 0xFF;
    my_bytes[j++] =  cmd_operand       & 0xFF;

    if (send_length > 4)
        send_length = 4;

    for (i=send_length; i>0; i--)
        my_bytes[j++] = (send_data >> (8*(i-1) ) ) & 0xFF;

    write_wb(WB_CFGTXDR, j, my_bytes);

    write_wb(WB_CFGCR, CFGCR_STOP_FRAME); // stop frame

    return 0;
}


uint8_t  one_xo3d_fpga8_32::prog_user_code_flash(uint32_t ucode)
{
    wb_cnf_write(PROG_USR_CODE, 0x000000, 4, ucode);
    return wb_wait_no_busy();
}

uint8_t one_xo3d_fpga8_32::wb_cnf_write_arr(uint8_t cmd_code, uint32_t cmd_operand, uint32_t send_length, uint8_t *send_data)
{
    uint8_t i;
    uint8_t send_cmd[8];

    write_wb(WB_CFGCR, CFGCR_START_FRAME); // start frame

    i = 0;
    send_cmd[i++] = cmd_code;
    send_cmd[i++] = (cmd_operand >> 16) & 0xFF;
    send_cmd[i++] = (cmd_operand >>  8) & 0xFF;
    send_cmd[i++] =  cmd_operand        & 0xFF;
    write_wb(WB_CFGTXDR, 4, send_cmd);

    write_wb(WB_CFGTXDR, send_length, send_data);

    return 0;
}

uint8_t one_xo3d_fpga8_32::code_sec2sel_flash_sec(uint8_t code_sec)
{
    switch(code_sec)
    {
        case CODE_FEAT        : return 3;
        case CODE_AES_KEY     : return 10;
        case CODE_PUBL_KEY    : return 6;
        case CODE_UFM3        : return 9;
        case CODE_UFM2        : return 8;
        case CODE_UFM1        : return 5;
        case CODE_UFM0        : return 1;
        case CODE_CFG1        : return 4;
        case CODE_CFG0        : return 0;
        default : return 0xF;
    }
}

// code_sec=0..5 for cfg0, cfg1, ufm0..3; 8 PUBL_KEY, 9 AES_KEY, 10 FEATURE
uint8_t one_xo3d_fpga8_32::set_address_fm(uint8_t code_sec, uint16_t addr)
{
    uint32_t lword;

    if ( (code_sec > CODE_FEAT) || ( (code_sec < CODE_PUBL_KEY) && (code_sec > CODE_UFM3) ) )
    {
        logWrite("# Invalid sector code %d in set_address_fm!\n", code_sec);
        return 0xFF;               // invalid sector code, exit
    }

    lword = code_sec2sel_flash_sec(code_sec);
    lword <<= 14;
    lword |= addr & 0x3FFF;  // 14-bit address

    return wb_cnf_write(SET_ADDR_FLASH_SEC, 0x000000, 4, lword);
}


uint8_t one_xo3d_fpga8_32::wb_cfg_reset_addr(uint8_t code_sec)
{
    if ( (code_sec > CODE_FEAT) || ( (code_sec < CODE_PUBL_KEY) && (code_sec > CODE_UFM3) ) )
    {
        logWrite("# Invalid sector code %d in wb_cfg_reset_addr!\n", code_sec);
        return 0xFF;               // invalid sector code, exit
    }

    return wb_cnf_write(RESET_ADDR_FLASH, 1L << (code_sec + 8), 0, 0);
}

uint8_t one_xo3d_fpga8_32::wb_ufm_reset_addr(uint8_t code_sec)
{
    if ( (code_sec <= CODE_UFM3) && (code_sec >= CODE_UFM0) )
        return wb_cnf_write(RESET_ADDR_UFM, 0x000000, 0, 0);
    else
    {
        logWrite("# Invalid sector code %d in wb_ufm_reset_addr!\n", code_sec);
        return 0xFF;
    }
}

uint8_t one_xo3d_fpga8_32::wb_cfg_enable()
{
    return wb_cnf_write(ISC_ENABLE_X, 1L << 19, 0, 0);
}

uint8_t one_xo3d_fpga8_32::wb_cfg_disable()
{
    if ( (wb_cfg_get_status(0) >> 12) & 1 )
        logWrite("Trying to disable the cfg interface while busy is 1!!!\n");
    wb_cnf_write(ISC_DISABLE, 0x0000, 0, 0);
    wb_cfg_bypass();

    return 0;
}

uint8_t one_xo3d_fpga8_32::wb_cfg_bypass()
{
    return wb_cnf_write(BYPASS_NULL_OP, 0xFFFFFF, 0, 0);
}

uint32_t one_xo3d_fpga8_32::wb_cfg_get_status(uint8_t show_bits)
// bit  8 Done
// bit  9 Config enable
// bit 12 Busy flag
// bit 13 Fail flag
// bit 25..22  EEEE code
// bit 27 ->  I - device verified correct (0) or failed (1), see the EEEE code
{
    uint32_t status;
    status = wb_cnf_read(RD_STA_REG, 0x000000, 4);
    write_wb(WB_CFGCR, CFGCR_STOP_FRAME);  // stop frame

    if (show_bits)
        logWrite("Status read, Done=%d, ConfEna=%d, Busy=%d, Fail=%d, PasswProtCFG=%d, PasswProtUFM=%d, PrimBootFail=%d, I=%d, EEEE=%d\n",
               (status >>  8) & 1,
               (status >>  9) & 1,
               (status >> 12) & 1,
               (status >> 13) & 1,
               (status >> 15) & 1,
               (status >> 17) & 1,
               (status >> 21) & 1,
               (status >> 27) & 1,
               (status >> 22) & 0xF);

    return status;
}

uint8_t one_xo3d_fpga8_32::wb_cfg_get_busy()
{
    return wb_cnf_read(GET_BUSY_FLAG, 0x000000, 1) & 0xFF;
}

uint8_t one_xo3d_fpga8_32::wb_cfg_erase(uint8_t code_sec)
{
    uint32_t lword;

    if ( (code_sec > CODE_FEAT) || ( (code_sec < CODE_PUBL_KEY) && (code_sec > CODE_UFM3) ) )
    {
        logWrite("# Invalid sector code %d in wb_cfg_erase!\n", code_sec);
        return 0xFF;               // invalid sector code, exit
    }

    lword = 1L << (code_sec + 8);
    return wb_cnf_write(ERASE_FLASH, lword, 0, 0);
}

uint8_t one_xo3d_fpga8_32::wb_cfg_write_page(uint8_t code_sec, uint8_t *byte_data)
{
    uint8_t cmd_code;

    if ( (code_sec > CODE_FEAT) || ( (code_sec < CODE_PUBL_KEY) && (code_sec > CODE_UFM3) ) )
    {
        logWrite("# Invalid sector code %d in wb_cfg_write_page!\n", code_sec);
        return 0xFF;               // invalid sector code, exit
    }
    // select the command according to the sector
    if (code_sec <= CODE_CFG1)       // 0..1
        cmd_code = PROG_FLASH;
    else if (code_sec <= CODE_UFM3)  // 2..5
        cmd_code = PROG_UFM;
    else                             // don't know now how to proceed? May be PROG_FLASH?
        return 0xFF;

    wb_cnf_write_arr(cmd_code, 0x000001, 16, byte_data);
    usleep(200);                     // wait 200 us
    return wb_wait_no_busy();        // wait until not busy
}

uint8_t one_xo3d_fpga8_32::wb_cfg_set_done()
{
    wb_cnf_write(SET_DONE_BIT, 0x000000, 0, 0);
    return wb_wait_no_busy();
}

uint8_t one_xo3d_fpga8_32::wb_cfg_refresh(int verify)
{
    uint32_t status;

    wb_cnf_write(REFRESH, 0x000000, 0, 0);
    if (verify)
    {
        sleep(1);
        m_uart32->ClearReadBuff();
        status = wb_cfg_get_status(0);
        if ( ( (status >> 22) & 0xF) == 0)
        {
            logWrite("\t> Refresh was successfull!\n");
            return 0;
        }
        else
        {
            logWrite("\t> !!! Refresh was NOT successfull !!!\n");
            status = wb_cfg_get_status(1);
            return 1;
        }
    }
    else
        return 0;
}

uint8_t one_xo3d_fpga8_32::wb_wait_no_busy()
{
    uint16_t cnt = 0;
    uint8_t busy;

    do
    {
        busy = wb_cfg_get_busy();
//        logWrite("Waiting for busy=0, last read 0x%02x\n", busy);
        cnt++;
    }
    while ( (busy & 0x80) && (cnt < WB_MAX_BUSY) );
    return (busy >> 7) & 1;
}

uint8_t one_xo3d_fpga8_32::page_non_zero(uint8_t *page_data)
{
    uint8_t i;

    for (i=0; i<16; i++)
    {
        if (*page_data != 0)
            return 1;
        page_data++;
    }
    return 0;
}

uint8_t one_xo3d_fpga8_32::wb_cfg_prog_flash(uint8_t code_sec, uint32_t prog_size, uint8_t *byte_data, int refresh)
{
    // ucode is fixed to 0
    return wb_cfg_prog_flash(code_sec, prog_size, byte_data, 0, refresh);
}

// when ucode != 0 it will be used to program the user code together with the config flash
// erase when prog_size=0 (*byte_data is then typically NULL), else program
uint8_t one_xo3d_fpga8_32::wb_cfg_prog_flash(uint8_t code_sec, uint32_t prog_size, uint8_t *byte_data, uint32_t ucode, int refresh)
{
    uint32_t i;
    uint32_t status, npages;
    int32_t nbytes, barstep, barnext;

    uint8_t prog_addr = 1;

    npages = prog_size >> 4;

    if(debug)
        logWrite("Enable transparent configuration\n");

    wb_cfg_enable();
    if ( wb_wait_no_busy() )
        logWrite("*** Timeout waiting for busy -> 0\n");

    status = wb_cfg_get_status(0);

    if ((status >> 13) & 1)
    {
        logWrite("*** Exit programming, as fail flag is 1\n");
        return 1;
    }

    if (prog_size == 0)
    {
        if(debug)
            logWrite("Erase flash sector in ufm(2..5)/cfg(0..1) %d\n", code_sec);

        wb_cfg_erase(code_sec);

        if ( wb_wait_no_busy() )
            logWrite("*** Timeout waiting for busy -> 0\n");

        status = wb_cfg_get_status(0);

        if ((status >> 13) & 1)
        {
            logWrite("*** Exit programming, as fail flag is 1\n");
            wb_cfg_disable();
            return 1;
        }
//      else
//          logWrite("Device erased!\n");
    }
    if (prog_size > 0)
    {
        nbytes = npages * 16;
        logWrite(  "Progress __________________________________________________\n");

        logWrite(  "         "); fflush(stdout);
//        logWrite(  "         ");

        barstep = nbytes/50;
        barnext = nbytes-barstep;

        for (i=0; i < npages; i++)
        {
            if (page_non_zero(byte_data) )
            {
                if (prog_addr)
                {
                    set_address_fm(code_sec, i);
                    prog_addr = 0;
                }
                wb_cfg_write_page(code_sec, byte_data);
                status = wb_cfg_get_status(0);
                if ((status >> 13) & 1)
                {
                    logWrite("*** Page %d, status read 0x%08x, fail flag is 1!!!\n", i, status);
                }
            }
            else
            {
                prog_addr = 1;
            }

            nbytes-=16;

            if ( nbytes <= barnext )
            {
                logWrite(  "|"); fflush(stdout);
//                logWrite(  "|");

                barnext -= barstep;
            }

            byte_data += 16;
        }
        logWrite(  " DONE!\n");

        if ((code_sec <= CODE_CFG1) && (ucode != 0) )
            prog_user_code_flash(ucode);
//        logWrite("Send DONE\n");
        wb_cfg_set_done();
        status = wb_cfg_get_status(0);
        if ((status >> 13) & 1)
        {
            logWrite("*** after DONE, status read 0x%08x, fail flag is 1!!!\n", status);
        }
        if (((status >> 8) & 1)==0)
        {
            logWrite("*** after DONE, status read 0x%08x, flag DONE is 0!!!\n", status);
        }
    }

//    logWrite("Disable transparent configuration\n");
    wb_cfg_disable();

    if ( (prog_size > 0) && (code_sec <= CODE_CFG1) && (refresh) )
    {
        logWrite("\t> Refresh the FPGA config from the flash CFG%d\n", code_sec);
        wb_cfg_refresh();
#ifdef _WIN32
        // usleep(1000);
        sleep(2);
#else
        sleep(1);
#endif
        m_uart32->ClearReadBuff();
        status = wb_cfg_get_status(0);
        if ( ( (status >> 23) & 0x7) == 0)
            logWrite("\t> Refresh was successfull!\n");
        else
            logWrite("\t> !!! Refresh was NOT successfull !!!\n");
    }

    return 0;
}

uint8_t one_xo3d_fpga8_32::wb_cfg_flash_rd(uint8_t code_sec, uint32_t data_size, uint8_t *byte_data)
{
    uint32_t npages, nbytes;
    uint32_t status;
    uint8_t cmd_code;

    // select the command according to the sector
    if (code_sec <= CODE_CFG1)       // 0..1
        cmd_code = READ_FLASH;
    else if (code_sec <= CODE_UFM3)  // 2..5
        cmd_code = READ_UFM;
    else                             // don't know now how to proceed? May be PROG_FLASH?
        return 0xFF;

    wb_cfg_enable();
    if ( wb_wait_no_busy() )
        logWrite("Timeout waiting for busy -> 0\n");

    status = wb_cfg_get_status(0);

    if ((status >> 13) & 1)
    {
        logWrite("Exit reading, as fail flag is 1\n");
        return 1;
    }

    set_address_fm(code_sec, 0);
    npages = data_size >> 4; // divided by 16
    npages &= 0x3FFF;
    nbytes = npages*16;

    if (npages > 1)
        npages++; // read 1 dummy page at the beginning when command READ_FLASH 10 0p pp

    wb_cnf_read(cmd_code, npages | (1 << 20), nbytes, byte_data);

    wb_cfg_disable();
    return 0;
}

uint8_t one_xo3d_fpga8_32::wb_cfg_flash_prd(uint8_t code_sec, uint32_t data_size, uint8_t *byte_data)
{
    uint32_t npages, i, j;
    uint32_t status;
    uint8_t cmd_code;

    // select the command according to the sector
    if (code_sec <= CODE_CFG1)       // 0..1
        cmd_code = READ_FLASH;
    else if (code_sec <= CODE_UFM3)  // 2..5
        cmd_code = READ_UFM;
    else                             // don't know now how to proceed? May be PROG_FLASH?
        return 0xFF;

    if(debug)
        logWrite("Enable transparent configuration\n");

    wb_cfg_enable();
    if ( wb_wait_no_busy() )
        logWrite("Timeout waiting for busy -> 0\n");

    status = wb_cfg_get_status(0);

    if ((status >> 13) & 1)
    {
        logWrite("Exit programming, as fail flag is 1\n");
        return 1;
    }

    set_address_fm(code_sec, 0);
    npages = data_size >> 4; // divided by 16
    npages &= 0x3FFF;

// reading page by page, takes longer, the result is the same
    logWrite("Starting read %d pages from sector (0..1 CFG, 2..5 UFM0..3) %d\n", npages, code_sec);
    for (i=0; i<npages; i++)
    {
        wb_cnf_read(cmd_code, 0x100001, 16, byte_data);

        logWrite("Page 0x%04x: ",i);
        for (j=0; j<16; j++)
            logWrite(" 0x%02x",byte_data[j]);
        logWrite("\n");
        byte_data += 16;
    }

    if(debug)
        logWrite("Disable transparent configuration\n");

    wb_cfg_disable();
    return 0;
}

uint32_t one_xo3d_fpga8_32::read_user_code_flash()
{
    uint32_t status;

    wb_cfg_enable();
    status = read_user_code_sram();
    wb_cfg_disable();
    return status;
}

uint32_t one_xo3d_fpga8_32::read_feat_bits()
{
    uint32_t status;
    uint8_t bbuffer[8];

    wb_cfg_enable();
    status = wb_cnf_read(READ_FEAT_BITS, 0x000000, 6, bbuffer);
    wb_cfg_disable();
    status = bbuffer[2];
    status <<= 8;
    status |= bbuffer[1];
    status <<= 8;
    status |= bbuffer[0];
    return status;
}

uint8_t one_xo3d_fpga8_32::print_feat_bits(uint32_t fb)
{
    uint8_t bb, mspi, i2c, sspi, jtag, done, initn, programn, assp, flash_prot, i2c_degl, i2c_degl_rng, vers_rollback;
    int idx;

    i2c_degl = fb & 1;
    fb >>= 1;
    flash_prot = fb & 7;
    fb >>= 3;

    fb >>= 4;
    assp = fb & 1;

    fb >>= 1;
    programn = fb & 1;

    fb >>= 1;
    initn = fb & 1;

    fb >>= 1;
    done = fb & 1;

    fb >>= 1;
    jtag = fb & 1;

    fb >>= 1;
    sspi = fb & 1;

    fb >>= 1;
    i2c = fb & 1;

    fb >>= 1;
    mspi = fb & 1;

    fb >>= 1;
    bb = fb & 7;

    fb >>= 3;
    i2c_degl_rng = fb & 1;

    fb >>= 1;
    vers_rollback = fb & 1;

    logWrite( "# Feature bits: bbb=%d, mspi=%d, i2c=%d, sspi=%d, jtag=%d, done=%d, initn=%d, programn=%d, my_assp=%d, flash_prot=%d, i2c_degl=%d, i2c_degl_rng=%d, vers_rollback=%d\n",
            bb, mspi, i2c, sspi, jtag, done, initn, programn, assp, flash_prot, i2c_degl, i2c_degl_rng, vers_rollback);

    logWrite( "# Special pins/ports enabled:");

    if (programn==0)
    {
        logWrite( " PROGRAMN");

    }
    if (initn   ==1)
    {
        logWrite( " INITN");

    }
    if (done    ==1)
    {
        logWrite( " DONE");

    }
    if (jtag    ==0)
    {
        logWrite( " JTAG");

    }
    if (sspi    ==0)
    {
        logWrite( " SSPI");

    }
    if (i2c     ==0)
    {
        logWrite( " I2C");

    }
    if (mspi    ==1)
    {
        logWrite( " MSPI");

    }
    logWrite( "\n");

    logWrite( "# Boot sequence: ");
    idx = 0;
    while ( (feat2boot_table[idx].bbb != bb) && (feat2boot_table[idx].mspi != mspi) ) idx++;

    if (feat2boot_table[idx].dual_boot > 0)
        logWrite( "Dual boot ");
    else
        logWrite( "Single boot ");

    logWrite( "%s\n", feat2boot_table[idx].bsource);
    return 0;
}

uint32_t one_xo3d_fpga8_32::comp_cfg_data(uint32_t nbytes, uint8_t *cfg1, uint8_t *cfg2)
{
    uint32_t err, i;
    err = 0;

    for (i=0; i<nbytes; i++)
    {
        if (*cfg1 != *cfg2)
        {
            err++;
            if (err < 10)
                logWrite("Err %2d  read 0x%02x  expected 0x%02x\n", err, *cfg1, *cfg2);
        }
        cfg1++;
        cfg2++;
    }
    return err;
}

uint32_t one_xo3d_fpga8_32::clip_conf_data(uint8_t *prog_data, uint32_t *length)
{
    uint8_t *prog_data_end;
    uint32_t len;

    len = *length;
    prog_data_end = prog_data + len - 1; // point to the last
    while ( (*prog_data_end == 0) && (len > 0) )
    {
        len--;
        prog_data_end--;
    }
    *length = len;
    return len;
}

uint32_t one_xo3d_fpga8_32::write_conf_file(FILE *f, uint8_t *prog_data, uint32_t length)
{
    uint32_t i;
    uint8_t *prog_data_end;

    prog_data_end = prog_data + length - 1; // point to the last
    while ( (*prog_data_end == 0) && (length > 0) )
    {
        length--;
        prog_data_end--;
    }

    for (i=0; i<length; i++)
        fprintf(f, "0x%02x\n",*prog_data++);
//              //fputc(cfg_data[i], f_out);
    return length;
}

uint32_t one_xo3d_fpga8_32::read_conf_file(FILE *f, uint8_t *prog_data, uint32_t max_length)
{
    char linebuf[128];
    uint32_t dat;
    int  args;
    uint32_t nbytes;

    nbytes = 0;
    while ( (fgets(linebuf, 128, f)) && (nbytes < max_length) )
    {
        args = sscanf(linebuf, "%x", &dat);
        if (args >= 1)
        {
            *prog_data = dat & 0xFF;
            prog_data++;
            nbytes++;
        }
    }
    return nbytes;
}

uint32_t one_xo3d_fpga8_32::read_conf_bin_file(FILE *f, uint8_t *prog_data, uint32_t max_length)
{
    int ci;

    uint32_t nbytes;

    nbytes = 0;

    do
    {
        ci = fgetc(f);
        if (ci != EOF)
        {
            *prog_data = ci & 0xFF;
            prog_data++;
            nbytes++;
        }
    }
    while ( (ci != EOF) && (nbytes < max_length) );
    return nbytes;
}



uint32_t one_xo3d_fpga8_32::get_version(void)
{
    return ReadReg(1, cfg_base + ADDR_VERSION);
}

uint32_t one_xo3d_fpga8_32::get_svn_id(void)
{
//    return ReadReg(3, ADDR_SVN);
    return m_uart32->Read3Bytes(cfg_base + ADDR_SVN, WSIZE_BYTE);
}

uint16_t one_xo3d_fpga8_32::get_svn_nr(void)
{
    return (get_svn_id() >> 13) & 0x7FF;
}

uint32_t one_xo3d_fpga8_32::get_compile_id(void)
{
//    return ReadReg(3, ADDR_COMPILE);
    return m_uart32->Read3Bytes(cfg_base + ADDR_COMPILE, WSIZE_BYTE);
}

uint32_t one_xo3d_fpga8_32::print_compile_id(uint32_t cmp_id)
{
    logWrite(  "# Compiled on %4d-%02d-%02d at %02d:%02d\n", (cmp_id       & 0x0F) + 2015,
            (cmp_id >> 4) & 0x0F,
            (cmp_id >> 8) & 0x1F,
            (cmp_id >>13) & 0x1F,
            (cmp_id >>18) & 0x3F);

    return cmp_id;
}

uint32_t one_xo3d_fpga8_32::print_program_id(uint32_t prg_id)
{
    logWrite(  "# Programmed on %4d-%02d-%02d at %02d:%02d:%02d\n", (prg_id       & 0x0F) + 2015,
            (prg_id >> 4) & 0x0F,
            (prg_id >> 8) & 0x1F,
            (prg_id >>13) & 0x1F,
            (prg_id >>18) & 0x3F,
            (prg_id >>24) & 0x3F);

    return prg_id;
}

uint32_t one_xo3d_fpga8_32::print_program_id()
{
    return print_program_id( read_user_code_flash());
}

uint32_t one_xo3d_fpga8_32::print_compile_id()
{
    return print_compile_id( get_compile_id());
}

uint32_t one_xo3d_fpga8_32::print_svn_id(uint32_t svn_id)
{
    logWrite(  "# SVN revision %d from %4d-%02d-%02d\n",     (svn_id >>13) & 0x7FF,
            (svn_id       & 0x0F) + 2015,
            (svn_id >> 4) & 0x0F,
            (svn_id >> 8) & 0x1F);


    return svn_id;
}

uint32_t one_xo3d_fpga8_32::print_svn_id()
{
    return print_svn_id(get_svn_id() );
}


uint8_t one_xo3d_fpga8_32::print_fstatus(uint32_t freq_sys_clk, int force_err)
{
    uint8_t frow[8], i, sta;
    uint32_t tr_id;
    uint32_t fpga_dev_id, user_code;
    char dev_name[512];

    logWrite(  "#\n");


    sta = get_version();
    fpga_dev_id = read_dev_id();
    user_code = read_user_code_sram();
    print_dev_id(fpga_dev_id, dev_name);
    tr_id = read_trace_id_dw();
    read_feature_row(frow);
    logWrite(  "# FPGA device ID is 0x%08x, ",fpga_dev_id);

    logWrite(  "FPGA is %s\n", dev_name);

    logWrite(  "# USERCODE in design is 0x%08x\n",user_code);

    logWrite(  "# USERCODE in flash  is 0x%08x\n",read_user_code_flash());

    print_program_id();
    logWrite(  "# TRACE_ID is: 0x%08x\n", tr_id);

    logWrite(  "# FEATURE_ROW is:");

    for (i=0; i<8; i++)
    {
        logWrite(  " %02x",frow[i]);

    }
    logWrite(  "\n");


    print_feat_bits(read_feat_bits());

    logWrite(  "# Design compiled for image %d\n", sta & 1);
    logWrite(  "# Hardwire version %d, assembly version %d\n", (sta >> 1) & 7, sta >> 4);

    print_svn_id();
    print_compile_id();
    if (freq_sys_clk > 0)
        check_fpga_cnf(freq_sys_clk, force_err);
    logWrite(  "#\n");

    return 0;
}

uint8_t one_xo3d_fpga8_32::print_lstatus(uint32_t freq_sys_clk, int force_err)
{
    print_svn_id();
    print_compile_id();
    if (freq_sys_clk > 0)
        check_fpga_cnf(freq_sys_clk, force_err);
    logWrite(  "#\n");
    return 0;
}


int32_t one_xo3d_fpga8_32::view_ram(uint8_t *myram, uint16_t len, uint32_t saddr, uint16_t bytes_in_row)
{
    int32_t i, mod;
    for (i=0; i<len; i++)
    {
        mod = i % bytes_in_row;
        if (mod == 0x0)
        {
            logWrite( "0x%04x : ", i+saddr);

        }
        logWrite( " 0x%02x",myram[i])  ;

        if (mod == (bytes_in_row-1))
        {
            logWrite( "\n");

        }
    }
    if (mod != (bytes_in_row-1))
    {
      logWrite( "\n");

    }
    return 0;
}

int32_t one_xo3d_fpga8_32::view_ram(uint16_t *myram, uint16_t len, uint32_t saddr, uint16_t words_in_row)
{
    int32_t i, mod;
    for (i=0; i<len; i++)
    {
        mod = i % words_in_row;
        if (mod == 0x0)
        {
            logWrite( "0x%06x : ", i+saddr);

        }
        logWrite( " 0x%04x", myram[i])  ;

        if (mod == (words_in_row-1))
        {
            logWrite( "\n");

        }
    }
    if (mod != (words_in_row-1))
    {
      logWrite( "\n");

    }
    return 0;
}

int32_t one_xo3d_fpga8_32::view_ram(uint32_t *myram, uint16_t len, uint32_t saddr, uint16_t dwords_in_row)
{
    int32_t i, mod;
    for (i=0; i<len; i++)
    {
        mod = i % dwords_in_row;
        if (mod == 0x0)
        {
            logWrite( "0x%06x : ", i+saddr);

        }
        logWrite( " 0x%08x", myram[i])  ;

        if (mod == (dwords_in_row-1))
        {
            logWrite( "\n");

        }
    }
    if (mod != (dwords_in_row-1))
    {
      logWrite( "\n");

    }
    return 0;
}

uint8_t one_xo3d_fpga8_32::get_crc_sta(int with_counters)
{
    last_crc = ReadReg(1, cfg_base + ADDR_CRC_CTRL);
//    logWrite("# last_crc is 0x%02x\n", last_crc);
    WriteReg(1, cfg_base + ADDR_CRC_CNT, 0); // latch the counter
    if (with_counters)
    {
        last_crc_cnt  = m_uart32->Read3Bytes(cfg_base + ADDR_CRC_CNT , WSIZE_BYTE);
        last_crc_time = m_uart32->Read3Bytes(cfg_base + ADDR_CRC_TIME, WSIZE_BYTE);
    }
    return last_crc;
}

uint32_t one_xo3d_fpga8_32::check_fpga_cnf(uint32_t freq_sys_clk, int force_err)
{
    force_err &= 1;

    WriteReg(1, cfg_base + ADDR_CRC_CTRL, 0);
    WriteReg(1, cfg_base + ADDR_CRC_CTRL, 1 << BIT_CHIP_CRC_ENA);
    WriteReg(1, cfg_base + ADDR_CRC_CTRL, 0);
    WriteReg(1, cfg_base + ADDR_CRC_CTRL, 1 << BIT_CHIP_CRC_ENA);
    WriteReg(1, cfg_base + ADDR_CRC_CTRL, (1 << BIT_CHIP_CRC_START) | (1 << BIT_CHIP_CRC_ENA) | (force_err << BIT_CHIP_CRC_FRERR) );
    print_crc_sta(freq_sys_clk, 0);
    do
    {
        get_crc_sta(0);
    }
    while ( (last_crc >> BIT_CHIP_CRC_RUN  ) & 1 );
    print_crc_sta(freq_sys_clk, 1);
    return last_crc;
}

uint32_t one_xo3d_fpga8_32::print_crc_sta(uint32_t freq_sys_clk, int with_counters)
{
    double crc_freq_meas;

    get_crc_sta(with_counters);
    logWrite(  "# CRC status byte is 0x%02x => in progress %d, done %d, err %d, force_err %d, start %d, enable %d\n",
         last_crc,
        (last_crc >> BIT_CHIP_CRC_RUN  ) & 1,
        (last_crc >> BIT_CHIP_CRC_DONE ) & 1,
        (last_crc >> BIT_CHIP_CRC_ERR  ) & 1,
        (last_crc >> BIT_CHIP_CRC_FRERR) & 1,
        (last_crc >> BIT_CHIP_CRC_START) & 1,
        (last_crc >> BIT_CHIP_CRC_ENA  ) & 1);
    if (with_counters)
    {
        logWrite( "# CRC counter is %d, CRC timer is %d\n", last_crc_cnt, last_crc_time);
        crc_freq_meas = 1.0*freq_sys_clk*last_crc_cnt/last_crc_time;
        logWrite( "# Real time is %0.3f ms, CRC frequency is %0.3f MHz, expected %0.3f MHz, deviation %0.1f %%\n",
            1000.0*last_crc_time/freq_sys_clk, 1e-6*crc_freq_meas, 1e-6*CRC_FREQ, 100.0*(crc_freq_meas/CRC_FREQ-1 ) );
    }
    return last_crc;
}

uint8_t  one_xo3d_fpga8_32::WriteReg(uint8_t len, uint32_t addr, uint32_t wdata)
{
    switch (len)
    {
        case 1: { m_uart32->WriteByte(  addr, wdata &     0xFF); break; }
        case 2: { m_uart32->WriteWord(  addr, wdata &   0xFFFF); break; }
        case 3: { m_uart32->Write3Bytes(addr, wdata & 0xFFFFFF); break; }
        case 4: { m_uart32->WriteDWord( addr, wdata           ); break; }
        default:
        {
            printf("Illegal register length %d (must be from 1 to 4)!\n", len);
            return 1;
        }
    }
    return 0;
}

uint32_t  one_xo3d_fpga8_32::ReadReg(uint8_t len, uint32_t addr)
{
    switch (len)
    {
        case 1: return m_uart32->ReadByte(  addr);
        case 2: return m_uart32->ReadWord(  addr); //, WSIZE_BYTE);
        case 3: return m_uart32->Read3Bytes(addr); //, WSIZE_BYTE);
        case 4: return m_uart32->ReadDWord( addr); //, WSIZE_BYTE);
        default:
        {
            printf("Illegal register length %d (must be from 1 to 4)!\n", len);
            return 0;
        }
    }
    return 0;
}


uint32_t one_xo3d_fpga8_32::read_imem_file(FILE *f, uint32_t *prog_data, uint32_t max_length)
{
    char linebuf[128];
    uint32_t dat;
    int  args;
    uint32_t nwords, nwords0;

    nwords = 0;
    nwords0 = 0;
    while ( (fgets(linebuf, 128, f)) && (nwords < max_length) )
    {
        args = sscanf(linebuf, "%x", &dat);
        if (args >= 1)
        {
            *prog_data = dat;
            if (dat != 0) nwords0=0; else nwords0++;
            prog_data++;
//            printf("# Addr 0x%04x  Data 0x%08x, nw0 %d\n", nwords, dat, nwords0);
            nwords++;
        }
    }
    logWrite("# Size of the block with 0x00000000 at the end of the IMEM %d of all %d words, max is %d\n", nwords0, nwords, max_length);
    return nwords;
}

int32_t one_xo3d_fpga8_32::set_sh_mem(uint32_t msize, uint32_t baddr, uint32_t *sh_mem, uint8_t ainc)
{
    uint16_t csize;

    do
    {
        if (msize > BLOCK_MAX_SIZE)
            csize = BLOCK_MAX_SIZE;
        else
            csize = msize;
        m_uart32->SendBurst(csize, ainc, 1, baddr, sh_mem);
        msize -= csize;
        if (ainc)
            baddr += csize;
        sh_mem+= csize;
    } while (msize > 0);
    return 0;
}
