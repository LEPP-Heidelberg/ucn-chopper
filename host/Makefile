## $Id: Makefile 1224 2026-09-18 09:42:59Z  $:
#SHELL=/bin/bash
#.SHELLFLAGS="-O extglob -c"
#
# for use under windows 
# make -d OS=windows
# MinGW must be installed under C:\MinGW

# hardware version, 0 on XO3D BB, 1 - N219 PCB
VERSION=1
USE_OPTICAL=0

# CPU_TYPE is LM32 or SW32
CPU_TYPE=SW32
#
ifeq ($(CPU_TYPE), SW32)
CPU_TYPE_DEF=CPU_SW32
endif

ifeq ($(CPU_TYPE), LM32)
CPU_TYPE_DEF=CPU_LM32
endif

SHELL := /bin/bash

CFLAGS = -g -Wall

# the power up ID, should be reprogrammed
# linux, rp4
OS=linux

# when programming for the first time using USB programming cable, execute 

# > latt314
# > programmer

# where:
# alias latt314='
# export PATH=$PATH:/usr/local/latt_prog/bin/lin64:/usr/local/latt_prog/ispfpga/bin/lin64;
# export LD_LIBRARY_PATH=/usr/local/latt_prog/bin/lin64:/usr/local/latt_prog/ispfpga/bin/lin64:/usr/local/latt_prog/bin/lin64/engines;
# export FOUNDRY=/usr/local/latt_prog/ispfpga;
# export LSC_DIAMOND=true;'
#
# address width 24, data width 32
LINK_OPT=--aw 24 --dw 32

ID_MASK=1

# UART baud rate:
#  Supported by Windows in DOS window: 1200, 2400, 4800, 9600, 19200, 38400, 57600, 115200
# +Supported by cygwin: 230400, 460800, 500000, 576000, 921600, 1000000, 2000000 (up to here by the most USB-UART chips), 3000000
# +Supported by linux: 4000000 (and only by few USB-UART chips)

# RP4 doesn't support more than 2MBit/s!
UART_BaudRate=4000000

# for prototype
ifeq ($(VERSION),0)

	# system clock, final version has 49152000 Hz
	FREQ_FCLK_SYS=48000000

	# location of the FPGA programming file
	PROG_FILE_W=./pgm/N219_LCMXO3D-9400HC-5I_v0_a.bin
	PROG_FILE_G=./pgm/N219_LCMXO3D-9400HC-5I_v0_b.bin
	dev_nr=1
	DEVICE_PREFIX=/dev/ttyUSB

endif

# for final
ifeq ($(VERSION),1)
	# system clock, final version has 49152000 Hz
	# for LM32
	FREQ_FCLK_SYS=49152000
	# for SW32
	FREQ_FCLK_SYS=32768000

	# location of the FPGA programming file
	PROG_FILE_W=./pgm/N219_LCMXO3D-9400HC-6C_v1_a.bin
	PROG_FILE_G=./pgm/N219_LCMXO3D-9400HC-6C_v1_b.bin

	dev_nr=0
	ifeq ($(USE_OPTICAL),1)
		DEVICE_PREFIX=/dev/ttyUSB
	else
		DEVICE_PREFIX=/dev/ttyACM
	endif

endif

DEV=$(DEVICE_PREFIX)$(dev_nr)

#IMEM_FILE=./pgm/lm32_xo2.mem
IMEM_FILE=./pgm/imem_dp.txt

# Note: in order to work without root rights with the ttyACM devices, execute
# sudo usermod -a -G dialout <username>

CXX=g++
#LDFLAGS=-L${DIMDIR}/linux
rm_cmd=rm -f
OS_DEF=_LINUX

DEV=$(DEVICE_PREFIX)$(dev_nr)


# debug level for the messages, 0 - lowest, 1 - normal, 2 - more
DLEVEL=0

# prefix for the common C++ classes
prefix=../upstream

# main program to reprogram the XO2 FPGA
FPGA_PROGRAM=xo3d_fpga8_32
FPGA_CLASS=one_xo3d_fpga8_32

UART_DEV_CLASS=uart
UART32_PROT_CLASS=uart32

# main program for the IF38A board
main_cpp=hbr

# top class for the FPGA design
top_class=C_hbr
class_dtemp=C_dtemp
class_dac=C_dual_dac
class_stat=C_simpl_stat
class_adcs131m04=C_ads131m04


