-- $Id: dpram_2rd.vhd 1194 2026-05-03 09:35:52Z angelov $:

library ieee;
USE IEEE.std_logic_1164.ALL;
USE IEEE.std_logic_unsigned.ALL;

entity dpram_2rd is
generic (Na     : Positive := 4;
         Nd     : positive := 8;
       async_rd : Boolean := false);
port(
    clk_A   : in  std_logic;
    weA     : in  std_logic;
    addrA   : in  std_logic_vector(Na-1 downto 0);
    dinA    : in  std_logic_vector(Nd-1 downto 0);
    doutA   : out std_logic_vector(Nd-1 downto 0);

    clk_B   : in  std_logic;
    addrB   : in  std_logic_vector(Na-1 downto 0);
    doutB   : out std_logic_vector(Nd-1 downto 0) );
end dpram_2rd;

architecture a of dpram_2rd is

type t_mem_data is array(0 to 2**Na - 1) of std_logic_vector(doutA'range);

signal mem_data : t_mem_data;
attribute syn_ramstyle : string;
attribute syn_ramstyle of mem_data : signal is "block_ram";
signal addri_A : integer range 0 to 2**Na - 1;
signal addri_B : integer range 0 to 2**Na - 1;

begin
     addri_A <= conv_integer(addrA);
     addri_B <= conv_integer(addrB);

ram: process(clk_A)
    begin
        if rising_edge(clk_A) then
            if weA = '1' then
                mem_data(addri_A) <= dinA;
            end if;
        end if;
    end process;

ar: if     async_rd generate
        doutA <= mem_data(addri_A);
        doutB <= mem_data(addri_B);
    end generate;

sr: if not async_rd generate
    process(clk_A)
    begin
        if rising_edge(clk_A) then
            doutA <= mem_data(addri_A);
        end if;
    end process;

    process(clk_B)
    begin
        if rising_edge(clk_B) then
            doutB <= mem_data(addri_B);
        end if;
    end process;

    end generate;
end;
