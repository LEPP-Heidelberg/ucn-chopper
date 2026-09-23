-- $Id: rom.vhd 1125 2024-11-14 07:05:44Z angelov $:

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.all;
USE IEEE.STD_LOGIC_UNSIGNED.all;

entity rom is
generic(Np : Integer := 9);
port(
    clk         : in  std_logic;
    rom_addr    : in  std_logic_vector(Np-1 downto 0);
    rom_dout    : out std_logic_vector(23 downto 0));
end rom;

architecture a of rom is

--signal rom_dat      : std_logic_vector(15 downto 0);

--signal rom_addr_i_s  : Integer range 0 to 2**Np-1;

-- dummy

begin

    process(clk)
    begin
        if rising_edge(clk) then
--           rom_addr_i_s  <= conv_integer(rom_addr);
           rom_dout <= X"0000" & rom_addr(7 downto 0);
        end if;
    end process;


end;
