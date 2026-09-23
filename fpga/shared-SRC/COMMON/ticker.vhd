-- $Id: ticker.vhd 632 2019-08-17 08:49:28Z angelov $:

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity Ticker is
    Generic(Divider     : integer := 100);
    Port (  clk         : in  std_logic;
            -- Ticks
            enable      : in  std_logic := '1';
            tick_out    : out std_logic);
end Ticker;

architecture Behavioral of Ticker is
    signal Counter: integer range 0 to Divider-1;
begin

    process(CLK)
    begin
        if rising_edge(CLK) then
            tick_out <= '0';
            if enable = '1' then
                if Counter = 0 then
                    Counter  <= Divider-1;
                    tick_out <= '1';
                else
                    Counter  <= Counter - 1;
                end if;
            end if;
        end if;
    end process;
end;
