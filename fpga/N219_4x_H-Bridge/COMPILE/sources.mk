# $Id: sources.mk 1215 2026-08-28 14:13:16Z  $:
#
# local for the project sources
pref_cores=../SRC/CORES
pref_top=../SRC/TOP
pref_risc=../plattform
pref_i2c=../SRC/I2C
pref_shutter=../SRC/SHUTTER
pref_ads131=../SRC/ADS131M04_32bit
pref_uart=../SRC/UART
#
# global sources
pref_global=../../../SRC
pref_common=$(pref_global)/COMMON
pref_xo2_cores=$(pref_global)/CORES
pref_uart32=$(pref_global)/UART32
pref_tsens=$(pref_global)/TSENS
#
# COMMON
#
src_common=\
$(pref_common)/svn_extract.vhd \
$(pref_common)/ssram.vhd       \
$(pref_common)/dpram.vhd       \
$(pref_common)/dpram_2rd.vhd   \
$(pref_common)/sc_fifo.vhd     \
$(pref_common)/filt_long.vhd   \
$(pref_common)/filt_short.vhd   \
$(pref_common)/pup_reset.vhd   \
$(pref_common)/led.vhd     \
$(pref_common)/clk_div.vhd     \
$(pref_common)/clock_div_ena.vhd \
$(pref_common)/we_leds_4_lev.vhd \
$(pref_common)/test_reg.vhd
#
# UART core
#
src_uart32=\
$(pref_uart32)/phase_acc.vhd \
$(pref_uart32)/ser_send.vhd    \
$(pref_uart32)/ser_recv.vhd    \
$(pref_uart32)/sendsm.vhd      \
$(pref_uart32)/recvsm.vhd      \
$(pref_uart32)/serial_send.vhd \
$(pref_uart32)/serial_recv.vhd \
$(pref_uart32)/prot_sm.vhd     \
$(pref_uart32)/wdog.vhd        \
$(pref_uart32)/uart.vhd        \
$(pref_uart32)/uart_top.vhd
#
# Temperatur sensors with 1-wire interface DS18B20 compatible
#
src_tsens=\
$(pref_tsens)/ds_pack.vhd    \
$(pref_tsens)/program.vhd    \
$(pref_tsens)/timeslots.vhd  \
$(pref_tsens)/byteslots.vhd  \
$(pref_tsens)/ds_top.vhd
#
# ADS131 (ADC) SPI Interface
src_ads131=\
$(pref_ads131)/ads131m04_pack.vhd  \
$(pref_ads131)/ads131m04_io.vhd    \
$(pref_ads131)/crc16reg.vhd        \
$(pref_ads131)/ads131m04_spi.vhd   \
$(pref_ads131)/ads131m04.vhd
#
# I2C
src_i2c=\
$(pref_i2c)/i2c_mast.vhd \
$(pref_i2c)/i2c_pack.vhd \
$(pref_i2c)/i2c_top32.vhd
#
src_shutter=\
$(pref_shutter)/hbr_gen_pkg.vhd \
$(pref_shutter)/hbr_dec_cnf.vhd \
$(pref_shutter)/pwm_gen.vhd \
$(pref_shutter)/hbr_sm.vhd \
$(pref_shutter)/hbr_gen.vhd
#
src_top=\
$(pref_top)/config_pkg.vhd     \
$(pref_xo2_cores)/sed_check_xo3d.vhd \
$(pref_top)/config.vhd         \
$(pref_xo2_cores)/efb_flash_xo3d.vhd \
$(pref_common)/wb2mybus.vhd \
$(pref_common)/wb_wrap_xo3d.vhd \
$(pref_top)/dec_mux.vhd        \
$(pref_top)/top_bus.vhd \
$(pref_uart)/crc8reg.vhd       \
$(pref_uart)/uc2tx.vhd         \
$(pref_risc)/lm32_xo2/soc/lm32_xo2.v \
$(pref_risc)/lm32_xo2/soc/lm32_xo2_vhd.vhd \
$(pref_top)/top_cpu.vhd \
$(pref_top)/top_leds.vhd \
$(pref_top)/uart_switch.vhd \
$(pref_top)/uart_rx_mix.vhd \
$(pref_cores)/pll_24k_32k_48k_ts.vhd \
$(pref_cores)/pll_12M_36M_48M_1M.vhd

# probably can be specified together with the VHDL files above
src_vlog=\
$(pref_risc)/lm32_xo2/soc/risc32.v

# $(pref_common)/dpram_2rd.vhd
# $(pref_common)/filt_short.vhd
