LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

-- $Id: crc8reg.vhd 1 2016-03-15 14:35:42Z angelov $:

entity crc8reg is
generic(LSBfirst : Boolean := true);
port (
    clk    : in  std_logic;
    load   : in  std_logic;
    din    : in  std_logic;
    ena    : in  std_logic;
    crc8   : out std_logic_vector(7 downto 0));
end crc8reg;

architecture a of crc8reg is

subtype byte is std_logic_vector(7 downto 0);

constant init_byte : byte := X"FF";
constant poly_byte : byte := X"31";

signal crc_reg    : byte;

begin
    -- receiver buffer
    process(clk)
    variable crc_new : byte;
    begin
        if rising_edge(clk) then
            if load = '1' then
                crc_reg <= init_byte;
            elsif ena = '1' then
                crc_new := crc_reg(6 downto 0) & '0';
                if crc_reg(7) /= din then
                    crc_reg <= crc_new xor poly_byte;
                else
                    crc_reg <= crc_new;
                end if;
            end if;
        end if;
    end process;

lsb: if LSBfirst generate
lsbi: for i in 0 to 7 generate
        crc8(i) <= crc_reg(7-i);
      end generate;
     end generate;

msb: if not LSBfirst generate
    crc8  <= crc_reg;
     end generate;
end;
