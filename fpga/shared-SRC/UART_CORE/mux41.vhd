LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

-- $Id: mux41.vhd 1 2016-03-15 14:35:42Z angelov $:

entity mux41 is
generic (N : Positive := 8);
port (
    I0  : in  std_logic_vector(N-1 downto 0);
    I1  : in  std_logic_vector(N-1 downto 0);
    I2  : in  std_logic_vector(N-1 downto 0);
    I3  : in  std_logic_vector(N-1 downto 0);
    SEL : in  std_logic_vector(  1 downto 0);
    Y   : out std_logic_vector(N-1 downto 0));
end mux41;

architecture a of mux41 is
begin
    with SEL select
    Y <= I3 when "11",
         I2 when "10",
         I1 when "01",
         I0 when "00",
         (others => '-') when others;
end;
