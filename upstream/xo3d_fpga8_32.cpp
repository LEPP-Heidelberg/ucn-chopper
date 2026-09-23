// $Id: xo3d_fpga8_32.cpp 1212 2026-08-21 14:35:39Z  $:

#include <stdio.h>   /* Standard input/output definitions, for perror() */
#include <stdint.h>
#include <stdlib.h>
#include <string.h>  /* String function definitions */
#include <unistd.h>  /* UNIX standard function definitions, for close() */
#include <fcntl.h>   /* File control definitions, for open() */
//#include <termios.h> /* POSIX terminal control definitions */
#include <signal.h>  /* ANSI C signal handling */
#include <time.h>
#include <math.h>

#include <sys/time.h>
 //stty -F /dev/ttyUSB0 115200

#include "uart32.h"
#include "one_xo3d_fpga8_32.h"

#ifdef _RP4
    #define DEVICE_PREFIX "/dev/ttyAMA"
    #ifndef DEVICE_PORT
    #define DEVICE_PORT   4
    #endif
    #define STARTING_PORT 0
    #define DEF_SET_LOW_LATENCY  0
#endif

#ifdef _LINUX
    #define DEVICE_PREFIX "/dev/ttyUSB"
    #ifndef DEVICE_PORT
    #define DEVICE_PORT   0
    #endif
    #define STARTING_PORT 0
    #define DEF_SET_LOW_LATENCY  1
#endif

#ifndef DEF_CSR_BASE
#define DEF_CSR_BASE  0x110
#endif

#ifndef DEF_WB_BASE
#define DEF_WB_BASE   0x000
#endif

#ifndef DEF_AWIDTH
#define DEF_AWIDTH 24
#endif

#ifndef DEF_DWIDTH
#define DEF_DWIDTH 32
#endif

#ifndef DEF_ID_MASK
#define DEF_ID_MASK 0x4000  // id=14
#endif

#ifndef DEF_ID
#define DEF_ID 14  // id=14
#endif

#define MAX_BOARDS 15

#ifndef FREQ_FCLK_SYS
#define FREQ_FCLK_SYS 32768000
#endif

#ifndef DEF_BRATE
#define DEF_BRATE 4000000
#endif
#define CRC_ERR  0

int32_t read_hex_dec(char *c, uint32_t *res);

uint8_t gen_psrg(uint8_t present)
{
    uint8_t b0, b1, newbit;

    b0 = present >> 7;
    b1 = (present >> 6) & 1;
    newbit = b0 ^ b1;
    newbit &= 1;
    return (present << 1) | newbit;
}

