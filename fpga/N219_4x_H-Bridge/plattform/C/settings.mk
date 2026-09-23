# $Id: settings.mk 1052 2024-01-09 13:43:32Z angelov $:
#
#-------------------------------------------------
#
# Name your output executable here:
# APP_OUTPUT_ELF will be used by the main makefile,
# so it should not be renamed to something else.
#
#-------------------------------------------------
APP_OUTPUT_ELF=lm32_xo2.elf
#
#-------------------------------------------------
# You do not want the intermediate and final outputs
# that will be deleted by a clean to clutter
# this project folder, so you specify your output
# directory.
#-------------------------------------------------
OUTPUT_DIR=./output
#
#-------------------------------------------------
# Provide compiler, assembler, and linker flags that will
# be used when building the application.
# Note: These flags do not affect the platform
# library if this project references the
# platform library.
#-------------------------------------------------
# CFLAGS affect C compiler: (standard gcc flags)
# 1. You want functions to be in their own sections for
#    size reduction (-ffunction-sections)
# 2. Optimization level (-O0 .. -O3)
# 3. Debug symbols (-g0 .. -g2)
# 4. Warnings (-w)
# 5. You want to use the standalone printf
# 6. You want to define __lm32__ preprocessor definition
CFLAGS= -ffunction-sections -O3 -g0 -w
#
# Add preprocessor defines to CFLAGS
# standalone printf implementation (-D_USE_LSCC_PRINTF_)
CFLAGS+=-D_USE_LSCC_PRINTF_ -D__lm32__
# -D__RELOCATE_EXCEPTION_TABLE__ was in the auto-generated Makefile
#
# LDFLAGS affect linker:
# Since you are using lm32-elf-gcc (and not lm32-elf-ld),
# you must specify -Wl, before the linker flag
# (refer to gcc documentation)
# Delete sections that are not used
# (thereby making your executable more compact)
LDFLAGS +=-Wl,--gc-sections
#
# Define which C library you want to use.
# You have two choices according to what Lattice provides:
# 1. -lsmallc (small Newlib C library)
# 2. -lc (complete C library)
C_LIB=-lsmallc
#
#
# sudo cp ./local/Xilinx/14.5/ISE_DS/ISE/lib/lin/libgmp.so.7 /usr/lib/libgmp.so.3