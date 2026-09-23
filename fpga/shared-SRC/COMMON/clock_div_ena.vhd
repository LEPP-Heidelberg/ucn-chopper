-- $Id: clock_div_ena.vhd 1200 2026-06-01 15:02:14Z angelov $:

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

entity clock_div_ena is
generic (Ndiv : Positive := 5);
port(
     -- clock
    clk             : in    std_logic;
    rst             : in    std_logic;
    ena             : in    std_logic := '1';
    q               : out   std_logic); -- 1 clock long
end clock_div_ena;

architecture a of clock_div_ena is

signal cnt      : Integer range 0 to Ndiv-1;
signal cnt_next : Integer range 0 to Ndiv-1;
signal cnt_is_0 : std_logic;

begin
    cnt_is_0 <= '1' when cnt = 0 else '0';

    process(all)
    begin
        if cnt_is_0 = '1' or rst = '1' then
            cnt_next <= Ndiv-1;
        else
            cnt_next <= cnt - 1;
        end if;
    end process;


    process(clk)
    begin
        if rising_edge(clk) then
            q <= '0';
            if ena='1' then
                cnt <= cnt_next;
                q   <= cnt_is_0;
            end if;
--          -- counter
--          if rst='1' or cnt = 0 then
--              cnt <= Ndiv-1;
--          elsif ena='1' then
--              cnt <= cnt - 1;
--          end if;
--          -- output
--          if cnt = 0 then
--              q <= ena;
--          end if;
        end if;
    end process;
end;