void print_usage(void)
{
    printf("xo3d_fpga8_32 [options]\n");
    printf("\n*** Interface functions\n");
    printf("\t--dev <device_id>, like /dev/ttyUSB0 (linux) or /dev/ttyS0 (cygwin) or //./COM5 (windows), default %s%d\n", DEVICE_PREFIX, DEVICE_PORT);
    printf("\t--port <%d..> : alternative to --dev, just specify the number of the port, default %d\n", STARTING_PORT, DEVICE_PORT);
    printf("--br <1200|2400|4800...115200|...1000000|...|4000000>, default %d\n", DEF_BRATE);
    printf("--nll : skip setting the low latency mode of the USB-UART port\n");
    printf("--sll : set the low latency mode of the USB-UART port\n");
    printf("--pingc <pings> : send <pings> times a byte-counter to the UART\n");
    printf("--pinga <pings> : send <pings> times 0xAA 0x55 to the UART\n");
    //
    printf("\n*** Address & internal bus\n");
    printf("--mask <11-bit> : mask with the selected boards, bits 1..10 used only, do not use with --id together!\n");
    printf("--id <1..15> : select a single id, do not use with --mask together! Default %d\n", DEF_ID);
    printf("--aw <16 | 24 | 32> : select the max address width in the design\n");
    printf("--dw <8 | 16 | 32> : select the max data width in the design\n");
    printf("--gmem8  <size> <address> : read some region (with data width= 8) from internal I/O and dump on screen\n");
    printf("--gmem16 <size> <address> : read some region (with data width=16) from internal I/O and dump on screen\n");
    printf("--gmem32 <size> <address> : read some region (with data width=32) from internal I/O and dump on screen\n");
    printf("--wr_imem <filename> : initialize the instruction memory of the CPU, one 32-bit word in hex format per line in the text file\n");

    printf("\n*** FPGA flash functions ***\n");
    printf("--svn_min <svn_min> : reprogram only if the FPGA has SVN revision less than the specified svn_min. Without this option the FPGA will be updated unconditionally.\n");
    printf("--epv_cfg <0|1> <filename> : read CFG data from <filename>, erase, program and verify the CFG0|1 flash in FPGAs without refresh\n");
    printf("--epv_ufm <0..3> <filename> : read UFM data from <filename>, erase, program and verify the UFM0..3 flash in FPGAs without refresh\n");
    printf("--vrf_cfg <0|1> <filename> : read CFG data from <filename> and verify the CFG0|1 flash in FPGAs\n");
    printf("--vrf_ufm <0..3> <filename> : read UFM data from <filename> and verify the UFM0..3 flash in FPGAs\n");
    printf("--refresh : send refresh command to the FPGA to load the firmware again from the internal config. memory\n");
    printf("--fstatus : read and print the FPGA status\n");

    printf("\n*** Advanced, can be used with single board only ***\n");
//    printf("--er_cfg : erase the CFG flash\n");
    printf("--er_ufm <0..3> : erase the UFM0..3\n");
//    printf("--ucode <32-bit user code | timestamp> : set the user code for subsequent programming of FPGA internal flash\n");
    printf("--rd_cfg <0|1> <size> <filename> : read from CFG0|1 <size> bytes and store to <filename>, <size>=0 means auto, trailing 0x00 omittet\n");
    printf("--rd_ufm <0..3> <size> <filename> : read from UFM0..3 <size> bytes and store to <filename>, <size>=0 means auto\n");
}


uint32_t get_current_time()
{
    uint32_t prg_id;
    time_t t = time(0);   // get time now
    struct tm * now = localtime( & t );
    prg_id = ( now->tm_sec << 24) | ( now->tm_min  << 18) | ( now->tm_hour  << 13) | (now->tm_mday  << 8) | ((now->tm_mon+1)     << 4) | ((now->tm_year+1900 - 2015) & 0xF);
    return prg_id;
}

#define DEBUG_MAIN 0
//#define N_SLAVES   15   // 15 single slaves
#define A_MEM_SIZE  0x1000
#define C_IMEM_SIZE 0x0800
#define C_IMEM_BASE 0x0000  // the byte address is x4