############################
#                          #
# C++ compile operations   #
#                          #
############################


# the program to erase, write, read the flash memories in the XO2, as well with some small utilities
$(FPGA_PROGRAM): CLogger.o $(UART32_PROT_CLASS).o $(UART_DEV_CLASS).o $(FPGA_CLASS).o $(FPGA_PROGRAM).o # CTimer.o 
	@echo "OS is $(OS), C++ compiler is $(CXX)"
	$(CXX) $(CFLAGS) $(LDFLAGS) -o $@ $^

$(FPGA_PROGRAM).o: $(prefix)/$(FPGA_PROGRAM).cpp $(prefix)/$(UART_DEV_CLASS).h $(prefix)/$(UART32_PROT_CLASS).h $(prefix)/$(FPGA_CLASS).h
	$(CXX) -D $(OS) -D DEF_BRATE=$(UART_BaudRate) \
	-D DEVICE_PORT=$(dev_nr) -D $(OS_DEF) -D DEF_CSR_BASE=0x800110 -D DEF_WB_BASE=0x800000 -D FREQ_FCLK_SYS=$(FREQ_FCLK_SYS) \
	-D DEF_AWIDTH=24 -D DEF_DWIDTH=32 -D DEF_ID=1 -D DEF_ID_MASK=2 -D DEVICE_PREFIX=\"$(DEVICE_PREFIX)\" \
	-c -Wall -pedantic -o $@ $<


$(main_cpp): CLogger.o $(UART32_PROT_CLASS).o $(UART_DEV_CLASS).o $(FPGA_CLASS).o $(top_class).o $(main_cpp).o $(class_adcs131m04).o $(class_stat).o $(class_dtemp).o $(class_dac).o
	@echo "OS is $(OS), C++ compiler is $(CXX)"
	$(CXX) $(CFLAGS) $(LDFLAGS) -o $@ $^

$(main_cpp).o: $(main_cpp).cpp $(top_class).cpp $(top_class).h $(prefix)/$(UART_DEV_CLASS).h $(prefix)/$(UART32_PROT_CLASS).h $(class_adcs131m04).h $(class_stat).h $(class_dtemp).h $(class_dac).h
	$(CXX) -D $(OS) -D DEF_BRATE=$(UART_BaudRate) -D DEVICE_PORT=$(dev_nr) -D $(OS_DEF) -D DEVICE_PREFIX=\"$(DEVICE_PREFIX)\" -D $(CPU_TYPE_DEF) \
	-D DEF_AWIDTH=24 -D DEF_DWIDTH=32 \
	-c -Wall -pedantic -o $@ $<


$(top_class).o: $(top_class).cpp $(top_class).h
	$(CXX) -D $(OS) -D $(CPU_TYPE_DEF) -c -Wall -pedantic $< -c -o $@

# the class with the functions to calculate the ADS configurations registers and with 
# the hardware functions to write/read them and to make some simple ADC tests
$(class_adcs131m04).o: $(class_adcs131m04).cpp $(class_adcs131m04).h uart32.o CLogger.o
	$(CXX) -D $(OS) -c -Wall -pedantic $< -c -o $@

# simple class for statistics, capabale of calculating min/max/mean/rms of a stream of ADC data (24-bit signed integers)
$(class_stat).o: $(class_stat).cpp $(class_stat).h
	$(CXX) -D $(OS) -c -Wall -pedantic $< -c -o $@

$(class_dtemp).o: $(class_dtemp).cpp $(class_dtemp).h uart32.o CLogger.o
	$(CXX) -D $(OS) -c -Wall -pedantic $< -c -o $@

$(class_dac).o: $(class_dac).cpp $(class_dac).h dac_mcp47feb.h uart32.o CLogger.o
	$(CXX) -D $(OS) -c -Wall -pedantic $< -c -o $@

# the class with the basic I/O functions over UART
$(UART_DEV_CLASS).o: $(prefix)/$(UART_DEV_CLASS).cpp $(prefix)/$(UART_DEV_CLASS).h
	$(CXX) -D $(OS) -c -Wall -pedantic $< -c -o $@

# the class with the protocol
$(UART32_PROT_CLASS).o: $(prefix)/$(UART32_PROT_CLASS).cpp $(prefix)/$(UART32_PROT_CLASS).h $(prefix)/$(UART_DEV_CLASS).h
	$(CXX) -D $(OS) -c -Wall -pedantic $< -c -o $@

