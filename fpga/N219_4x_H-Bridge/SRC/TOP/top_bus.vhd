-- $Id: top_bus.vhd 1216 2026-09-02 16:57:27Z  $:

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

-- contains all periphery devices

use work.DateTime_pkg.all;
use work.config_pkg.all;

entity top_bus is
generic (
    N_TSENS         : Integer range 1 to 4 :=  4 ;  -- number of 1-wire temeprature sensors
    N_ADC_CHIPS     : Integer range 1 to 3 :=  2;  -- number of ADC chips, from 1 to 4
    FCLK_SYS        : Integer := 40000000;
    Nleds           : Positive := 8;
    -- bus parameters
    Nbits           : Positive := 32;  -- max 8..32
    Abits           : Natural  := 16); -- 0..31
port (
    clk_sys         : in  std_logic;
    clk_ads         : in  std_logic;
    clk_ts          : in  std_logic;
    reset           : in  std_logic;
    cpu_rst         : out std_logic;

    h_debug         : out std_logic_vector(7 downto 0);
    -- status inputs
    -- active low, open-drain, with pull-up
    h_fault_n     : in    std_logic;

    -- Operation Modi (s. datasheet for details)
    -- TOFF - 0, 1, open, 330k to GND
    -- TOFF pin     off-time in us
    -- 0            7
    -- 1            16
    -- Hi-Z         24
    -- 330k to GND  32
    h_toff          : out   std_logic;
    h_toff_330k_gnd : out   std_logic;

    -- decay pin        decay mode
    --  0           Slow decay (brake or high-side re-circulation)
    --  1           Smart tune dynamic decay
    -- Hi-Z         Mixed decay: 30% fast
    h_decay         : out   std_logic;

    -- When the OCPM pin is logic low, the device has latch-off type recovery - which means once the OCP
    -- condition is removed, normal operation resumes after applying an nSLEEP reset pulse or a power cycling.
    --
    -- When the OCPM pin is logic high, normal operation resumes automatically (driver operation and nFAULT
    -- released) after the tRETRY time has elapsed and the fault condition is removed.
    h_ocpm          : out   std_logic;

    -- turn all outputs off
    h_sleep_n       : out   std_logic;

    -- Single H-Bridge Mode (MODE1 = 1), or Dual H-Bridge Mode (MODE1 = 0)
    -- The MODE2 pin has to be grounded to select PH/EN interface.
    -- To select PWM interface, keep MODE2 pin floating or connect the MODE2 pin to DVDD.
    h_mode          : out   std_logic_vector(2 downto 1);
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

    control_ocpl    : in    std_logic_vector(2 downto 1);
    control_afbr    : in    std_logic_vector(2 downto 1);

    light_sw        : in    std_logic_vector(4 downto 1);

    -- MCP47FEB22 dual 12-bit DAC
    dac_scl         : out   std_logic;
    dac_sda         : inout std_logic;

    -- ADS131M04 simultaneous sampling ADCs
    -- ADC master clock 8.192 MHz
    ads_mclk        : out   std_logic;
    -- sync/reset
    ads_sync_n      : out   std_logic;
    -- data ready
    ads_drdy_n      : in    std_logic_vector(N_ADC_CHIPS-1 downto 0);
    -- ADC spi interface
    ads_cs_n        : out   std_logic;
    ads_mosi        : out   std_logic;
    ads_sclk        : out   std_logic_vector(N_ADC_CHIPS-1 downto 0);
    ads_miso        : in    std_logic_vector(N_ADC_CHIPS-1 downto 0);

    dtemp           : inout std_logic_vector(N_TSENS-1 downto 0);

    -- LEDs
    leds            : out   std_logic_vector(2*Nleds-1 downto 0);
    leds_blink      : out   std_logic_vector(  Nleds-1 downto 0);
    leds_softw      : out   std_logic_vector(  Nleds-1 downto 0);

    -- UART output from CPU
    uart_sel        : out   std_logic_vector( 1 downto 0);
    uart_tx_cpu     : out   std_logic;
    uart_tx_ena     : out   std_logic;

    -- from the configuration bus
    bus_we          : in    std_logic;
    bus_ena         : in    std_logic;
    ack             : out   std_logic;
    addr            : in    std_logic_vector(Abits-1 downto 0);
    wdata           : in    std_logic_vector(Nbits-1 downto 0);
    rdata           : out   std_logic_vector(Nbits-1 downto 0));
