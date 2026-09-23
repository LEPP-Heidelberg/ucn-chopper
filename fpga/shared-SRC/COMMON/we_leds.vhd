-- $Id: we_leds.vhd 1138 2025-02-01 08:28:15Z angelov $:

library ieee;
use ieee.std_logic_1164.all;

entity we_leds is
generic(
    FCLK            : Positive := 40000000;
    -- for 10 MHz clock:
    Nleds           : Positive :=   2);
port (
    clk             : in    std_logic;
    reset           : in    std_logic;

    code_green      : in    std_logic_vector(      7 downto 0);
    code_red        : in    std_logic_vector(      7 downto 0);
    code_blue       : in    std_logic_vector(      7 downto 0);

    leds_in         : in    std_logic_vector(Nleds-1 downto 0);
    led_ic_in       : out   std_logic);
end we_leds;

architecture a of we_leds is

type sm_type is (sm_idle, sm_reset, sm_load_led, sm_send_led);
signal sm  : sm_type;
-- WÅrth Electronic Datasheet used:
-- 1313210530000 Datasheet WL-ICLED Integrated Controller within LED

-- reference clock
constant FCLK_REF   : Positive := 10000000; -- 10 MHz

-- < previous bit > -----------.  < Tx_Low > -< next bit >
--                  < Tx_High > \___________/


-- lengths of the pulses in periods of the reference clock
-- begin of the sequence - reset pulse with this width:
constant Time_RESET     : Positive := 2500 ;

-- for each LED - 8 green, 8 red and 8 blue bits, MSBit first:
-- with widths 300 ns (150 - 450 ns) and 900 ns (750 - 1050 ns), here in ticks for 10 MHz clock:
constant Time_0_HIGH    : Positive :=    3 ;  -- and 1 LOW
constant Time_0_LOW     : Positive :=    9 ;  -- and 1 HIGH
-- full period for 1 bit, 1200 ns, from 900 to 1500 ns
constant Ticks_Per  : Positive := (Time_0_HIGH + Time_0_LOW)*FCLK/FCLK_REF;

-- how to send 1 bit:
-- 1) set output to 1, load the counter with Ticks_Per-1
-- 2) count down
-- 3) when transmitting 1 - compare the counter with TURN2LOW_1
--    when transmitting 0 - compare the counter with TURN2LOW_0
-- 4) compare OK => clear the output (0)
-- 5) the counter continues to count down
-- 6) counter is 0? => finished transmitting the bit
constant TURN2LOW_0 : Positive := (Time_0_LOW   )*FCLK/FCLK_REF;
constant TURN2LOW_1 : Positive := (Time_0_HIGH  )*FCLK/FCLK_REF;

signal cnt_pulse    : Integer range 0 to Ticks_Per-1;

constant Ticks_RESET : Integer := FCLK/FCLK_REF*Time_RESET;
signal cnt_reset    : Integer range 0 to Ticks_RESET-1;

signal led_c_bit    : std_logic;
signal sent_bit     : std_logic;
signal finish_1bit  : std_logic;

signal leds_sr      : std_logic_vector(leds_in'range);

signal led_GRB      : std_logic_vector(23 downto 0); -- 24 bits, MSBit G7, LSBit B0
signal sr_GRB       : std_logic_vector(led_GRB'high-1 downto 0); -- 23 bits
signal start_GRB    : std_logic;
signal finish_GRB   : std_logic;

signal cnt_bits     : Integer range 0 to led_GRB'high;
signal cnt_leds     : Integer range 0 to Nleds-1;

begin

    -- input : bit to be sent in sent_bit => must be updated after finish_1bit
    --         runs automatically when not in reset mode
    -- output: flag finish_1bit is 1
    --         serial output is in led_c_bit
    process(clk)
    begin
        if rising_edge(clk) then
            finish_1bit <= '0';
            if sm=sm_reset then
                led_c_bit <= '1';
                cnt_pulse <= Ticks_Per-1;
            else
                if cnt_pulse /= 0 then
                    cnt_pulse <= cnt_pulse - 1;
                end if;
                if cnt_pulse = 1 then
                    finish_1bit <= not led_c_bit;
                end if;

                if finish_1bit='1' then
                    cnt_pulse <= Ticks_Per-1;
                    led_c_bit <= '1';
                end if;

                if (sent_bit='0' and cnt_pulse=TURN2LOW_0) or (sent_bit='1' and cnt_pulse=TURN2LOW_1) then
                    led_c_bit <= '0';
                end if;
              end if;
        end if;
    end process;


    -- input : led_GRB - 24 bit, MSBit G7, LSBit B0
    --         start_GRB is 1
    -- output: finish_GRB is 1
    process(clk)
    begin
        if rising_edge(clk) then
            finish_GRB <= '0';
            if start_GRB='1' then
                sent_bit   <= led_GRB(led_GRB'high);
                sr_GRB     <= led_GRB(sr_GRB'range);
                cnt_bits   <= led_GRB'high;
            elsif cnt_bits /= 0 then
                if finish_1bit='1' then
                    cnt_bits   <= cnt_bits - 1;
                    sent_bit   <= sr_GRB(sr_GRB'high);
                    sr_GRB     <= sr_GRB(sr_GRB'high-1 downto 0) & '0';
                end if;
            else
                finish_GRB <= finish_1bit;
            end if;
        end if;
    end process;

    led_GRB <= code_green & code_red & code_blue when leds_sr(leds_sr'high) = '1' else (others => '0');

    process(clk)
    begin
        if rising_edge(clk) then
            start_GRB <= '0';
            led_ic_in <= led_c_bit;
            case sm is
                when sm_idle =>
                    sm <= sm_reset;
                    cnt_reset <= Ticks_RESET-1;
                    led_ic_in <= '0';

                when sm_reset =>
                    led_ic_in <= '0';
                    cnt_leds <= Nleds-1;
                    if cnt_reset /= 0 then
                        cnt_reset <= cnt_reset - 1;
                    else
                        sm        <= sm_load_led;
                        leds_sr   <= leds_in;
                    end if;

                when sm_load_led =>
                    start_GRB <= '1';
                    sm <= sm_send_led;

                when sm_send_led =>
                    if finish_GRB = '1' then
                        if cnt_leds /= 0 then
                            cnt_leds  <= cnt_leds - 1;
                            start_GRB <= '1';
                            leds_sr <= leds_sr(leds_sr'high-1 downto 0) & '0';
                            sm        <= sm_load_led;
                        else
                            sm <= sm_idle;
                            led_ic_in <= '0';
                        end if;
                    end if;
                when others => sm <= sm_idle;
            end case;

            if reset='1' then
                sm <= sm_idle;
            end if;

        end if;
    end process;

end;
