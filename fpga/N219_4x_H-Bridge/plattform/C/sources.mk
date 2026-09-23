# $Id: sources.mk 1216 2026-09-02 16:57:27Z angelov $:

#--------------------------------------------------------------
#- The source files that you want to compile
#- - main.c
#- - crt0ram.S (boot code) provided by platform library
#- CXX_SRCS are the .cpp source files (C++)
#- C_SRCS are the .c source files (C)
#- .S and .s are assembly source files for LatticeMico32
#--------------------------------------------------------------
#- C++ sources (.cpp)
CXX_SRCS=

#- C sources (.c)
C_SRCS=main.c design_functions.c uart_send.c DDInit.c
#
#- Assembly source files (.s and .S)
ASM_SRCS=crt0ram.S

#--------------------------------------------------------------
# Specify where this project can find platform-
# specific source files that are required for your build (in 
# this case, the only such file is crt0ram.S.)
#--------------------------------------------------------------
VPATH+=$(PLATFORM_LIB_PATH)/$(PLATFORM_NAME)/


#--------------------------------------------------------------
# In case the source files include header files provided by
# the platform library project, specify where these can be 
# found.
#--------------------------------------------------------------
#INCLUDE_PATH+=$(PLATFORM_LIB_PATH)/$(PLATFORM_NAME)/
INCLUDE_PATH+=./$(PLATFORM_NAME)