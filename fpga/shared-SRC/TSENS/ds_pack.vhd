-- $Id: ds_pack.vhd 844 2022-01-25 17:06:19Z angelov $:

library ieee;
use ieee.std_logic_1164.all;

package ds_pack is

constant reset   : std_logic_vector( 3 downto 0) := X"0";
constant rd_cmd  : std_logic_vector( 3 downto 0) := X"1";
constant wr_cmd  : std_logic_vector( 3 downto 0) := X"2";
constant h_high  : std_logic_vector( 3 downto 0) := X"3";
constant stop    : std_logic_vector( 3 downto 0) := X"4";

subtype int_addr is std_logic_vector(1 downto 0);
-- the addresses are actually 8..11 when reading and not fully decoded when writing (0..3 possible!)
constant ADDR_CONFIG        : int_addr := "00";
constant BIT_CNF_TRES       : Integer := 0;
constant BIT_CNF_AUTO       : Integer := 2;
constant BIT_CNF_START      : Integer := 3;

constant ADDR_PRESENCE      : int_addr := "01";
constant BIT_NSENSORS       : Integer := 12;
constant ADDR_ALARM_THRESH  : int_addr := "10";
constant ADDR_ALARM_MASK    : int_addr := "11";

subtype temp_reg is std_logic_vector(11 downto 0);

constant INIT_THRESH        : temp_reg := x"500"; -- this corresponds to 80 C
constant MAX_THRESH         : temp_reg := x"640"; -- 100 C

-- tL and tH are threshold for alarm, we do not use it, but
-- they will be read back and so the interface can be tested!


subtype resol_type is std_logic_vector(1 downto 0);
constant TRES_12_BIT        : resol_type := "11";
constant TRES_11_BIT        : resol_type := "10";
constant TRES_10_BIT        : resol_type := "01";
constant TRES_9_BIT         : resol_type := "00";

-- read a DS18B20 1-wire temperature sensor
-- tres     bits    conv. time [ms]
-- "11"     12      750
-- "10"     11      375
-- "01"     10      187.5
-- "00"      9       93.75
constant TRES_INI           : resol_type := TRES_12_BIT; -- resolution
constant tL                 : std_logic_vector( 7 downto 0) := X"00"; -- T low
constant tH                 : std_logic_vector( 7 downto 0) := X"11"; -- T high


end ds_pack;

package body ds_pack is

end ds_pack;