end top_bus;

architecture a of top_bus is

component ssram is
generic (Na     : Positive := 4;
         Nd     : positive := 8;
       async_rd : Boolean := true);
port(
    clk     : in  std_logic;
    we      : in  std_logic;
    addr    : in  std_logic_vector(Na-1 downto 0);
    din     : in  std_logic_vector(Nd-1 downto 0);
    dout    : out std_logic_vector(Nd-1 downto 0) );
end component;

component test_reg is
generic (
    Nbits       : Positive :=  8;  -- max 8..32
    Abits       : Natural  := 10); -- 0..31
port (
    clk         : in  std_logic;
    reset       : in  std_logic;

    we          : in  std_logic;
    rd          : in  std_logic;
    ack         : out std_logic;
    addr        : in  std_logic_vector(Abits-1 downto 0);
    wdata       : in  std_logic_vector(Nbits-1 downto 0);
    rdata       : out std_logic_vector(Nbits-1 downto 0));
end component;

component dec_mux is
generic (Na  : Positive := 16;
         Ndc : Integer range 16 to 32 := 16;
         Nd  : Positive := 32);
port(
    clk             : in  std_logic;
    -- to the bus master
    bus_we          : in  std_logic;
    bus_ena         : in  std_logic;

    bus_ack         : out std_logic;

    addr            : in  std_logic_vector(Na-1 downto 0);
    data_read       : out std_logic_vector(Nd-1 downto 0);

    -- to the bus devices
    -- to the EFB
    we_wb           : out std_logic;
    rd_wb           : out std_logic;
    bus_ack_wb      : in  std_logic;

    drd_wb          : in  std_logic_vector(   7 downto 0);

    -- common config
    we_conf         : out std_logic;
    drd_conf        : in  std_logic_vector(Ndc-1 downto 0);

    -- I2C master to the dual DAC
    we_i2c          : out std_logic;
    drd_i2c         : in  std_logic_vector(Nd-1 downto 0);

    -- two H-bridges in the same chip DRV8262
    we_hbr          : out std_logic;
    drd_hbr         : in  std_logic_vector(Nd-1 downto 0);

    -- ADS131M04 ADCs
    we_ads          : out std_logic;
    drd_ads         : in  std_logic_vector(Nd-1 downto 0);

    -- UART output port of the CPU
    we_tx_cpu       : out std_logic;
    drd_tx_cpu      : in  std_logic_vector(Nbits-1 downto 0);

    -- digital temperature sensor with 1-wire interface
    we_dtemp        : out std_logic;
    drd_dtemp       : in  std_logic_vector(Nd-1 downto 0);

    -- Pseudorandom generator to test the interface
    we_psrg_tst     : out std_logic;
    rd_psrg_tst     : out std_logic;
    bus_ack_psrg    : in  std_logic;
    drd_psrg_tst    : in  std_logic_vector(Nd-1 downto 0);

    -- Small Shared memory 512x32
    we_sh_small     : out std_logic;
    drd_sh_small    : in  std_logic_vector(Nd-1 downto 0) );

end component;

component config is
generic(
    Nbits   : Integer range 16 to 32 := 16;
    Nleds   : Integer range  0 to 16 :=  4;
    RegOut  : Boolean := false);
