LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.all;

-- $Id: counter.vhd 1 2016-03-15 14:35:42Z angelov $:

entity counter is
generic (N : Positive := 8);
port (
    clk     : in  std_logic;
    sload   : in  std_logic;
    high_b  : in  std_logic; -- load the high byte
    cnten   : in  std_logic;
    d       : in  std_logic_vector(  N-1 downto 0);
    q       : out std_logic_vector(2*N-1 downto 0) );
end counter;

architecture a of counter is

signal q_i       : std_logic_vector(2*N-2 downto 0);
signal sload_e_i : std_logic;

begin
process(clk)
begin
    if clk'event and clk='1' then
       if sload = '1' then
           if high_b='1' then
               q_i(2*N-2 downto N) <= d(N-2 downto 0);
               sload_e_i <= d(N-1);
           else
               q_i(N-1 downto 0) <= d;
           end if;
       elsif cnten = '1' then
           if sload_e_i = '1' then
                q_i <= q_i + 1;
           end if;
       end if;
    end if;
end process;

q <= sload_e_i & q_i;

end;