# the class with the XO2 FPGA specific functions
$(FPGA_CLASS).o: $(prefix)/$(FPGA_CLASS).cpp $(prefix)/$(FPGA_CLASS).h
	$(CXX) -D $(OS) -c -Wall -pedantic $< -c -o $@

	
CLogger.o: $(prefix)/CLogger.cpp $(prefix)/CLogger.h
#	@echo "Called CLogger.o"
	$(CXX) $(CFLAGS) -D $(OS) -Wall -pedantic $< -c -o $@

clean:
	-$(rm_cmd) *.o $(FPGA_PROGRAM) $(main_cpp) $(main_cpp).exe



############################
#                          #
# FPGA Flash operations    #
#                          #
############################
#
# program new FPGA image
prog_w:
	./$(FPGA_PROGRAM) --br $(UART_BaudRate) --dev $(DEV) --id $(ID_MASK) --epv_cfg 0 $(PROG_FILE_W)

prog_g:
	./$(FPGA_PROGRAM) --br $(UART_BaudRate) --dev $(DEV) --id $(ID_MASK) --epv_cfg 1 $(PROG_FILE_G)

imem:
	./$(main_cpp) --br $(UART_BaudRate) --dev $(DEV) --id $(ID_MASK) --wr_imem $(IMEM_FILE)

# verify the FPGA image
vrf_w:
	./$(FPGA_PROGRAM) --br $(UART_BaudRate) --dev $(DEV) --id $(ID_MASK) --fstatus --vrf_cfg 0 $(PROG_FILE_W)

vrf_g:
	./$(FPGA_PROGRAM) --br $(UART_BaudRate) --dev $(DEV) --id $(ID_MASK) --fstatus --vrf_cfg 1 $(PROG_FILE_G)



# reload the FPGA configuration from the internal flash
# Note: the IDs need to be reprogrammed after that!
refresh:
	./$(FPGA_PROGRAM) --br $(UART_BaudRate) --dev $(DEV) --id $(ID_MASK) --refresh
	sleep 1

# read the FPGA status, the IDs have to be programmed before
fstatus:
	./$(FPGA_PROGRAM) --br $(UART_BaudRate) --dev $(DEV) --id $(ID_MASK) --fstatus


############################
#                          #
# Measurements             #
#                          #
############################
# time step in ms, time scale, power scale
#TABLE_RISING=waveforms/legacy/simpl_wave.dat 0 1 1
TABLE_RISING=waveforms/legacy/rect_wave.dat 0 1 1
#TABLE_RISING=close.dat 0 1 1
TABLE_FALLING=wave_corr_cat2.dat 0 0.1 -1
TABLE_FALLING=waveforms/legacy/rect_wave.dat 0 1 -1

# parameters of the H-bridge chip, see the datasheet!
HBR_DECAY=0
HBR_TOFF=0
# sleep_n must be 1, otherwise the H-bridge is off
HBR_SLEEP_N=1

# parameters of the state machine controlling the sequence
# short the coil when no power: <mask> <1|0 for on/off>
SLOW_DECAY=3 1
# preserve the last PWM state when sequence finished: <mask> <1|0 for on/off>
PRESERVE_LAST=3 0
# OLD: 4800 | 8000 | 9600 | 16000 | 19200 | 24000 | 32000 | 48000
# NEW: 4000, 6400, 8000, 12800, 16000, 25600, 32000, 64000
# the program selects the requested (if available) or the next smaller available frequency
PWM_FREQ=6000

# ADC parameters (for 2x ADS131M04), better not to change!
# Sampling rate in Hz from 250 to 64 kS/s, here we should take the max!
ADS_SRATE=64000
# ADC chop mode is available only up to 8 kS/s!
ADS_GC=0
# mux=0 is the normal position, the others 1..3 are for testing only
ADS_MUX=0
# shift right the data from the ADC, in case of 16-bit transfer
# not necessary to shift additionally by 8 bits!
ADS_SHR=0
# data transfer as 16 or 24 bit, in case of 64 kS/s must use 16-bit
# the ADC initialization is done in 24-bit mode.
ADS_16BIT=1
# this number is only for testing
NSAMPLES=1000

adc_conf:
	./$(main_cpp) --dev $(DEV) --adc_chip_mask 3 0 --adc_auto_read 0 1 0
	sleep 1
	./$(main_cpp) --dev $(DEV) --adc_conf $(ADS_SRATE) $(ADS_GC) $(ADS_MUX) $(ADS_SHR) --adc_16 $(ADS_16BIT) --adc_auto_read 1 1 1 --adc_get_freq_per

