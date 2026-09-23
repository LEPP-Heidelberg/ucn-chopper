-- $Id: dmem.vhd 1125 2024-11-14 07:05:44Z angelov $:

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.all;
USE IEEE.STD_LOGIC_UNSIGNED.all;

-- addr
-- MSB=1 : RAM
-- MSB=0 : ROM

entity dmem is
generic (Nsram   : Integer := 5;
         Ndata   : Integer := 16;
         SyncOut : Boolean := false);
port(
    clk         : in  std_logic;
    addr        : in  std_logic_vector(Nsram-1 downto 0);
    we          : in  std_logic;
    data_in     : in  std_logic_vector(Ndata-1 downto 0);
    data_out    : out std_logic_vector(Ndata-1 downto 0));
end dmem;

architecture a of dmem is

type data_array is array(0 to 2**Nsram-1) of std_logic_vector(data_out'range);

signal myram : data_array;

attribute syn_ramstyle : string;
attribute syn_ramstyle of myram : signal is "block_ram";

signal addr_ram : std_logic_vector(Nsram-1 downto 0);
signal dout_ram : std_logic_vector(Ndata-1 downto 0);
signal we_ram   : std_logic;

begin
    addr_ram <= addr(addr_ram'range);
    we_ram   <= we;

    -- writing to the dmem
    process(clk)
    begin
        if rising_edge(clk) then
            if we_ram='1' then
                myram(conv_integer(addr_ram)) <= data_in;
            end if;
        end if;
    end process;

    -- reading from dmem
sync_out: if SyncOut generate
    process(clk)
    begin
        if rising_edge(clk) then
            dout_ram <= myram(conv_integer(addr_ram));
        end if;
    end process;
end generate;

async_out: if not SyncOut generate

    dout_ram <= myram(conv_integer(addr_ram));

end generate;

    data_out <= dout_ram;
end;
