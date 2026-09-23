-- $Id: hbr_dec_cnf.vhd 1214 2026-08-26 05:57:40Z  $:

library ieee;
use ieee.std_logic_1164.all;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

use work.hbr_gen_pkg.all;

entity hbr_dec_cnf is
generic(Na_RAM : Integer := 10);
port(
     -- clock
    clk             : in  std_logic;
    reset           : in  std_logic;

    -- to the bus
    we              : in    std_logic;
    -- Addr(MSB..MSB-1)
    --      0, 1        config
    --      2           RAM with sequence0
    --      3           RAM with sequence1
    addr            : in    std_logic_vector(Na_RAM+1 downto 0);
    din             : in    std_logic_vector(31 downto 0);
    dout            : out   std_logic_vector(31 downto 0);

    we_ram          : out   std_logic_vector(1 downto 0);
    drd_ram_0       : in    std_logic_vector(TABLE_WIDTH-1 downto 0);
    drd_ram_1       : in    std_logic_vector(TABLE_WIDTH-1 downto 0);


    hbr_config      : out   hbr_conf_type;

    -- 8-bit power, how long to be ON in the period above, will be shifted left by 4..0 depending on FREQ_DIV
    -- used only in manual mode of operation!
--  pwm_man_power   : out   std_logic_vector(PWM_BITS-1 downto 0);

    -- on/off (the 4 IN outputs to H-bridge) in bits 3..0, the next state in bits 7..4
    -- the duration in bits 23..8 in PWM periods
    h_man_outp_1    : out   std_logic_vector(TABLE_WIDTH-1 downto 0);
    h_man_outp_2    : out   std_logic_vector(TABLE_WIDTH-1 downto 0);
    h_single        : out   std_logic_vector( 2 downto 1);

    -- divide system clock 48*2^10 to get
    -- code:      0    1      2      3      4      5      6      7
    -- PWM Freq 4800, 8000, 9600, 16000, 19200, 24000, 32000, 48000
    pwm_freq_div    : out   std_logic_vector( 2 downto 0);

    -- address range - where to read the sequence from the RAMs
    -- start address in 31..16 and number of PWM periods in 15..0
    seq_ad_beg_on_1 : out   std_logic_vector(Na_RAM-1 downto 0);
    seq_ad_len_on_1 : out   std_logic_vector(Na_RAM-1 downto 0);

    seq_ad_beg_on_2 : out   std_logic_vector(Na_RAM-1 downto 0);
    seq_ad_len_on_2 : out   std_logic_vector(Na_RAM-1 downto 0);

    seq_ad_beg_off_1: out   std_logic_vector(Na_RAM-1 downto 0);
    seq_ad_len_off_1: out   std_logic_vector(Na_RAM-1 downto 0);

    seq_ad_beg_off_2: out   std_logic_vector(Na_RAM-1 downto 0);
    seq_ad_len_off_2: out   std_logic_vector(Na_RAM-1 downto 0);

    status          : in    std_logic_vector(31 downto 0);

    sm_reset        : out   std_logic_vector( 2 downto 1);
    start_on        : out   std_logic_vector( 2 downto 1);
    start_off       : out   std_logic_vector( 2 downto 1) );
end hbr_dec_cnf;

architecture a of hbr_dec_cnf is

subtype full_addr_type  is  std_logic_vector(Na_RAM+1 downto 0);
subtype mfull_addr_type is  std_logic_vector(Na_RAM+1 downto Na_RAM);

constant ADDR_RNG_STA_CONFIG    : full_addr_type := (Na_RAM+1 => '0', others => '-');
constant ADDR_RNG_TABLE_0       : full_addr_type := (Na_RAM+1 downto Na_RAM => "10", others => '-');
constant ADDR_RNG_TABLE_1       : full_addr_type := (Na_RAM+1 downto Na_RAM => "11", others => '-');

constant MADDR_RNG_STA_CONFIG    : mfull_addr_type := "0-";
constant MADDR_RNG_TABLE_0       : mfull_addr_type := "10";
constant MADDR_RNG_TABLE_1       : mfull_addr_type := "11";

