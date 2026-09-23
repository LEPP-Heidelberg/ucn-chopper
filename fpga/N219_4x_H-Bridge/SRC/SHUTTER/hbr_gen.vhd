-- $Id: hbr_gen.vhd 1214 2026-08-26 05:57:40Z  $:

library ieee;
use ieee.std_logic_1164.all;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

use work.hbr_gen_pkg.all;

entity hbr_gen is
generic(Na_RAM : Integer := 10);
port(
     -- clock
    clk         : in  std_logic;
    reset       : in  std_logic;

    h_debug     : out std_logic_vector(7 downto 0);

    -- to the bus
    we          : in    std_logic;
    -- Addr(MSB..MSB-1)
    --      0, 1        config
    --      2           RAM with sequence0
    --      3           RAM with sequence1
    addr        : in    std_logic_vector(Na_RAM+1 downto 0);
    din         : in    std_logic_vector(31 downto 0);
    dout        : out   std_logic_vector(31 downto 0);

    -- status inputs
    -- active low, open-drain, with pull-up
    fault_n     : in    std_logic;

    -- Operation Modi (s. datasheet for details)
    -- TOFF - 0, 1, open, 330k to GND
    -- TOFF pin     off-time in us
    -- 0            7
    -- 1            16
    -- Hi-Z         24
    -- 330k to GND  32
    toff            : out   std_logic;
    toff_330k_gnd   : out   std_logic;

    -- decay pin        decay mode
    --  0           Slow decay (brake or high-side re-circulation)
    --  1           Smart tune dynamic decay
    -- Hi-Z         Mixed decay: 30% fast
    decay           : out   std_logic;

    -- When the OCPM pin is logic low, the device has latch-off type recovery - which means once the OCP
    -- condition is removed, normal operation resumes after applying an nSLEEP reset pulse or a power cycling.
    --
    -- When the OCPM pin is logic high, normal operation resumes automatically (driver operation and nFAULT
    -- released) after the tRETRY time has elapsed and the fault condition is removed.
    ocpm            : out   std_logic;

    -- turn all outputs off
    sleep_n         : out   std_logic;

    -- Single H-Bridge Mode (MODE1 = 1), or Dual H-Bridge Mode (MODE1 = 0)
    -- The MODE2 pin has to be grounded to select PH/EN interface.
    -- To select PWM interface, keep MODE2 pin floating or connect the MODE2 pin to DVDD.
    mode            : out   std_logic_vector(2 downto 1);
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
    h_inp           : out   std_logic_vector(4 downto 1);

    busy            : out   std_logic_vector(2 downto 1);

    light_sw        : in    std_logic_vector(4 downto 1);

    control_ocpl    : in    std_logic_vector(2 downto 1);
    control_afbr    : in    std_logic_vector(2 downto 1) );
end hbr_gen;

architecture a of hbr_gen is

component filt_long is
generic (N     : Positive := 3);
port(
     clk        : in  std_logic;
     d          : in  std_logic; -- input
     inv_q      : in  std_logic; -- invert (1) or not (0) the input
     ena_edge   : in  std_logic; -- enable edge detection
     pos_edge   : out std_logic; -- rising edge of the output
     neg_edge   : out std_logic; -- falling edge of the output
     q          : out std_logic);-- filtered (eventually inverted) output
end component;

component hbr_dec_cnf is
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
--    pwm_man_power   : out   std_logic_vector(PWM_BITS-1  downto 0);

    -- on/off (the 4 IN outputs to H-bridge) in bits 3..0, the next state in bits 7..4
    -- the duration in bits 23..8 in PWM periods
    h_man_outp_1    : out   std_logic_vector(TABLE_WIDTH-1 downto 0);
    h_man_outp_2    : out   std_logic_vector(TABLE_WIDTH-1 downto 0);
    h_single        : out   std_logic_vector( 2 downto 1);

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
end component;

component pwm_gen is
--generic(Na_RAM : Integer := 10);
port(
    clk         : in  std_logic;
    reset       : in  std_logic;

    -- 7..0 for higherst ... lowest frequency
    freq_code   : in  std_logic_vector(2 downto 0);
    pwm_tick    : out std_logic;

    pwr_code    : in  std_logic_vector(PWM_BITS-1 downto 0);

    pwr_on      : out std_logic);
