LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

-- $Id: crc16reg.vhd 835 2022-01-11 18:52:17Z angelov $:

entity crc16reg is
generic(LSBfirst : Boolean := false);
port (
    clk    : in  std_logic;
    ansi   : in  std_logic; -- 1 for ANSI, 0 for CCITT, this bit is static while calculating the CRC
    load   : in  std_logic; -- load the initial word
    din    : in  std_logic; -- the new bit
    ena    : in  std_logic; -- new bit present
    crc16  : out std_logic_vector(15 downto 0);
    crc_is0: out std_logic);
end crc16reg;

architecture a of crc16reg is

constant N : integer := 16;

subtype word is std_logic_vector(N-1 downto 0);

-- CCITT CRC polynomial = x^16 + x^12 + x^5 + 1
constant init_word_CCITT : word := x"FFFF";
constant poly_word_CCITT : word := x"1021";
-- ANSI CRC polynomial = x^16 + x^15 + x^2 + 1
constant init_word_ANSI  : word := x"FFFF";
constant poly_word_ANSI  : word := x"8005";

signal crc_reg    : word;
constant crc0reg  : word := (others => '0');
signal poly_word  : word;
signal init_word  : word;

begin
    -- normally the same, therefore not registered
    init_word <= init_word_ANSI when ansi='1' else init_word_CCITT;

    -- receiver buffer
    process(clk)
    variable crc_new : word;
    begin
        if rising_edge(clk) then
            if ansi='1' then
                poly_word <= poly_word_ANSI;
            else
                poly_word <= poly_word_CCITT;
            end if;

            if load = '1' then
                crc_reg <= init_word;
            elsif ena = '1' then -- there is a new bit din
                crc_new := crc_reg(N-2 downto 0) & '0';   -- 1) shift left
                if crc_reg(N-1) /= din then               -- 2) if the new bit is different from the MSB of crc
                    crc_reg <= crc_new xor poly_word;     --     then xor with the poly
                else
                    crc_reg <= crc_new;                   --     else just store
                end if;
            end if;

            if crc_reg=crc0reg then
                crc_is0 <= '1';
            else
                crc_is0 <= '0';
            end if;
        end if;
    end process;

lsb: if LSBfirst generate
lsbi: for i in 0 to N-1 generate
        crc16(i) <= crc_reg(N-1-i);
      end generate;
     end generate;

msb: if not LSBfirst generate
    crc16  <= crc_reg;
     end generate;
end;