port(
    clk           : in    std_logic;
    reset         : in    std_logic;
    we            : in    std_logic;
    addr          : in    std_logic_vector( 4 downto 0);
    din           : in    std_logic_vector(Nbits-1 downto 0);
    dout          : out   std_logic_vector(Nbits-1 downto 0);

--    dbg_sel       : out   std_logic_vector( 2 downto 0);
    uart_sel      : out   std_logic_vector( 1 downto 0);
    soft_rst      : out   std_logic;
    cpu_rst       : out   std_logic;
    leds_softw    : out std_logic_vector(  Nleds-1 downto 0);
    leds_blink    : out std_logic_vector(  Nleds-1 downto 1);
    leds          : out std_logic_vector(2*Nleds-1 downto 1) );
end component;

component wb_wrap_xo3d is
generic(
    DEV_DENSITY          : in String  := "9400L";  -- or 4300L
    EFB_WB_CLK_FREQ      : in String  := "32.0";
    UFM0_INIT_START_PAGE : in Integer := 3581;     -- 766 for 4300
    UFM1_INIT_START_PAGE : in Integer := 3581;     -- /
    UFM2_INIT_START_PAGE : in Integer := 1149;
    UFM3_INIT_START_PAGE : in Integer :=  190);
port(
    clk           : in    std_logic;
    rst           : in    std_logic;

    debug         : out   std_logic_vector(27 downto 0);

    we            : in    std_logic;
    rd_req        : in    std_logic;
    bus_ack       : out   std_logic;
    addr          : in    std_logic_vector( 6 downto 0);
    din           : in    std_logic_vector( 7 downto 0);
    dout          : out   std_logic_vector( 7 downto 0));
end component;

