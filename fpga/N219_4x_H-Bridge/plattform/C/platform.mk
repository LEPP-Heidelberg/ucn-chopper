# $Id: platform.mk 1052 2024-01-09 13:43:32Z angelov $:
#
#Define platform-specific settings that can be quickly changed.
#
#
PLATFORM_NAME=lm32_xo2
PLATFORM_DIRECTORY= $(PROJECT_DIRECTORY)/$(PLATFORM_NAME)
PLATFORM_FILE=$(PLATFORM_NAME).msb
PLATFORM_FILE_PATH=../$(PLATFORM_NAME)/soc
#
#PLATFORM_LIB_PATH=../$(PLATFORM_NAME)/soc
PLATFORM_BLD_CFG=Release
PLATFORM_LIB_PATH=./$(PLATFORM_BLD_CFG)
#
#
#
# Derive other information from the basic platform
# information as required by main makefile.
#
# 1. Specify where these platform-dependent makefiles are
#    located.
#PLATFORM_MAKEFILES_DIR = $(addprefix $(PLATFORM_LIB_PATH),\
#	$(addprefix /$(PLATFORM_NAME), /$(PLATFORM_BLD_CFG)))

PLATFORM_MAKEFILES_DIR=./$(PLATFORM_NAME)/$(PLATFORM_BLD_CFG)

	
#
# 2. Platform library (relative path and name)
#    required by main makefile.
PLATFORM_LIBRARY=$(addprefix $(PLATFORM_LIB_PATH)/,	$(addprefix $(PLATFORM_BLD_CFG)/, $(addprefix $(PLATFORM_BLD_CFG)/, lib$(PLATFORM_NAME).a)))

PLATFORM_LIBRARY=$(PLATFORM_BLD_CFG)/$(PLATFORM_BLD_CFG)/lib$(PLATFORM_NAME).a

#
# 3. Linker file required by main makefile
LD_FILE=$(PLATFORM_MAKEFILES_DIR)/linker.ld
#
# 4. $(CPU_CONFIG) defines CPU-specific configuration.
# CPU-specific configuration is platform-dependent, so you
# put it in this file.
# Platform_rules.mk contains CPU configuration.
#
include $(PLATFORM_MAKEFILES_DIR)/platform_rules.mk