LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

-- $Id: recvsm.vhd 974 2023-06-27 07:36:53Z angelov $:

entity recvsm is
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
    Bittime : Positive := 100;
    Nbits   : Positive := 8);
port (
    clk    : in  std_logic;
    reset  : in  std_logic;
    start  : in  std_logic; -- falling edge detected, used as start
    redge  : in  std_logic; -- rising edge detected, used to resynchronize
    rx     : in  std_logic; -- input, used to detect timeouts (break)
    break  : out std_logic;  -- long frame detected
    sample : out std_logic;  -- 1 clock long
    busy   : out std_logic;
    ready  : out std_logic); -- 1 clock long
end recvsm;

architecture a of recvsm is

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

signal bitcounter : Integer range 0 to Nbits;
signal bittimer   : Integer range 0 to Bittime-1;

type recv_state_type is (idle, wordpar, finish);
type bitt_state_type is (ph_idle, ph_recv);
-- The syn_encoding attribute has 4 values:
-- sequential, onehot, gray and safe.
attribute syn_enum_encoding : string;
attribute syn_enum_encoding of recv_state_type : type is "gray";

signal recv_statem : recv_state_type;
signal ph_sm       : bitt_state_type;

signal norising     : std_logic;
signal was_break    : std_logic;
signal reset_ph_acc : std_logic;
signal bit_sample   : std_logic;

begin
    process(clk)
    begin
        if rising_edge(clk) then
            sample <= '0';
            ready  <= '0';
            reset_ph_acc <= '0';
            norising <= norising and not redge;
            case recv_statem is
                when idle =>
                    busy       <= '0';
                    norising   <= '1';
                    was_break  <= '0';
                    bitcounter <= Nbits;
                    if start = '1' then
                        recv_statem <= wordpar;
                        busy   <= '1';
                    end if;
                when wordpar =>
                    if bit_sample = '1' then
                        if bitcounter /= Nbits then -- skip the start bit!
                            sample <= '1';
                        end if;
                        if bitcounter /= 0 then
                            bitcounter  <= bitcounter - 1;
                        else
                            recv_statem <= finish;
                        end if;
                    end if;
                when finish  =>
                    if bit_sample = '1' then
                        if rx = '1' then
                            recv_statem <= idle;
                            reset_ph_acc <= '1';
                            ready <= not was_break;
                        else
                            was_break <= norising;
                        end if;
                    end if;
                when others => recv_statem <= idle;
            end case;

            if reset = '1' then
                busy        <= '0';
                recv_statem <= idle;
                bitcounter  <= Nbits;
                norising    <= '1';
                was_break   <= '0';
                reset_ph_acc <= '1';
            end if;
        end if;
    end process;

    break <= was_break;


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
--  start  : in  std_logic := '0';

    -- receiver signals:
    -- falling edge detected, used as start in receiver mode, the sample output comes at half period, then each period
    fedge  => start,
    -- resynchronizing in receiver mode
    redge  => redge,
    -- both signals load the accumulator with the half of its max

    -- sample/shift enable, 1 clock long
    -- generated when underflow in accumulator occurs
    sh_ena => bit_sample);

else generate

-- simple bit timing, when system_clock/baud_rate is an integer
    bit_sample <= '1' when bittimer=0 else '0';
    process(clk)
    begin
        if rising_edge(clk) then
            case ph_sm is
                when ph_idle =>
                    bittimer   <= (Bittime-1)/2;  -- was -2?
                    if start='1' then
                        ph_sm <= ph_recv;
                    end if;
                when ph_recv =>
                    if bit_sample = '0' then
                        bittimer <= bittimer - 1;
                    else
                        bittimer   <= Bittime-1;      -- init the bit timer for the next bit
                    end if;
                    if reset_ph_acc='1' then
                        ph_sm <= ph_idle;
                    end if;
            end case;
            -- resynchronize
            if (start = '1' or redge = '1') and (Bittime > 7) then
                bittimer <= (Bittime-1)/2;
            end if;

            if reset = '1' or reset_ph_acc='1' then
                ph_sm    <= ph_idle;
            end if;
        end if;
    end process;

end generate;

end;
