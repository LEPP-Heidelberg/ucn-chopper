-- $Id: pwm_gen.vhd 1209 2026-08-13 09:31:10Z  $:

library ieee;
use ieee.std_logic_1164.all;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

use work.hbr_gen_pkg.all;

entity pwm_gen is
--generic(Na_RAM : Integer := 10);
port(
     -- clock
    clk         : in  std_logic;
    reset       : in  std_logic;

    -- 7..0 for higherst ... lowest frequency
    freq_code   : in  std_logic_vector(2 downto 0);
    pwm_tick    : out std_logic;

    pwr_code    : in  std_logic_vector(PWM_BITS-1 downto 0);

    pwr_on      : out std_logic);
end pwm_gen;

architecture a of pwm_gen is

signal prescaler    : std_logic_vector(5+8-PWM_BITS downto 0);
signal presc_ini    : std_logic_vector(prescaler'range);
signal pwr_cnt      : std_logic_vector(PWM_BITS-1 downto 0);
constant pwr_cnt_all1  : std_logic_vector(PWM_BITS-1 downto 0) := (others => '1');
signal div_out      : std_logic;
signal pwr_not_off  : std_logic;

signal pwr_pipe     : std_logic_vector(1 downto 0);

begin
    process(clk)
    begin
        if rising_edge(clk) then
            div_out  <= '0';
            pwm_tick <= '0';

            if pwr_code = 0 then pwr_not_off <= '0'; else pwr_not_off <= '1'; end if;

            case freq_code is
                when "000" => presc_ini <= conv_std_logic_vector(SYS_CLK/PWM_STEPS/PWM_FREQUENCIES(0)-1, prescaler'length);
                when "001" => presc_ini <= conv_std_logic_vector(SYS_CLK/PWM_STEPS/PWM_FREQUENCIES(1)-1, prescaler'length);
                when "010" => presc_ini <= conv_std_logic_vector(SYS_CLK/PWM_STEPS/PWM_FREQUENCIES(2)-1, prescaler'length);
                when "011" => presc_ini <= conv_std_logic_vector(SYS_CLK/PWM_STEPS/PWM_FREQUENCIES(3)-1, prescaler'length);
                when "100" => presc_ini <= conv_std_logic_vector(SYS_CLK/PWM_STEPS/PWM_FREQUENCIES(4)-1, prescaler'length);
                when "101" => presc_ini <= conv_std_logic_vector(SYS_CLK/PWM_STEPS/PWM_FREQUENCIES(5)-1, prescaler'length);
                when "110" => presc_ini <= conv_std_logic_vector(SYS_CLK/PWM_STEPS/PWM_FREQUENCIES(6)-1, prescaler'length);
                when "111" => presc_ini <= conv_std_logic_vector(SYS_CLK/PWM_STEPS/PWM_FREQUENCIES(7)-1, prescaler'length);
                when others => presc_ini <= (others => '-');
            end case;

            if prescaler = 0 then
                prescaler <= presc_ini;
                div_out <= '1';
            else
                prescaler <= prescaler - 1;
            end if;

            if div_out='1' then
                pwr_cnt <= pwr_cnt + 1;
                if pwr_cnt = pwr_cnt_all1 then
                    pwm_tick <= '1';
                end if;
            end if;

            if pwr_code >= pwr_cnt then
                pwr_pipe(0) <= pwr_not_off;
              --  pwr_on <= pwr_not_off;
            else
                pwr_pipe(0) <= '0';
              --  pwr_on <= '0';
            end if;

            pwr_pipe(pwr_pipe'high downto 1) <= pwr_pipe(pwr_pipe'high-1 downto 0);

            if reset='1' then
              --  pwr_on <= '0';
                prescaler <= presc_ini;
                div_out <= '0';
                pwr_cnt <= (0 => '1', others => '0');
                pwm_tick <= '0';
            end if;


        end if;
    end process;

    pwr_on <= pwr_pipe(pwr_pipe'high);
end;
