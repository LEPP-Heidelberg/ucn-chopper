-- $Id: sw32_pack.vhd 1136 2025-01-27 18:19:13Z angelov $:

library ieee;
use ieee.std_logic_1164.all;

package sw32_pack is

constant CARRY_FLAG_BIT : Integer := 1;
constant ZERO_FLAG_BIT  : Integer := 0;

subtype opcode_type is std_logic_vector( 4 downto 0);
subtype op_not_type is std_logic_vector( 1 downto 0);

-- logical
-- operations with only one operand
constant INSTR_NOT  : opcode_type := "00000";
constant INS_MOD_NOT : op_not_type := "00"; -- not
constant INS_MOD_SWP : op_not_type := "01"; -- swap hi-lo word
constant INS_MOD_SXT : op_not_type := "10"; -- sign extension 16->32
constant INS_MOD_MOV : op_not_type := "11"; -- just move
-- operations with two operands
constant INSTR_XOR  : opcode_type := "00001";
constant INSTR_OR   : opcode_type := "00010";
constant INSTR_AND  : opcode_type := "00011";
-- bit
constant INSTR_MKB  : opcode_type := "10000";
constant INSTR_INB  : opcode_type := "10001";
constant INSTR_SEB  : opcode_type := "10010";
constant INSTR_CLB  : opcode_type := "10011";
-- arithmetic
constant INSTR_SHL  : opcode_type := "00100";
constant INSTR_SHR  : opcode_type := "00101";
constant INSTR_ROL  : opcode_type := "10100";
constant INSTR_ROR  : opcode_type := "10101";
--
constant INSTR_SUB  : opcode_type := "00110";
constant INSTR_ADD  : opcode_type := "00111";
constant INSTR_SBB  : opcode_type := "10110";
constant INSTR_ADC  : opcode_type := "10111";
-- load const
constant INSTR_LDL  : opcode_type := "01000";
constant INSTR_LDL1 : opcode_type := "11000";
constant INSTR_LDH  : opcode_type := "01001";
constant INSTR_LDH1 : opcode_type := "11001";
-- load/store
constant INSTR_STO  : opcode_type := "01010";
constant INSTR_LDD  : opcode_type := "01011";

constant INSTR_PSH  : opcode_type := "11010";
constant INSTR_POP  : opcode_type := "11011";

constant INSTR_JZ   : opcode_type := "01100";
constant INSTR_JC   : opcode_type := "01101";
constant INSTR_JNZ  : opcode_type := "11100";
constant INSTR_JNC  : opcode_type := "11101";
constant INSTR_JS   : opcode_type := "01110";
constant INSTR_JMP  : opcode_type := "11110";
constant INSTR_RTS  : opcode_type := "01111";
constant INSTR_HLT  : opcode_type := "11111";

constant OP_CODE_MSB  : Integer := 23;
constant OP_CODE_LSB  : Integer := OP_CODE_MSB - opcode_type'length+1;
constant OP_CODE_WAIT : Integer := 5;
constant OP_CODE_I_O  : Integer := 6;
constant OP_RG_TARG_MSB  : Integer := 18;
constant OP_RG_TARG_LSB  : Integer := 15;
constant OP_RG_TARG_LSB_LC  : Integer := 23;  -- when load constant command
constant OP_RG_SRC1_MSB : Integer := 14;
constant OP_RG_SRC1_LSB : Integer := 11;
constant OP_RG_SRC2_MSB : Integer := 10;
constant OP_RG_SRC2_LSB : Integer :=  7;

constant OP_INFO_MSB : Integer :=  5;
constant OP_INFO_LSB : Integer :=  0;
constant OP_INFO_WIDTH : Integer :=  OP_INFO_MSB-OP_INFO_LSB+1;

constant OP_R1MD_MSB : Integer :=  6;
constant OP_R1MD_LSB : Integer :=  0;
-- only by add/sub, specify R1 to be 0..2**R1MD_WIDTH-1 instead of 1
constant R1MD_WIDTH  : Integer :=  OP_R1MD_MSB-OP_R1MD_LSB+1; -- 1..7, bits in immediate constant as r1, 1 means r1 is always 1

constant OP_IMMW_MSB : Integer := 15;
constant OP_IMMW_LSB : Integer :=  0;

-- 23 ... 19      18 .. 16  15  14 .. 11   10 ..  7   6    5   4 .. 0
-- op_code hex    reg_target   reg_src1   reg_src2  I/O  WS   OP_IMM hex     Comment
--                 rt           rs1         rs2                 imm
--  NOT  00        0..F         0..F         -        -   -     - 00         rt = ~ rs1
--  SWP  00        0..F         0..F         -        -   -     - 01         rt = rs1[15..0], rs1[31..16] - swap hi-low word
--  SXT  00        0..F         0..F         -        -   -     - 02         rt = sign extended 16-bit rs1[15..0]
--  MOV  00        0..F         0..F         -        -   -     - 03         rt = rs1
--  XOR  01        0..F         0..F        0..F      -   -      -           rt = rs1 ^ rs2
--  OR   02        0..F         0..F        0..F      -   -      -           rt = rs1 | rs2
--  AND  03        0..F         0..F        0..F      -   -      -           rt = rs1 & rs2
--  MKB  10        0..F         0..F         -        -   -     0..1F        rt = rs1 &  (1 << imm)
--  INB  11        0..F         0..F         -        -   -     0..1F        rt = rs1 ^  (1 << imm)
--  SEB  12        0..F         0..F         -        -   -     0..1F        rt = rs1 |  (1 << imm)
--  CLB  13        0..F         0..F         -        -   -     0..1F        rt = rs1 & ~(1 << imm)
--  SHL  04        0..F         0..F         -        -   -      01          rt = rs1 << 1              OP_IMM can be used for barrell shifter, now=1
--  SHR  05        0..F         0..F         -        -   -      01          rt = rs1 >> 1              logical, OP_IMM can be used for barrell shifter, now=1
--  SAR  05        0..F         0..F         -        -   -      11          rt = rs1 >> 1              arithm, OP_IMM3..0 can be used for barrell shifter, now=1, OP_IMM4=1
--  ROL  14        0..F         0..F         -        -   -      01          rt = rs1 << 1|Carry        Carry=MSB(rs1), OP_IMM can be used for barrell shifter, now=1
--  ROR  15        0..F         0..F         -        -   -      01          rt = rs1 >> 1|Carry<<31    Carry=LSB(rs1), OP_IMM can be used for barrell shifter, now=1

end sw32_pack;

package body sw32_pack is

end sw32_pack;
