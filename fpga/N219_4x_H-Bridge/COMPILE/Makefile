# $Id: Makefile 1216 2026-09-02 16:57:27Z  $:

# the name of the top file
project=top

# hardware version, 0 on XO3D BB, 1 - N219 PCB
VERSION=1

# assembly variation, if any
assembly_id=0

# Image: 0 or 1
IMAGE=0
ifeq ($(IMAGE),0)
	JED_ENDING=a
endif
ifeq ($(IMAGE),1)
	JED_ENDING=b
endif
#
###########################
# Sources
###########################
#
include sources.mk
#
# timestamp file
BUILDSTAMP=$(pref_top)/DateTime_pkg.vhd
#
# top of the design
TOP=$(pref_top)/top_$(VERSION).vhd
#
#
# list of all VHDL & Verilog sources in design
sources=$(src_common) $(src_uart32) $(src_tsens) $(src_i2c) $(src_ads131) $(src_shutter) $(src_top) $(BUILDSTAMP) $(TOP)
#
# file with sources prepared for synplyfy
SRC_TCL=./SCRIPTS/add_sources_syn.tcl
#
# the pin constraint file
constr_file=./SCRIPTS/pins_$(VERSION).lpf
#
#
###########################
# FPGA settings
###########################
FPGA_FAMILY=MachXO3D
# ZC. HC, HE
FPGA_SERIES=HC
#
ifeq ($(VERSION), 0)
# Prototype with Lattice Breakout Board
# 4 (slowest), 5 or 6 (fastest) for HC
	FPGA_SPEED_GRADE=5
	FPGA_TEMP_CLASS=Industrial
	FPGA_PACKAGE=CABGA256
	FPGA_SIZE=9400
endif
#
ifeq ($(VERSION), 1)
	FPGA_SPEED_GRADE=5
# Industrial or Commercial
	FPGA_TEMP_CLASS=Commercial
	FPGA_PACKAGE=QFN72
	FPGA_SIZE=9400
endif

# for ZC, speed grade 2 or 3
#FPGA_SERIES=ZC
#FPGA_SPEED_GRADE=3

#
FPGA_DEVICE=LCMXO3D-$(FPGA_SIZE)$(FPGA_SERIES)
FPGA_FULL_DEVICE=$(FPGA_DEVICE)-$(FPGA_SPEED_GRADE)$(FPGA_TEMP_CLASS)
FPGA_FULL_DEVICE=N219_$(FPGA_DEVICE)-$(FPGA_SPEED_GRADE)$(shell printf '%s' "$(FPGA_TEMP_CLASS)" | cut -c1)_v$(VERSION)
#
# directory for the programming files
PROGR=./PROG_VER$(VERSION)_IMG$(IMAGE)
#
# File to init the IMEM of the LM32 CPU
LM32_INIT_IMEM=../plattform/C/output/lm32_xo2.mem
#
# quartz clock speed
#QCLK=40000000
#
# UART baud rate:
#  Supported by Windows in DOS window: 1200, 2400, 4800, 9600, 19200, 38400, 57600, 115200
# +Supported by cygwin: 230400, 460800, 500000, 576000, 921600, 1000000, 2000000 (up to here by the most USB-UART chips), 3000000
# +Supported by linux: 4000000 (and only by few USB-UART chips)
UART_BaudRate =4000000
# not used now, but defined here
ACC_NBITS=11
USE_ACC=true
#

all: clean DateTime syn_syn ed2ng_syn map par timing jed bin bit rep # backanno (after timing when necessary)

rep:
	@grep -A 17 "Report Summary" REPORTS/report_timing_par.txt
	@grep -A 35 -m 1 "Design Summary" REPORTS/lattice_map.mrp
	@echo "Search for latches in synthesis report"
	@-grep "Latch bits:" ./REPORTS/synth_report.srf

# create the directories if necessary
REPORTS NETLIST LAST $(PROGR):
	if [ ! -d $@ ]; then mkdir -p $@; fi

# create the VHDL package with data, time, subversion info & other important constants
DateTime:
	-rm $(BUILDSTAMP)
	@echo "package DateTime_pkg is" > $(BUILDSTAMP)

	@echo "  constant FPGA_SIZE_I: natural := $(FPGA_SIZE);"        >> $(BUILDSTAMP)
	@echo "  constant FPGA_SIZE  : string  := \"$(FPGA_SIZE)L\";"   >> $(BUILDSTAMP)
