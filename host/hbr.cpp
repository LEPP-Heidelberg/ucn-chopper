// $Id: hbr.cpp 1224 2026-09-18 09:42:59Z  $:

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

#include "../upstream/uart32.h"
#include "C_hbr.h"
#include "C_ads131m04.h"
#include "C_dual_dac.h"
#include "C_dtemp.h"
#include "C_simpl_stat.h"



#ifndef DEVICE_PREFIX
#define DEVICE_PREFIX "/dev/ttyUSB"
//#define DEVICE_PREFIX "/dev/ttyACM"
#endif

#ifndef DEVICE_PORT
#define DEVICE_PORT   1
#endif

#define STARTING_PORT 0

// 0 for ttyACM, 1 for ttyUSB
#define DEF_SET_LOW_LATENCY 1

#ifndef DEF_AWIDTH
#define DEF_AWIDTH 24
#endif

#ifndef DEF_DWIDTH
#define DEF_DWIDTH 32
#endif


#ifndef DEF_ID_MASK
// 10 boards, ID from 1 to 10, ID=0 not used!
#define DEF_ID_MASK 0x01
#endif

#ifndef DEF_BRATE
#define DEF_BRATE 4000000
#endif

#define ADS_SAMPLING_RATE       ADS_SRATE_1K
#define ADC_CHIP_MASK           3   // 2 ADC chips
#define ADS_GAIN                0

#define MAX_PWR_TABLE_LEN       2048

#define DEBUG_MAIN 0
#define msleep(x) usleep(1000*x)

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
    printf("hbr [options]\n");
    printf("\n*** Interface ***\n");
    printf("--dev <device_id>, like /dev/ttyUSB0 (linux) or /dev/ttyS0 (cygwin) or //./COM5 (windows), default %s%d\n", DEVICE_PREFIX, DEVICE_PORT);
    printf("--port <%d..> : alternative to --dev, just specify the number of the port, default %d\n", STARTING_PORT, DEVICE_PORT);
    printf("--br <1200|2400|4800...115200|...1000000|...|4000000>, default %d\n", DEF_BRATE);
    printf("--nll : skip setting the low latency mode of the USB-UART port\n");
    //
    printf("\n*** Common functions ***\n");
    printf("--id <1..10> : select a single id, default %d\n", DEF_ID_MASK);

    printf("-d : turn on debug info\n");

    printf("\n*** Main functions ***\n");
    printf("--status : read and print the board status\n");
    printf("--hbr_decay <0..2> : set the HBR decay: 0 - slow, 1 - smart, 2 - mixed\n");
    printf("--hbr_toff <0..3> : set the HBR Toff: 0..3 for off time in us 7, 16, 24, 32\n");
    printf("--hbr_opcm <0 | 1> : set the HBR OCPM pin\n");
    printf("--hbr_sleep_n <0 | 1> : set the HBR SLEEP_n pin, 0 means OFF! Can be used to clear the FAULT condition.\n");
    printf("--hbr_mode12 <mode1=0|1> <mode2=0|1> : activate sleep_n, then set the HBR MODE1 and MODE2 pins, be carefull!\n");
    printf("--ctrl_in_afbr|ocpl <ch=0|1> <ena=0|1> <inv=0|1> : enable/disable and optionally invert the control inputs\n");
    printf("--set_pwm <freq= %d", PWM_FREQ[0]);
        for (int i=1; i<8; i++) printf(" | %d", PWM_FREQ[i]);
        printf(" > : set the PWM frequency [Hz], default %d\n", PWM_FREQ[0]);
    printf("--set_slow_dec_sm <ch_mask> <slow_decay> : when set, the coil is shorted when not driven, otherwise remains offen\n");
    printf("--set_preserve_last <ch_mask> <preserve_last> : when set, the last PWM state will remain for ever");
    printf("--hbr_rep : report the settings\n");
    printf("--single <ch=0|1> <hbr_state=0..3> <duration=1..256 in PWM periods> <power=0..255> : activate the HBR for some time\n");
    printf("--start <ch_mask=0..3> <seq1=0|1> <seq2=0|1> : start the previously programmed sequence(s) at H-bridge 1 and 2\n");
    printf("--sm_reset <ch_mask=0..3> : reset the state machines controlling the sequence(s) at H-bridge 1 and 2\n");

    printf("\n*** PWM profiles ***\n");
    printf("--create_table <a lot of parameters, use the newer functions!>\n");
    printf("--read_table <filename> <time_step_ms> <time_scale> <power_scale> : read from a file a power profile (PieceWise linear - PWL), scale optionally and generate the table\n");
    printf("\tin the file: lines with time in ms and power in %% from -100 to +100\n");
    printf("\ttime_step_ms : specify the time step or write 0 to use the current PWM frequency\n");
    printf("\ttime_scale : use 1 when no modification required\n");
    printf("\tpower_scale : use 1 when no modification required, resulting power outside -100...+100 %% will be clipped\n");
    printf("\tthe resampled waveform will be stored for debugging in res_wave.dat\n");
    printf("--load_table <ch> <rising_edge> : load the just generated table to the FPGA into ch (0..1) and edge (0..1)\n");
    printf("--export_table <filename.mem> : export the just generated table as a hex file, suitable to init the FPGA memories in the compilation\n");

    printf("\n*** dual DAC functions ***\n");
    printf("--dac_write2eep : when writing anything to DAC, write to EEPROM, default write only to the register\n");
    printf("--init_hbr_vref : should be done only once after power up. If stored to EEPROM, don't need to do this anymore\n");
    printf("--set_hbr_vref <ch=0|1> <volt=0..3.3V> : Set the VREF of H-bridge chip, thus setting the max current (s. datasheet). Default 3.3V\n");

    printf("\n*** ADC ADS131M08 functions ***\n");
  //  printf("\t--adc_conf <srate> <gc_flag> <inp_mux> <do_offs> <shift_r> :\n");
    printf("\t--adc_conf <srate> <gc_flag> <inp_mux> <shift_r> : reset ADCs, then configure\n");
    printf("\t - <srate> sampling rate from 250 to 32000 in steps of x2\n");
    printf("\t - <gc_flag> gc_flag 0 or 1, use chopper swapped inputs to correct ADC offset\n");
    printf("\t - <inp_mux> from 0 to 3 for 0 normal, 1 short, 2/3 test +/-2/15 of full scale, do_offs correction (but run --base... before)\n");