//int main(void)
int main(int argc, char** argv)
{
    uart32 *my_uart32;
    one_xo3d_fpga8_32 *p_design; // the last #15 is broadcast
    uint32_t br;
    uint16_t svn_min;

    char dev_id[512];
    uint32_t board_id = DEF_ID;
    uint32_t id_mask = DEF_ID_MASK;
    uint32_t awidth = DEF_AWIDTH;
    uint32_t dwidth = DEF_DWIDTH;
    int debug_class = DEBUG_MAIN;

    int set_low_latency = DEF_SET_LOW_LATENCY ;

    setbuf(stdout, 0);
    sprintf(dev_id, "%s%d", DEVICE_PREFIX, DEVICE_PORT); // default
    br = DEF_BRATE;

    printf("Running on ");
    #ifdef _RP4
        printf("RP4\n");
    #else
        printf("LINUX\n");
    #endif

    svn_min = 0xFFFF; // if not programmed

    if (argc < 2)
    {
        printf("program path: %s\n",argv[0]);
        print_usage();
        return(1);
    }
    else
    // Parameters treated independent on their position on the command line
    for (int idx=1; idx<argc; idx++)
    {
        if (debug_class)
            printf("Current cmd line option is %s\n",argv[idx]);
        if (strcmp(argv[idx],"--dev") == 0 )
        {
            idx++;
            strcpy(dev_id, argv[idx]);
        }
        else
        if (strcmp(argv[idx],"--port") == 0 )
        {
            sprintf(dev_id, "%s%d", DEVICE_PREFIX, atoi(argv[++idx]));
        }
        else
        if (strcmp(argv[idx],"--br") == 0 )
        {
            br = atoi(argv[++idx]);
//            printf("Bit rate option --br with parameter %d found\n", br);
        }
        else
        if (strcmp(argv[idx],"--nll") == 0 )
        {
            set_low_latency = 0;
        }
        else
        if (strcmp(argv[idx],"--sll") == 0 )
        {
            set_low_latency = 1;
        }
        else
        if (strcmp(argv[idx],"--aw") == 0 )
        {
            awidth = atoi(argv[++idx]);
        }
        else
        if (strcmp(argv[idx],"--dw") == 0 )
        {
            dwidth = atoi(argv[++idx]);
        }
        else
        if (strcmp(argv[idx],"--mask") == 0 )
        {
            read_hex_dec(argv[++idx], &id_mask);
            id_mask &= 0xFFFF;
            board_id = 1;
        }
        else
        if (strcmp(argv[idx],"--id") == 0 )
        {
            read_hex_dec(argv[++idx], &board_id);
            if ( (board_id <= 15) && (board_id >= 0) )
            id_mask = 1 << board_id;
        }
        else
        if (strcmp(argv[idx],"--svn_min") == 0 )
        {
             svn_min = atoi(argv[++idx]);
             printf("Setting min SVN revision to %d, for all FPGA config functions\n", svn_min);
        }
    }
    my_uart32 = new uart32(dev_id, br);
    my_uart32->set_slave_mask(board_id);
    my_uart32->set_max_wsize(dwidth);
    my_uart32->set_max_asize(awidth);

    if (set_low_latency == 1)
    {
        char out_arr[534];
        printf("# Setting %s to low latency mode\n", dev_id);
        sprintf(out_arr, "setserial %s low_latency", dev_id);
        system(out_arr);
    }

    p_design = new one_xo3d_fpga8_32(debug_class, my_uart32, DEF_WB_BASE, DEF_CSR_BASE);

    if (debug_class)
        printf("UART %s open at speed %d\n", dev_id, br);

    // Parameters treated dependent on their position on the command line
    for (int idx=1; idx<argc; idx++)
    {
        if (debug_class)
            printf("Current cmd line option is %s\n", argv[idx]);
        // Skip the parameters treated independent on their position on the command line
        if (strcmp(argv[idx],"--dev") == 0 )
        {
            idx++;
        }
        else
        if (strcmp(argv[idx],"--port") == 0 )
        {
            idx++;
        }
        else
        if (strcmp(argv[idx],"--br") == 0 )
        {
            idx++;
        }
        else
        if (strcmp(argv[idx],"--nll") == 0 )
        {
        }
        else
        if (strcmp(argv[idx],"--sll") == 0 )
        {
        }
        else
        if (strcmp(argv[idx],"--aw") == 0 )
        {
            idx++;
        }
        else
        if (strcmp(argv[idx],"--dw") == 0 )
        {
            idx++;
        }
        else
        if (strcmp(argv[idx],"--svn_min") == 0 )
        {
            idx++;
        }
        else
        if (strcmp(argv[idx],"--id") == 0 )
        {
            idx++;
        }
        else
        if (strcmp(argv[idx],"--mask") == 0 )
        {
            idx++;
        }
        else
        // Parameters treated dependent on their position on the command line

        // UART diagnostic functions
        if (strcmp(argv[idx],"--break") == 0 )
        {
            my_uart32->SendBreak(1);
        }
        else
        if (strcmp(argv[idx],"--pingc") == 0 )
        {
            int pings = atoi(argv[++idx]);
            printf("Sending %d times a counter\n",pings);
            for (int i=0; i<pings; i++)
            {
                usleep(1000);
                my_uart32->WriteSingleByte(i & 0xFF);
            }
        }
        else
        if (strcmp(argv[idx],"--pinga") == 0 )
        {
            int pings = atoi(argv[++idx]);
            printf("Sending %d times 0xAA 0x55\n",pings);
            for (int i=0; i<pings; i++)
            {
                usleep(1000);
                my_uart32->WriteSingleByte(0xAA);
                //usleep(1);
                my_uart32->WriteSingleByte(0x55);
            }
        }
        else
        // Test RAM functions
        if (strcmp(argv[idx],"--gmem32") == 0 )
        {
            uint32_t msize, maddr;
            uint32_t my_ram32[A_MEM_SIZE];

            read_hex_dec(argv[++idx], &msize);
            read_hex_dec(argv[++idx], &maddr);

            for (int brd_id=1; brd_id <= MAX_BOARDS; brd_id++)
                if ((id_mask >> brd_id) & 1)
                {
                    my_uart32->set_slave_mask(brd_id);
                    printf("Get I/O range 0x%04x .. 0x%04x from board %d\n", maddr, maddr+msize-1, brd_id);
                    my_uart32->RecvBurst(msize, 1, 1, maddr, my_ram32);
                    p_design->view_ram(my_ram32, msize, maddr);
                }
        }
        else
        if (strcmp(argv[idx],"--gmem16") == 0 )
        {
            uint32_t msize, maddr;
            uint32_t my_ram16[A_MEM_SIZE];

            read_hex_dec(argv[++idx], &msize);
            read_hex_dec(argv[++idx], &maddr);

            for (int brd_id=1; brd_id <= MAX_BOARDS; brd_id++)
                if ((id_mask >> brd_id) & 1)
                {
                    my_uart32->set_slave_mask(brd_id);
                    printf("Get I/O range 0x%04x .. 0x%04x from board %d\n", maddr, maddr+msize-1, brd_id);
                    my_uart32->RecvBurst(msize, 1, 1, maddr, my_ram16);
                    p_design->view_ram(my_ram16, msize, maddr);
                }
        }
        else
        if (strcmp(argv[idx],"--gmem8") == 0 )
        {
            uint32_t msize, maddr;
            uint32_t my_ram8[A_MEM_SIZE];

            read_hex_dec(argv[++idx], &msize);
            read_hex_dec(argv[++idx], &maddr);

            for (int brd_id=1; brd_id <= MAX_BOARDS; brd_id++)
                if ((id_mask >> brd_id) & 1)
                {
                    my_uart32->set_slave_mask(brd_id);
                    printf("Get I/O range 0x%04x .. 0x%04x from board %d\n", maddr, maddr+msize-1, brd_id);
                    my_uart32->RecvBurst(msize, 1, 1, maddr, my_ram8);
                    p_design->view_ram(my_ram8, msize, maddr);
                }
        }
        else
        if (strcmp(argv[idx],"--wr_imem") == 0 )
        {
            char inp_file[512];
            uint32_t imem_data[C_IMEM_SIZE];
            FILE *f_inp;

            // open the file with the IMEM for reading
            strcpy(inp_file, argv[++idx]);
            f_inp = fopen(inp_file,"r");
            // read the IMEM from file
            p_design->read_imem_file(f_inp, imem_data, C_IMEM_SIZE);
            fclose(f_inp);
            printf("# Write to IMEM\n");
            p_design->WriteReg(1, DEF_CSR_BASE - 15, 1); // CPU reset
            p_design->set_sh_mem(C_IMEM_SIZE, C_IMEM_BASE, imem_data, 1);
            p_design->WriteReg(1, DEF_CSR_BASE - 15, 1); // CPU reset
            p_design->WriteReg(1, DEF_CSR_BASE - 15, 1); // CPU reset
//            p_design->send_cmd(1 << BIT_CONFIG_CMD_CPU_RST);
        }
        else
        // FPGA configuration functions
        if (strcmp(argv[idx],"--fstatus") == 0 )
        {
            for (int brd_id=1; brd_id <= MAX_BOARDS; brd_id++)
                if ((id_mask >> brd_id) & 1)
                {
                    my_uart32->set_slave_mask(brd_id);
                    printf("# FPGA config status of board %d, emulate CRC error is %d\n", brd_id, CRC_ERR);
                    p_design->print_fstatus(FREQ_FCLK_SYS, CRC_ERR);
                }
        }
        else
        if (strcmp(argv[idx],"--lstatus") == 0 )
        {
            for (int brd_id=1; brd_id <= MAX_BOARDS; brd_id++)
                if ((id_mask >> brd_id) & 1)
                {
                    my_uart32->set_slave_mask(brd_id);
                    printf("# FPGA config status of board %d, emulate CRC error is %d\n", brd_id, CRC_ERR);
                    p_design->print_lstatus(FREQ_FCLK_SYS, CRC_ERR);
                }
        }
        else
        // Wishbone functions
        if (strcmp(argv[idx],"--rd_ufm") == 0 )
        {
            uint8_t  cfg_data[MAX_CFG_DATA];
            int code_sec = atoi(argv[++idx]) & 3; // 0..3
            int nbytes   = atoi(argv[++idx]);
            char out_file[512];
            FILE *f_out;

            // open the file with the output data
            strcpy(out_file, argv[++idx]);

            printf("# Read the UFM%d in FPGA\n", code_sec);
            code_sec += CODE_UFM0;
            if (nbytes==0) nbytes = 16*(p_design->pages_in_dev(code_sec));
            f_out = fopen(out_file, "w");
            // read UFM
            p_design->wb_cfg_flash_rd(code_sec, nbytes, cfg_data);
            // store to a file
            for (int i=0; i<nbytes; i++)
            {
                fprintf(f_out, "%02x", cfg_data[i]);
                if ((i & 0xF) == 0xF)
                    fprintf(f_out, "\n");
            }
            fclose(f_out);
        }
        else
        if (strcmp(argv[idx],"--rd_cfg") == 0 )
        {
            uint8_t  cfg_data[MAX_CFG_DATA];
            int code_sec = atoi(argv[++idx]) & 1; // 0 or 1
            int nbytes   = atoi(argv[++idx]);
            char out_file[512];
            FILE *f_out;

            strcpy(out_file, argv[++idx]);

            printf("# Read the FPGA config\n");
            if (nbytes==0) nbytes = 16*(p_design->pages_in_dev(code_sec) & 0xFFFF)-32;
            f_out = fopen(out_file, "w");
            // read CFG flash
            p_design->wb_reset();
            p_design->wb_cfg_flash_rd(code_sec, nbytes, cfg_data);
            // store to a file
            p_design->write_conf_file(f_out, cfg_data, nbytes);
            fclose(f_out);
        }
        else
        if (strcmp(argv[idx],"--er_ufm") == 0 )
        {
            int code_sec = atoi(argv[++idx]) & 3; // 0..3
            printf("# Erase UFM%d\n", code_sec);
            p_design->wb_reset();
            p_design->wb_cfg_prog_flash(code_sec + CODE_UFM0, 0, NULL, 0);
        }
        else
        if (strcmp(argv[idx],"--refresh") == 0 )
        {
            // starting from the last board in the chain, after refresh it has the power up ID
            // and the boards behind it are not accessable
            // a "new_ids" command is necessary, but this can be done when all are refreshed
            // the dynamic ID is used only in some designs!!!
            for (int brd_id=MAX_BOARDS; brd_id > 0; brd_id--)
                if ((id_mask >> brd_id) & 1)
                {
                    my_uart32->set_slave_mask(brd_id);
                    printf("# Refresh the FPGA config in board %d\n", brd_id);
                    p_design->wb_reset();
                    p_design->wb_cfg_refresh(0);
                }
        }
        else
        if (strcmp(argv[idx],"--epv_cfg") == 0 )
        {
            uint8_t  cfg_data[MAX_CFG_DATA];
            uint8_t  cfg_data_rd[MAX_CFG_DATA];
            FILE *f_inp;
            char inp_file[512];
            uint32_t ucode;

            int code_sec = atoi(argv[++idx]) & 1; // 0 or 1
            strcpy(inp_file, argv[++idx]);
            // auto length
            int nbytes = 16*(p_design->pages_in_dev(code_sec) & 0xFFFF)-32;
            // open the file with the config for reading
            f_inp = fopen(inp_file, "r");

            // clear the array for config data
            for (int i=0; i<nbytes; i++)
            {
                cfg_data[i] = 0;
            }
            // read the config
            if (strstr(inp_file, ".jbt") )
                p_design->read_conf_file(f_inp, cfg_data, nbytes);
            else if (strstr(inp_file, ".bin") )
                p_design->read_conf_bin_file(f_inp, cfg_data, nbytes);
            else
            {
                printf("! Unexpected file extension, only .bin (binary) or .jbt (hex, one byte per line) possible!\n");
                break;
            }
            fclose(f_inp);
            // loop the boards avaialble
            for (int brd_id=MAX_BOARDS; brd_id > 0; brd_id--)
                if ((id_mask >> brd_id) & 1)
                {
                    my_uart32->set_slave_mask(brd_id);
                    // write the config to the internal flash
                    if (p_design->get_svn_nr() < svn_min)
                    {
                        printf("# Erase Program & Verify the FPGA config of board %d\n", brd_id);
                        // clear the array for config data
                        for (int i=0; i<nbytes; i++)
                        {
                            cfg_data_rd[i] = 0;
                        }
                        printf("\tPresent SVN version is %d, required min is %d, updating...\n", p_design->get_svn_nr(), svn_min);
                        printf("\t> Erasing config data...\n");
                        p_design->wb_reset();
                        p_design->wb_cfg_prog_flash(code_sec, 0, NULL, 0);
                        printf("\t> Programming config data...\n");
                        ucode = get_current_time();
                        p_design->wb_reset();
                        p_design->wb_cfg_prog_flash(code_sec, nbytes, cfg_data, ucode, 0);
                        p_design->wb_reset();
                        printf("\t> Verifying config data...");
                        // read CFG flash
                        p_design->wb_cfg_flash_rd(code_sec, nbytes, cfg_data_rd);
                        // compare
                        if (p_design->comp_cfg_data(nbytes, cfg_data, cfg_data_rd) > 0)
                        {
                            printf(" FAIL!!!\n");
                            return VERIFY_ERR;
                        }
                        else
                            printf(" OK\n");
                    }
                }
        }
        else
        if (strcmp(argv[idx],"--vrf_cfg") == 0 )
        {
            uint8_t  cfg_data[MAX_CFG_DATA];
            uint8_t  cfg_data_rd[MAX_CFG_DATA];
            FILE *f_inp;
            char inp_file[512];
            int code_sec = atoi(argv[++idx]) & 1; // 0 or 1
            strcpy(inp_file, argv[++idx]);
            int nbytes = 16*(p_design->pages_in_dev(code_sec) & 0xFFFF)-32;

            printf("# Verify FPGA config %d\n", code_sec);
            // auto length
            // clear the array for config data
            for (int i=0; i<nbytes; i++)
                cfg_data[i] = 0;
            // open the file with the config for reading
            f_inp = fopen(inp_file,"r");
            // read the config
            printf("# Reading the FPGA config %d from %s\n", code_sec, inp_file);
            // read the config
            if (strstr(inp_file, ".jbt") )      // one byte per line as text in hex format
                p_design->read_conf_file(f_inp, cfg_data, nbytes);
            else if (strstr(inp_file, ".bin") ) // binary
                p_design->read_conf_bin_file(f_inp, cfg_data, nbytes);
            else
            {
                printf("! Unexpected file extension, only .bin (binary) or .jbt (hex, one byte per line) possible!\n");
                break;
            }
            fclose(f_inp);
            // loop the boards available
            for (int brd_id=1; brd_id <= MAX_BOARDS; brd_id++)
                if ((id_mask >> brd_id) & 1)
                {
                    printf("\n# FPGA config status of board %d\n", brd_id);
                    my_uart32->set_slave_mask(brd_id);
                    // clear the array for config data read
                    for (int i=0; i<nbytes; i++)
                        cfg_data_rd[i] = 0;
                    printf("\tBoard %2d, Present SVN version is %d, verifying...\n", board_id, p_design->get_svn_nr());
                    printf("\t> Verifying config data...");
                    // read CFG flash
                    p_design->wb_reset();
                    p_design->wb_cfg_flash_rd(code_sec, nbytes, cfg_data_rd);
                    if (p_design->comp_cfg_data(nbytes, cfg_data, cfg_data_rd) > 0)
                        printf(" FAIL!!!\n");
                    else
                        printf(" OK\n");
                }
        }
        else
        {
            printf("Unknown command line option %s\n",argv[idx]);
            print_usage();
            return(1);
        }
    }

    if (debug_class)
        printf("Bytes sent/received %d / %d\n", my_uart32->BytesSent(), my_uart32->BytesReceived());

    delete p_design;
    return (0);
}

int32_t read_hex_dec(char *c, uint32_t *res)
{
    int32_t e,d;
    uint32_t w;
    e = -1;
    if(strlen(c) > 2)
    {
        if (strncmp(c, "0x",2) == 0) // hex
        {
                e = sscanf(c, "0x%x", &w);
                *res = w;
        } else { // dec
                e = sscanf(c, "%d", &d);
                *res = d;
        }
    }
    else
    { // short dec
        e = sscanf(c, "%d", &d);
        *res = d;
    }

    if (e == 1) return 0;
    else return -1;
}
