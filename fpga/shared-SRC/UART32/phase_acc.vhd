LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.all;
USE IEEE.STD_LOGIC_UNSIGNED.all;

-- $Id: phase_acc.vhd 975 2023-06-29 05:57:14Z angelov $:

entity phase_acc is
generic(
    -- decrement the accumulator after each clock
    ACC_DECR    : Positive := 125;
    -- size of the accumulator
    ACC_NBITS   : Positive := 10);
    -- the numbers here correspond to 32.768 MHz clock and 4 Mbit/s baud rate:
    -- the desired divider ratio is 32.768/4 = 8.192
    -- 8.192*ACC_DECR=2**ACC_NBITS
    -- so the "ideal" Bittime is 2**ACC_NBITS/ACC_DECR = system_clock/baud_rate
port (
    clk    : in  std_logic;
    ena    : in  std_logic := '1';
    -- sender signals:
    -- start the sequence, activate the sh_ena at the end of each bit to be sent
    -- start fills the accumulator
    start  : in  std_logic := '0';

    -- receiver signals:
    -- falling edge detected, used as start in receiver mode, the sample output comes at half period, then each period
    fedge  : in  std_logic := '0';
    -- resynchronizing in receiver mode
    redge  : in  std_logic := '0';
    -- both signals load the accumulator with the half of its max

    -- sample/shift enable, 1 clock long
    -- generated when underflow in accumulator occurs
    sh_ena : out std_logic);
end phase_acc;

architecture a of phase_acc is

signal acc_reg      : std_logic_vector(ACC_NBITS-1 downto 0);
signal acc_inp      : std_logic_vector(ACC_NBITS   downto 0);
constant acc_dec    : std_logic_vector(ACC_NBITS   downto 0) := conv_std_logic_vector(ACC_DECR, ACC_NBITS+1);
-- compensate the latency of the circuit by loading smaller values
-- load a full period when starting to send
constant acc_iniF   : std_logic_vector(ACC_NBITS   downto 0) := conv_std_logic_vector(2**ACC_NBITS-1-ACC_DECR, ACC_NBITS+1);
-- load a half period after edges
constant acc_iniE   : std_logic_vector(ACC_NBITS   downto 0) := conv_std_logic_vector(2**(ACC_NBITS-1)-1-ACC_DECR, ACC_NBITS+1);

begin

    process(all)
    begin
        if start='1' then
            -- load a full period when starting to send
            acc_inp <= acc_iniF;
        elsif fedge='1' or redge='1' then
            -- load a half period after edges
            acc_inp <= acc_iniE;
        else
            -- change the phase
            acc_inp <= ('0' & acc_reg) - acc_dec;
        end if;
    end process;

    process(clk)
    begin
        if rising_edge(clk) then
            if ena='1' then
                acc_reg <= acc_inp(acc_reg'range);
                sh_ena  <= acc_inp(ACC_NBITS);
            else
                sh_ena  <= '0';
            end if;
        end if;
    end process;

end;