#	@echo "  constant UFM_INIT_START_PAGE  : Integer  := $(UFM_INIT_START_PAGE);"       >> $(BUILDSTAMP)
#	@echo "  constant QCLK       : natural := $(QCLK);"             >> $(BUILDSTAMP)
	@echo "  constant UART_BaudRate : natural := $(UART_BaudRate);" >> $(BUILDSTAMP)
	@echo "  constant USE_ACC    : boolean := $(USE_ACC);"          >> $(BUILDSTAMP)
	@echo "  constant ACC_NBITS  : natural := $(ACC_NBITS);"        >> $(BUILDSTAMP)
	@echo "  constant hw_version : natural := $(VERSION);"       >> $(BUILDSTAMP)
	@echo "  constant as_version : natural := $(assembly_id);"      >> $(BUILDSTAMP)
	@echo "  constant BOOT_IMG   : natural := $(IMAGE);"            >> $(BUILDSTAMP)
#
	@echo "  constant DTYear     : natural := $(shell date +%Y);"   >> $(BUILDSTAMP)
	@echo "  constant DTMonth    : natural := $(shell date +%m);"   >> $(BUILDSTAMP)
	@echo "  constant DTDay      : natural := $(shell date +%d);"   >> $(BUILDSTAMP)
	@echo "  constant DThour     : natural := $(shell date +%H);"   >> $(BUILDSTAMP)
	@echo "  constant DTminute   : natural := $(shell date +%M);"   >> $(BUILDSTAMP)
	@echo "  constant DTsecond   : natural := $(shell date +%S);"   >> $(BUILDSTAMP)
	@echo "  constant svn_rev    : string  := \"$(shell svn info -r head| grep -o "Rev:.*")\";" >> $(BUILDSTAMP)
	@echo "  constant svn_date   : string  := \"$(shell svn info -r head| grep -o "Date:.*")\";" >> $(BUILDSTAMP)
#	@echo "  constant svn_rev    : string  := \"$(shell svn info | grep -o "Rev:.*")\";" >> $(BUILDSTAMP)
#	@echo "  constant svn_date   : string  := \"$(shell svn info | grep -o "Date:.*")\";" >> $(BUILDSTAMP)
	@echo "end DateTime_pkg;" >> $(BUILDSTAMP)

# use Synplicity for synthesis
syn_syn: REPORTS NETLIST
	-rm $(SRC_TCL)
	@echo "# add all source files to the project" >> $(SRC_TCL)
	@for src_file in $(sources) ; do \
	echo "add_file {$$src_file}" >> $(SRC_TCL) ; \
	done
	@echo "set_option -include_path {$(pref_risc)/risc32/soc}" >> $(SRC_TCL)
	@echo "Sources in the project for synthesis"
	@cat $(SRC_TCL)
	@echo "Starting synthesis with Synplicity, edif output"
	synpwrap -prj ./SCRIPTS/synplify.tcl -log ./REPORTS/synplify_report.log

syn_err:
	-grep "@E" NETLIST/syntax.log
	-grep "@E" NETLIST/top.srr

ed2ng_syn: # for synplify
	# edif to ngd convert
	edif2ngd -l $(FPGA_FAMILY) -d $(FPGA_DEVICE) -cbn synplify -nopropwarn ./NETLIST/$(project).edf ./NETLIST/$(project).ngo
	ngdbuild -dt -a $(FPGA_FAMILY) -d $(FPGA_DEVICE) ./NETLIST/$(project).ngo ./NETLIST/$(project).ngd

map:
	# map
	cat $(constr_file) > ./SCRIPTS/constr.lpf
	@echo "SYSCONFIG CUR_DESIGN_BOOT_LOCATION=IMAGE_$(IMAGE)  ;" >> ./SCRIPTS/constr.lpf
	map -m -c 1 ./NETLIST/$(project).ngd SCRIPTS/constr.lpf -o ./NETLIST/$(project).ncd -pr ./SCRIPTS/pins.prf -a $(FPGA_FAMILY) -p $(FPGA_DEVICE) -s $(FPGA_SPEED_GRADE) -oc Commercial -t $(FPGA_PACKAGE) -ioreg b -split_node -td_pack -mp REPORTS/lattice_map.mrp | tee REPORTS/lattice_map.log #-retime

