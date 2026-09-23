-- $Id: i2c_pack.vhd 1065 2024-03-16 06:40:18Z angelov $:

library ieee;
use ieee.std_logic_1164.all;

package i2c_pack is

constant CMD_NULL   : std_logic_vector( 2 downto 0) := "000"; -- NULL, nothing, used for r/w

constant CMD_RSTRT  : std_logic_vector( 2 downto 0) := "111"; -- repeated start

constant CMD_STOP   : std_logic_vector( 2 downto 0) := "001";
constant CMD_START  : std_logic_vector( 2 downto 0) := "010";
constant CMD_GETA   : std_logic_vector( 2 downto 0) := "011";
constant CMD_GIVA   : std_logic_vector( 2 downto 0) := "100";
constant CMD_PUTB   : std_logic_vector( 2 downto 0) := "101";
constant CMD_GETB   : std_logic_vector( 2 downto 0) := "110";

end i2c_pack;

package body i2c_pack is

end i2c_pack;