end component;

component dpram_2rd is
generic (Na     : Positive := 4;
         Nd     : positive := 8;
       async_rd : Boolean := false);
port(
    clk_A   : in  std_logic;
    weA     : in  std_logic;
    addrA   : in  std_logic_vector(Na-1 downto 0);
    dinA    : in  std_logic_vector(Nd-1 downto 0);
    doutA   : out std_logic_vector(Nd-1 downto 0);

    clk_B   : in  std_logic;
    addrB   : in  std_logic_vector(Na-1 downto 0);
    doutB   : out std_logic_vector(Nd-1 downto 0) );
end component;

component hbr_sm is
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
    h_inp           : out std_logic_vector(2 downto 1) );
end component;

component LED is
generic (
    RISING_ENABLED   : Boolean := true;
    FALLING_ENABLED  : Boolean := true;
    invert_in   : Boolean := false;
    invert_out  : Boolean := false);
Port (
    CLK         : in  std_logic;
    Tick        : in  std_logic;   -- about 50 Hz
    -- Sig
    I           : in  std_logic;
    O           : out std_logic);
end component;

signal we_ram           : std_logic_vector( 1 downto 0);
signal drd_ram_0        : std_logic_vector(TABLE_WIDTH-1 downto 0);
signal drd_ram_1        : std_logic_vector(TABLE_WIDTH-1 downto 0);


signal hbr_config       : hbr_conf_type;

signal ocpl_pos_edge    : std_logic_vector(2 downto 1);
signal ocpl_neg_edge    : std_logic_vector(2 downto 1);
signal ocpl_filt        : std_logic_vector(2 downto 1);

signal afbr_pos_edge    : std_logic_vector(2 downto 1);
signal afbr_neg_edge    : std_logic_vector(2 downto 1);
signal afbr_filt        : std_logic_vector(2 downto 1);

signal ctrl_filt        : std_logic_vector(2 downto 1);
signal ctrl_on          : std_logic_vector(2 downto 1);
signal ctrl_off         : std_logic_vector(2 downto 1);

signal status           : std_logic_vector(31 downto 0);

signal start_on         : std_logic_vector( 2 downto 1);
signal start_off        : std_logic_vector( 2 downto 1);

--signal pwm_man_power    : std_logic_vector(PWM_BITS-1  downto 0);

    -- on/off (the 4 IN outputs to H-bridge) in bits 3..0, the next state in bits 7..4
    -- the duration in bits 23..8 in PWM periods
signal h_man_outp_1     : std_logic_vector(TABLE_WIDTH-1 downto 0);
signal h_man_outp_2     : std_logic_vector(TABLE_WIDTH-1 downto 0);

    -- divide system clock 48*2^10 by 4096, 2048, 1024, 512, 256 (128, 64?) to get 12, 24, 48, 96, 192 kHz (384, 768 ?)
    -- put here the log2, 12, 11, 10, 9, 8, used globally for manual and sequence mode of operation
    -- 4-bits
signal pwm_freq_div     : std_logic_vector( 2 downto 0);

signal sm_ramd_1        : std_logic_vector(TABLE_WIDTH-1 downto 0);
signal sm_ramd_2        : std_logic_vector(TABLE_WIDTH-1 downto 0);
signal sm_addr_1        : std_logic_vector(Na_RAM-1 downto 0);
signal sm_addr_2        : std_logic_vector(Na_RAM-1 downto 0);

signal seq_ad_beg_on_1  : std_logic_vector(Na_RAM-1 downto 0);
signal seq_ad_len_on_1  : std_logic_vector(Na_RAM-1 downto 0);

signal seq_ad_beg_on_2  : std_logic_vector(Na_RAM-1 downto 0);
signal seq_ad_len_on_2  : std_logic_vector(Na_RAM-1 downto 0);

signal seq_ad_beg_off_1 : std_logic_vector(Na_RAM-1 downto 0);
signal seq_ad_len_off_1 : std_logic_vector(Na_RAM-1 downto 0);

