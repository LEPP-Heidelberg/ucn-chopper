#-- Lattice Semiconductor Corporation Ltd.
#-- Synplify OEM project file

# $Id: synplify.tcl 1054 2024-01-16 09:02:14Z angelov $:

# device options
set_option -technology MachXO3D
set_option -part LCMXO3D_9400HC
set_option -package BG256I
set_option -speed_grade -6

# compilation/mapping options
#
# Enables or disables resource sharing globally.
# This is a compiler-specific optimization, and does
# not affect resource sharing in the mapper.
set_option -resource_sharing true
#
# use verilog 2001 standard option
set_option -vlog_std v2001
set_option -vhdl2008 1

# map options
add_file -constraint {./SCRIPTS/synpl.sdc}
#
# ----------------------------------------------------------------------------------------------
# Enables/disables auto constraints.
set_option -frequency auto
#
set_option -maxfan 1000
set_option -auto_constrain_io 0
#
# ----------------------------------------------------------------------------------------------
# Enables/disables I/O insertion in some technologies.
set_option -disable_io_insertion false
#
# ----------------------------------------------------------------------------------------------
# When enabled (1), registers may be moved into combinational
# logic to improve performance. The default value is 0 (disabled).
set_option -retiming true
#
# ----------------------------------------------------------------------------------------------
# Runs designs at a faster frequency by moving registers into the multiplier, creating pipeline stages.
set_option -pipe true
#
# ----------------------------------------------------------------------------------------------
# Enables or disables the sequential optimizations for the design.
# (Note that unused registers will still be removed from the design.)
# The default value is true (sequential optimizations not performed).
# When true, delay and area size might increase. Value can be 1 or true, 0 or false.
# With this option enabled, the FSM Compiler and FSM Explorer options are effectively disabled.
#
set_option -no_sequential_opt 0
#
# ----------------------------------------------------------------------------------------------
# this was false and the area was larger!
# Enables (yes) or disables forced use of the global set/reset routing resources.
# When the value is auto, the synthesis tool decides whether to use the global set/reset resources.
set_option -force_gsr yes
#
set_option -compiler_compatible 0
set_option -dup false
#
# ----------------------------------------------------------------------------------------------
# Sets the global frequency.
set_option -frequency 32
#
# ----------------------------------------------------------------------------------------------
# FSM compile options:
# possible encodings are: default, gray, onehot, sequential
set_option -default_enum_encoding gray
#
# Enables/disables the FSM compiler. Controls the use of FSM synthesis for state machines.
# The default is false (FSM Compiler disabled). Value can be 1 or true, 0 or false.
# When this option is true, the FSM Compiler automatically recognizes and optimizes
# state machines in the design. The FSM Compiler extracts the state machines as symbolic graphs,
# and then optimizes them by re-encoding the state representations and generating a better logic
# optimization starting point for the state machines.
# However, if you turn off sequential optimizations for the design, FSM Compiler and/or the
# syn_state_machine directive and syn_encoding attribute are effectively disabled.
set_option -symbolic_fsm_compiler 1
#

# simulation options

# timing analysis options

#automatic place and route (vendor) options
set_option -write_apr_constraint 1

# synplifyPro options
set_option -fix_gated_and_generated_clocks 1
set_option -update_models_cp 0
set_option -resolve_multiple_driver 0

#-- add_file options
#add_file -vhdl {D:/Lattice/Diamond/3.13/cae_library/synthesis/vhdl/machxo3d.vhd}
set_option -include_path {../plattform/lm32_xo2/soc}
source "SCRIPTS/add_sources_syn.tcl"

#-- top module name
set_option -top_module top

# set_option -hdl_param -set E_FLASH $ext_flash

#-- set result format/file last
project -result_file {./NETLIST/top.edf}

#-- error message log file
project -log_file {./REPORTS/synth_report.srf}

#-- set any command lines input by customer


#-- run Synplify with 'arrange HDL file'
project -run hdl_info_gen -fileorder
project -run -clean
# hdl_param -list
