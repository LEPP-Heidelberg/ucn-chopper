LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.all;
USE IEEE.STD_LOGIC_UNSIGNED.all;

-- $Id: wdog.vhd 801 2021-12-13 15:10:06Z angelov $:

entity wdog is
generic(
    Nwdog       : Natural := 24  -- number of bits in watchdog timer - counts down and when 0 => inactive
);
port (
    clk         : in  std_logic;
    reset       : in  std_logic;
    disable     : in  std_logic;
    rx          : in  std_logic;
    rst_out     : out std_logic);
end wdog;

architecture a of wdog is

signal wdog_cnt    : std_logic_vector(Nwdog-1 downto 0);
constant wdog_zero : std_logic_vector(Nwdog-1 downto 0) := (others => '0');
constant wdog_one  : std_logic_vector(Nwdog-1 downto 0) := (0 => '1', others => '0');


begin
gen:  if Nwdog > 2 generate
    process(clk)
    begin
        if rising_edge(clk) then
            rst_out <= reset;
            if rx = '0' or reset = '1' or disable='1' then
                wdog_cnt <= (others => '1');
            elsif wdog_cnt /= wdog_zero then
                wdog_cnt <= wdog_cnt - 1;
            end if;
            if wdog_cnt = wdog_one then
                rst_out <= '1';
            end if;
        end if;
    end process;

else generate

    rst_out <= reset;

end generate;

end;

