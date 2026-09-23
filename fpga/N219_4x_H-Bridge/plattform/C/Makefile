# $Id: Makefile 1128 2024-12-06 18:24:16Z angelov $:
#
PROJECT_NAME=lm32_xo2
BUILD_CONFIGURATION=Release
PROJECT_DIRECTORY=..
PLATFORM_LIB_PATH=../C
APP_ELF=$(BUILD_CONFIGURATION)/$(PROJECT_NAME).elf
#
# Include settings.mk that contain settings
# required by this makefile.
#
include settings.mk
include platform.mk
#
# Include makefile that contains the sources
# information, that is, sources to build and the
# locations where these sources can be found.
#
include sources.mk
# timestamp, created here before the compilation
BUILDSTAMP=DateTime.h
#
#
#
# You must prefix -I to each of the include paths,
# then make this available to the compiler.
# Modify CFLAGS to contain the include path.
#
CFLAGS += $(foreach inc_path, $(INCLUDE_PATH), -I$(inc_path))

#--------------------------------------------------------------
# Now that you have defined your .c, .s, .S and .cpp sources,
# extract the .o files that are needed for a successful build.
#--------------------------------------------------------------
OBJS=$(sort $(C_SRCS:.c=.o) $(patsubst %.cxx, %.o, $(patsubst %.cc, %.o, $(patsubst %.cpp, %.o, $(patsubst %.C, %.o,$(CXX_SRCS)))))	$(patsubst %.S, %.o, $(patsubst %.s, %.o, $(ASM_SRCS))))

#OBJS=main.o DDInit.o adcs_io.o i2c.o uart_send.o crt0ram.o

#------------------------------------------------------
# Prefix the output directory to the .o files,
# because that is where you want these .o files to be created
# and where the build process can find these created objects
# for the .elf build.
#------------------------------------------------------
APP_OBJS=$(addprefix $(OUTPUT_DIR)/, $(OBJS))

# we also modify where we want our .elf to be created
APP_ELF=$(addprefix $(OUTPUT_DIR)/, $(APP_OUTPUT_ELF))

.PHONY: all dummy clean
#--------------------------------------------------------
#
# Rule to clean this project.
# You just want to delete items that you created when building,
# including the output directory.
#
#--------------------------------------------------------
clean:
	@echo cleaning...
	rm -r -f $(OUTPUT_DIR)

# Dummy rule prepares for a build such as creating the output 
# directory.
dummy:
	@mkdir -p $(OUTPUT_DIR)
#	@echo $(VPATH)
	@echo "App Objects are:"
	@echo $(APP_OBJS)


#
# “All” rule defines how to build the output desired.
#
all: dummy DateTime $(APP_ELF) $(OUTPUT_DIR)/$(PROJECT_NAME).mem


# Define a function to build application.
define build_app
	lm32-elf-gcc \
	$(CPU_CONFIG) \
	-T $(LD_FILE) \
	-o$1 \
	$(APP_OBJS) \
	$(PLATFORM_LIBRARY) \
	-lm \
	$(C_LIB) \
	-lgcc \
	$(PLATFORM_LIBRARY) \
	-lnosys \
	$(LDFLAGS)
endef

#
# Define how to build the .elf file.
# This depends on the objects required, as well as
# the CPU configuration makefile.
# That is, if any change is detected, rebuild the 
# elf file.
#
$(APP_ELF): $(APP_OBJS) $(PLATFORM_RULES_MAKEFILE) $(LD_FILE) $(PLATFORM_LIBRARY)
	@echo
	@echo
	@echo building $(APP_ELF)
	$(call build_app,$@)
	lm32-elf-size $(APP_ELF)
	lm32-elf-objdump -d $(APP_ELF) > $(OUTPUT_DIR)/dump.txt

#--------------------------------------------------------------
# Create a generic rule to build .o files from .c files.
#--------------------------------------------------------------
$(OUTPUT_DIR)/%.o : %.c
	@echo
	@echo compiling $< to $@
	@echo
	lm32-elf-gcc -c $(CPU_CONFIG) $(CFLAGS) $(CPPFLAGS) $< -o $@

#--------------------------------------------------------------
# Create a generic rule to build .o files from .S files.
#--------------------------------------------------------------
$(OUTPUT_DIR)/%.o : $(PLATFORM_NAME)/%.S
	@echo
	@echo compiling $< to $@
	@echo
	lm32-elf-gcc -c $(CPU_CONFIG) $(CFLAGS) $(CPPFLAGS) $< -o $@

#--------------------------------------------------------------
# Create a bin file for memory initialisaton
#--------------------------------------------------------------
$(OUTPUT_DIR)/$(PROJECT_NAME).bin : $(APP_ELF)
	lm32-elf-objcopy -O binary $< $@

#--------------------------------------------------------------
# Create a hex-text file for memory initialisaton
#--------------------------------------------------------------
$(OUTPUT_DIR)/$(PROJECT_NAME).mem : $(OUTPUT_DIR)/$(PROJECT_NAME).bin
	bin_to_verilog --EB --width 4 $< $@


DateTime:
	@echo "#define DTYear     0x$(shell date +%Y)"   >  $(BUILDSTAMP)
	@echo "#define DTMonth    0x$(shell date +%m)"   >> $(BUILDSTAMP)
	@echo "#define DTDay      0x$(shell date +%d)"   >> $(BUILDSTAMP)
	@echo "#define DThour     0x$(shell date +%H)"   >> $(BUILDSTAMP)
	@echo "#define DTminute   0x$(shell date +%M)"   >> $(BUILDSTAMP)
	@echo "#define DTsecond   0x$(shell date +%S)"   >> $(BUILDSTAMP)
