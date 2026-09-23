LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

-- $Id: ser_recv.vhd 801 2021-12-13 15:10:06Z angelov $:

entity ser_recv is
generic(Nbits   : Positive := 8; LSBfirst : Boolean := true);
port (
    clk    : in  std_logic;
    reset  : in  std_logic;
    rx     : in  std_logic;
    sample : in  std_logic;
    parity : out std_logic;
    dout   : out std_logic_vector(Nbits-1 downto 0));
end ser_recv;

architecture a of ser_recv is

signal rec_buffer : std_logic_vector(dout'range);
signal par        : std_logic;

begin
    -- receiver buffer
lsb: if LSBfirst generate -- LSB first

    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                rec_buffer <= (others => '0');
                par <= '0';
            elsif sample='1' then
                rec_buffer <= rx & rec_buffer(rec_buffer'high downto 1);
                par <= par xor rx;
            end if;
        end if;
    end process;
    end generate;

msb: if not LSBfirst generate -- MSB first
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                rec_buffer <= (others => '0');
                par <= '0';
            elsif sample='1' then
                rec_buffer <= rec_buffer(rec_buffer'high-1 downto 0) & rx;
                par <= par xor rx;
            end if;
        end if;
    end process;
    end generate;

    dout   <= rec_buffer;
    parity <= par;
end;
