-- $Id: pup_reset.vhd 849 2022-02-08 10:08:53Z angelov $:
library ieee;
use ieee.std_logic_1164.all;

entity pup_reset is
generic(inv_input   : Boolean := false); -- true for active low, false for active high
port(
    clk           : in    std_logic;
    reset_pin     : in    std_logic;
    reset_out     : out   std_logic);
end pup_reset;

architecture behav of pup_reset is

signal reset_arr    : std_logic_vector(7 downto 0) := (others => '1');
signal reset_level  : std_logic;

begin
    reset_level <= '0' when inv_input else '1';

    process(clk)
    begin
        if rising_edge(clk) then
            if reset_pin=reset_level then
                reset_arr <= (0 => '0', others => '1');
                reset_out <= '1';
            else
                reset_arr <= reset_arr(reset_arr'high-1 downto 0) & '0';
                if reset_arr=X"00" or reset_arr=X"FF" then reset_out <= '0';
                                                      else reset_out <= '1';
                end if;
            end if;
        end if;
    end process;

end;
