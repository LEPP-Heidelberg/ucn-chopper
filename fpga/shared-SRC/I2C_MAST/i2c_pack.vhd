-- $Id: i2c_pack.vhd 470 2018-08-15 06:37:33Z angelov $:

library ieee;
use ieee.std_logic_1164.all;

package i2c_pack is

constant CMD_RBYTE  : std_logic_vector( 2 downto 0) := "000";
constant CMD_WBYTE  : std_logic_vector( 2 downto 0) := "111";

constant CMD_STOP   : std_logic_vector( 2 downto 0) := "001";
constant CMD_START  : std_logic_vector( 2 downto 0) := "010";
constant CMD_GETA   : std_logic_vector( 2 downto 0) := "011";
constant CMD_GIVA   : std_logic_vector( 2 downto 0) := "100";
constant CMD_PUTB   : std_logic_vector( 2 downto 0) := "101";
constant CMD_GETB   : std_logic_vector( 2 downto 0) := "110";

end i2c_pack;

package body i2c_pack is

end i2c_pack;
