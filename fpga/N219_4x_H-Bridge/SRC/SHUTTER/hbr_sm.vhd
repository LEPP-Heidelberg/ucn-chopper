-- $Id: hbr_sm.vhd 1217 2026-09-03 13:17:29Z  $:

library ieee;
use ieee.std_logic_1164.all;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

use work.hbr_gen_pkg.all;

entity hbr_sm is
generic(Na_RAM : Integer := 10);
port(
     -- clock
    clk             : in  std_logic;
    reset           : in  std_logic;

    -- to PWM
    pwr_code        : out std_logic_vector(PWM_BITS-1 downto 0);
    -- from PWM
    pwm_tick        : in  std_logic;
    pwm_reset       : out std_logic;

    pwr_on          : in  std_logic;

    -- from config
    h_MODE2         : in  std_logic;
    h_slow_decay    : in  std_logic;    -- when off, short the coil instead of Hi-Z
--    pwm_man_pwr     : in  std_logic_vector(PWM_BITS-1  downto 0);
    -- on/off (the 4 IN outputs to H-bridge) in bits 3..0, the next state in bits 7..4
    -- the duration in bits 23..8 in PWM periods
    h_man_outp      : in  std_logic_vector(TABLE_WIDTH-1 downto 0);
    -- start single shot
    h_single        : in  std_logic;

    -- start sequences, can not be simultaneously activ
    ctrl_on         : in  std_logic;
    ctrl_off        : in  std_logic;


    -- from the config
    -- address range - where to read the sequence from the RAMs
    -- start address in 31..16 and number of PWM periods in 15..0
    seq_ad_beg_on   : in   std_logic_vector(Na_RAM-1 downto 0);
    seq_ad_len_on   : in   std_logic_vector(Na_RAM-1 downto 0);

    seq_ad_beg_off  : in   std_logic_vector(Na_RAM-1 downto 0);
    seq_ad_len_off  : in   std_logic_vector(Na_RAM-1 downto 0);

    remain_in_last  : in   std_logic;

    -- to/from the RAMs
    sm_addr         : out std_logic_vector(Na_RAM-1 downto 0);
    sm_ramd         : in  std_logic_vector(TABLE_WIDTH-1 downto 0);

    busy            : out std_logic;
    -- 1,2 control outputs 1,2, 3,4 control outputs 3,4
    -- PH/EN MODE2=0
    -- in1/3    in2/4   out1/3  out2/4  Comment (provided sleep_n = 1)
    --  0         x       H        H    Brake (High-Side Slow Decay)
    --  1         0       L        H    Reverse (OUT2/4 -> OUT1/3)
    --  1         1       H        L    Forward (OUT1/3 -> OUT2/4)

    -- PWM MODE2=1
    -- in1/3    in2/4   out1/3  out2/4  Comment (provided sleep_n = 1)
    --  0         0     Hi-Z     Hi-Z   Coast (H-Bridge outputs Hi-Z)
    --  0         1       L        H    Reverse (OUT2/4 -> OUT1/3)
    --  1         0       H        L    Forward (OUT1/3 -> OUT2/4)
    --  1         1       H        H    Brake (High-Side Slow Decay)
    h_inp           : out std_logic_vector(2 downto 1) );
end hbr_sm;


architecture a of hbr_sm is

-- input/output to the state machine:
-- both modes:
-- inputs
--      pwm_tick - new PWM period
--      pwr_on - PWM
-- outputs
--      pwr_code
--      h_inp(1..2)

-- single shot mode:
--  inputs
--      h_man_outp, h_single
--      pwm_man_power
--  outputs


-- sequence mode:
--      ctrl_on(1..2)   \ starts
--      ctrl_off(1..2)  /
-- config inputs:
--      seq_ad_beg_[on|off]_[1|2], seq_ad_len_[on|off]_[1|2] - start address & length
--      sm_ramd_[1|2] - data from RAM

-- outputs
--      sm_addr_[1|2]

type sm_type is (sm_idle, sm_man_start, sm_man_fin,
                 sm_seq_start, sm_seq_read, sm_seq_next, sm_fin);

signal hbr_sm   : sm_type;

signal enable_on  : std_logic;
signal enable_off : std_logic;

signal reset_sm : std_logic;
--signal dir      : std_logic;

signal pwm_cnt  : std_logic_vector(TABLE_WDT_DUR-1 downto 0);

