
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

-- $Id: prior_reg.vhd 65 2016-08-30 13:15:36Z angelov $:

entity prior_reg is
generic(N : Positive := 4);
port(clk    : in  std_logic;
     ena    : in  std_logic;
     sclr   : in  std_logic;
     invec  : in  std_logic_vector(N-1 downto 0);
     outvec : out std_logic_vector(N-1 downto 0) );
end prior_reg;

architecture a of prior_reg is

signal veto : std_logic_vector(N-1 downto 0);

begin
    process(invec)
    variable tmp : std_logic;
    begin
        veto(N-1) <= '0';
        tmp := '0';
        for i in N-2 downto 0 loop
            tmp := tmp or invec(i+1);
            veto(i) <= tmp;
        end loop;
    end process;

    process(clk)
    begin
        if rising_edge(clk) then
            if sclr = '1' then outvec <= (others => '0');
            elsif ena = '1' then
                for i in N-1 downto 0 loop
                    outvec(i) <= invec(i) and not veto(i);
                end loop;
            end if;
        end if;
    end process;
end;
