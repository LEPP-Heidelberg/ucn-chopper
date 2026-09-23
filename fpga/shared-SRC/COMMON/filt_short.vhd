-- $Id: filt_short.vhd 470 2018-08-15 06:37:33Z angelov $:

LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.std_logic_arith.ALL;
USE IEEE.std_logic_unsigned.ALL;

entity filt_short is
port(
        clk     : in    std_logic;
        din     : in    std_logic;
        dout    : out   std_logic);
end filt_short;

architecture a of filt_short is

signal sr   : std_logic_vector(3 downto 0);

begin

    process(clk)
    begin
        if rising_edge(clk) then
            sr <= din & sr(sr'high downto 1);
            case sr is
                when "0000" => dout <= '0';
                when "1000" => NULL;
                when "0100" => dout <= '0';
                when "0010" => dout <= '0';
                when "0001" => NULL;

                when "1111" => dout <= '1';
                when "0111" => NULL;
                when "1011" => dout <= '1';
                when "1101" => dout <= '1';
                when "1110" => NULL;

                when "1100" => NULL;
                when "0110" => NULL;
                when "0011" => NULL;

                when "1010" => NULL;
                when "0101" => NULL;

                when "1001" => NULL;

                when others => dout <= '-';
            end case;
        end if;
    end process;
end;
