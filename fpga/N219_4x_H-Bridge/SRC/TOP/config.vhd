-- $Id: config.vhd 1216 2026-09-02 16:57:27Z  $:

library ieee;
use ieee.std_logic_1164.all;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

use work.config_pkg.all;
use work.DateTime_pkg.all;
use work.svn_extract.all;

entity config is
generic(
    Nbits   : Integer range 16 to 32 := 16;
    Nleds   : Integer range  0 to 16 :=  4;
    RegOut  : Boolean := false);
port(
    clk             : in  std_logic;
    reset           : in  std_logic;
    we              : in  std_logic;
    addr            : in  std_logic_vector( 4 downto 0);
    din             : in  std_logic_vector(Nbits-1 downto 0);
    dout            : out std_logic_vector(Nbits-1 downto 0);

--    dbg_sel     : out std_logic_vector( 2 downto 0);
    uart_sel    : out std_logic_vector( 1 downto 0);
    soft_rst    : out std_logic;
    cpu_rst     : out std_logic;
    leds_softw  : out std_logic_vector(  Nleds-1 downto 0);
    leds_blink  : out std_logic_vector(  Nleds-1 downto 0);
    leds        : out std_logic_vector(2*Nleds-1 downto 0) );
end config;

architecture behav of config is

component sed_check is
port(
    clk           : in  std_logic;
    rst           : in  std_logic;
    sed_enable_s  : in  std_logic;
    sed_start_s   : in  std_logic;    -- start (system clk)
    sed_frcerr_s  : in  std_logic;    -- force error (system clk)
    sed_err_s     : out std_logic;
    sed_done_s    : out std_logic;
    sed_in_prog_s : out std_logic;
    sed_time_s    : out std_logic_vector(19 downto 0); -- measured in system clocks
    sed_cnt_s     : out std_logic_vector(19 downto 0) ); -- cycles in the own clock
end component;

signal compile_date_time : std_logic_vector(23 downto 0);
signal svn_date_ver      : std_logic_vector(23 downto 0);

signal timer            : std_logic_vector(31 downto 0);
signal timer_lat0       : std_logic_vector(31 downto 0);
signal timer_lat1       : std_logic_vector(31 downto 0);
signal timer_lat2       : std_logic_vector(31 downto 0);
signal timer_run        : std_logic;