signal seq_ad_beg_off_2 : std_logic_vector(Na_RAM-1 downto 0);
signal seq_ad_len_off_2 : std_logic_vector(Na_RAM-1 downto 0);

signal pwm_tick         : std_logic_vector(2 downto 1);
signal h_single         : std_logic_vector(2 downto 1);

signal pwr_code_1       : std_logic_vector(PWM_BITS-1 downto 0);
signal pwr_code_2       : std_logic_vector(PWM_BITS-1 downto 0);

signal pwm_pwr_on       : std_logic_vector(2 downto 1);
signal pwm_reset        : std_logic_vector(2 downto 1);
signal sm_reset         : std_logic_vector(2 downto 1);
signal busy_i           : std_logic_vector(2 downto 1);

--signal h_slow_decay     : std_logic_vector(2 downto 1);    -- when off, short the coil instead of Hi-Z

begin

    busy <= busy_i;

ctrl_filt_i: for i in 1 to 2 generate

filt_afbr_i: filt_long
generic map(N => NFILT)
port map(
     clk        => clk,
     d          => control_afbr(i),
     inv_q      => hbr_config(HBR_BIT_INV_AFBR + i - 1),
     ena_edge   => hbr_config(HBR_BIT_ENA_AFBR + i - 1),
     pos_edge   => afbr_pos_edge(i),
     neg_edge   => afbr_neg_edge(i),
     q          => afbr_filt(i) );

filt_ocpl_i: filt_long
generic map(N => NFILT)
port map(
     clk        => clk,
     d          => control_ocpl(i),
     inv_q      => hbr_config(HBR_BIT_INV_OPCPL + i - 1),
     ena_edge   => hbr_config(HBR_BIT_ENA_OPCPL + i - 1),
     pos_edge   => ocpl_pos_edge(i),
     neg_edge   => ocpl_neg_edge(i),
     q          => ocpl_filt(i) );

     ctrl_filt(i) <= (afbr_filt(i) and hbr_config(HBR_BIT_ENA_AFBR  + i - 1) ) or
                     (ocpl_filt(i) and hbr_config(HBR_BIT_ENA_OPCPL + i - 1) );

     ctrl_on( i)  <= afbr_pos_edge(i) or ocpl_pos_edge(i) or start_on( i);
     ctrl_off(i)  <= afbr_neg_edge(i) or ocpl_neg_edge(i) or start_off(i);

end generate;

    process(all)
    begin
        status <= (others => '0');
        status(           0) <= fault_n;
        status( 3 downto  2) <= busy_i;
        status( 7 downto  4) <= conv_std_logic_vector(Na_RAM, 4);
        status( 9 downto  8) <= ctrl_filt;
        status(19 downto 16) <= light_sw;
    end process;

    h_debug <= h_single & pwm_pwr_on & ctrl_on & ctrl_off;


hbr_cnf_i: hbr_dec_cnf
generic map(Na_RAM => Na_RAM)
port map(
     -- clock
    clk             => clk,
    reset           => reset,

    -- to the bus
    we              => we,
    -- Addr(MSB..MSB-1)
    --      0, 1        config
    --      2           RAM with sequence0
    --      3           RAM with sequence1
    addr            => addr,
    din             => din,
    dout            => dout,

    we_ram          => we_ram,
    drd_ram_0       => drd_ram_0,
    drd_ram_1       => drd_ram_1,


    hbr_config      => hbr_config,

    -- 8-bit power, how long to be ON in the period above, will be shifted left by 4..0 depending on FREQ_DIV
    -- used only in manual mode of operation!
--    pwm_man_power   => pwm_man_power,

    -- on/off (the 4 IN outputs to H-bridge) in bits 3..0, the next state in bits 7..4
    -- the duration in bits 23..8 in PWM periods
    h_man_outp_1    => h_man_outp_1,
    h_man_outp_2    => h_man_outp_2,
    h_single        => h_single,

    -- divide system clock 48*2^10 kHz by 4096, 2048, 1024, 512, 256 (128, 64?) to get 12, 24, 48, 96, 192 kHz (384, 768 ?)
    -- put here the log2, 12, 11, 10, 9, 8, used globally for manual and sequence mode of operation
    -- 3-bits
    pwm_freq_div    => pwm_freq_div,

    -- address range - where to read the sequence from the RAMs
    -- start address in 31..16 and number of PWM periods in 15..0
    seq_ad_beg_on_1 => seq_ad_beg_on_1,
    seq_ad_len_on_1 => seq_ad_len_on_1,

    seq_ad_beg_on_2 => seq_ad_beg_on_2,
    seq_ad_len_on_2 => seq_ad_len_on_2,

    seq_ad_beg_off_1=> seq_ad_beg_off_1,
    seq_ad_len_off_1=> seq_ad_len_off_1,

    seq_ad_beg_off_2=> seq_ad_beg_off_2,
    seq_ad_len_off_2=> seq_ad_len_off_2,

    status          => status,

    sm_reset        => sm_reset,
    start_on        => start_on,
    start_off       => start_off);