component hbr_gen is
generic(Na_RAM : Integer := 10);
port(
     -- clock
    clk         : in  std_logic;
    reset       : in  std_logic;

    h_debug     : out std_logic_vector(7 downto 0);

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
end component;

component uc2tx is
generic(
    USE_ACC     : boolean := false;
    -- decrement the accumulator after each clock
    ACC_DECR    : Positive := 125;
    -- size of the accumulator
    ACC_NBITS   : Positive := 10;
    Bittime  : Positive := 24; -- for normal transfer, by 48 MHz system clock 2 MBit/s
    BittimeF : Positive := 12; -- for faster transfer, must be smaller than Bittime!
    Ntx_fifo : Natural  :=  8; -- number of address bits in the tx FIFO
    LSBfirst : Boolean  := true);
port (
    csi_clk_sys     : in  std_logic;
    rsi_reset       : in  std_logic;
    -- CPU interface
    avs_mm_write    : in  std_logic;
    avs_mm_read     : in  std_logic;
    avs_mm_address  : in  std_logic_vector(2 downto 0);
    avs_mm_writedata: in  std_logic_vector(31 downto 0);
    avs_mm_readdata : out std_logic_vector(31 downto 0);
    -- serial interface
    coe_tx          : out std_logic;
    coe_busy        : out std_logic);
end component;


component i2c_top32 is
generic (
    waittime    : Positive := 400;
    timeoutmax  : Positive := 10;
    Nfil        : Positive := 3;
    DEL_READY   : Positive := 3);
port(
    clk     : in    std_logic;

    reset   : in    std_logic;

    we      : in    std_logic;
    addr    : in    std_logic_vector( 1 downto 0);
    CDin    : in    std_logic_vector(31 downto 0);
    CDout   : out   std_logic_vector(31 downto 0);


    scl     : out   std_logic;  -- 1 means Z, 0 means 0
    sda_i   : in    std_logic;
    sda_o   : out   std_logic); -- 1 means Z, 0 means 0
end component;


component ads131m04 is
generic (
         SignFlag   : Boolean  := true;
         FCLK_ADC   : Positive := 32768000;
         Ndata      : Positive := 24; -- ADC data bus width
         Nchips     : Integer range 1 to 4 :=  1;  -- number of ADC chips, from 1 to 4
         UNSORTED   : Boolean := false;
         Nchannels  : Integer              := 12); -- from 4*(Nchips-1)+1 to 4*Nchips
port (
    clk             : in  std_logic;
    clk_adc         : in  std_logic; -- 2 x ADC clock out (2 x 8.192 MHz)
    rst             : in  std_logic;

    -- config bus
    we              : in  std_logic;
    addr            : in  std_logic_vector( 4 downto 0);
    wdata           : in  std_logic_vector(31 downto 0);
    rdata           : out std_logic_vector(31 downto 0);

--    debug           : out std_logic_vector(7 downto 0);
    -- SPI status
    busy            : out std_logic;

    -- ADC output direct
    adc_data_valid  : out std_logic; -- 1 clock long, new ADC data present
    adc_data        : out std_logic_vector(Nchannels*Ndata-1 downto 0); -- new ADC data

    -- ADC signals
    cs_n            : out std_logic;
    -- ADC master clock
    mclk            : out std_logic;
    sync_n          : out std_logic;
    -- ADC spi interface
    mosi            : out std_logic;
    sclk            : out std_logic_vector(Nchips-1 downto 0);
    miso            : in  std_logic_vector(Nchips-1 downto 0);
    drdy_n          : in  std_logic_vector(Nchips-1 downto 0));
end component;

component ds_top is
generic (
    short_prog : boolean := true;
    RegOut  : Boolean := false;
    Ndata   : Integer range 12 to 32  :=  32;  -- number of bits in the data interface, min 12!
    Nsens   : Integer range 1 to 8    :=   5;  -- number of sensors
    Nrst0   : Integer range 0 to 1023 := 512;  -- us, pull down time
    Nrsts   : Integer range 0 to  255 := 100;  -- us, sample time
    Nrst1   : Integer range 0 to 1023 := 512;  -- us, high Z time
    Nwr0    : Integer range 0 to  127 :=  80;  -- us, pull down time
    Nwr1    : Integer range 0 to   15 :=   8;  -- us, pull down time
    Nrd     : Integer range 0 to    3 :=   2;  -- us, pull down time
    Ntts    : Integer range 0 to  127 :=  90;  -- us, total time for a time slot read/write
    Nrds    : Integer range 0 to   15 :=   8); -- us, sample time for read
port (
    clk_sys : in    std_logic;
    clk_1MHz: in    std_logic;
    rst     : in    std_logic;
    alarm   : out   std_logic;
    pres_flag : out std_logic_vector(Nsens-1 downto 0);
    -- to the I/O cell
    oe      : out   std_logic;
    dout    : out   std_logic;
    din     : in    std_logic_vector(Nsens-1 downto 0);

    rd_id0  : out   std_logic_vector(63 downto 0);
    rd_id1  : out   std_logic_vector(63 downto 0);
    -- read port for the read bytes, 0..8
    we      : in    std_logic;
    addr    : in    std_logic_vector( 3 downto 0);
    CDin    : in    std_logic_vector(Ndata-1 downto 0);
    CDout   : out   std_logic_vector(Ndata-1 downto 0)
    );
end component;

constant I2C_SCL_FREQ   : Integer := 110000;
constant WAITT_I2C  : Integer := FCLK_SYS/(3*I2C_SCL_FREQ); -- 3 clocks/I2C clock period, SCL frequency = 400kHz

constant Nram_a : Integer :=  9;
constant Nb_cnf : Integer := 32;

-- whishbone bus to the EFB (flash etc.)
signal we_wb            : std_logic;
signal rd_wb            : std_logic;
signal bus_ack_wb       : std_logic;
signal drd_wb           : std_logic_vector(   7 downto 0);


-- I2C master
signal we_i2c           : std_logic;
signal drd_i2c          : std_logic_vector(Nbits-1 downto 0);

-- H-bridge controller
signal we_hbr           : std_logic;
signal drd_hbr          : std_logic_vector(Nbits-1 downto 0);

-- 2x ADS131M04 quad simultaneous sampling ADCs
signal we_ads           : std_logic;
signal drd_ads          : std_logic_vector(Nbits-1 downto 0);

    -- common config
signal we_conf          : std_logic;
signal drd_conf         : std_logic_vector(Nb_cnf-1 downto 0);

signal we_tx_cpu        : std_logic;
signal drd_tx_cpu       : std_logic_vector(Nbits-1 downto 0);

    -- digital temperature sensor with 1-wire interface
signal we_dtemp         : std_logic;
signal drd_dtemp        : std_logic_vector(Nbits-1 downto 0);
signal dtemp_oe         : std_logic;
signal dtemp_dout       : std_logic;
signal dtemp_din        : std_logic_vector(dtemp'length-1 downto 0);


    -- pseudorandom test port
signal we_psrg_tst      : std_logic;
signal rd_psrg_tst      : std_logic;
signal drd_psrg_tst     : std_logic_vector(Nbits-1 downto 0);
signal bus_ack_psrg     : std_logic;

    -- Shared memory
signal we_sh_small      : std_logic;
signal drd_sh_small     : std_logic_vector(Nbits-1 downto 0);

signal soft_rst         : std_logic;
signal sda_o, sda_i, scl: std_logic;

constant Bittime        : Natural := (FCLK_SYS + UART_BaudRate/2)/UART_BaudRate;
constant ACC_DECR       : Natural := ( (2**ACC_NBITS)*UART_BaudRate + FCLK_SYS/2 ) / FCLK_SYS;

begin

ssram_i: ssram
generic map(
    Na     => Nram_a,
    Nd     => Nbits,
    async_rd => (Nram_a < 7) ) -- force small memories to be implemented as LUT memories
port map(
    clk     => clk_sys,
    we      => we_sh_small,
    addr    => addr(Nram_a-1 downto 0),
    din     => wdata,
    dout    => drd_sh_small);

-- Test register with pseudorandom generator, to test the interface
psrg_tst_i: test_reg
generic map(
    Nbits       => 32,
    Abits       => 13)
port map(
    clk         => clk_sys,
    reset       => soft_rst,

    we          => we_psrg_tst,
    rd          => rd_psrg_tst,
    ack         => bus_ack_psrg,
    addr        => addr(12 downto 0),
    wdata       => wdata,
    rdata       => drd_psrg_tst);

-- general config
config_i: config
generic map(
    Nbits   => Nb_cnf,
    Nleds   => Nleds,
    RegOut  => false)
port map(
    clk             => clk_sys,
    reset           => reset,
    we              => we_conf,
    addr            => addr(4 downto 0),
    din             => wdata(Nb_cnf-1 downto 0),
    dout            => drd_conf,

--    dbg_sel         => open,
    uart_sel        => uart_sel,
    soft_rst        => soft_rst,
    cpu_rst         => cpu_rst,
    leds_softw      => leds_softw,
    leds_blink      => leds_blink,
    leds            => leds );

flash_cfg: wb_wrap_xo3d
generic map(
    EFB_WB_CLK_FREQ => "40.0")
--    UFM0_INIT_START_PAGE => 766, -- or use the default for 9400 device
--    UFM1_INIT_START_PAGE => 766, --  /
--    DEV_DENSITY     => FPGA_SIZE) -- /
port map(
    clk           => clk_sys,
    rst           => reset,

    debug         => open,

    we            => we_wb,
    rd_req        => rd_wb,
    bus_ack       => bus_ack_wb,
    addr          => addr( 6 downto 0),
    din           => wdata(7 downto 0),
    dout          => drd_wb);

-- decoder/multiplexer for all I/O modules
dec_mux_i: dec_mux
generic map(
    Na  => Abits,
    Ndc => Nb_cnf,
    Nd  => Nbits)
port map(
    clk             => clk_sys,
    -- to the bus master
    bus_we          => bus_we,
    bus_ena         => bus_ena,

    bus_ack         => ack,

    addr            => addr,
    data_read       => rdata,

    -- to the bus devices
    we_wb           => we_wb,
    rd_wb           => rd_wb,
    bus_ack_wb      => bus_ack_wb,

    drd_wb          => drd_wb,

    -- common config
    we_conf         => we_conf,
    drd_conf        => drd_conf,

    -- I2C master
    we_i2c          => we_i2c,
    drd_i2c         => drd_i2c,

    -- dual H-bridge
    we_hbr          => we_hbr,
    drd_hbr         => drd_hbr,

    -- ADS131M04 ADCs
    we_ads          => we_ads,
    drd_ads         => drd_ads,

    -- UART TX
    we_tx_cpu       => we_tx_cpu,
    drd_tx_cpu      => drd_tx_cpu,

    -- digital temperature sensor with 1-wire interface
    we_dtemp        => we_dtemp,
    drd_dtemp       => drd_dtemp,

    -- PSRG test
    we_psrg_tst     => we_psrg_tst,
    rd_psrg_tst     => rd_psrg_tst,
    bus_ack_psrg    => bus_ack_psrg,
    drd_psrg_tst    => drd_psrg_tst,

    -- Small LUT based Shared memory
    we_sh_small     => we_sh_small,
    drd_sh_small    => drd_sh_small);


i2c_i: i2c_top32
generic map(
    waittime    => WAITT_I2C)
--    timeoutmax  : Positive := 10;
--    Nfil        : Positive := 3;
--    DEL_READY   : Positive := 3);
port map(
    clk     => clk_sys,

    reset   => reset,

    we      => we_i2c,
    addr    => addr(1 downto 0),
    CDin    => wdata,
    CDout   => drd_i2c,

    scl     => scl,
    sda_i   => sda_i,
    sda_o   => sda_o );

    -- tri-stated and bidirectional i2c and 1-wire interface temp. sensor
    process(all)
    begin
        for i in dtemp'range loop
            if dtemp_oe='1' then dtemp(i) <= dtemp_dout; else dtemp(i) <= 'Z'; end if;
            dtemp_din(i) <= dtemp(i);
        end loop;
    end process;

