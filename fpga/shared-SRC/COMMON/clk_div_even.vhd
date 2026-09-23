-- $Id: clk_div_even.vhd 1146 2025-02-16 09:17:31Z angelov $:

-- this design is much better for timing than clk_div.vhd for large dividers!
-- But is for even divider only! Can be extended for odd, but the
-- case is relatively rare - odd and large.

LIBRARY ieee;
USE ieee.std_logic_1164.all;

entity clk_div_even is
GENERIC (Nd : Positive := 50);
PORT(
    clk     : in  std_logic;
    en      : in  std_logic;
    div     : out std_logic);
end clk_div_even;

architecture a of clk_div_even is

signal q    : std_logic;
signal en_d : std_logic;
signal en_r : std_logic;
signal cnt  : Integer range 0 to Nd/2-1;

begin
    -- sync the enable, in case it comes not from a register
    process(clk)
    begin
        if rising_edge(clk) then
            en_r <= en;
        end if;
    end process;

    -- this is the case for Nd=2, 0, 1 and 3 are here but not legal
div2: if Nd < 4 generate
    en_d <= en_r;
end generate;

    -- this is the case for Nd=4 and larger
    -- note that odd number are treated as the next smaller even number!
divN: if Nd > 3 generate
    process(clk) -- frequency divider
    begin
        if rising_edge(clk) then
            en_d <= '0';
            if en_r='1' then
                if cnt=0 then
                    cnt <= Nd/2 - 1;
                    en_d <= '1';
                else
                    cnt <= cnt - 1;
                end if;
            end if;
        end if;
    end process;
end generate;

    process(clk)
    begin
        if rising_edge(clk) then
            if en_d='1' then
                q <= not q;
            end if;
        end if;
    end process;

    div <= q;

end;
