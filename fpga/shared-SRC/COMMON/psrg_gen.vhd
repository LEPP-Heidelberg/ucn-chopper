-- $Id: psrg_gen.vhd 126 2016-12-27 15:04:36Z angelov $:

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

entity psrg_gen is
generic(
        N : Positive := 4);
port(
        clk     : in    std_logic;
        rst     : in    std_logic;
        ce      : in    std_logic;
        q       : out   std_logic_vector(N-1 downto 0);
        full    : out   std_logic);
end psrg_gen;

architecture a of psrg_gen is

function psrg(sr : std_logic_vector) return std_logic is
variable bit0 : std_logic;
begin
 case sr'length is
  when 32 => bit0 := sr(31) xor sr(21) xor sr( 1) xor sr( 0);
  when 31 => bit0 := sr(30) xor sr(27);
  when 30 => bit0 := sr(29) xor sr( 5) xor sr( 3) xor sr( 0);
  when 29 => bit0 := sr(28) xor sr(26);
  when 28 => bit0 := sr(27) xor sr(24);
  when 27 => bit0 := sr(26) xor sr( 4) xor sr( 1) xor sr( 0);
  when 26 => bit0 := sr(25) xor sr( 5) xor sr( 1) xor sr( 0);
  when 25 => bit0 := sr(24) xor sr(21);
  when 24 => bit0 := sr(23) xor sr(22) xor sr(21) xor sr(16);
  when 23 => bit0 := sr(22) xor sr(17);
  when 22 => bit0 := sr(21) xor sr(20);
  when 21 => bit0 := sr(20) xor sr(18);
  when 20 => bit0 := sr(19) xor sr(16);
  when 19 => bit0 := sr(18) xor sr( 5) xor sr( 1) xor sr( 0);
  when 18 => bit0 := sr(17) xor sr(10);
  when 17 => bit0 := sr(16) xor sr(13);
  when 16 => bit0 := sr(15) xor sr(14) xor sr(12) xor sr( 3);
  when 14 => bit0 := sr(13) xor sr( 4) xor sr( 2) xor sr( 0);
  when 13 => bit0 := sr(12) xor sr( 3) xor sr( 2) xor sr( 0);
  when 12 => bit0 := sr(11) xor sr( 5) xor sr( 3) xor sr( 0);
  when 11 => bit0 := sr(10) xor sr( 8);
  when 10 => bit0 := sr( 9) xor sr( 6);
  when  9 => bit0 := sr( 8) xor sr( 4);
  when  8 => bit0 := sr( 7) xor sr( 5) xor sr( 4) xor sr( 3);
  when  5 => bit0 := sr( 4) xor sr( 2);
  when 15 | 7 | 6 | 4 | 3 =>
             bit0 := sr(sr'length-1) xor sr(sr'length-2);
--when 15 => bit0 := sr(14) xor sr(13);
--when  7 => bit0 := sr( 6) xor sr( 5);
--when  6 => bit0 := sr( 5) xor sr( 4);
--when  4 => bit0 := sr( 3) xor sr( 2);
  when others => bit0 := '-';
 end case;
 return bit0;
end;

constant full_dat   : std_logic_vector(N-1 downto 0) := (others => '1');
constant zero_dat   : std_logic_vector(N-1 downto 0) := (others => '0');
signal   preg       : std_logic_vector(N-1 downto 0);
signal   is_zero    : std_logic;
signal   is_full    : std_logic;

begin
    process(clk)
    variable bit_in : std_logic;
    begin
        if rising_edge(clk) then
            is_full <= '0';
            -- flags
            if preg = zero_dat then is_zero <= '1'; else is_zero <= '0'; end if;

            if rst='1' then
                preg <= full_dat;
            elsif ce='1' then
                if preg = full_dat then
                    is_full <= '1';
                end if;
                -- new bit in, avoid stuck at 00..00
                bit_in := psrg(preg) or is_zero;
                for i in 1 to N-1 loop
                    preg(i) <= preg(i-1);
                end loop;
                preg(0) <= bit_in;
            end if;
        end if;
    end process;
    full <= is_full;
    q <= preg;
end;
