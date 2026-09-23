# $Id: Makefile 1212 2026-08-21 14:35:39Z  $:

PREF_GLOBAL=../../../SRC
PREF_COMMON=$(PREF_GLOBAL)/COMMON

#1 HBR or I2C
SIM_PROJ=I2C

ifeq ($(SIM_PROJ),HBR)
PREF_SHUTTER=../SRC/SHUTTER

TOP=hbr_gen

SOURCES=\
$(PREF_COMMON)/dpram_2rd.vhd   \
$(PREF_COMMON)/filt_long.vhd   \
$(PREF_SHUTTER)/hbr_gen_pkg.vhd \
$(PREF_SHUTTER)/hbr_dec_cnf.vhd \
$(PREF_SHUTTER)/pwm_gen.vhd \
$(PREF_SHUTTER)/hbr_sm.vhd \
$(PREF_SHUTTER)/$(TOP).vhd
TB_SOURCES=$(PREF_SHUTTER)/hbr_gen_pkg.vhd ./SRC/$(TOP)_tb.vhd
endif
#$(PREF_COMMON)/sc_fifo.vhd


ifeq ($(SIM_PROJ),I2C)
PREF_I2C=../SRC/I2C
PREF_SLAVE=../../A434_DDC112/SRC

TOP=i2c_top32

SOURCES=\
$(PREF_COMMON)/filt_short.vhd   \
$(PREF_I2C)/i2c_pack.vhd \
$(PREF_I2C)/i2c_mast.vhd \
$(PREF_I2C)/i2c_top32.vhd \

TB_SOURCES=$(PREF_COMMON)/filt_long.vhd $(PREF_I2C)/i2c_pack.vhd $(PREF_SLAVE)/i2c_slave.vhd $(PREF_SLAVE)/i2c_slave_detect.vhd ./SRC/$(TOP)_tb.vhd
endif


VCOM_OPT=-explicit -rangecheck -quiet 
VSIM_OPT=-nocollapse -i -quiet -t 1ps -voptargs=+acc
# functional.top
#vsim_opt=-nocollapse -i -quiet -t 1ps -voptargs=-access functional.top
#vsim_opt=-nocollapse -i -quiet -t 1ps -voptargs=-debug functional.top
 
VLOG_OPT=-quiet

# compile for functional simulation
fcomp: functional work
#	echo $(SOURCES)
#	vcom -work work -2008 $(VCOM_OPT) $(packages)
	vcom -work functional -2008 -explicit $(VCOM_OPT) $(SOURCES)
#	vlog -work functional $(VLOG_OPT) $(tb_sources_v)
	vmap fpga functional
	vcom -quiet -work work -2008 -explicit $(VCOM_OPT) $(TB_SOURCES)

# start functional simulation
fsim: fcomp
	vmap fpga functional
	vsim $(VSIM_OPT) 'work.$(TOP)_tb' -do 'wave_$(TOP).do'

# create work library
functional work:
	if [ ! -d $@ ]; then vlib $@; fi

# Clean all library directories
clean:
	rm -rf functional work questa.ini transcript vsim.wlf

.PHONY: fcomp fsim clean
