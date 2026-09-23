-- $Id: top_1.vhd 1217 2026-09-03 13:17:29Z  $:

library ieee;
use ieee.std_logic_1164.all;

use work.DateTime_pkg.all;

entity top is
generic(
    Nleds           : Positive := 16;
    N_TSENS         : Integer range 1 to 4 :=  4 ;  -- number of 1-wire temeprature sensors
    N_ADC_CHIPS     : Integer range 1 to 3 :=  2);  -- number of ADC chips, from 1 to 4
port (
    -- clock input from oscillator, 24.576 MHz
    clk_x           : in    std_logic;
    -- neighbour pins to clk
    gnd_pin         : out   std_logic_vector(3 downto 0);
    -- active low reset - jumper or button
    reset_n         : in    std_logic;

    -- uart to the USB-UART chip
    uart_usb_rx     : in    std_logic;
    uart_usb_tx     : out   std_logic;
    -- uart via optical links (AFBR)
    uart_opt_rx     : in    std_logic;
    uart_opt_tx     : out   std_logic;

    h_debug         : out std_logic_vector(7 downto 0);
    -- DRV8262 dual H-bridge
    -- fault, active low, open-drain, with pull-up
    h_fault_n       : in    std_logic;

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

    -- shutter control via optocouplers or optical links (AFBR)
    control_ocpl    : in    std_logic_vector(2 downto 1);
    control_afbr    : in    std_logic_vector(2 downto 1);

    -- end position switches, use the JTAG and will be disabled when JTAGENB=1
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

    -- 1-wire temperature sensors, glued somewhere, two of them on the H-bridge
    dtemp           : inout std_logic_vector(N_TSENS-1 downto 0);

    -- LEDs with serial interface
    -- LED1 is the first in the chain, LED16 the last
    -- LED1 - show UART activity
    -- LED2 - LEMO inp J2
    -- LED3 - LEMO inp J3
    -- LED4 - AFBR inp U7
    -- LED5 - AFBR inp U9
    -- LED6 - AFBR out TX
    -- LED7 - AFBR inp RX

    -- LED8-11 - DB15 - temp. sensor, end switches?
    -- LED12-13 - H out   R22
    -- LED14-15 - H out   R37
    -- LED16 - power, alive?
    led_out         : out   std_logic);
end top;

architecture wrapper of top is

component top_cpu is
generic(
    Nleds           : Positive := 8;
    N_TSENS         : Integer range 1 to 4 :=  4 ;  -- number of 1-wire temeprature sensors
    N_ADC_CHIPS     : Integer range 1 to 3 :=  2;  -- number of ADC chips, from 1 to 4
    FCLK_SYS        : Integer := 40000000);
port (
    clk_sys         : in    std_logic;
    clk_ads         : in    std_logic;
    clk_ts          : in    std_logic;
    reset           : in    std_logic;

    -- uart to the USB-UART chip or uart via optical links (AFBR)
    uart_rx         : in    std_logic;
    uart_tx         : out   std_logic;

    h_debug         : out std_logic_vector(7 downto 0);
    -- DRV8262 dual H-bridge
    -- fault, active low, open-drain, with pull-up
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

    -- shutter control via optocouplers or optical links (AFBR)
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
    leds_softw      : out   std_logic_vector(  Nleds-1 downto 0);
    leds_blink      : out   std_logic_vector(  Nleds-1 downto 0) );
end component;

component uart_mix is
generic(
    Nint    : Integer := 2;
    Nfilt   : Integer := 3);
port(
    clk           : in  std_logic;
    reset         : in  std_logic;

    -- _dbg without inversion & filter & activity check to minimize the ressource usage,
    --      rx_dbg direct and-ed with the result of the mixing
    rx_dbg        : in  std_logic := '1';
    --      tx_dbg is just registered tx_core, tri-stated when inactive
    tx_dbg        : out std_logic;

    rx_pin        : in  std_logic_vector(Nint-1 downto 0);
    rx_inv        : in  std_logic_vector(Nint-1 downto 0);  -- static config, normally constants

    -- to/from the core logic, only once
    rx_core       : out std_logic;
    tx_core       : in  std_logic;
    tx_enable     : in  std_logic;  -- used to tri-state the TX outputs when inactive

    tx_pin        : out std_logic_vector(Nint-1 downto 0);   -- the TX pins, when inactive - tri-stated
    tx_inv        : in  std_logic_vector(Nint-1 downto 0);   -- static config, normally constants
    mask_act      : out std_logic_vector(Nint-1 downto 0) ); -- status
end component;

component pup_reset is
generic(inv_input   : Boolean := false);
port(
    clk           : in    std_logic;
    reset_pin     : in    std_logic;
    reset_out     : out   std_logic);
end component;

-- in the final version, with 24.576 MHz oscillator
component pll_24k_32k_48k_ts is
    port (
        CLKI    : in  std_logic;
        CLKOP   : out  std_logic;
        CLKOS   : out  std_logic;
        CLKOS2  : out  std_logic);