pwm_gen1_i: pwm_gen
port map(
     -- clock
    clk         => clk,
    reset       => pwm_reset(1),

    -- 7..0 for higherst ... lowest frequency
    freq_code   => pwm_freq_div,
    pwm_tick    => pwm_tick(1),

    pwr_code    => pwr_code_1,

    pwr_on      => pwm_pwr_on(1));

pwm_gen2_i: pwm_gen
port map(
     -- clock
    clk         => clk,
    reset       => pwm_reset(2),

    -- 7..0 for higherst ... lowest frequency
    freq_code   => pwm_freq_div,
    pwm_tick    => pwm_tick(2),

    pwr_code    => pwr_code_2,

    pwr_on      => pwm_pwr_on(2));

table1_i: dpram_2rd
generic map(Na => Na_RAM,
            Nd => TABLE_WIDTH,
           async_rd => false)
port map(
    clk_A   => clk,
    weA     => we_ram(0),
    addrA   => addr(Na_RAM-1 downto 0),
    dinA    => din(TABLE_WIDTH-1 downto 0),
    doutA   => drd_ram_0,

    clk_B   => clk,
    addrB   => sm_addr_1,
    doutB   => sm_ramd_1);

table2_i: dpram_2rd
generic map(Na => Na_RAM,
            Nd => TABLE_WIDTH,
           async_rd => false)
port map(
    clk_A   => clk,
    weA     => we_ram(1),
    addrA   => addr(Na_RAM-1 downto 0),
    dinA    => din(TABLE_WIDTH-1 downto 0),
    doutA   => drd_ram_1,

    clk_B   => clk,
    addrB   => sm_addr_2,
    doutB   => sm_ramd_2);


sm_1_i: hbr_sm
generic map(Na_RAM => Na_RAM)
port map(
     -- clock
    clk             => clk,
    reset           => sm_reset(1),

    -- to PWM
    pwr_code        => pwr_code_1,
    -- from PWM
    pwm_tick        => pwm_tick(1),
    pwm_reset       => pwm_reset(1),
    pwr_on          => pwm_pwr_on(1),

    -- from config
    h_mode2         => hbr_config(HBR_BIT_MODE+1),
    h_slow_decay    => hbr_config(HBR_BIT_SL_DEC_SM),
    -- on/off (the 4 IN outputs to H-bridge) in bits 3..0, the next state in bits 7..4
    -- the duration in bits 23..8 in PWM periods
    h_man_outp      => h_man_outp_1,
    -- start single shot
    h_single        => h_single(1),

    -- start sequences, can not be simultaneously activ
    ctrl_on         => ctrl_on(1),
    ctrl_off        => ctrl_off(1),

    -- from the config
    -- address range - where to read the sequence from the RAMs
    -- start address in 31..16 and number of PWM periods in 15..0
    seq_ad_beg_on   => seq_ad_beg_on_1,
    seq_ad_len_on   => seq_ad_len_on_1,

    seq_ad_beg_off  => seq_ad_beg_off_1,
    seq_ad_len_off  => seq_ad_len_off_1,

    remain_in_last  => hbr_config(HBR_BIT_REM_LAST),

    -- to/from the RAMs
    sm_addr         => sm_addr_1,
    sm_ramd         => sm_ramd_1,

    busy            => busy_i(1),
    h_inp           => h_inp(2 downto 1) );