--  dac_scl <= '0' when scl='0'   else 'Z';
    dac_scl <= scl; -- no other masters on the bus!
    dac_sda <= '0' when sda_o='0' else 'Z';
    sda_i   <= dac_sda;


ads131_i: ads131m04
generic map(
--         SignFlag   : Boolean  := true;
--         FCLK_ADC   : Positive := 32768000;
--         Ndata      : Positive := 24; -- ADC data bus width
         Nchips     => 2,
--         UNSORTED   : Boolean := false;
         Nchannels  => 8) -- important only for the parallel output, we don't use it now
port map(
    clk             => clk_sys,
    clk_adc         => clk_ads,
    rst             => reset,

    -- config bus
    we              => we_ads,
    addr            => addr( 4 downto 0),
    wdata           => wdata,
    rdata           => drd_ads,

--    debug           : out std_logic_vector(7 downto 0);
    -- SPI status
    busy            => open,

    -- ADC output direct - do not use here, only read per software
    adc_data_valid  => open,
    adc_data        => open,

    -- ADC signals
    cs_n            => ads_cs_n,
    -- ADC master clock
    mclk            => ads_mclk,
    sync_n          => ads_sync_n,
    -- ADC spi interface
    mosi            => ads_mosi,
    sclk            => ads_sclk,
    miso            => ads_miso,
    drdy_n          => ads_drdy_n);