signal sm_acnt  : std_logic_vector(sm_addr'range);

signal h_next   : std_logic_vector(h_inp'range);

begin
    -- MODE2 expected to be 1!
    process(clk)
    begin
        if rising_edge(clk) then
            -- reset when h_mode2 is wrong!
            reset_sm <= reset or not h_mode2;
            pwm_reset <= reset;

            -- modulate with PWM only 01 or 10 states, but not 11 (brake)!
            if and(h_next) then
                h_inp <= h_next;
            else
                if pwr_on='1' then h_inp <= h_next;     -- 01 or 10
                              else h_inp <= (others => h_slow_decay); end if; -- 00 map to 00 or 11
            end if;

            busy      <= '1';
            case hbr_sm is
                when sm_idle =>
                    busy      <= '0';
                    if remain_in_last='0' then
                        pwm_reset <= '1';
                        h_next    <= "00"; -- Hi-Z all outputs
                        h_inp     <= "00"; -- Hi-Z all outputs
                        pwr_code  <= (others => '0');
                    else
                        if pwr_code > MAX_IDLE_POWER_CODE then
                            pwr_code <= MAX_IDLE_POWER_CODE;
                        end if;
                    end if;

                    if h_single='1' then -- single shot
                        pwr_code <= h_man_outp(TABLE_POS_PWR+TABLE_WDT_PWR-1 downto TABLE_POS_PWR);
                        pwm_cnt  <= h_man_outp(TABLE_POS_DUR+TABLE_WDT_DUR-1 downto TABLE_POS_DUR);
                        h_next   <= h_man_outp(TABLE_POS_OUT+1               downto TABLE_POS_OUT);
                        hbr_sm   <= sm_man_start;
                        busy     <= '1';
                    end if;

                    if ctrl_on='1' and enable_on='1' then
                        sm_addr <= seq_ad_beg_on;
                        sm_acnt <= seq_ad_len_on;
                        --dir     <= '1';
                        hbr_sm  <= sm_seq_start;
                        busy    <= '1';
                    end if;

                    if ctrl_off='1' and enable_off='1' then
                        sm_addr <= seq_ad_beg_off;
                        sm_acnt <= seq_ad_len_off;
                        --dir     <= '0';
                        hbr_sm  <= sm_seq_start;
                        busy    <= '1';
                    end if;

                when sm_man_start =>
                    if pwm_tick = '1' then
                        if pwm_cnt /= 0 then
                            pwm_cnt <= pwm_cnt - 1;
                        else
                            pwr_code <= (others => '0');
                            hbr_sm   <= sm_idle;
                            h_next   <= "00"; -- Hi-Z all outputs
                        end if;
                    end if;

                when sm_seq_start =>
                    pwm_reset <= '1';
                    hbr_sm <= sm_seq_read;

                when sm_seq_read  =>
                    --pwm_reset <= '1';
                    pwr_code <= sm_ramd(TABLE_POS_PWR+TABLE_WDT_PWR-1 downto TABLE_POS_PWR);
                    pwm_cnt  <= sm_ramd(TABLE_POS_DUR+TABLE_WDT_DUR-1 downto TABLE_POS_DUR);
                    h_next   <= sm_ramd(TABLE_POS_OUT+1               downto TABLE_POS_OUT);
                    hbr_sm   <= sm_seq_next;
                    sm_addr  <= sm_addr + 1; -- point to the next RAM data

                when sm_seq_next =>
                    if pwm_tick = '1' then
                        if pwm_cnt /= 0 then
                            pwm_cnt <= pwm_cnt - 1;
                        else
                            if sm_acnt = 0 then
                                hbr_sm <= sm_idle;
                            else
                                sm_acnt <= sm_acnt - 1;
                                hbr_sm   <= sm_seq_read;
                            end if;
                        end if;
                    end if;
                when sm_fin =>
                    hbr_sm <= sm_idle;

                when others => hbr_sm <= sm_idle;
            end case;

            if reset_sm='1' then
                hbr_sm <= sm_idle;
                pwm_reset <= '1';
                h_next    <= "00"; -- Hi-Z all outputs
                h_inp     <= "00"; -- Hi-Z all outputs
                pwr_code  <= (others => '0');
            end if;

        end if;
    end process;

    process(clk)
    begin
        if rising_edge(clk) then
            if seq_ad_len_on = 0 then
                enable_on <='0';
            else
                enable_on <='1';
            end if;

            if seq_ad_len_off = 0 then
                enable_off <='0';
            else
                enable_off <='1';
            end if;
        end if;
    end process;

end;
