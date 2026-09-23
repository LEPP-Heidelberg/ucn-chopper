#ifndef __ONE_XO3D_FPGA8_32_H__
#define __ONE_XO3D_FPGA8_32_H__

// $Id: one_xo3d_fpga8_32.h 1207 2026-07-28 14:53:54Z  $:

#include <stdio.h>   /* Standard input/output definitions, for perror() */
#include <stdint.h>
#include <stdlib.h>
#include <string.h>  /* String function definitions */
#include <unistd.h>  /* UNIX standard function definitions, for close() */
#include <fcntl.h>   /* File control definitions, for open() */
#include <signal.h>  /* ANSI C signal handling */
#include <memory>
#include <sys/time.h>

#include "CLogger.h"

// EFB : interface to flash memory
#define WB_CFGCR            0x070
#define CFGCR_START_FRAME   0x80
#define CFGCR_STOP_FRAME    0x00
#define WB_CFGTXDR          0x071
#define WB_CFGSR            0x072
#define WB_CFGRXDR          0x073
#define WB_CFGIRQ           0x074
#define WB_CFGIRQEN         0x075
#define WB_EFBIRQ           0x077

#define WB_MAX_BUSY         20000

// CFG0 and 1
#define XO3D_CFG_PAGES_4300  5758
#define XO3D_CFG_PAGES_9400 12541
// UFM0 and 1
#define XO3D_UFM0_PAGES_4300  767
#define XO3D_UFM0_PAGES_9400 3582
// for both FPGA sizes
#define XO3D_UFM2_PAGES      1150
#define XO3D_UFM3_PAGES       191
#define MAX_CFG_DATA        (XO3D_CFG_PAGES_9400*16)

// Commands
#define RD_STA_REG          0x3C
#define ISC_DISABLE         0x26
#define REFRESH             0x79
#define BIT_STR_CHECK       0x7D    // not implemented yet
#define PROG_UFM            0xC9
#define PROG_FLASH          0x70
#define PROG_USR_CODE       0xC2
#define ERASE_FLASH         0x0E
#define READ_FLASH          0x73
#define READ_UFM            0xCA
#define READ_FEAT_BITS      0xFB
#define READ_DEV_ID         0xE0
#define READ_USR_CODE       0xC0
#define READ_TRACE_ID       0x19
#define READ_FEATURE_ROW    0xE7
#define SET_ADDR_FLASH_SEC  0xB4
#define RESET_ADDR_FLASH    0x46
#define RESET_ADDR_UFM      0x47
#define ISC_ENABLE_X        0x74
#define GET_BUSY_FLAG       0xF0
#define SET_DONE_BIT        0x5E
#define BYPASS_NULL_OP      0xFF

#define DEV_ID_MachXO3D_4300 0x012E2043
#define DEV_ID_MachXO3D_9400 0x212E3043

// bit pos in ERASE_FLASH, RESET_ADDR_FLASH, RESET_ADDR_UFM commands are the CODE_xxx + 8
#define CODE_FEAT          10
#define CODE_AES_KEY        9
#define CODE_PUBL_KEY       8
#define CODE_UFM3           5
#define CODE_UFM2           4
#define CODE_UFM1           3
#define CODE_UFM0           2
#define CODE_CFG1           1
#define CODE_CFG0           0

typedef struct
{
    const uint8_t bbb;       // bbbb bits
    const uint8_t mspi;      // mspi persistence bit
    const uint8_t dual_boot; // dual boot?
    const char* bsource;   // boot from?
} feat2boot;

//  bbb m Boot Mode Boot From
//  000 0 Dual      CFG0 - CFG1
//  000 1 Dual      CFG0 - Ext
//  001 0 Dual      CFG1 - CFG0
//  001 1 Single    Ext
//  010 0 Dual      No Boot
//  010 1 Dual      Ext - CFG0
//  011 0 Single    CFG0
//  011 1 Dual      Ext - Ext
//  100 0 Single    CFG1
//  100 1 Dual      CFG1 - Ext
//  101 0 Dual      Boot from former bitstream first
//  101 1 Single    Ext
//  110 0 Dual      No Boot
//  110 1 Dual      Ext - CFG1
//  111 0 Dual      Boot from latter bitstream first
//  111 1 Dual      Ext - Ext

#define FEAT_BOOT_TABLE_LEN  16
const feat2boot feat2boot_table[FEAT_BOOT_TABLE_LEN] = {
// bbbb     M_SPI     dual?    source.| HW ver. | FPGA short ID
{   0,         0,      1,      "CFG0->CFG1" },
{   0,         1,      1,      "CFG0->ext"  },
{   1,         0,      1,      "CFG1->CFG0" },

{   1,         1,      0,      "ext"        },
{   5,         1,      0,      "ext"        },

{   2,         0,      1,      "no boot"    },
{   6,         0,      1,      "no boot"    },

{   2,         1,      1,      "ext->CFG0"  },
{   3,         0,      0,      "CFG0"       },
{   4,         0,      0,      "CFG1"       },
{   4,         1,      1,      "CFG1->ext"  },
{   5,         0,      1,      "former 1st" },
{   6,         1,      1,      "ext->CFG1"  },
{   7,         0,      1,      "latter 1st" },

{   3,         1,      1,      "ext->ext"   },
{   7,         1,      1,      "ext->ext"   }};