end component;

component top_leds is
generic(
    SYS_CLK         : Integer  := 49152000;
    N_TSENS         : Integer range 1 to 4 :=  4 ;  -- number of 1-wire temeprature sensors
    Nleds           : Positive := 16);
port (
    -- clock input from oscillator, 24.576 MHz
    clk             : in    std_logic;
    reset           : in    std_logic;

    -- uart to the USB-UART chip or uart via optical links (AFBR)
    uart_usb_rx     : in    std_logic;
    uart_usb_tx     : in    std_logic;

    uart_opt_rx     : in    std_logic;
    uart_opt_tx     : in    std_logic;

    uart_opt_act    : in    std_logic;

    -- DRV8262 dual H-bridge
    -- fault, active low, open-drain, with pull-up
    h_fault_n       : in    std_logic;

    -- turn all outputs off
    h_sleep_n       : in    std_logic;

    h_inp           : in    std_logic_vector(4 downto 1);

    -- shutter control via optocouplers or optical links (AFBR)
    control_ocpl    : in    std_logic_vector(2 downto 1);
    control_afbr    : in    std_logic_vector(2 downto 1);

    light_sw        : in    std_logic_vector(4 downto 1);


    dtemp           : in    std_logic_vector(N_TSENS-1 downto 0);

    -- LEDs
    leds_conf       : in    std_logic_vector(2*Nleds-1 downto 0);
    leds_softw      : in    std_logic_vector(  Nleds-1 downto 0);
    leds_blink      : in    std_logic_vector(  Nleds-1 downto 0);

    -- LEDs with serial interface
    -- LED1 is the first in the chain, LED16 the last
    -- LED1 - show USB UART activity
    -- LED2 - LEMO inp J2
    -- LED3 - LEMO inp J3
    -- LED4 - AFBR inp U7
    -- LED5 - AFBR inp U9
    -- LED6 - AFBR out TX
    -- LED7 - AFBR inp RX

    -- LED8-11 - DB15 - temp. sensor, end switches?
    -- LED12-13 - H out   R22
    -- LED14-15 - H out   R37
    -- LED16 - power, alive?
    led_out         : out   std_logic);
end component;
                                  -- Hz
constant QCLK       : Integer := 24576000;
constant ADS_CLK    : Integer := 32768000;
constant SYS_CLK    : Integer := 49152000;
constant TS_CLK     : Integer :=  1024000;
constant DBG_ADC    : Integer := 0;

signal clk_sys      : std_logic;
signal clk_ads      : std_logic;
signal clk_ts       : std_logic;
signal reset_sync   : std_logic;
signal uart_tx      : std_logic;
signal uart_rx      : std_logic;
signal leds_out_i   : std_logic;

signal uart_opt_act : std_logic;

signal leds_conf    : std_logic_vector(2*Nleds-1 downto 0);
signal leds_blink   : std_logic_vector(  Nleds-1 downto 0);
signal leds_softw   : std_logic_vector(  Nleds-1 downto 0);

begin

pll_i: pll_24k_32k_48k_ts
    port map(
        CLKI    => clk_x,    -- 24576000 Hz
        CLKOP   => clk_ads,  -- 32768000 Hz
        CLKOS   => clk_sys,  -- 49152000 Hz
        CLKOS2  => clk_ts);  --  1024000 Hz

reset_gen_i: pup_reset
generic map(
    inv_input   => true)  -- true for active low, false for active high
port map(
    clk         => clk_sys,
    reset_pin   => reset_n,
    reset_out   => reset_sync);

top_i: top_cpu
generic map(
    Nleds           => Nleds,
    N_TSENS         => N_TSENS,
    N_ADC_CHIPS     => N_ADC_CHIPS,
    FCLK_SYS        => SYS_CLK)
