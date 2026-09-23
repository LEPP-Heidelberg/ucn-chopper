-- $Id: hbr_gen_pkg.vhd 1215 2026-08-28 14:13:16Z  $:

library ieee;
use ieee.std_logic_1164.all;

use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

package hbr_gen_pkg is

--constant NA_RAM_HBR_GEN : Integer := 10;
-- filter at the control inputs from afbr and optocopupl.
constant NFILT          : Integer :=  3;
constant DUAL_MODE      : Boolean := true;
constant PWM_MODE       : Boolean := true;
constant MODE1_PROG_FIX : Boolean := true;
constant MODE2_PROG_FIX : Boolean := true;

-- Type declarations
subtype h_cnf_addr_type is std_logic_vector( 3 downto 0);

subtype hbr_conf_type   is std_logic_vector(19 downto 0);

-- write the complete 16-bit word
constant ADDR_H_CONF       : h_cnf_addr_type := "0000";
-- or write the bit position in bits 7..4 and the 1 or 2 bits in pos 0 or 1..0
constant ADDR_H_BIT_CNF    : h_cnf_addr_type := "0001";

    -- TOFF conf    off-time in us
    -- 0            7
    -- 1            16
    -- 2            24
    -- 3            32
    constant HBR_BIT_TOFF       : Integer := 0; -- 2 bits
    -- decay pin        decay mode
    --  0           Slow decay (brake or high-side re-circulation)
    --  1           Smart tune dynamic decay
    --  2,3         Mixed decay: 30% fast
    constant HBR_BIT_DECAY      : Integer := 2; -- 2 bits
    -- Single H-Bridge Mode (MODE1 = 1), or Dual H-Bridge Mode (MODE1 = 0)
    -- The MODE2 pin has to be grounded to select PH/EN interface.
    -- To select PWM interface, keep MODE2 pin floating or connect the MODE2 pin to DVDD.
    constant HBR_BIT_MODE       : Integer := 4; -- 2 bits
    constant HBR_BIT_OCPM       : Integer := 6; -- 1 bit
    constant HBR_BIT_SLEEP_N    : Integer := 7; -- 1 bit

    constant DEF_HBR_TOFF       : std_logic_vector(HBR_BIT_TOFF +1 downto HBR_BIT_TOFF ) := "00";
    constant DEF_HBR_DECAY      : std_logic_vector(HBR_BIT_DECAY+1 downto HBR_BIT_DECAY) := "00";
    constant DEF_HBR_MODE       : std_logic_vector(HBR_BIT_MODE +1 downto HBR_BIT_MODE ) := "10";
    constant DEF_HBR_OCPM       : std_logic := '1';
    constant DEF_HBR_SLEEP_N    : std_logic := '0';

    constant HBR_BIT_ENA_OPCPL : Integer := 8; -- 2 bits
    constant DEF_HBR_ENA_OPCPL : std_logic_vector(HBR_BIT_ENA_OPCPL +1 downto HBR_BIT_ENA_OPCPL ) := "00";
    constant HBR_BIT_ENA_AFBR  : Integer :=10; -- 2 bits
    constant DEF_HBR_ENA_AFBR  : std_logic_vector(HBR_BIT_ENA_AFBR  +1 downto HBR_BIT_ENA_AFBR  ) := "00";
    constant HBR_BIT_INV_OPCPL : Integer :=12; -- 2 bits
    constant DEF_HBR_INV_OPCPL : std_logic_vector(HBR_BIT_INV_OPCPL +1 downto HBR_BIT_INV_OPCPL ) := "00";
    constant HBR_BIT_INV_AFBR  : Integer :=14; -- 2 bits
    constant DEF_HBR_INV_AFBR  : std_logic_vector(HBR_BIT_INV_AFBR  +1 downto HBR_BIT_INV_AFBR  ) := "00";

    constant HBR_BIT_SL_DEC_SM : Integer :=16; -- 2 bits
    constant DEF_HBR_SL_DEC_SM : std_logic_vector(HBR_BIT_SL_DEC_SM +1 downto HBR_BIT_SL_DEC_SM ) := "00";

    constant HBR_BIT_REM_LAST  : Integer :=18; -- 2 bits
    constant DEF_HBR_REM_LAST  : std_logic_vector(HBR_BIT_REM_LAST + 1 downto HBR_BIT_REM_LAST  ) := "00";

-- status, still not well defined
constant ADDR_H_STAT       : h_cnf_addr_type := "0010";


    -- divide system clock 48*2^10 to get
    -- code:      0    1      2      3      4      5      6      7
    -- PWM Freq 4800, 8000, 9600, 16000, 19200, 24000, 32000, 48000
constant ADDR_PWM_FREQ_DIV : h_cnf_addr_type := "0011";

-- single shot: on/off (the 2 IN outputs to H-bridge)
--  17..16  2 bits for the state (IN of HBR)
--  15.. 8  8 bits for duration in PWM periods
--   7.. 0  8 bits for power
constant ADDR_H_OUTP_1     : h_cnf_addr_type := "0100";
constant ADDR_H_OUTP_2     : h_cnf_addr_type := "0101";

