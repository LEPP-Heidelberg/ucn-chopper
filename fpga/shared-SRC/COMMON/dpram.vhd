-- $Id: dpram.vhd 1205 2026-07-03 14:41:40Z  $:

library ieee;
USE IEEE.std_logic_1164.ALL;
USE IEEE.std_logic_unsigned.ALL;

entity dpram is
generic (Na     : Positive := 4;      -- address width
         Nd     : positive := 8;      -- data width
         IMPL   : Natural  := 0;      -- 0 - behaviour, 1 - PMI, 2 - core gen (1 and 2 not implemented here)
         LATTICE : boolean := false;  -- true: registered address, false : registered data of async read
       async_rd : Boolean  := false); -- asynchronous read, not possible with block RAMs
port(
    clk_r   : in  std_logic;
    clk_w   : in  std_logic;
    we      : in  std_logic;
    raddr   : in  std_logic_vector(Na-1 downto 0);
    waddr   : in  std_logic_vector(Na-1 downto 0);
    din     : in  std_logic_vector(Nd-1 downto 0);
    dout    : out std_logic_vector(Nd-1 downto 0) );
end dpram;

architecture a of dpram is

type t_mem_data is array(0 to 2**Na - 1) of std_logic_vector(dout'range);

signal mem_data : t_mem_data;
attribute syn_ramstyle : string;
-- implement as EBR, registers or distributed RAM?
attribute syn_ramstyle of mem_data : signal is "block_ram";
attribute syn_ramstyle of mem_data : signal is "no_rw_check";
--attribute syn_ramstyle of mem_data : signal is "registers";
--attribute syn_ramstyle of mem_data : signal is "distributed ";
signal addri_r  : integer range 0 to 2**Na - 1;
signal addri_w  : integer range 0 to 2**Na - 1;
signal rg_addri_r : integer range 0 to 2**Na - 1;

begin
     addri_r <= conv_integer(raddr);
     addri_w <= conv_integer(waddr);

ram: process(clk_w)
    begin
        if rising_edge(clk_w) then
            if we = '1' then
                mem_data(addri_w) <= din;
            end if;
        end if;
    end process;

ar: if async_rd generate
        dout <= mem_data(addri_r);
    end generate;

sr: if not async_rd generate

lat: if LATTICE generate
    process(clk_r)
    begin
        if rising_edge(clk_r) then
            rg_addri_r <= addri_r;
        end if;
    end process;

    dout <= mem_data(rg_addri_r);

else generate

    process(clk_r)
    begin
        if rising_edge(clk_r) then
            dout <= mem_data(addri_r);
        end if;
    end process;

    end generate;

    end generate;
end;
