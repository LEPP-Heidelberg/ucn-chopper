`define LATTICE_FAMILY "MachXO3D"
`define LATTICE_FAMILY_MachXO3D
`define LATTICE_DEVICE "All"
`ifndef SYSTEM_CONF
`define SYSTEM_CONF
`timescale 1ns / 100 ps
`define CFG_EBA_RESET 32'h0
`define CFG_DISTRAM_POSEDGE_REGISTER_FILE
`define SHIFT_ENABLE
`define CFG_PL_BARREL_SHIFT_ENABLED
`define CFG_SIGN_EXTEND_ENABLED
`define CFG_DRAM_ENABLED
`define CFG_DRAM_BASE_ADDRESS 32'h8000
`define CFG_DRAM_LIMIT 32'h87ff
`define CFG_DRAM_INIT_FILE_FORMAT "hex"
`define CFG_DRAM_INIT_FILE "none"
`define ADDRESS_LOCK
`define CFG_DRAM_LOCK
`define LM32_I_PC_WIDTH 21
`define ADDRESS_LOCK
`define IM_ebrEBR_WB_DAT_WIDTH 32
`define IM_ebrINIT_FILE_NAME "none"
`define IM_ebrINIT_FILE_FORMAT "hex"
`define ADDRESS_LOCK
`define slave_passthruS_WB_DAT_WIDTH 32
`define S_WB_SEL_WIDTH 4
`define slave_passthruS_WB_ADR_WIDTH 32
`define master_passthruM_WB_DAT_WIDTH 32
`define M_WB_SEL_WIDTH 4
`define master_passthruM_WB_ADR_WIDTH 32
`endif // SYSTEM_CONF