tx_cpu_i: uc2tx
generic map(
    USE_ACC     => USE_ACC,
    -- decrement the accumulator after each clock
    ACC_DECR    => ACC_DECR,
    -- size of the accumulator
    ACC_NBITS   => ACC_NBITS,
    Bittime     => Bittime,
    BittimeF    => Bittime,
    Ntx_fifo    => 10)
--        LSBfirst : Boolean  := true);
port map(
    csi_clk_sys     => clk_sys,
    rsi_reset       => reset,
    -- CPU interface
    avs_mm_write    => we_tx_cpu,
    avs_mm_read     => '0',
    avs_mm_address  => addr(2 downto 0),
    avs_mm_writedata=> wdata,
    avs_mm_readdata => drd_tx_cpu,
    -- serial interface
    coe_tx          => uart_tx_cpu,
    coe_busy        => uart_tx_ena);

hbr_gen_i: hbr_gen
generic map(Na_RAM => NA_RAM_HBR_GEN )
port map(
     -- clock
    clk             => clk_sys,
    reset           => reset,

    h_debug         => h_debug,
    we              => we_hbr,
    -- Addr(MSB..MSB-1)
    --      0, 1        config
    --      2           RAM with sequence0
    --      3           RAM with sequence1
    addr            => addr(NA_RAM_HBR_GEN+1 downto 0),
    din             => wdata,
    dout            => drd_hbr,

    -- status inputs
    -- active low, open-drain, with pull-up
    fault_n         => h_fault_n,

    -- Operation Modi (s. datasheet for details)
    -- TOFF - 0, 1, open, 330k to GND
    -- TOFF pin     off-time in us
    -- 0            7
    -- 1            16
    -- Hi-Z         24
    -- 330k to GND  32
    toff            => h_toff,
    toff_330k_gnd   => h_toff_330k_gnd,

    -- decay pin        decay mode
    --  0           Slow decay (brake or high-side re-circulation)
    --  1           Smart tune dynamic decay
    -- Hi-Z         Mixed decay: 30% fast
    decay           => h_decay,

    -- When the OCPM pin is logic low, the device has latch-off type recovery - which means once the OCP
    -- condition is removed, normal operation resumes after applying an nSLEEP reset pulse or a power cycling.
    --
    -- When the OCPM pin is logic high, normal operation resumes automatically (driver operation and nFAULT
    -- released) after the tRETRY time has elapsed and the fault condition is removed.
    ocpm            => h_ocpm,

    -- turn all outputs off
    sleep_n         => h_sleep_n,

    -- Single H-Bridge Mode (MODE1 = 1), or Dual H-Bridge Mode (MODE1 = 0)
    -- The MODE2 pin has to be grounded to select PH/EN interface.
    -- To select PWM interface, keep MODE2 pin floating or connect the MODE2 pin to DVDD.
    mode            => h_mode,
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
    h_inp           => h_inp,

    busy            => open,

    light_sw        => light_sw,

    control_ocpl    => control_ocpl,
    control_afbr    => control_afbr);