port map(
    clk_sys         => clk_sys,
    clk_ads         => clk_ads,
    clk_ts          => clk_ts,
    reset           => reset_sync,

    -- uart
    uart_rx         => uart_rx,
    uart_tx         => uart_tx,

--    h_debug         => h_debug,
    h_debug         => open,
    -- DRV8262 dual H-bridge
    -- fault, active low, open-drain, with pull-up
    h_fault_n     => h_fault_n,

    -- Operation Modi (s. datasheet for details)
    -- TOFF - 0, 1, open, 330k to GND
    -- TOFF pin     off-time in us
    -- 0            7
    -- 1            16
    -- Hi-Z         24
    -- 330k to GND  32
    h_toff          => h_toff,
    h_toff_330k_gnd => h_toff_330k_gnd,

    -- decay pin        decay mode
    --  0           Slow decay (brake or high-side re-circulation)
    --  1           Smart tune dynamic decay
    -- Hi-Z         Mixed decay: 30% fast
    h_decay         => h_decay,

    -- When the OCPM pin is logic low, the device has latch-off type recovery - which means once the OCP
    -- condition is removed, normal operation resumes after applying an nSLEEP reset pulse or a power cycling.
    --
    -- When the OCPM pin is logic high, normal operation resumes automatically (driver operation and nFAULT
    -- released) after the tRETRY time has elapsed and the fault condition is removed.
    h_ocpm          => h_ocpm,

    -- turn all outputs off
    h_sleep_n       => h_sleep_n,

    -- Single H-Bridge Mode (MODE1 = 1), or Dual H-Bridge Mode (MODE1 = 0)
    -- The MODE2 pin has to be grounded to select PH/EN interface.
    -- To select PWM interface, keep MODE2 pin floating or connect the MODE2 pin to DVDD.
    h_mode          => h_mode,
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

    -- shutter control via optocouplers or optical links (AFBR)
    control_ocpl    => control_ocpl,
    control_afbr    => control_afbr,

    light_sw        => light_sw,

    -- MCP47FEB22 dual 12-bit DAC
    dac_scl         => dac_scl,
    dac_sda         => dac_sda,

    -- ADS131M04 simultaneous sampling ADCs
    -- ADC master clock 8.192 MHz
    ads_mclk        => ads_mclk,
    -- sync/reset
    ads_sync_n      => ads_sync_n,
    -- data ready
    ads_drdy_n      => ads_drdy_n,
    -- ADC spi interface
    ads_cs_n        => ads_cs_n,
    ads_mosi        => ads_mosi,
    ads_sclk        => ads_sclk,
    ads_miso        => ads_miso,

    dtemp           => dtemp,

    -- LEDs
    leds            => leds_conf,
    leds_softw      => leds_softw,
    leds_blink      => leds_blink);

uart_mix_i: uart_mix
generic map(
    Nint    => 1,
    Nfilt   => 3)
port map(
    clk           => clk_sys,
    reset         => reset_sync,

    -- _dbg without inversion & filter & activity check to minimize the ressource usage,
    --      rx_dbg direct and-ed with the result of the mixing
    rx_dbg        => uart_usb_rx,
    --      tx_dbg is just registered tx_core, tri-stated when inactive
    tx_dbg        => uart_usb_tx,

    rx_pin(0)     => uart_opt_rx,
    rx_inv(0)     => '1',

    -- to/from the core logic, only once
    rx_core       => uart_rx,
    tx_core       => uart_tx,
    tx_enable     => '1',

    tx_pin(0)     => uart_opt_tx,
    tx_inv(0)     => '1',
    mask_act(0)   => uart_opt_act);

    gnd_pin <= (others => '0');

top_leds_i: top_leds
generic map(
    SYS_CLK         => SYS_CLK,
    N_TSENS         => N_TSENS,
    Nleds           => Nleds)
port map(
    -- clock input from oscillator, 24.576 MHz
    clk             => clk_sys,
    reset           => reset_sync,

    -- uart to the USB-UART chip or uart via optical links (AFBR)
    uart_usb_rx     => uart_usb_rx,
    uart_usb_tx     => uart_usb_tx,

    uart_opt_rx     => uart_opt_rx,
    uart_opt_tx     => uart_opt_tx,

    uart_opt_act    => uart_opt_act,

    -- DRV8262 dual H-bridge
    -- fault, active low, open-drain, with pull-up
    h_fault_n       => h_fault_n,

    -- turn all outputs off
    h_sleep_n       => h_sleep_n,

    h_inp           => h_inp,

    -- shutter control via optocouplers or optical links (AFBR)
    control_ocpl    => control_ocpl,
    control_afbr    => control_afbr,

    light_sw        => light_sw,


    dtemp           => dtemp,

    -- LEDs
    leds_conf       => leds_conf,
    leds_softw      => leds_softw,
    leds_blink      => leds_blink,

    -- LEDs with serial interface
    -- LED1 is the first in the chain, LED16 the last
    -- LED1 - show UART activity
    -- LED2 - LEMO inp J2
    -- LED3 - LEMO inp J3
    -- LED4 - AFBR inp U7
    -- LED5 - AFBR inp U9
    -- LED6 - AFBR out TX
    -- LED7 - AFBR inp RX

    -- LED8-11 - DB15 - temp. sensor, end switches?
    -- LED12-13 - H out   R22
    -- LED14-15 - H out   R37
    -- LED16 - power, alive?
    led_out         => leds_out_i);

    -- invert the output, as the level converter inverts!
    led_out <= not leds_out_i;

--    h_debug(0) <= dac_scl;
--    h_debug(1) <= dac_sda;

    h_debug(0) <= uart_rx;
    h_debug(1) <= uart_tx;
    h_debug(2) <= ads_sync_n;
    h_debug(3) <= ads_drdy_n(DBG_ADC);
    h_debug(4) <= ads_cs_n;
    h_debug(5) <= ads_sclk(DBG_ADC);
    h_debug(6) <= ads_mosi;
    h_debug(7) <= ads_miso(DBG_ADC);

end;