//    printf("\t - <do_offs> correct the offset with the previously determined by the --adc_rd & --set_base or imported by --imp_base options\n");
    printf("\t - <shift_r> shift the ADC data to the right by 0..16 bits, need to be 0 when running --base_rd for the offset correction\n");
    printf("\t--adc_rd_all_reg <srate> ... <shift_r> : parameter as above, check if the registers correspond to the expected settings\n");
    printf("\t--adc_reset : send reset to the ADCs via the SYNC/RESET line\n");
    printf("\t--adc_sync : send sync to the ADCs via the SYNC/RESET line\n");
    printf("\t--adc_spi_reset : reset of the SPI master\n");
    printf("\t--adc_auto_read <auto> <crc> <sync> : set the auto read bit in order to read automatically each new sample, enable the hardware crc generator (otherwise in software), sync at the same time\n");
    printf("\t--adc_chip_mask <chip_mask> <chip_sel> : set the mask with the active ADC chips, select one of them for debugging of its DRDY_n output\n");
    printf("\t--adc_get_freq_per : measure the frequency and the period of DRDY_n output of the all active ADC chips (it takes 1-2 seconds/chip)\n");
    printf("\t--adc_get_per : measure the period of DRDY_n output of the all active ADC chips (it takes 1-2 seconds/chip)\n");
    printf("\t--adc_wreg <reg_addr> <reg_data> : write to the register with address reg_addr reg_data to all chips in the previously set chip_mask\n");
    printf("\t--adc_standby : send the command STANDBY to the ADCs\n");
    printf("\t--adc_wakeup : send the command WAKEUP to the ADCs\n");
    printf("\t--adc_rd <nsamples> : read nsamples from the ADC, calculate statistics on the ADC data\n");

    printf("\n*** Advanced features, for debugging ***\n");
    printf("--rd_reg <len=1..4> <addr> : read one register of len bytes at addr (dec or 0x hex) and print it as hex\n");
    printf("--pingc <pings> : send <pings> times a byte-counter to the UART\n");
    printf("--pinga <pings> : send <pings> times 0xAA 0x55 to the UART\n");
}