adc_read:
	./$(main_cpp) --dev $(DEV) --adc_rd $(NSAMPLES)

#
# old, not very practical waveform
load_table0r:
	./$(main_cpp) --create_table 48000 1 1.1 1.0 4.0 1.0 -0.4 2.1 1.1 0.3 10 --load_table 0 1

load_table0f:
	./$(main_cpp) --create_table 48000 1 1.5 0.8 3.0 1.0 -0.3 2.0 0.5 0.3 10 --load_table 0 0


load_table1r:
	./$(main_cpp) --dev $(DEV) --create_table 48000 1 1.1 1.0 2.0 1.0 -0.4 2.1 1.1 0.3 10 --load_table 1 1

load_table1f:
	./$(main_cpp) --dev $(DEV) --create_table 48000 1 1.5 0.8 1.5 1.0 -0.3 2.0 0.5 0.3 10 --load_table 1 0

hbr_full_conf0: refresh hbr_conf pwl_table0r pwl_table0f hbr_rep

hbr_full_conf1: refresh hbr_conf pwl_table1r pwl_table1f hbr_rep

hbr_rep:
	./$(main_cpp) --dev $(DEV) --hbr_rep --status

hbr_conf:
	./$(main_cpp) --dev $(DEV) --set_pwm $(PWM_FREQ) --ctrl_in_afbr 0 1 0 --ctrl_in_afbr 1 1 0 --ctrl_in_ocpl 0 1 0 --ctrl_in_ocpl 1 1 0 \
	--hbr_decay $(HBR_DECAY) --hbr_toff $(HBR_TOFF) --set_slow_dec_sm $(SLOW_DECAY) --set_preserve_last $(PRESERVE_LAST) \
	--hbr_sleep_n 1 --sm_reset 3

all_conf: hbr_conf adc_conf pwl_table0f pwl_table0r pwl_table1f pwl_table1r hbr_rep

pwl_table0r:
# use the current/last PWM frequency, scaling factors for time and power : 1, 1
# load the table to channel 0, rising edge
	./$(main_cpp) --dev $(DEV) --read_table $(TABLE_RISING) --load_table 0 1

pwl_table0f:
# use the current/last PWM frequency, scaling factors for time and power : 1, 1
# load the table to channel 0, falling edge
	./$(main_cpp) --dev $(DEV) --read_table $(TABLE_FALLING) --load_table 0 0

pwl_table1r:
# use the current/last PWM frequency, scaling factors for time and power : 1, 1
# load the table to channel 1, rising edge
	./$(main_cpp) --dev $(DEV) --read_table $(TABLE_RISING) --load_table 1 1

pwl_table1f:
# use the current/last PWM frequency, scaling factors for time and power : 1, 1
# load the table to channel 1, falling edge
	./$(main_cpp) --dev $(DEV) --read_table $(TABLE_FALLING) --load_table 1 0

start0r:
	./$(main_cpp) --adc_chip_mask 3 0
	./$(main_cpp) --start 1 1 1
	./$(main_cpp) --get_adc_buff adc.dat
	./$(FPGA_PROGRAM) --gmem16 2048 0x806000 |less

start0f:
	./$(main_cpp) --adc_chip_mask 3 0
	./$(main_cpp) --start 1 0 1
	./$(main_cpp) --get_adc_buff adc.dat
	./$(FPGA_PROGRAM) --gmem16 2048 0x806000 |less

start1r:
	./$(main_cpp) --adc_chip_mask 3 1
	./$(main_cpp) --start 2 1 1
	./$(main_cpp) --get_adc_buff adc.dat
	./$(FPGA_PROGRAM) --gmem16 2048 0x806000 |less

start1f:
	./$(main_cpp) --adc_chip_mask 3 1
	./$(main_cpp) --start 2 0 1
	./$(main_cpp) --get_adc_buff adc.dat
	./$(FPGA_PROGRAM) --gmem16 2048 0x806000 |less

start_r:
	./$(main_cpp) --adc_chip_mask 3 1
	./$(main_cpp) --start 3 1 1
	./$(main_cpp) --get_adc_buff adc.dat
	./$(FPGA_PROGRAM) --gmem16 2048 0x806000 |less


.PHONY: clean fstatus refresh prog_w prog_g vrf vrf
