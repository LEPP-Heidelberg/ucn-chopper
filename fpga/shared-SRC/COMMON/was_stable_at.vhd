-- $Id: was_stable_at.vhd 880 2022-04-05 15:41:53Z angelov $:

LIBRARY IEEE;
use IEEE.std_logic_1164.all;

entity was_stable_at is
generic (N     : Positive := 3);
port(
     clk        : in  std_logic;
     d          : in  std_logic;
     changed    : out std_logic;
     st_hi_pul  : out std_logic;
     st_lo_pul  : out std_logic;
     st_hi_sta  : out std_logic;
     st_lo_sta  : out std_logic);
end was_stable_at;

architecture a of was_stable_at is

signal counts       : Integer range 0 to N-1;
signal samples      : std_logic_vector(1 downto 0);
signal stab_sta_i   : std_logic;

begin

  process(clk)
  begin
    if rising_edge(clk) then
      changed <= '0';
      samples <= samples(0) & d;
      changed <= samples(0) xor samples(1);

      if (samples(0) xor samples(1)) = '1' then -- different
        changed    <= '1';
        counts     <= N-2;
        stab_sta_i <= '0';
        st_hi_pul  <= '0';
        st_lo_pul  <= '0';
        st_hi_sta  <= '0';
        st_lo_sta  <= '0';
      else
        if counts = 0 then
            stab_sta_i <= '1';
            st_hi_pul <=      samples(1)  and (not stab_sta_i);
            st_lo_pul <= (not samples(1)) and (not stab_sta_i);
            st_hi_sta <=      samples(1) ;
            st_lo_sta <= (not samples(1));
        else
            counts <= counts - 1; -- count down
        end if;
      end if;
    end if;
  end process;

end;