signal hbr_config_i             : hbr_conf_type;
--signal pwm_man_power_i          : std_logic_vector(pwm_man_power'range);

signal h_man_outp_1_i           : std_logic_vector(h_man_outp_1'range);
signal h_man_outp_2_i           : std_logic_vector(h_man_outp_2'range);

signal pwm_freq_div_i           : std_logic_vector(pwm_freq_div'range);

signal seq_ad_beg_on_1_i        : std_logic_vector(Na_RAM-1 downto 0);
signal seq_ad_len_on_1_i        : std_logic_vector(Na_RAM-1 downto 0);

signal seq_ad_beg_on_2_i        : std_logic_vector(Na_RAM-1 downto 0);
signal seq_ad_len_on_2_i        : std_logic_vector(Na_RAM-1 downto 0);

signal seq_ad_beg_off_1_i       : std_logic_vector(Na_RAM-1 downto 0);
signal seq_ad_len_off_1_i       : std_logic_vector(Na_RAM-1 downto 0);

signal seq_ad_beg_off_2_i       : std_logic_vector(Na_RAM-1 downto 0);
signal seq_ad_len_off_2_i       : std_logic_vector(Na_RAM-1 downto 0);

signal we_cnf                   : std_logic;
signal drd_sta_cnf              : std_logic_vector(31 downto 0);

begin
--    we          : in    std_logic;
    -- Addr(MSB..MSB-1)
    --      0, 1        config
    --      2           RAM with sequence0
    --      3           RAM with sequence1
--  process(all)
--  begin
--      we_cnf <= '0';
--      we_ram <= "00";
--      dout   <= (others => '0');
--      case? addr is
--          when ADDR_RNG_STA_CONFIG =>
--              we_cnf <= we;
--              dout   <= drd_sta_cnf;
--
--          when ADDR_RNG_TABLE_0 =>
--              we_ram(0) <= we;
--              dout(drd_ram_0'range) <= drd_ram_0;
--
--          when ADDR_RNG_TABLE_1 =>
--              we_ram(1) <= we;
--              dout(drd_ram_1'range) <= drd_ram_1;
--
--          when others => NULL;
--
--      end case?;
--  end process;

    process(all)
    begin
        we_cnf <= '0';
        we_ram <= "00";
        dout   <= (others => '0');
        case? addr(addr'high downto addr'high-1) is
            when "0-" =>
                we_cnf <= we;
                dout   <= drd_sta_cnf;

            when "10" =>
                we_ram(0) <= we;
                dout(drd_ram_0'range) <= drd_ram_0;

            when "11" =>
                we_ram(1) <= we;
                dout(drd_ram_1'range) <= drd_ram_1;

            when others => NULL;

        end case?;
    end process;

    process(all)
    begin
        drd_sta_cnf <= (others => '0');
        case addr(3 downto 0) is

            when ADDR_START_ON_OFF | ADDR_H_STAT =>
                drd_sta_cnf(status'range) <= status;

            when ADDR_H_CONF | ADDR_H_BIT_CNF =>
                drd_sta_cnf(hbr_config'range) <= hbr_config_i;

            when ADDR_H_OUTP_1 =>
                drd_sta_cnf(h_man_outp_1'range) <= h_man_outp_1_i;

            when ADDR_H_OUTP_2 =>
                drd_sta_cnf(h_man_outp_2'range) <= h_man_outp_2_i;

--          when ADDR_PWM_POWER =>
--              drd_sta_cnf(pwm_man_power'range) <= pwm_man_power_i;

            when ADDR_PWM_FREQ_DIV =>
                drd_sta_cnf(pwm_freq_div'range) <= pwm_freq_div_i;

            when ADDR_SEQ_AD_RANGE_ON_1 =>
                drd_sta_cnf(Na_RAM-1    downto  0) <= seq_ad_beg_on_1_i;
                drd_sta_cnf(Na_RAM-1+16 downto 16) <= seq_ad_len_on_1_i;

            when ADDR_SEQ_AD_RANGE_ON_2 =>
                drd_sta_cnf(Na_RAM-1    downto  0) <= seq_ad_beg_on_2_i;
                drd_sta_cnf(Na_RAM-1+16 downto 16) <= seq_ad_len_on_2_i;

            when ADDR_SEQ_AD_RANGE_OFF_1 =>
                drd_sta_cnf(Na_RAM-1    downto  0) <= seq_ad_beg_off_1_i;
                drd_sta_cnf(Na_RAM-1+16 downto 16) <= seq_ad_len_off_1_i;

            when ADDR_SEQ_AD_RANGE_OFF_2 =>
                drd_sta_cnf(Na_RAM-1    downto  0) <= seq_ad_beg_off_2_i;
                drd_sta_cnf(Na_RAM-1+16 downto 16) <= seq_ad_len_off_2_i;

            when others => NULL;
        end case;

    end process;

    process(clk)
    variable bit_offs   : Integer range 0 to 31;
    begin
        if rising_edge(clk) then
            h_single <= "00";
            sm_reset   <= (others => reset);
            start_on   <= "00";
            start_off  <= "00";
            if we_cnf='1' then
                case addr(3 downto 0) is

                    when ADDR_START_ON_OFF =>
                        sm_reset <= din(5 downto 4);

                        if din(5) = '0' then
                            if    din(1)='1' then start_on(2)  <= '1';
                            elsif din(3)='1' then start_off(2) <= '1'; end if;
                        end if;

                        if din(4) = '0' then
                            if    din(0)='1' then start_on(1)  <= '1';
                            elsif din(2)='1' then start_off(1) <= '1'; end if;
                        end if;

                    when ADDR_H_CONF =>
                        hbr_config_i <= din(hbr_config'range);

                    when ADDR_H_BIT_CNF =>
                        bit_offs := conv_integer(din(8 downto 4));
                        case bit_offs is
                            when HBR_BIT_TOFF | HBR_BIT_TOFF + 1 =>
                                hbr_config_i(HBR_BIT_TOFF + 1 downto HBR_BIT_TOFF  ) <= din(1 downto 0);

                            when HBR_BIT_DECAY | HBR_BIT_DECAY + 1 =>
                                hbr_config_i(HBR_BIT_DECAY +1 downto HBR_BIT_DECAY ) <= din(1 downto 0);

                            when HBR_BIT_MODE | HBR_BIT_MODE + 1 =>
                                hbr_config_i(HBR_BIT_MODE + 1 downto HBR_BIT_MODE  ) <= din(1 downto 0);

                            when HBR_BIT_OCPM                   =>
                                hbr_config_i(HBR_BIT_OCPM         ) <= din(0);

                            when HBR_BIT_SLEEP_N                =>
                                hbr_config_i(HBR_BIT_SLEEP_N      ) <= din(0);

                            when HBR_BIT_ENA_OPCPL              =>
                                hbr_config_i(HBR_BIT_ENA_OPCPL    ) <= din(0);

                            when HBR_BIT_ENA_OPCPL+1            =>
                                hbr_config_i(HBR_BIT_ENA_OPCPL+1  ) <= din(0);

                            when HBR_BIT_INV_OPCPL              =>
                                hbr_config_i(HBR_BIT_INV_OPCPL    ) <= din(0);

                            when HBR_BIT_INV_OPCPL+1            =>
                                hbr_config_i(HBR_BIT_INV_OPCPL+1  ) <= din(0);

                            when HBR_BIT_ENA_AFBR               =>
                                hbr_config_i(HBR_BIT_ENA_AFBR     ) <= din(0);

                            when HBR_BIT_ENA_AFBR +1            =>
                                hbr_config_i(HBR_BIT_ENA_AFBR +1  ) <= din(0);

                            when HBR_BIT_INV_AFBR               =>
                                hbr_config_i(HBR_BIT_INV_AFBR     ) <= din(0);

                            when HBR_BIT_INV_AFBR +1            =>
                                hbr_config_i(HBR_BIT_INV_AFBR +1  ) <= din(0);

                            when HBR_BIT_SL_DEC_SM              =>
                                hbr_config_i(HBR_BIT_SL_DEC_SM    ) <= din(0);

                            when HBR_BIT_SL_DEC_SM +1           =>
                                hbr_config_i(HBR_BIT_SL_DEC_SM +1 ) <= din(0);

                            when HBR_BIT_REM_LAST              =>
                                hbr_config_i(HBR_BIT_REM_LAST    ) <= din(0);

                            when HBR_BIT_REM_LAST +1           =>
                                hbr_config_i(HBR_BIT_REM_LAST +1 ) <= din(0);
                            when others => NULL;

                        end case;

                    when ADDR_H_OUTP_1 =>
                        h_man_outp_1_i <= din(h_man_outp_1'range);
                        h_single(1)  <= '1';

                    when ADDR_H_OUTP_2 =>
                        h_man_outp_2_i <= din(h_man_outp_2'range);
                        h_single(2)  <= '1';

                    when ADDR_PWM_FREQ_DIV =>
                        pwm_freq_div_i <= din(pwm_freq_div'range);

                    when ADDR_SEQ_AD_RANGE_ON_1 =>
                        seq_ad_beg_on_1_i <= din(Na_RAM-1    downto  0);
                        seq_ad_len_on_1_i <= din(Na_RAM-1+16 downto 16);

                    when ADDR_SEQ_AD_RANGE_ON_2 =>
                        seq_ad_beg_on_2_i <= din(Na_RAM-1    downto  0);
                        seq_ad_len_on_2_i <= din(Na_RAM-1+16 downto 16);

                    when ADDR_SEQ_AD_RANGE_OFF_1 =>
                        seq_ad_beg_off_1_i <= din(Na_RAM-1    downto  0);
                        seq_ad_len_off_1_i <= din(Na_RAM-1+16 downto 16);

                    when ADDR_SEQ_AD_RANGE_OFF_2 =>
                        seq_ad_beg_off_2_i <= din(Na_RAM-1    downto  0);
                        seq_ad_len_off_2_i <= din(Na_RAM-1+16 downto 16);

                    when others => NULL;
                end case;
            end if;
            if reset='1' then
                hbr_config_i       <= hbr_default(DUAL_MODE);
                -- put later the best PWM freq
                pwm_freq_div_i     <= (others => '0');
                -- put later some limits according to the default content of the memories
                seq_ad_beg_on_1_i  <= (others => '0');
                seq_ad_len_on_1_i  <= (others => '0');
                seq_ad_beg_on_2_i  <= (others => '0');
                seq_ad_len_on_2_i  <= (others => '0');
                seq_ad_beg_off_1_i <= (others => '0');
                seq_ad_len_off_1_i <= (others => '0');
                seq_ad_beg_off_2_i <= (others => '0');
                seq_ad_len_off_2_i <= (others => '0');
            end if;
            -- preserve the MODE1 (dual/single) ?
            if MODE1_PROG_FIX then
                if DUAL_MODE then hbr_config_i(HBR_BIT_MODE) <= '0';
                             else hbr_config_i(HBR_BIT_MODE) <= '1'; end if;
            end if;
            -- preserve the MODE2 (PH/EN or PWM) ?
            if MODE2_PROG_FIX then
                if PWM_MODE  then hbr_config_i(HBR_BIT_MODE+1) <= '1';
                             else hbr_config_i(HBR_BIT_MODE+1) <= '0'; end if;
            end if;
        end if;
    end process;

    hbr_config       <= hbr_config_i ;
    h_man_outp_1     <= h_man_outp_1_i ;
    h_man_outp_2     <= h_man_outp_2_i ;
    pwm_freq_div     <= pwm_freq_div_i ;

    seq_ad_beg_on_1  <= seq_ad_beg_on_1_i ;
    seq_ad_len_on_1  <= seq_ad_len_on_1_i ;

    seq_ad_beg_on_2  <= seq_ad_beg_on_2_i ;
    seq_ad_len_on_2  <= seq_ad_len_on_2_i ;

    seq_ad_beg_off_1 <= seq_ad_beg_off_1_i;
    seq_ad_len_off_1 <= seq_ad_len_off_1_i;

    seq_ad_beg_off_2 <= seq_ad_beg_off_2_i;
    seq_ad_len_off_2 <= seq_ad_len_off_2_i;
end;
