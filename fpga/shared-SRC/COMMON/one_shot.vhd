-- $Id: one_shot.vhd 115 2016-12-13 15:40:22Z angelov $:

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
--use IEEE.STD_LOGIC_ARITH.ALL;
--use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity one_shot is
generic (Pulse_length : Positive := 5);
port(
     -- clock
    clk             : in    std_logic;
    rst             : in    std_logic;
    trigger         : in    std_logic;
    q               : out   std_logic);
end one_shot;

architecture a of one_shot is

signal cnt       : Integer range 0 to Pulse_length-1;
signal trigg_old : std_logic;

begin
    process(clk) -- just sync
    begin
        if rising_edge(clk) then
            trigg_old <= trigger;
            -- counter
            if trigger='1' and trigg_old='0' then
                cnt <= Pulse_length - 1;
                q <= '1';
            elsif cnt /= 0 then
                cnt <= cnt - 1;
            else
                q <= '0';
            end if;
        end if;
    end process;
end;
