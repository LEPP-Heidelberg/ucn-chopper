-- $Id: ssram.vhd 1136 2025-01-27 18:19:13Z angelov $:

library ieee;
USE IEEE.std_logic_1164.ALL;
USE IEEE.std_logic_unsigned.ALL;

entity ssram is
generic (Na     : Positive := 4;
         Nd     : positive := 8;
       async_rd : Boolean := true);
port(
    clk     : in  std_logic;
    we      : in  std_logic;
    addr    : in  std_logic_vector(Na-1 downto 0);
    din     : in  std_logic_vector(Nd-1 downto 0);
    dout    : out std_logic_vector(Nd-1 downto 0) );
end ssram;

architecture a of ssram is

type t_mem_data is array(0 to 2**addr'length - 1) of std_logic_vector(dout'range);
signal mem_data : t_mem_data;
--signal raddri   : integer range 0 to 2**addr'length - 1;
signal addri    : integer range 0 to 2**addr'length - 1;

begin
     addri <= conv_integer(addr);

ram: process(clk)
    begin
        if rising_edge(clk) then
--            raddri <= addri;
            if we = '1' then
                mem_data(addri) <= din;
            end if;
        end if;
    end process;

ar: if     async_rd generate
        dout <= mem_data( addri);
    end generate;

sr: if not async_rd generate
    process(clk)
    begin
        if rising_edge(clk) then
            dout <= mem_data(addri);
        end if;
    end process;
    end generate;
end;
