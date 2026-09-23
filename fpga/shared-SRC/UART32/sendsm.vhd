LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

-- $Id: sendsm.vhd 1208 2026-08-08 16:11:40Z  $:

entity sendsm is
generic(
    USE_ACC     : boolean := false;
    -- decrement the accumulator after each clock
    ACC_DECR    : Positive := 125;
    -- size of the accumulator
    ACC_NBITS   : Positive := 10;
    -- the numbers here correspond to 32.768 MHz clock and 4 Mbit/s baud rate:
    -- the desired divider ratio is 32.768/4 = 8.192
    -- 8.192*ACC_DECR=2**ACC_NBITS
    -- so the "ideal" Bittime is 2**ACC_NBITS/ACC_DECR = system_clock/baud_rate

    Bittime  : Positive := 100;
    BittimeF : Positive := 50;
    Nidle    : Positive := 2;
    Nbits    : Positive := 8);
port (
    clk     : in  std_logic;
    reset   : in  std_logic;
    fast_m  : in  std_logic := '0';
    start   : in  std_logic;
    busy    : out std_logic;
    shift   : out std_logic;
    crc_ena : out std_logic;
    ready   : out std_logic);
end sendsm;

architecture a of sendsm is

component phase_acc is
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
end component;

signal bitcounter   : Integer range 0 to Nbits+Nidle;
signal bittimer     : Integer range 0 to Bittime-1;
signal bittimer_ini : Integer range 0 to Bittime-1;

-- The syn_encoding attribute has 4 values:
-- sequential, onehot, gray and safe.
type send_state_type is (idle, wordpar);
attribute syn_enum_encoding : string;
attribute syn_enum_encoding of send_state_type : type is "gray";

signal send_statem : send_state_type;

signal bit_sample   : std_logic;
signal ready_i      : std_logic;


type bitt_state_type is (ph_idle, ph_send);
signal ph_sm       : bitt_state_type;

begin
    process(clk)
    begin
        if rising_edge(clk) then
            shift   <= '0';
            ready_i <= '0';
            crc_ena <= '0';
            if reset = '1' then
                send_statem <= idle;
                bitcounter  <= Nbits+Nidle; -- including the start bit
                busy        <= '0';
            else
            case send_statem is
            when idle =>
                busy  <= '0';
                bitcounter <= Nbits+Nidle; -- including the start bit;
                if start = '1' then
                    send_statem <= wordpar;
                    busy  <= '1';
                end if;
            when wordpar =>
                if bit_sample = '1' then
                    shift <= '1';

                    if bitcounter /= (Nbits+Nidle) and -- start bit
                       bitcounter >= Nidle then crc_ena <= '1'; end if;

                    if bitcounter /= 0 then
                        bitcounter  <= bitcounter - 1;
                    else
                        send_statem <= idle;
                        ready_i <= '1';
                        busy  <= '0';
                    end if;
                end if;
            when others => send_statem <= idle;
            end case;
            end if;
        end if;
    end process;

    ready <= ready_i;

with_acc: if USE_ACC generate
phase_acc_i: phase_acc
generic map(
    -- decrement the accumulator after each clock
    ACC_DECR    => ACC_DECR,
    -- size of the accumulator
    ACC_NBITS   => ACC_NBITS)
    -- the numbers here correspond to 32.768 MHz clock and 4 Mbit/s baud rate:
    -- the desired divider ratio is 32.768/4 = 8.192
    -- 8.192*ACC_DECR=2**ACC_NBITS
    -- so the "ideal" Bittime is 2**ACC_NBITS/ACC_DECR = system_clock/baud_rate
port map(
    clk    => clk,
--  ena    : in  std_logic := '1';
    -- sender signals:
    -- start the sequence, activate the sh_ena at the end of each bit to be sent
    -- start fills the accumulator
    start  => start,

    -- receiver signals:
    -- falling edge detected, used as start in receiver mode, the sample output comes at half period, then each period
--  fedge  => start,
    -- resynchronizing in receiver mode
--  redge  => redge,
    -- both signals load the accumulator with the half of its max

    -- sample/shift enable, 1 clock long
    -- generated when underflow in accumulator occurs
    sh_ena => bit_sample);

else generate

    bittimer_ini <= Bittime-1 when fast_m='0' else BittimeF-1;
    -- simple bit timing, when system_clock/baud_rate is an integer
    bit_sample <= '1' when bittimer=0 else '0';

    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                ph_sm    <= ph_idle;
                bittimer <= bittimer_ini;
            else
            case ph_sm is
            when ph_idle =>
                bittimer   <= bittimer_ini;
                if start = '1' then
                    ph_sm <= ph_send;
                end if;
            when ph_send =>
                if bit_sample = '0' then
                    bittimer <= bittimer - 1;
                else
                    bittimer <= bittimer_ini;
                end if;
                if ready_i='1' then
                    ph_sm <= ph_idle;
                end if;
            end case;
            end if;
        end if;
    end process;

end generate;

end;