signal command_i        : std_logic_vector( 3 downto 0);
signal uart_sel_i       : std_logic_vector(uart_sel'range);
--signal dbg_sel_i        : std_logic_vector(dbg_sel'range);

signal long_cmd         : std_logic_vector( 3 downto 0);
constant long_cmd0      : std_logic_vector(long_cmd'range) := (others => '0');

-- combinational output of the read mux
signal dout_i           : std_logic_vector(dout'range);
signal leds_i           : std_logic_vector(leds'range);
signal leds_blink_i     : std_logic_vector(leds_blink'range);
signal leds_softw_i     : std_logic_vector(leds_softw'range);

signal sed_enable_s     : std_logic;    -- initialize: 0 -> 1 -> 0 after device reprogrammed
                                        -- enable checking: turn on (1) to do the test, level sensitive
signal sed_start_s      : std_logic;    -- start (system clk)
signal sed_frcerr_s     : std_logic;    -- force error (system clk)
signal sed_err_s        : std_logic;    -- error(s) found
signal sed_done_s       : std_logic;    -- finished checking
signal sed_in_prog_s    : std_logic;    -- SED in progress

signal long_sed         : std_logic_vector( 3 downto 0); -- to create long pulses to the SED circuit
constant long_sed0      : std_logic_vector(long_sed'range) := (others => '0');

-- counter for the core clocks necessary for the CRC check
signal sed_cnt_s        : std_logic_vector(19 downto 0);
-- when the CRC frequency is high enough (> system clk), sed_time needs no more bits
signal sed_time_s       : std_logic_vector(sed_cnt_s'range);

begin

    compile_date_time <= conv_std_logic_vector(DTMinute,    6) &
                         conv_std_logic_vector(DTHour,      5) &
                         conv_std_logic_vector(DTDay,       5) &
                         conv_std_logic_vector(DTMonth,     4) &
                         conv_std_logic_vector(DTYear-2015, 4);

    svn_date_ver      <= conv_std_logic_vector(get_ver(svn_rev),       11) &
                         conv_std_logic_vector(get_day(svn_date),       5) &
                         conv_std_logic_vector(get_month(svn_date),     4) &
                         conv_std_logic_vector(get_year(svn_date)-2015, 4);

    -- the read process
    process(all)
    begin
        dout_i  <= (others => '0');
        case addr is
            when ADDR_LED =>
                dout_i(leds_i'range) <= leds_i;

            when ADDR_COMMAND =>
                dout_i(BIT_CMD_CPU_RST) <= command_i(BIT_CMD_CPU_OFF);
                dout_i(BIT_CMD_CPU_OFF) <= command_i(BIT_CMD_CPU_OFF);

            when ADDR_UART_SEL =>
                dout_i(uart_sel_i'range) <= uart_sel_i;

            when ADDR_TIMER   =>
                dout_i <= timer;

            when ADDR_TIMER_LAT0 =>
                dout_i <= timer_lat0;

            when ADDR_TIMER_LAT1 =>
                dout_i <= timer_lat1;

            when ADDR_TIMER_LAT2 =>
                dout_i <= timer_lat2;

            when ADDR_LED_BLINK =>
                dout_i(leds_blink_i'range) <= leds_blink_i;
                dout_i(leds_softw'length-1+16 downto 16) <= leds_softw_i;

            when ADDR_CHIP_CRC =>
                -- status
                dout_i(BIT_CRC_RUN)   <= sed_in_prog_s;
                dout_i(BIT_CRC_DONE)  <= sed_done_s;
                dout_i(BIT_CRC_ERR)   <= sed_err_s;
                -- command
                dout_i(BIT_CRC_FRERR) <= sed_frcerr_s;
                dout_i(BIT_CRC_START) <= sed_start_s;
                dout_i(BIT_CRC_ENA)   <= sed_enable_s;
                dout_i(31 downto 16)  <= x"AFFE";

            when ADDR_SED_TIME0 =>
                dout_i( 7 downto  0) <= sed_time_s( 7 downto  0);
            when ADDR_SED_TIME1 =>
                dout_i( 7 downto  0) <= sed_time_s(15 downto  8);
            when ADDR_SED_TIME2 =>
                dout_i( 3 downto  0) <= sed_time_s(19 downto 16);

            when ADDR_CRC_CNT0 =>
                dout_i( 7 downto  0) <= sed_cnt_s( 7 downto  0);
            when ADDR_CRC_CNT1 =>
                dout_i( 7 downto  0) <= sed_cnt_s(15 downto  8);
            when ADDR_CRC_CNT2 =>
                dout_i( 3 downto  0) <= sed_cnt_s(19 downto 16);

            when ADDR_SVN0    =>
                dout_i( 7 downto  0) <= svn_date_ver( 7 downto  0);
            when ADDR_SVN1    =>
                dout_i( 7 downto  0) <= svn_date_ver(15 downto  8);
            when ADDR_SVN2    =>
                dout_i( 7 downto  0) <= svn_date_ver(23 downto 16);

            when ADDR_CMP0    =>
                dout_i( 7 downto  0) <= compile_date_time( 7 downto  0);
            when ADDR_CMP1    =>
                dout_i( 7 downto  0) <= compile_date_time(15 downto  8);
            when ADDR_CMP2    =>
                dout_i( 7 downto  0) <= compile_date_time(23 downto 16);

            when ADDR_VERSION =>
                if BOOT_IMG=1 then dout_i(BIT_BOOT_IMG) <= '1'; end if;
                dout_i(BIT_VER_HW+2 downto BIT_VER_HW) <= conv_std_logic_vector(hw_version, 3);
                dout_i(BIT_VER_AS+3 downto BIT_VER_AS) <= conv_std_logic_vector(as_version, 4);

            when others => dout_i <= (others => '-');
        end case;
    end process;

with_o_reg: if RegOut generate
    process(clk)
    begin
        if rising_edge(clk) then
            dout <= dout_i;
        end if;
    end process;
else generate

    dout <= dout_i;

end generate;

    -- the write process
    process(clk)
    begin
        if rising_edge(clk) then
            if long_sed /= long_sed0 then
                long_sed <= long_sed - 1;
            else
                sed_start_s  <= '0';
            end if;

            if long_cmd /= long_cmd0 then
                long_cmd <= long_cmd - 1;
            else
                command_i   <= (others => '0');
            end if;

            -- preserve the permanent CPU off
            command_i(BIT_CMD_CPU_OFF) <= command_i(BIT_CMD_CPU_OFF);

            if timer_run='1' then
                timer <= timer + 1;
            end if;

            if reset='1' then
                long_cmd <= (others => '1');
                long_sed <= (others => '1');
                sed_enable_s <= '0';
                command_i(BIT_CMD_SFT_RST) <= '1'; -- soft reset
                command_i(BIT_CMD_CPU_RST) <= '1'; -- cpu reset
                command_i(BIT_CMD_CPU_OFF) <= '0';
                uart_sel_i <= (others => '0');
                timer <= (others => '0');
                timer_lat0 <= (others => '0');
                timer_lat1 <= (others => '0');
                timer_lat2 <= (others => '0');
--                dbg_sel_i <= (others => '0');
                leds_i <= (others => '1');
                leds_i(1 downto 0) <= "11";
                leds_blink_i <= (others => '0');
                leds_softw_i <= (leds_softw_i'high => '1', others => '0');
                timer_run     <= '0';

            elsif we='1' then
                case addr is
                    when ADDR_LED =>
                        leds_i <= din(leds_i'range);

                    when ADDR_CHIP_CRC =>
                        sed_enable_s  <= din(BIT_CRC_ENA);
                        sed_start_s   <= din(BIT_CRC_START);
                        sed_frcerr_s  <= din(BIT_CRC_FRERR);
                        long_sed      <= (others => '1');

--                    when ADDR_CRC_CNT0 | ADDR_CRC_CNT1 | ADDR_CRC_CNT2 => NULL;

                    when ADDR_COMMAND  =>
                        command_i <= din(command_i'range);
                        long_cmd  <= (others => '1');

                    when ADDR_UART_SEL => -- not used now in this design!
                        uart_sel_i <= din(uart_sel'range);

                    when ADDR_TIMER =>
                        if din(BIT_TIMER_CLR)='1' then timer <= (others => '0'); end if;
                        timer_run <= din(BIT_TIMER_RUN);
                        if din(BIT_TIMER_LAT0)='1' then timer_lat0 <= timer; end if;
                        if din(BIT_TIMER_LAT1)='1' then timer_lat1 <= timer; end if;
                        if din(BIT_TIMER_LAT2)='1' then timer_lat2 <= timer; end if;

                    when ADDR_TIMER_LAT0 =>
                        timer_lat0 <= timer;

                    when ADDR_TIMER_LAT1 =>
                        timer_lat1 <= timer;

                    when ADDR_TIMER_LAT2 =>
                        timer_lat2 <= timer;

                    when ADDR_LED_BLINK  =>
                        leds_blink_i  <= din(leds_blink_i'range);
                        leds_softw_i  <= din(leds_softw_i'length-1+16 downto 16);

                    when others => NULL;
                end case;
            end if;

            cpu_rst <= command_i(BIT_CMD_CPU_OFF) or command_i(BIT_CMD_CPU_RST);

            if sed_done_s='1' or reset='1' then
                sed_frcerr_s  <= '0';
            end if;

        end if;
    end process;

    soft_rst <= command_i(BIT_CMD_SFT_RST);
--    dbg_sel  <= dbg_sel_i;
    uart_sel <= uart_sel_i;
    leds     <= leds_i;
--    leds     <= (others => '1');
    leds_blink  <= leds_blink_i;
    leds_softw  <= leds_softw_i;

sed_check_i: sed_check
port map(
    clk           => clk,
    rst           => reset,
    sed_enable_s  => sed_enable_s,
    sed_start_s   => sed_start_s,
    sed_frcerr_s  => sed_frcerr_s,
    sed_err_s     => sed_err_s,
    sed_done_s    => sed_done_s,
    sed_in_prog_s => sed_in_prog_s,
    sed_time_s    => sed_time_s,
    sed_cnt_s     => sed_cnt_s);

end;
