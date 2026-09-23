LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.all;
USE IEEE.STD_LOGIC_UNSIGNED.all;

-- $Id: wdog.vhd 695 2021-03-29 17:56:59Z angelov $:

entity wdog is
generic(
        Nwdog    : Natural := 24  -- number of bits in watchdog timer - counts down and when 0 => inactive
);
port (
    clk          : in  std_logic;
    rst_n        : in  std_logic;
    disable      : in  std_logic;
    rx           : in  std_logic;
    rstout_n     : out std_logic);
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
            rstout_n <= rst_n;
            if rx = '0' or rst_n = '0' or disable='1' then
                wdog_cnt <= (others => '1');
            elsif wdog_cnt /= wdog_zero then
                wdog_cnt <= wdog_cnt - 1;
            end if;
            if wdog_cnt = wdog_one then
                rstout_n <= '0';
            end if;
        end if;
    end process;

else generate

--ngen: if Nwdog = 0 generate

    rstout_n <= rst_n;

end generate;

end;