-- 1-wire temperature sensors
ds_top_i: ds_top
generic map(
    short_prog => false,
    RegOut  => true,
    Ndata   => Nbits,
    Nsens   => dtemp'length)
--  Nrst0   : Integer range 0 to 1023 := 512;  -- us, pull down time
--  Nrsts   : Integer range 0 to  255 := 100;  -- us, sample time
--  Nrst1   : Integer range 0 to 1023 := 512;  -- us, high Z time
--  Nwr0    : Integer range 0 to  127 :=  80;  -- us, pull down time
--  Nwr1    : Integer range 0 to   15 :=   8;  -- us, pull down time
--  Nrd     : Integer range 0 to    3 :=   2;  -- us, pull down time
--  Ntts    : Integer range 0 to  127 :=  90;  -- us, total time for a time slot read/write
--  Nrds    : Integer range 0 to   15 :=   8); -- us, sample time for read
port map(
    clk_sys => clk_sys,
    clk_1MHz=> clk_ts,
    rst     => reset,
    alarm   => open,
    pres_flag => open,
    -- to the I/O cell
    oe      => dtemp_oe,
    dout    => dtemp_dout,
    din     => dtemp_din,
    rd_id0  => open,
    rd_id1  => open,
    -- read port for the read bytes, 0..8
    we      => we_dtemp,
    addr    => addr(3 downto 0),
    CDin    => wdata,
    CDout   => drd_dtemp);

end;
