LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

-- $Id: ser_send.vhd 1 2016-03-15 14:35:42Z angelov $:

entity ser_send is
generic(Nbits   : Positive := 8; LSBfirst : Boolean := true);
port (
    clk    : in  std_logic;
    rst_n  : in  std_logic;
    load   : in  std_logic;
    din    : in  std_logic_vector(Nbits-1 downto 0);
    shift  : in  std_logic;
    parity : out std_logic;
    tx     : out std_logic);
end ser_send;

architecture a of ser_send is

signal send_buffer : std_logic_vector(Nbits downto 0);
signal par         : std_logic;

begin
    -- send buffer

lsb: if LSBfirst generate -- LSB first

    process(clk)
    begin
        if rising_edge(clk) then
            if rst_n = '0' then
                send_buffer <= (others => '1');
                par <= '0';
            elsif load = '1' then
                send_buffer <= din & '0'; -- start bit 0
                par <= '0';
            elsif shift = '1' then
                send_buffer <= '1' & send_buffer(send_buffer'high downto 1); -- fill with 1
                par <= par xor send_buffer(0);
            end if;
        end if;
    end process;
    tx <= send_buffer(0);

    end generate;


msb: if not LSBfirst generate -- MSB first

    process(clk)
    begin
        if rising_edge(clk) then
            if rst_n = '0' then
                send_buffer <= (others => '1');
                par <= '0';
            elsif load = '1' then
                send_buffer <= '0' & din; -- start bit 0
                par <= '0';
            elsif shift = '1' then
                send_buffer <= send_buffer(send_buffer'high-1 downto 0) & '1'; -- fill with 1
                par <= par xor send_buffer(send_buffer'high);
            end if;
        end if;
    end process;
    tx <= send_buffer(send_buffer'high);

    end generate;

    parity <= par;
end;