uint32_t dump_current_time(FILE *f)
{
    time_t t = time(0);   // get time now
    struct tm * now = localtime( & t );
    fprintf(f, "%4d-%02d-%02d:%02d-%02d-%02d",
        now->tm_year+1900,
        now->tm_mon+1,
        now->tm_mday,
        now->tm_hour,
        now->tm_min,
        now->tm_sec);
    return 0;
}


//int main(void)
int main(int argc, char** argv)
{
    // class to work with the UART
    uart32 *my_uart32;
    // class to control the main functions
    C_hbr *p_hbr;
    // additional classes
    C_ads131m04 *my_ads;        // ADS131M04 ADCs
    C_dtemp *my_dtemp;          // 1-wire Temp. Sensors
    C_dual_dac *my_dual_dac;    // dual I2C DAC
    C_simpl_stat adc_stat[4*NCHIPS_ADC];  // simple statistics of the ADC data, 4 channels in chip

    // bit rate
    uint32_t br = DEF_BRATE;
    int ads_16bit_data = 0;

    // debug flag for single oeprations
    int dbg = 0;
    // debug for the complete classes
    int debug_class = DEBUG_MAIN;
    // set the low latency of USB-UART in the linux OS
    // - not necessary in RP4 and some all Linux distributions
    int set_low_latency = DEF_SET_LOW_LATENCY;
    // full device name as string
    char dev_id[512];
    // ID on the UART bus, in this project is always the same constant
    uint32_t board_id = DEF_ID_MASK;

    uint32_t chip_mask = ADC_CHIP_MASK, chip_sel;
    int dac_write2eep = 0;

    uint32_t tbl_data[SEQ_LENGTH], tbl_len = 0;


    setbuf(stdout, 0);
    sprintf(dev_id, "%s%d", DEVICE_PREFIX, DEVICE_PORT); // default

    if ( strstr(dev_id, "ttyUSB") != NULL )
        set_low_latency = 1;
    else
        set_low_latency = 0;

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
            if ( strstr(dev_id, "ttyUSB") != NULL )
                set_low_latency = 1;
            else
                set_low_latency = 0;
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
        }
        else
        if (strcmp(argv[idx],"--nll") == 0 )
        {
            set_low_latency = 0;
        }
        else
        if (strcmp(argv[idx],"--id") == 0 )
        {
            read_hex_dec(argv[++idx], &board_id);
        }
    }
    my_uart32 = new uart32(dev_id, br);
    my_uart32->set_slave_mask(board_id);
    my_uart32->set_max_wsize(DEF_DWIDTH);
    my_uart32->set_max_asize(DEF_AWIDTH);

    if (set_low_latency == 1)
    {
        char out_arr[534];
        printf("# Setting %s to low latency mode\n", dev_id);
        sprintf(out_arr, "setserial %s low_latency", dev_id);
        system(out_arr);
    }

    p_hbr = new C_hbr(debug_class, my_uart32);

    // create new object with the ADC parameters
    my_ads     = new C_ads131m04( my_uart32, ADDR_ADS_ADC, 0);
    // 1-wire temperature sensors
    my_dtemp   = new C_dtemp(     my_uart32, ADDR_DTEMP);
    my_dual_dac= new C_dual_dac(  my_uart32, ADDR_I2C);


    if (debug_class)
        printf("UART %s open at speed %d\n", dev_id, br);

    // Parameters treated dependent on their position on the command line
    for (int idx=1; idx<argc; idx++)
    {
        if (debug_class)
            printf("Current cmd line option is %s\n",argv[idx]);
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
        if (strcmp(argv[idx],"--id") == 0 )
        {
            idx++;
        }
        else
        if (strcmp(argv[idx],"--nll") == 0 )
        {
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
            uint32_t pings, i;

            pings = atoi(argv[++idx]);
            printf("Sending %d times a counter\n",pings);
            for (i=0; i<pings; i++)
            {
                usleep(1000);
                my_uart32->WriteSingleByte(i & 0xFF);
            }
        }
        else
        if (strcmp(argv[idx],"--pinga") == 0 )
        {
            uint32_t pings, i;

            pings = atoi(argv[++idx]);

            printf("Sending %d times 0xAA 0x55\n",pings);
            for (i=0; i<pings; i++)
            {
                usleep(1000);
                my_uart32->WriteSingleByte(0xAA);
                //usleep(1);
                my_uart32->WriteSingleByte(0x55);
            }
        }
        else
        if (strcmp(argv[idx],"-d") == 0 )
        {
            dbg = 1;
        }
        else
        // FPGA configuration functions
//      if (strcmp(argv[idx],"--fstatus") == 0 )
//      {
//          p_pmon->print_fstatus();
//            p_pmon->get_cpu_prog_timestamp(1);
//            p_pmon->get_temp(1);
//      }
//      else
        if (strcmp(argv[idx],"--status") == 0 )
        {
            p_hbr->get_cpu_prog_timestamp(1);
            p_hbr->read_temper(1);
            my_dtemp->get_presence_mask();
            my_dtemp->rep_temp();
        }
        else
        if (strcmp(argv[idx],"--hbr_decay") == 0 )
        {
            int decay;

            decay = atoi(argv[++idx]);
            p_hbr->set_hbr_conf_decay(decay, 1);
        }
        else
        if (strcmp(argv[idx],"--hbr_toff") == 0 )
        {
            int toff;

            toff = atoi(argv[++idx]);
            p_hbr->set_hbr_conf_toff(toff, 1);
        }
        else
        if (strcmp(argv[idx],"--hbr_ocpm") == 0 )
        {
            int ocpm;

            ocpm = atoi(argv[++idx]);
            p_hbr->set_hbr_conf_ocpm(ocpm, 1);
        }
        else
        if (strcmp(argv[idx],"--hbr_sleep_n") == 0 )
        {
            int sleep_n;

            sleep_n = atoi(argv[++idx]);
            p_hbr->set_hbr_conf_sleep_n(sleep_n, 1);
        }
        else
        if (strcmp(argv[idx],"--ctrl_in_afbr") == 0 )
        {
            int ch;
            int ena;
            int inv;

            ch  = atoi(argv[++idx]);
            ena = atoi(argv[++idx]);
            inv = atoi(argv[++idx]);
            p_hbr->set_hbr_conf_ena_inv_afbr(ch, ena, inv, 1);
        }
        else
        if (strcmp(argv[idx],"--ctrl_in_ocpl") == 0 )
        {
            int ch;
            int ena;
            int inv;

            ch  = atoi(argv[++idx]);
            ena = atoi(argv[++idx]);
            inv = atoi(argv[++idx]);
            p_hbr->set_hbr_conf_ena_inv_ocpl(ch, ena, inv, 1);
        }
        else
        if (strcmp(argv[idx],"--set_preserve_last") == 0 )
        {
            int ch_mask;
            int preserve;

            ch_mask  = atoi(argv[++idx]);
            preserve = atoi(argv[++idx]);
            p_hbr->set_preserve_last(ch_mask, preserve, 1);
        }
        else
        if (strcmp(argv[idx],"--set_slow_dec_sm"  ) == 0 )
        {
            int ch_mask;
            int sl_decay;

            ch_mask  = atoi(argv[++idx]);
            sl_decay = atoi(argv[++idx]);
            p_hbr->set_hbr_sm_slow_decay(ch_mask, sl_decay, 1);
        }
        else
        if (strcmp(argv[idx],"--hbr_mode12") == 0 )
        {
            int mode1, mode2;

            mode1 = atoi(argv[++idx]);
            mode2 = atoi(argv[++idx]);
            p_hbr->set_hbr_conf_sleep_n(0, 1);
            p_hbr->set_hbr_conf_mode(mode1, mode2, 1);
            sleep(1);
        }
        else
        if (strcmp(argv[idx],"--set_pwm") == 0 )
        {
            int pwm_freq;

            pwm_freq = atoi(argv[++idx]);
            pwm_freq = p_hbr->set_pwm_freq(pwm_freq, 1);
        }
        else
        if (strcmp(argv[idx],"--hbr_rep") == 0 )
        {
            p_hbr->get_hbr_conf(1);
            p_hbr->hbr_rep_pwm();
            p_hbr->hbr_rep_seq_table();
            my_dual_dac->get_dacs(1);
        }
        else
        if (strcmp(argv[idx],"--single") == 0 )
        {
            int ch;
            int hbr_state;
            int duration;
            int power;

            ch        = atoi(argv[++idx]);
            hbr_state = atoi(argv[++idx]);
            duration  = atoi(argv[++idx]);
            power     = atoi(argv[++idx]);

            p_hbr->single_shot(ch, hbr_state, duration, power, 1);
        }
        else
        if (strcmp(argv[idx],"--start") == 0 )
        {
            int ch_mask;
            int seq_ch1;
            int seq_ch2;

            ch_mask = atoi(argv[++idx]);
            seq_ch1 = atoi(argv[++idx]);
            seq_ch2 = atoi(argv[++idx]);

            p_hbr->hbr_seq_start(ch_mask, seq_ch1, seq_ch2, 1);
        }
        else
        if (strcmp(argv[idx],"--sm_reset") == 0 )
        {
            int ch_mask;

            ch_mask = atoi(argv[++idx]);

            p_hbr->hbr_seq_reset(ch_mask, 1);
        }
        else
        if (strcmp(argv[idx],"--create_table") == 0 )
        {
            int pwm_freq;
            int h_state;
            float rt, ap, wt, ft, an, wn, r2, bp, wb;

            pwm_freq = atoi(argv[++idx]);
            h_state  = atoi(argv[++idx]);
            rt       = atof(argv[++idx]);
            ap       = atof(argv[++idx]);
            wt       = atof(argv[++idx]);
            ft       = atof(argv[++idx]);
            an       = atof(argv[++idx]);
            wn       = atof(argv[++idx]);
            r2       = atof(argv[++idx]);
            bp       = atof(argv[++idx]);
            wb       = atof(argv[++idx]);

            tbl_len = p_hbr->hbr_create_seq_table(
                  // all times in ms
                  h_state,
                  pwm_freq, // pwm frequency in Hz
                  rt, ap, // rt - rise time, ap - amplitude positive
                  wt, ft, // wt - width with ap, ft - fall time to an
                  an, wn, // an - amplitude negative, wn - width negative
                  r2, bp, // r2 - second rise time to bp, bp - background power
                  wb,           // wb - width with background
                  tbl_data, // integer data to load to the table:
                  // bits 17..16 - state, bits 15..8 - duration, bits 7..0 - power
                  // return the length of the table
                  1);
        }
        else
        if (strcmp(argv[idx],"--read_table") == 0 )
        {
            char inp_file[512];
            FILE *f;
            float time_ms[MAX_PWR_TABLE_LEN];
            float power[  MAX_PWR_TABLE_LEN];
            float tstep, tscale, pscale;
            int flength, ilength;
            int16_t ipower[UNCOMPR_LENGTH];

            // open the file with the IMEM for reading
            strcpy(inp_file, argv[++idx]);
            tstep  = atof(argv[++idx]);
            tscale = atof(argv[++idx]);
            pscale = atof(argv[++idx]);

            f = fopen(inp_file,"r");

            flength = p_hbr->read_power_profile(f, time_ms, power, MAX_PWR_TABLE_LEN, 1);
            ilength = p_hbr->resample_power_profile(tstep, tscale, pscale, time_ms, power, flength, ipower, 1);
            tbl_len = p_hbr->compress_power_profile(ilength, ipower, tbl_data, 1);

            fclose(f);
        }
        else
        if (strcmp(argv[idx],"--load_table") == 0 )
        {
            int ch, re;

            ch = atoi(argv[++idx]);
            re = atoi(argv[++idx]);

            if ( (tbl_len > 0) && (tbl_len <= SEQ_LENGTH) )
            {
                p_hbr->hbr_upload_seq_table(ch, re, tbl_len, tbl_data, 1);
                if (tbl_len > (SEQ_LENGTH/2) )
                    printf("# The table is longer than 1/2 of the memory size reserved for this channel!\n");
            }
            else
                printf("# First create a table using --read_table, then execute --load_table immediately after that!\n");
        }
        else
        if (strcmp(argv[idx],"--export_table") == 0 )
        {
            char out_file[512];
            FILE *f;

            // open the file with the IMEM for reading
            strcpy(out_file, argv[++idx]);
            f = fopen(out_file,"w");

            if ( (tbl_len > 0) && (tbl_len <= SEQ_LENGTH) )
            {
                if (tbl_len > (SEQ_LENGTH/2) )
                    printf("# The table is longer than 1/2 of the memory size reserved for one channel!\n");
                for (int i=0; i<tbl_len; i++)
                    fprintf(f, "%05x\n", tbl_data[i]);
                fclose(f);
            }
            else
                printf("# First create a table using --read_table, then execute --export_table immediately after that!\n");
        }
        else
        // ADS131
        if (strcmp(argv[idx],"--adc_conf") == 0 )
        {
            int srate, in_mux, gc_flag, shift_r, do_offs;

            srate   = atoi(argv[++idx]);
            gc_flag = atoi(argv[++idx]);
            in_mux  = atoi(argv[++idx]);
//            do_offs = atoi(argv[++idx]);
            shift_r = atoi(argv[++idx]);
            do_offs = 0;

            // reset the SPI master only
            my_ads->hw_spi_reset();
            my_ads->hw_chip_mask(chip_mask, 0);
            // turn off auto read, set the automatic CRC calculation, don't send sync now
            my_ads->hw_auto_read(0, AUTO_CRC, 0, 0, chip_mask);
            // send reset to the ADCs via the sync/reset line
            my_ads->hw_adc_reset(1);
            // send the ADS in standby when programming and reading back the registers
            // - reading works not reliable now when the ADCs are running!
            my_ads->hw_send_cmd(ADS131_STANDBY, chip_mask);
            // read all registers, no safe mode -> pipelined read, only once per register
            my_ads->hw_rd_all_regs(chip_mask, 0);
            // dump the table with the read register values, expected the reset values
            printf("\n# After Reset\n");
            for (int i=0; i<NCHIPS_ADC; i++)
            {
                fprintf(stdout, "\n# ADS131M04 Chip %d, register table\n", i);
                my_ads->print_table(stdout, i, 1, 1);
            }

            // prepare the register values based on the sampling rate, gains, input mux, last parameter is debug
            my_ads->prepare_all_regs(srate, gc_flag, ADS_GAIN, in_mux, do_offs, shift_r, chip_mask, 1);
            // write all registers, pipelined, when writing the next register check the responce to the previous write!
            my_ads->hw_wr_all_regs(REG_ANY, chip_mask);
            // read all registers, no safe mode -> pipelined read, only once per register
            my_ads->hw_rd_all_regs(chip_mask, 0);
            // wake up the ADC
            my_ads->hw_send_cmd(ADS131_WAKEUP, chip_mask);
            // print the results
            printf("# Read back after init and dump reset, calculated and read values\n");
            for (int i=0; i<NCHIPS_ADC; i++)
            {
                fprintf(stdout, "\n# ADS131M04 Chip %d, register table\n", i);
                my_ads->print_table(stdout, i, 1, 1);
            }
        }
        else
        if (strcmp(argv[idx],"--adc_rd_all_reg") == 0 )
        {
            int srate, in_mux, gc_flag, shift_r, do_offs;

            srate   = atoi(argv[++idx]);
            gc_flag = atoi(argv[++idx]);
            in_mux  = atoi(argv[++idx]);
//            do_offs = atoi(argv[++idx]);
            shift_r = atoi(argv[++idx]);
            do_offs = 0;

            my_ads->prepare_all_regs(srate, gc_flag, ADS_GAIN, in_mux, do_offs, shift_r, chip_mask, 1);
            my_ads->hw_spi_reset();
            my_ads->hw_auto_read(0, AUTO_CRC, 0, 0, chip_mask);
            my_ads->hw_send_cmd(ADS131_STANDBY, chip_mask);
            my_ads->hw_rd_all_regs(chip_mask, 0);
            my_ads->hw_send_cmd(ADS131_WAKEUP, chip_mask);
            printf("# Read back and dump reset, calculated and read values\n");
            for (int i=0; i<NCHIPS_ADC; i++)
            {
                fprintf(stdout, "\n# ADS131M04 Chip %d, register table\n", i);
                my_ads->print_table(stdout, i, 1, 0);
            }
        }
        else
        if (strcmp(argv[idx],"--adc_reset") == 0 )
        {
            my_ads->hw_adc_reset(1);
        }
        else
        if (strcmp(argv[idx],"--adc_sync") == 0 )
        {
            my_ads->hw_adc_sync(1);
        }
        else
        if (strcmp(argv[idx],"--adc_16") == 0 )
        {
            ads_16bit_data = atoi(argv[++idx]) & 1;
        }
        else
        if (strcmp(argv[idx],"--adc_spi_reset") == 0 )
        {
            my_ads->hw_spi_reset();
        }
        else
        if (strcmp(argv[idx],"--adc_auto_read") == 0 )
        {
            int auto_read, sync, auto_crc;

            auto_read = atoi(argv[++idx]);
            auto_crc  = atoi(argv[++idx]);
            sync      = atoi(argv[++idx]);

            if (ads_16bit_data)
            {
                my_ads->set_16_24b(0);  // prepare the new value of MODE register
                my_ads->hw_update_all_regs(); // update only changed
            }
                                                                            // clear new
            my_ads->hw_auto_read(auto_read, auto_crc, sync, ads_16bit_data, 0, chip_mask);
        }
        else
        if (strcmp(argv[idx],"--adc_chip_mask") == 0 )
        {
            chip_mask = atoi(argv[++idx]);
            chip_sel  = atoi(argv[++idx]);
                        // mask             select
            my_ads->hw_chip_mask(chip_mask, chip_sel);
        }
        else
        if (strcmp(argv[idx],"--adc_get_freq_per") == 0 )
        {
            my_ads->hw_get_freq_per(chip_sel, 1);
        }
        else
        if (strcmp(argv[idx],"--adc_get_per") == 0 )
        {
            my_ads->hw_get_per(chip_sel, 1);
        }
        else
        if (strcmp(argv[idx],"--adc_wreg") == 0 ) // <reg_addr> <reg_data>
        {
            uint32_t reg_data, reg_addr;

            read_hex_dec(argv[++idx], &reg_addr);
            read_hex_dec(argv[++idx], &reg_data);
            my_ads->hw_wr_reg(reg_addr, reg_data, chip_mask);
        }
        else
        if (strcmp(argv[idx],"--adc_standby") == 0 )
        {
            my_ads->hw_send_cmd(ADS131_STANDBY, chip_mask);
            printf("# Send the chips with mask 0x%02x in standby\n", chip_mask);
        }
        else
        if (strcmp(argv[idx],"--adc_wakeup") == 0 ) // <reg_addr> <reg_data>
        {
            my_ads->hw_send_cmd(ADS131_WAKEUP, chip_mask);
            printf("# Wakeup the ADC chips with mask 0x%02x\n", chip_mask);
        }
        else
        if (strcmp(argv[idx],"--adc_rd") == 0 )
        {
            int nsampl;
            int32_t adc_data[N_ADC_CHANNELS_ALL];

                                // mask             select
            nsampl=atoi(argv[++idx]);
            // read two samples, to skip the first samples after reset/sync
            my_ads->hw_rd_adc(adc_data);
            my_ads->hw_rd_adc(adc_data);
            for (int sampl=0; sampl < nsampl; sampl++)
            {
                my_ads->hw_rd_adc(adc_data);
                for (int i=0; i<NCHIPS_ADC*4; i++)
                {
                    if (sampl==0) adc_stat[i].init();
                    adc_stat[i].add(adc_data[i]);
                }
            }
            printf("# ch#  MIN abs/%%       MAX abs/%%      MEAN abs/%%     AC-RMS abs/%%       P-P abs/%%\n");
            for (int i=0; i<NCHIPS_ADC*4; i++)
            {
                printf(" %2d %8d %6.2f %8d %6.2f %8.0f %6.2f %8.0f %6.3f %8d %6.3f\n", i,
                    adc_stat[i].get_min(), 100.0*adc_stat[i].get_min() /ADC_MAX_CODE,
                    adc_stat[i].get_max(), 100.0*adc_stat[i].get_max() /ADC_MAX_CODE,
                    adc_stat[i].get_mean(),100.0*adc_stat[i].get_mean()/ADC_MAX_CODE,
                    adc_stat[i].get_rms(), 100.0*adc_stat[i].get_rms() /ADC_MAX_CODE,
                    adc_stat[i].get_max()-adc_stat[i].get_min(),100.0*(adc_stat[i].get_max()-adc_stat[i].get_min())/ADC_MAX_CODE  );
            }
        }
        else
        if (strcmp(argv[idx],"--get_adc_buff") == 0 )
        {
            char out_file[512];
            FILE *f;

            // open the file
            strcpy(out_file, argv[++idx]);
            f = fopen(out_file,"w");
            p_hbr->read_adc_buffer(f);
        }
        else
        if (strcmp(argv[idx],"--dac_write2eep") == 0 )
        {
            dac_write2eep = 1;
        }
        else
        if (strcmp(argv[idx],"--init_hbr_vref") == 0 )
        {
            // need to be done only once after power up and when stored to EEPROM - only once!
            my_dual_dac->init_dac_ref(DAC_USED_REF, dac_write2eep, 1);
        }
        else
        if (strcmp(argv[idx],"--set_hbr_vref") == 0 )
        {
            int ch;
            float volt;
            // may be swap 1 and 2!
            ch  =atoi(argv[++idx]);
            volt=atof(argv[++idx]);
            my_dual_dac->set_dac_volt(ch, volt, DAC_USED_REF, dac_write2eep, 1);
        }
        else
        if (strcmp(argv[idx],"--rd_reg") == 0 ) // <len> <addr>
        {
            uint32_t rd_len, rd_addr, rd_val = 0;

            if (idx+2 >= argc ||
                read_hex_dec(argv[idx+1], &rd_len) || read_hex_dec(argv[idx+2], &rd_addr) ||
                rd_len < 1 || rd_len > 4)
            {
                printf("--rd_reg needs <len=1..4> <addr>\n");
                return 1;
            }
            idx += 2;
            switch (rd_len)
            {
                case 1: rd_val = my_uart32->ReadByte(  rd_addr); break;
                case 2: rd_val = my_uart32->ReadWord(  rd_addr); break;
                case 3: rd_val = my_uart32->Read3Bytes(rd_addr); break;
                case 4: rd_val = my_uart32->ReadDWord( rd_addr); break;
            }
            printf("0x%0*x\n", (int) (2*rd_len), rd_val);
        }
        else
        if (strcmp(argv[idx],"--cpu_off") == 0 )
        {
            p_hbr->send_cmd(1 << BIT_CONFIG_CMD_CPU_OFF, 1);
        }
        else
        if (strcmp(argv[idx],"--cpu_rst") == 0 )
        {
            p_hbr->send_cmd(1 << BIT_CONFIG_CMD_CPU_RST, 1);
        }
        else
        if (strcmp(argv[idx],"--wr_imem") == 0 )
        {
            FILE *f_inp;
            char inp_file[512];
            uint32_t imem_data[IMEM_SIZE];

            p_hbr->send_cmd(1 << BIT_CONFIG_CMD_CPU_OFF, 1);
            // open the file with the IMEM for reading
            strcpy(inp_file, argv[++idx]);
            f_inp = fopen(inp_file,"r");
            // read the IMEM from file
            p_hbr->read_imem_file(f_inp, imem_data, IMEM_SIZE);

            fclose(f_inp);
            // write to the IMEM
            printf("# Write %d words to IMEM at 0x%06x\n", IMEM_SIZE, ADDR_IMEM_BASE);
            p_hbr->set_sh_mem(IMEM_SIZE, ADDR_IMEM_BASE, imem_data, 1);
            p_hbr->send_cmd(1 << BIT_CONFIG_CMD_CPU_RST, 1);
            p_hbr->send_cmd(0, 1);
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

    delete p_hbr;
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

// Function to Set the Switching MOSFETS
// @param fet_n: What FET will be controlled with this instruction set. 0 = LV FET, 1 = HV FET
// @param fet_enable: Enables the Driver of FET n. 0 = disabled, 1 = Enabled
// @param fet_signal: Switches the FETs on and off. 0 = off, 1 = on
// @return 0: Function ended Successfully
// @return 1: FAILURE by invalid Parameter Values
//uint8_t set_fet(uint8_t fet_n, uint8_t fet_enable, uint8_t fet_signal) {
//    // parameter check
//    if(fet_n > 1 || fet_enable > 1 || fet_signal > 1) {
//        // PRINT ERROR
//        return 1; // FAILURE by invalid Parameter Values
//    }
//
//    // Transmit controll signals to FPGA
//
//    return 0; // SUCCESS
//}