-- bit 0/2 start seq on ch 1 to turn on/off the shutter
-- bit 1/3 start seq on ch 2 to turn on/off the shutter
-- bit 4/5 reset the sequence state machines at ch 1, 2
constant ADDR_START_ON_OFF : h_cnf_addr_type := "0111";

-- start address in 15.. 0 and number of PWM periods in 31..16 for input 1 when turning shutter on
constant ADDR_SEQ_AD_RANGE_ON_1 : h_cnf_addr_type := "1000";
-- start address in 15.. 0 and number of PWM periods in 31..16 for input 1 when turning shutter off
constant ADDR_SEQ_AD_RANGE_OFF_1 : h_cnf_addr_type := "1001";
-- start address in 15.. 0 and number of PWM periods in 31..16 for input 2 when turning shutter on
constant ADDR_SEQ_AD_RANGE_ON_2 : h_cnf_addr_type := "1010";
-- start address in 15.. 0 and number of PWM periods in 31..16 for input 2 when turning shutter off
constant ADDR_SEQ_AD_RANGE_OFF_2 : h_cnf_addr_type := "1011";

-- current pointer to the table and state machine states of both channels
constant ADDR_SEQ_STATUS         : h_cnf_addr_type := "1100";


constant TABLE_POS_PWR  : Integer :=  0;
constant TABLE_WDT_PWR  : Integer :=  8;
constant TABLE_POS_DUR  : Integer := TABLE_POS_PWR + TABLE_WDT_PWR ;
constant TABLE_WDT_DUR  : Integer :=  8;
constant TABLE_POS_OUT  : Integer := TABLE_POS_DUR + TABLE_WDT_DUR;
constant TABLE_WIDTH    : Integer := TABLE_WDT_PWR + TABLE_WDT_DUR + 2;
-- structure of the RAM block with the sequence
-- width 18 bits (to use more effectively the EBRs)
--  17..16  2 bits for the state (IN of HBR)
--  15.. 8  8 bits for duration in PWM periods
--   7.. 0  8 bits for power



function hbr_default(dual : Boolean) return hbr_conf_type;

constant SYS_CLK    : Integer := 48*1024*1000;

constant PWM_BITS   : Integer := 8;  -- 4..8
constant PWM_STEPS  : Integer := 2**PWM_BITS;

constant MAX_IDLE_POWER_CODE : std_logic_vector(PWM_BITS-1 downto 0) := conv_std_logic_vector(PWM_STEPS/4, PWM_BITS);

subtype PWM_FREQ_TYPE is Integer;
-- we have 8 possible settings
type PWM_FREQ_ARR_TYPE is array(0 to 7) of PWM_FREQ_TYPE;
-- possible CONV frequencies as a function of the code comming from the uController:
constant PWM_FREQUENCIES : PWM_FREQ_ARR_TYPE :=
-- code:  0    1      2      3      4      5      6      7
       (4800, 8000, 9600, 16000, 19200, 24000, 32000, 48000);
-- PWM frequency in Hz:

end hbr_gen_pkg;

package body hbr_gen_pkg is

function hbr_default(dual : Boolean) return hbr_conf_type is
variable hbr_def : hbr_conf_type;
begin
        hbr_def := (others => '0');
        hbr_def(HBR_BIT_TOFF +1 downto HBR_BIT_TOFF ) := DEF_HBR_TOFF;
        hbr_def(HBR_BIT_DECAY+1 downto HBR_BIT_DECAY) := DEF_HBR_DECAY;
        hbr_def(HBR_BIT_MODE +1 downto HBR_BIT_MODE ) := DEF_HBR_MODE;
        hbr_def(HBR_BIT_OCPM                        ) := DEF_HBR_OCPM;
        hbr_def(HBR_BIT_SLEEP_N                     ) := DEF_HBR_SLEEP_N;
        if dual then
            hbr_def(HBR_BIT_MODE +1) := '1';
        else
            hbr_def(HBR_BIT_MODE +1) := '0';
        end if;

        hbr_def(HBR_BIT_ENA_OPCPL +1 downto HBR_BIT_ENA_OPCPL) := DEF_HBR_ENA_OPCPL;
        hbr_def(HBR_BIT_INV_OPCPL +1 downto HBR_BIT_INV_OPCPL) := DEF_HBR_INV_OPCPL;

        hbr_def(HBR_BIT_ENA_AFBR  +1 downto HBR_BIT_ENA_AFBR ) := DEF_HBR_ENA_AFBR ;
        hbr_def(HBR_BIT_INV_AFBR  +1 downto HBR_BIT_INV_AFBR ) := DEF_HBR_INV_AFBR ;

        hbr_def(HBR_BIT_SL_DEC_SM +1 downto HBR_BIT_SL_DEC_SM) := DEF_HBR_SL_DEC_SM;

        hbr_def(HBR_BIT_REM_LAST + 1 downto HBR_BIT_REM_LAST ) := DEF_HBR_REM_LAST;

    return hbr_def;
end;

end hbr_gen_pkg;
