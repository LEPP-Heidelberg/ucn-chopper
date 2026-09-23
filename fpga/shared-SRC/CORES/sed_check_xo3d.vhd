-- $Id: sed_check_xo3d.vhd 1064 2024-03-06 09:34:43Z angelov $:

library ieee;
use ieee.std_logic_1164.all;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity sed_check is
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
end sed_check;

architecture behav of sed_check is

COMPONENT SEDFA
   GENERIC(
--  supported freqencies in MHz
--  2.08     4.59    10.23  ??  38
--  2.15     4.75    10.64  ??  44.33
--  2.22     4.93    11.08  ??  53.2
--  2.29     5.12    11.57  ??  66.5
--  2.38     5.32    12.09  ??  88.67
--  2.46     5.54    12.67  ?? 133
--  2.56     5.78    13.30
--  2.66     6.05    14.00
--  2.77     6.33    14.78
--  2.89     6.65    15.65
--  3.02     7.00    16.63
--  3.17     7.39    17.73
--  3.33     7.82    19.00
--  3.50     8.31    20.46
--  3.69     8.58    22.17
--  3.91     8.87    24.18
--  4.16     9.17    26.60
--  4.29     9.50    29.56
--  4.43     9.85    33.25
    SED_CLK_FREQ  : string  := "3.5";
    CHECKALWAYS   : string  := "DISABLED";  -- not used now!
    --"256L","640L","1200L","2000L","4000L","7000L", "640U", "1200U", "2000U"
    DEV_DENSITY   : string  := "9400L");
PORT(
    SEDENABLE  :  in  STD_LOGIC;
    SEDSTART   :  in  STD_LOGIC;
    SEDFRCERR  :  in  STD_LOGIC;
    SEDSTDBY   :  in  STD_LOGIC;
    SEDERR     :  out STD_LOGIC;
    SEDDONE    :  out STD_LOGIC;
    SEDINPROG  :  out STD_LOGIC;
    SEDCLKOUT  :  out STD_LOGIC);
END COMPONENT;

--attribute SED_CLK_FREQ : string ;
--attribute SED_CLK_FREQ of SEDinst0 : label is "13.30";
--attribute CHECKALWAYS : string ;
--attribute CHECKALWAYS of SEDinst0 : label is "DISABLED" ;
--attribute DEV_DENSITY : string ;
--attribute DEV_DENSITY of SEDinst0 : label is "640L" ;

signal SEDENABLE         : std_logic;    -- initialize: 0 -> 1 -> 0 after device reprogrammed
                                         -- enable checking: turn on (1) to do the test, level sensitive
signal SEDSTART          : std_logic;    -- start, 0 -> 1 -> 0
signal SEDFRCERR         : std_logic;    -- force error to the core
signal SEDERR            : std_logic;    -- error(s) found
signal SEDDONE           : std_logic;    -- finished checking
signal SEDINPROG         : std_logic;    -- SED in progress
signal SEDCLKOUT         : std_logic;    -- clock out, gated with SEDENABLE, use it to synchronize the inputs!

-- counter for the core clocks necessary for the CRC check
signal sed_cnt_ena       : std_logic;
signal sed_cnt_ena_o     : std_logic;
signal sed_start_o       : std_logic;
signal sed_cnt           : std_logic_vector(sed_cnt_s'range);
-- copy of sed_cnt
-- when the CRC frequency is high enough (> system clk), sed_time need no more bits
signal sed_time_ena      : std_logic;
signal seddone_l         : std_logic;
signal sederr_l          : std_logic;
signal sed_time          : std_logic_vector(sed_time_s'range);

signal del_sed          : std_logic_vector( 6 downto 0); -- to create long pulses to the SED circuit
constant del_sed0       : std_logic_vector(del_sed'range) := (others => '0');

begin
    SEDENABLE <= sed_enable_s;

    process(clk)
    begin
        if rising_edge(clk) then
            sed_start_o <= sed_start_s;
            if sed_start_o='0' and sed_start_s='1' then -- start right now
              sed_time <= (others => '0'); -- clear the timer
              sed_time_ena <= '1';
            end if;

            if SEDDONE='1' or rst='1' then
                sed_time_ena <= '0';
            end if;

            if sed_time_ena='1' then
                sed_time <= sed_time + 1;
            end if;

            sed_cnt_ena_o <= sed_cnt_ena;

            if SEDDONE='1' and sed_cnt_ena='0' and sed_cnt_ena_o='1' then
                sed_cnt_s <= sed_cnt;
            end if;

            sed_in_prog_s <= SEDINPROG;
            sed_done_s    <= seddone_l;
            sed_err_s     <= sederr_l;

        end if;
    end process;
    sed_time_s <= sed_time;


    process(SEDCLKOUT, SEDENABLE)
    begin
        if SEDENABLE='0' then
            SEDSTART    <= '0';
            SEDFRCERR   <= '0';
            sed_cnt_ena <= '0';
            seddone_l   <= '0';
            sederr_l    <= '0';
            del_sed     <= (others => '1');

        elsif rising_edge(SEDCLKOUT) then

            -- synchronize the control signals to the SED circuit with the internal clock


            if sed_start_s='1' then
                del_sed <= (others => '1');
                SEDFRCERR <= '0';
            elsif del_sed /= del_sed0 then
                del_sed <= del_sed - 1;
            else
                SEDFRCERR <= sed_frcerr_s;
            end if;

            if sed_start_s='1' then
                SEDSTART  <= '1';
                seddone_l <= '0';
            elsif SEDDONE='1' then
                SEDSTART  <= '0';
                seddone_l <= '1';
            end if;

            if sed_start_s='1' then
                sederr_l <= '0';
            else
                sederr_l <= sederr_l or SEDERR;
            end if;

            -- count the clocks necessary to check the FPGA config
            -- 1. create a count enable signal
            if SEDSTART='1' then
                sed_cnt_ena <= '1';         -- start the counter
            elsif SEDDONE='1' then
                sed_cnt_ena <= '0';         -- stop the counter when done
            end if;

            -- 2. the counter
            if sed_cnt_ena='0' then
                if SEDSTART='1' then
                    sed_cnt <= (others => '0'); -- clear the counter
                end if;
            else
                sed_cnt <= sed_cnt + 1;
            end if;

        end if;
    end process;

crc_check_i: SEDFA
    generic map(
    SED_CLK_FREQ => "33.25",
    CHECKALWAYS => "DISABLED",
    DEV_DENSITY => "9400L" )
    port map(
        SEDENABLE   => SEDENABLE,       --< initialize: 0 -> 1 -> 0 after device reprogrammed
                                        --< enable checking: turn on (1) to do the test, level sensitive
        SEDSTART    => SEDSTART,        --< start SED cycle, 0 -> 1 -> 0
        SEDFRCERR   => SEDFRCERR,       --< force error
        SEDSTDBY    => '0',
        SEDERR      => SEDERR,          --> error found
        SEDDONE     => SEDDONE,         --> finished
        SEDINPROG   => SEDINPROG,       --> SED in progress
        SEDCLKOUT   => SEDCLKOUT);      --> clock out, gated with SEDENABLE, use it to synchronize the inputs!

end;