par: #./NETLIST/$(project).edf
	# place & route
	par ./NETLIST/$(project).ncd -w ./NETLIST/$(project)_par.ncd ./SCRIPTS/pins.prf -sp $(FPGA_SPEED_GRADE) |tee REPORTS/lattice_par.log
	cp -p ./NETLIST/$(project)_par.pad ./REPORTS/report_pinout.txt

timing:
	# io setup and hold times report
	iotiming -s -sp $(FPGA_SPEED_GRADE) ./NETLIST/$(project)_par.ncd ./SCRIPTS/pins.prf -o REPORTS/report_timing_io_par.txt
	# timing analysis report
	trce ./NETLIST/$(project)_par.ncd ./SCRIPTS/pins.prf -allprefpath -fullname -clockdomain -sethld -v 10 -sphld m -sp $(FPGA_SPEED_GRADE) -o REPORTS/report_timing_par.txt
	# timing backannotation
	ldbanno ./NETLIST/$(project)_par.ncd -n vhdl -x -neg -w -o ./NETLIST/$(project)_ba.vho -d ./NETLIST/$(project)_ba.sdf

jed: $(PROGR)
	# bitfile (jedec) generation
	bitgen -g RamCfg:Reset -g DisableUES:FALSE -w ./NETLIST/$(project)_par.ncd -jedec $(PROGR)/$(FPGA_FULL_DEVICE).jed ./SCRIPTS/pins.prf

bit: $(PROGR)
	# bitfile (bit) generation
	bitgen -g RamCfg:Reset -g DisableUES:FALSE -w ./NETLIST/$(project)_par.ncd ./$(PROGR)/$(FPGA_FULL_DEVICE)_$(JED_ENDING).bit ./SCRIPTS/pins.prf

# convert the JEDEC file to a binary file using a Lattice conversion tool
bin: $(PROGR)
	ddtcmd -oft jed2bin -dev $(FPGA_DEVICE) -if $(PROGR)/$(FPGA_FULL_DEVICE)_$(JED_ENDING).jed -of $(PROGR)/$(FPGA_FULL_DEVICE)_$(JED_ENDING).bin

# copy the programming files to the server
cpprog:
	scp $(PROGR)/$(FPGA_FULL_DEVICE)_$(JED_ENDING).bin $(LM32_INIT_IMEM) angelov@ew-va-r61:Lattice_XO2_UART/PROJECTS/N219_4x_H-Bridge/C/pgm/
	#scp $(PROGR)/*.jed $(PROGR)/*.bit $(PROGR)/*.bin angelov@147.142.17.33:SVN/Lattice_XO2_UART/PROJECTS/N216_MOSFET_SW/C
	
# Only important for the FPGA compilation:
# in ../plattform/lm32_xo2/soc/lm32_xo2.v
# search for: .INIT_FILE_NAME("none"),
# replace with: .INIT_FILE_NAME("../plattform/C/output/lm32_xo2.mem"),

# not important for the FPGA compilation:
#
# in ../plattform/lm32_xo2/soc/lm32_xo2.msb
# search for: <Parm Name="INIT_FILE_NAME" OType="String" Text="Initialization File Name" Type="File" Value="none" isparm="true"/>
#
# in ../plattform/lm32_xo2/soc/system_conf.v
# search for: `define IM_ebrINIT_FILE_NAME "none"
#
# execute once only after generating the CPU core
#
set_mem_file:
	grep -i '.INIT_FILE_NAME' ../plattform/lm32_xo2/soc/lm32_xo2.v
	sed -i 's\.INIT_FILE_NAME("none"),\.INIT_FILE_NAME("$(LM32_INIT_IMEM)"),\g' ../plattform/lm32_xo2/soc/lm32_xo2.v

show_mem_file:
	grep -i '.INIT_FILE_NAME' ../plattform/lm32_xo2/soc/lm32_xo2.v

clean:
	-rm -rf REPORTS/* NETLIST/* \
	$(PROGR)/* SCRIPTS/pins*.prf \
	*.log synlog.tcl licbug.txt stdout.log* pmi*

clean_prog:
	rm -rf PROG_VER?_IMG?/*.alt PROG_VER?_IMG?/*.bgn PROG_VER?_IMG?/*.drc PROG_VER?_IMG?/*.alt PROG_VER?_IMG?/*.fea PROG_VER?_IMG?/*.jed_list
