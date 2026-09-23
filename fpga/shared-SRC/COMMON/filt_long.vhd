-- $Id: filt_long.vhd 980 2023-07-17 18:14:54Z angelov $:

LIBRARY IEEE;
use IEEE.std_logic_1164.all;

entity filt_long is
generic (N     : Positive := 3); -- how many samples should be equal to accept the level
port(
     clk        : in  std_logic;
     d          : in  std_logic; -- input
     inv_q      : in  std_logic; -- invert (1) or not (0) the input
     ena_edge   : in  std_logic; -- enable edge detection
     pos_edge   : out std_logic; -- rising edge of the output
     neg_edge   : out std_logic; -- falling edge of the output
     q          : out std_logic);-- filtered (eventually inverted) output
end filt_long;

architecture a of filt_long is

signal counts  : Integer range 0 to N-1;
signal samples : std_logic_vector(1 downto 0);

signal q_i  : std_logic;

begin

n_gt_2: if N > 2 generate
    process(clk)
    begin
        if rising_edge(clk) then
            samples <= samples(0) & d;
            pos_edge <= '0';
            neg_edge <= '0';
            if (samples(0) xor samples(1)) = '1' then -- different
                counts <= N-2;
            else
                if counts = 0 then
                    pos_edge <= ena_edge and (inv_q xor      samples(1) ) and not q_i;
                    neg_edge <= ena_edge and (inv_q xor (not samples(1))) and     q_i;
                    q_i      <= inv_q xor      samples(1);
                else
                    counts <= counts - 1; -- count down
                end if;
            end if;
        end if;
    end process;
end generate;

n_eq_2: if N=2 generate

    process(clk)
    begin
        if rising_edge(clk) then
            samples <= samples(0) & d;
            pos_edge <= '0';
            neg_edge <= '0';
            if (samples(0) xor samples(1)) = '0' then -- equal
                pos_edge <= ena_edge and (inv_q xor      samples(1) ) and not q_i;
                neg_edge <= ena_edge and (inv_q xor (not samples(1))) and     q_i;
                q_i      <= inv_q xor      samples(1);
            end if;
        end if;
    end process;
end generate;

n_eq_1: if N=1 generate
    -- N = 1
    process(clk)
    begin
        if rising_edge(clk) then
            samples(0) <= d;
            pos_edge <= '0';
            neg_edge <= '0';
            if ena_edge='1' then
                pos_edge <= (inv_q xor samples(0) ) and not q_i;
                neg_edge <= (inv_q xor (not samples(0))) and q_i;
            end if;
            q_i <= samples(0) xor inv_q;
        end if;
    end process;

end generate;

  q <= q_i;

end;
