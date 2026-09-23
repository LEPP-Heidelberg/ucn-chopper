LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.all;
USE IEEE.STD_LOGIC_UNSIGNED.all;

entity my_addsub is
    generic (width : Integer := 16);
    port (
      A       : in  std_logic_vector(width-1 downto 0);
      B       : in  std_logic_vector(width-1 downto 0);
      CI      : in  std_logic;
      ADD_SUB : in  std_logic;
      SUM     : out std_logic_vector(width-1 downto 0);
      CO      : out std_logic);
    end my_addsub;

architecture a of my_addsub is

signal sum_i : std_logic_vector(width downto 0);
signal C     : std_logic_vector(width downto 0);
signal AC    : std_logic_vector(width downto 0);
signal BC    : std_logic_vector(width downto 0);

begin

    process(CI, A, B, ADD_SUB)
    begin
        C <= (others => '0');
        C(0) <= CI;
        BC <= (others => '0');
        BC(B'range) <= B;
        if ADD_SUB='0' then BC(B'range) <= not B; end if;
        AC <= (others => '0');
        AC(A'range) <= A;
    end process;

    sum_i <= AC + BC + C;
    SUM <= sum_i(SUM'range);
    CO  <= sum_i(sum_i'high);

end;