#define ADDR_STATUS         0x000
#define ADDR_CRC_CTRL       0x001   // 1 byte
        #define BIT_CHIP_CRC_ENA    0   // enable checking, must be pulsed 0->1->0 once to init the circuit
        #define BIT_CHIP_CRC_START  1   // start building the CRC, automatically cleared
        #define BIT_CHIP_CRC_FRERR  2   // force CRC error, automatically cleared
        // status bits, read only
        #define BIT_CHIP_CRC_DONE   4   // check done
        #define BIT_CHIP_CRC_RUN    5   // check in progeress
        #define BIT_CHIP_CRC_ERR    6   // error!
#define ADDR_CRC_CNT        0x002   // 3 bytes, but 2 bytes used
#define ADDR_CRC_TIME       0x005   // 3 bytes, but 2 bytes used
#define ADDR_SVN            0x009   // 3 bytes
#define ADDR_COMPILE        0x00C   // 3 bytes
#define ADDR_VERSION        0x00F   // 1 byte

#define DEF_WB_BASE_ADDR    0x000
#define DEF_CSR_BASE_ADDR   0x110


#define CRC_FREQ        33250000 // Hz


// return code of the program when fail in verify
#define VERIFY_ERR              1

class one_xo3d_fpga8_32  : public CLogger
{
public:
    one_xo3d_fpga8_32(uint8_t new_debug, uart32* p_uart32, uint32_t new_wb_base = DEF_WB_BASE_ADDR, uint32_t new_cfg_base = DEF_CSR_BASE_ADDR);
    ~one_xo3d_fpga8_32();

    void Debug(bool enable);

    // EFB
    uint8_t  wb_reset();   // reset the WB bus access to flash Memory
    // write to the wishbone bus
    int32_t  write_wb(uint8_t wb_addr, uint8_t wb_data);
    // ... same, but more bytes
    int32_t  write_wb(uint8_t wb_addr, uint8_t nbytes, uint8_t *wb_data);
    // read from the wishbone bus
    uint8_t  read_wb(uint8_t wb_addr);
    // ... same, but more bytes
    uint8_t  read_wb(uint8_t wb_addr, uint8_t nbytes, uint8_t *rd_data);

    // EFB functions to access the flash memory
    // read & check the device id
    uint32_t read_dev_id();
    // read the feature bits
    uint32_t read_feat_bits();
    // print the feature bits
    uint8_t  print_feat_bits(uint32_t fb);
    // read user code from SRAM (or from design)
    uint32_t read_user_code_sram();
    // read the user code from Flash Memory
    uint32_t read_user_code_flash();
    // program the user code (should be erased before)
    uint8_t  prog_user_code_flash(uint32_t ucode);
    // decode the device id as FPGA type
    uint32_t print_dev_id(uint32_t dev_id, char *s);
    // returns the ufm pages (in bits 31..16) and config pages (in bits 15..0):
    uint32_t pages_in_dev(uint32_t dev_id, uint8_t code_sec);
    // same, but read the device id first from FPGA
    uint32_t pages_in_dev(uint8_t code_sec);
    // load the configuration from the internal flash, the FPGA design is for short time dead!
    uint8_t  wb_cfg_refresh(int verify = 0);
    // read the configuration hex file, one byte per line
    uint32_t read_conf_file(FILE *f, uint8_t *prog_data, uint32_t max_length);
    // read the configuration from a bin file
    uint32_t read_conf_bin_file(FILE *f, uint8_t *prog_data, uint32_t max_length);
    // write the configuration hex file, one byte per line
    uint32_t write_conf_file(FILE *f, uint8_t *prog_data, uint32_t length);
    uint32_t clip_conf_data(uint8_t *prog_data, uint32_t *length);
    uint32_t comp_cfg_data(uint32_t nbytes, uint8_t *cfg1, uint8_t *cfg2);
    // read trace_id from the FPGA
    uint8_t  read_trace_id(uint8_t * trid);
    uint16_t read_trace_id_short();
    uint32_t read_trace_id_dw();
    // read feature row from the FPGA
    uint8_t  read_feature_row(uint8_t *frow);
    // write internal flash, UFM or CFG and the user code
    uint8_t  wb_cfg_prog_flash(uint8_t code_sec, uint32_t prog_size, uint8_t * byte_data, uint32_t ucode, int refresh = 1);
    // write internal flash, UFM or CFG without the user code
    uint8_t  wb_cfg_prog_flash(uint8_t code_sec, uint32_t prog_size, uint8_t * byte_data, int refresh = 1);
    // read the internal flash, UFM or CFG
    uint8_t  wb_cfg_flash_rd(uint8_t code_sec, uint32_t data_size, uint8_t *byte_data);
    // read page by page the internal flash, UFM or CFG - for debugging
    uint8_t  wb_cfg_flash_prd(uint8_t code_sec, uint32_t data_size, uint8_t *byte_data);

