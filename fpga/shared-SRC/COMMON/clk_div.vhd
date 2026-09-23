-- $Id: clk_div.vhd 659 2021-02-13 10:33:37Z angelov $:

LIBRARY ieee;
USE ieee.std_logic_1164.all;

entity clk_div is
GENERIC (Nd : Integer := 50);
PORT(
        clk, en : IN  STD_LOGIC;
        div     : OUT STD_LOGIC);
end clk_div;

architecture a of clk_div is
SIGNAL q   : STD_LOGIC;
begin

div1: if Nd < 2 generate
    q <= clk;
    end generate;

div2: if Nd = 2 generate
    process(clk)
    begin
        if clk'event and clk='1' then
            q <= not q;
        end if;
    end process;
end generate;

divN: if Nd > 2 generate
    process(clk) -- frequency divider
    variable cnt : Integer range 0 to Nd-1;
    begin
        if clk'event and clk='1' then
            if en='1' then
                if cnt=0 then cnt := Nd-1; q <= '1';
                         else cnt := cnt - 1;
                end if;
                if cnt = (Nd/2-1) then
                    q <= '0';
                end if;
            end if;
        end if;
    end process;
end generate;
div <= q;
end;
