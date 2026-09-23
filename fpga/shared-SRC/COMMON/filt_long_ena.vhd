-- $Id: filt_long_ena.vhd 1065 2024-03-16 06:40:18Z angelov $:

LIBRARY IEEE;
use IEEE.std_logic_1164.all;

entity filt_long_ena is
generic (N     : Positive := 3);
port(
     clk        : in  std_logic;
     clk_ena    : in  std_logic;
     d          : in  std_logic;
     inv_q      : in  std_logic;
     ena_edge   : in  std_logic;
     pos_edge   : out std_logic;
     neg_edge   : out std_logic;
     q          : out std_logic);
end filt_long_ena;

architecture a of filt_long_ena is

signal counts  : Integer range 0 to N-1;
signal samples : std_logic_vector(1 downto 0);

signal q_i  : std_logic;

begin

ngt2: if N > 2 generate
  process(clk)
  begin
    if rising_edge(clk) then
        pos_edge <= '0';
        neg_edge <= '0';
        if clk_ena='1' then
            samples <= samples(0) & d;
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
    end if;
  end process;
end generate;

neq2: if N = 2 generate
    process(clk)
    begin
        if rising_edge(clk) then
            pos_edge <= '0';
            neg_edge <= '0';
            if clk_ena='1' then
                samples <= samples(0) & d;
                if (samples(0) xor samples(1)) = '0' then -- equal
                    pos_edge <= ena_edge and (inv_q xor      samples(1) ) and not q_i;
                    neg_edge <= ena_edge and (inv_q xor (not samples(1))) and     q_i;
                    q_i      <= inv_q xor      samples(1);
                end if;
            end if;
        end if;
    end process;
end generate;

neq1: if N = 1 generate
    process(clk)
    begin
        if rising_edge(clk) then
            pos_edge <= '0';
            neg_edge <= '0';
            if clk_ena='1' then
                samples <= samples(0) & d;
                pos_edge <= ena_edge and (inv_q xor      samples(1) ) and not q_i;
                neg_edge <= ena_edge and (inv_q xor (not samples(1))) and     q_i;
                q_i      <= inv_q xor      samples(1);
            end if;
        end if;
    end process;
end generate;

  q <= q_i;

end;