    // len is 1..4, write to a single configuration register 1 to 4 bytes
    uint8_t  WriteReg(uint8_t len, uint32_t addr, uint32_t wdata);
    uint32_t ReadReg( uint8_t len, uint32_t addr);
    uint32_t get_svn_id(void);
    uint16_t get_svn_nr(void);
    uint32_t get_compile_id(void);
    uint32_t print_compile_id(uint32_t cmp_id);
    uint32_t print_compile_id();
    uint32_t print_svn_id(uint32_t svn_id);
    uint32_t print_svn_id();
    uint32_t print_program_id(uint32_t prg_id);
    uint32_t print_program_id();
    uint32_t get_version(void);
    uint8_t  get_crc_sta(int with_counters);
    uint32_t print_crc_sta(uint32_t freq_sys_clk, int with_counters);
    uint32_t check_fpga_cnf(uint32_t freq_sys_clk, int force_err = 0);
    uint8_t  print_fstatus(uint32_t freq_sys_clk=0, int force_err = 0);
    uint8_t  print_lstatus(uint32_t freq_sys_clk=0, int force_err = 0);

    int32_t view_ram(  uint8_t  *myram, uint16_t len, uint32_t saddr, uint16_t bytes_in_row = 16);
    int32_t view_ram(  uint16_t *myram, uint16_t len, uint32_t saddr, uint16_t words_in_row = 8);
    int32_t view_ram(  uint32_t *myram, uint16_t len, uint32_t saddr, uint16_t dwords_in_row = 8);

    uint32_t read_imem_file(FILE *f, uint32_t *prog_data, uint32_t max_length);
    int32_t  set_sh_mem(uint32_t msize, uint32_t baddr, uint32_t *sh_mem, uint8_t ainc);

    // EFB privat
    // check the device id
protected:
    uint8_t  check_dev_id(uint32_t dev_id, char *s);
    uint32_t wb_cnf_read(uint8_t cmd_code, uint32_t cmd_operand, uint8_t recv_length);
    uint8_t  wb_cnf_read(uint8_t cmd_code, uint32_t cmd_operand, uint32_t recv_length, uint8_t *recv_data);
    uint8_t  wb_cnf_write(uint8_t cmd_code, uint32_t cmd_operand, uint8_t send_length, uint32_t send_data);
    uint8_t  wb_cnf_write_arr(uint8_t cmd_code, uint32_t cmd_operand, uint32_t send_length, uint8_t *send_data);
    uint8_t  set_address_fm(uint8_t code_sec, uint16_t addr);
    uint8_t  wb_cfg_reset_addr(uint8_t code_sec);
    uint8_t  wb_ufm_reset_addr(uint8_t code_sec);
    uint8_t  wb_cfg_enable();
    uint8_t  wb_cfg_disable();
    uint8_t  wb_cfg_bypass();
    uint8_t  wb_cfg_get_busy();
    uint8_t  wb_cfg_set_done();
    uint8_t  page_non_zero(uint8_t *page_data);
    uint32_t wb_cfg_get_status(uint8_t show_bits);
    uint8_t  wb_cfg_erase(uint8_t code_sec);
    uint8_t  wb_cfg_write_page(uint8_t code_sec, uint8_t * byte_data);
    uint8_t  wb_wait_no_busy();
    uint8_t  code_sec2sel_flash_sec(uint8_t code_sec);

    uint16_t fpga_size, cfg_pages, ufm_pages[4];
    uint8_t debug;
    uart32* m_uart32;
    uint8_t last_crc;
    uint32_t last_crc_cnt;
    uint32_t last_crc_time;
    uint32_t last_dev_id;
    uint32_t wb_base;
    uint32_t cfg_base;
};

#endif /* __ONE_XO3D_FPGA8_32_H__ */

//  XO3D-4300
//                UFM0      UFM1        UFM2        UFM3      CFG0*       CFG1*
//  Bits        98,176     98,176      147,200     24,448    737,024     737,024
//  Bytes       12,272     12,272      18,400       3,056     92,128      92,128
//  Pages       767         767         1,150       191        5,758       5,758
//
//  XO3D-9400
//                UFM0      UFM1        UFM2        UFM3      CFG0*       CFG1*
//  Bits        458,496    458,496     147,200     24,448  1,605,248   1,605,248
//  Bytes        57,312     57,312      18,400      3,056    200,656     200,656
//  Pages         3,582      3,582       1,150        191     12,541      12,541