sm_2_i: hbr_sm
generic map(Na_RAM => Na_RAM)
port map(
     -- clock
    clk             => clk,
    reset           => sm_reset(2),

    -- to PWM
    pwr_code        => pwr_code_2,
    -- from PWM
    pwm_tick        => pwm_tick(2),
    pwm_reset       => pwm_reset(2),
    pwr_on          => pwm_pwr_on(2),

    -- from config
    h_mode2         => hbr_config(HBR_BIT_MODE+1),
    h_slow_decay    => hbr_config(HBR_BIT_SL_DEC_SM+1),
    -- on/off (the 4 IN outputs to H-bridge) in bits 3..0, the next state in bits 7..4
    -- the duration in bits 23..8 in PWM periods
    h_man_outp      => h_man_outp_2,
    -- start single shot
    h_single        => h_single(2),

    -- start sequences, can not be simultaneously activ
    ctrl_on         => ctrl_on(2),
    ctrl_off        => ctrl_off(2),

    -- from the config
    -- address range - where to read the sequence from the RAMs
    -- start address in 31..16 and number of PWM periods in 15..0
    seq_ad_beg_on   => seq_ad_beg_on_2,
    seq_ad_len_on   => seq_ad_len_on_2,

    seq_ad_beg_off  => seq_ad_beg_off_2,
    seq_ad_len_off  => seq_ad_len_off_2,

    remain_in_last  => hbr_config(HBR_BIT_REM_LAST + 1),

    -- to/from the RAMs
    sm_addr         => sm_addr_2,
    sm_ramd         => sm_ramd_2,

    busy            => busy_i(2),
    h_inp           => h_inp(4 downto 3) );

-- connect the outputs
    process(hbr_config)
    begin
    -- Operation Modi (s. datasheet for details)
    -- TOFF - 0, 1, open, 330k to GND
    -- TOFF pin     off-time in us
    -- 0            7
    -- 1            16
    -- Hi-Z         24
    -- 330k to GND  32
        toff <= 'Z';
        toff_330k_gnd <= 'Z';
        case hbr_config(HBR_BIT_TOFF+1 downto HBR_BIT_TOFF) is
        when "00" =>
            toff <= '0';
            toff_330k_gnd <= '0';
        when "01" =>
            toff <= '1';
            toff_330k_gnd <= '1';
        when "10" =>
            toff <= 'Z';
            toff_330k_gnd <= '0';
        when "11" =>
            toff <= 'Z';
            toff_330k_gnd <= 'Z';
        when others =>
            NULL;
        end case;

    -- decay pin        decay mode
    --  0           Slow decay (brake or high-side re-circulation)
    --  1           Smart tune dynamic decay
    -- Hi-Z         Mixed decay: 30% fast
        case? hbr_config(HBR_BIT_DECAY+1 downto HBR_BIT_DECAY) is
            when "00" => decay <= '0';
            when "01" => decay <= '1';
            when "1-" => decay <= 'Z';
            when others => decay <= 'Z';
        end case?;
    end process;

    -- When the OCPM pin is logic low, the device has latch-off type recovery - which means once the OCP
    -- condition is removed, normal operation resumes after applying an nSLEEP reset pulse or a power cycling.
    --
    -- When the OCPM pin is logic high, normal operation resumes automatically (driver operation and nFAULT
    -- released) after the tRETRY time has elapsed and the fault condition is removed.
    ocpm <= hbr_config(HBR_BIT_OCPM);

    -- turn all outputs off
    sleep_n <= hbr_config(HBR_BIT_SLEEP_N);

    -- Single H-Bridge Mode (MODE1 = 1), or Dual H-Bridge Mode (MODE1 = 0)
    -- The MODE2 pin has to be grounded to select PH/EN interface.
    -- To select PWM interface, keep MODE2 pin floating or connect the MODE2 pin to DVDD.
    mode <= hbr_config(HBR_BIT_MODE+1 downto HBR_BIT_MODE);

end;
