-- $Id: top_cpu.vhd 1215 2026-08-28 14:13:16Z  $:
-- contains following components:
--  LM32 CPU
--  UART -> configuration bus master
--  Bus with all periphery devices
-- The user should add its own devices to the top_bus entity

library ieee;
use ieee.std_logic_1164.all;

use work.DateTime_pkg.all;

entity top_cpu is
generic(
    Nleds           : Positive := 8;
    N_TSENS         : Integer range 1 to 4 :=  4 ;  -- number of 1-wire temeprature sensors
    N_ADC_CHIPS     : Integer range 1 to 3 :=  2;  -- number of ADC chips, from 1 to 4
    FCLK_SYS        : Natural := 40000000);
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

    dtemp           : inout std_logic_vector( 3 downto 0);

    -- LEDs
    leds            : out   std_logic_vector(2*Nleds-1 downto 0);
    leds_softw      : out   std_logic_vector(  Nleds-1 downto 0);
    leds_blink      : out   std_logic_vector(  Nleds-1 downto 0) );
end top_cpu;

architecture rtl of top_cpu is

-- Component Declaration

------ INSERT CPU component declaration here ------
--------------------------------------------------------

-- Name     Base Address        Size (bytes)        End Address
-- IMEM     0x0000 0000         0x0 2000            0x0000 1FFF
-- DMEM     0x0000 8000         0x0 1000            0x0000 8FFF
-- SLAVE    0x8000 0000         0x4 0000            0x8003 FFFF (16-bit address x 32-bit data word) CPU is master
-- MASTER   0x0000 0000         unlimited           0xFFFF FFFF (32-bit address x  8-bit data word) EXT is master

-- Disabled Divider
-- Disabled Multiplier
-- Enabled Sign Extend
-- Enabled Pipelined Barrel Shifter
-- No caches!
-- DMEM as inline memory!
-- Disabled Debug Interface
-- Distributed RAM for register file

component lm32_xo2_vhd is
port(
    clk_i                               : in  std_logic;
    reset_n                             : in  std_logic;

-- master is the risc32 system
-- slave is the external system
-- address space is 0x80000000 to 0x8003FFFF, size is 0x00040000 (16-bit address x 32-bit data word)
-- in our bus system we use only 32-bit data and ignore the 2 LSBits of the address, so our address
-- space is 0..0xFFFF
    slave_passthruclk                   : out std_logic;
    slave_passthrurst                   : out std_logic;
    slave_passthruslv_adr               : out std_logic_vector(31 downto 0);
    slave_passthruslv_master_data       : out std_logic_vector(31 downto 0);
    slave_passthruslv_slave_data        : in  std_logic_vector(31 downto 0);
    slave_passthruslv_strb              : out std_logic;
    slave_passthruslv_cyc               : out std_logic;
    slave_passthruslv_ack               : in  std_logic;
    slave_passthruslv_err               : in  std_logic;
    slave_passthruslv_rty               : in  std_logic;
    slave_passthruslv_sel               : out std_logic_vector( 3 downto 0);
    slave_passthruslv_we                : out std_logic;
    slave_passthruslv_bte               : out std_logic_vector( 1 downto 0);
    slave_passthruslv_cti               : out std_logic_vector( 2 downto 0);
    slave_passthruslv_lock              : out std_logic;
    slave_passthruintr_active_high      : in  std_logic;

-- master is external
-- slave is the risc32 system
-- no restrictions for the address space?
    master_passthrumstr_adr             : in  std_logic_vector(31 downto 0);
    master_passthrumstr_data_to_slv     : in  std_logic_vector(31 downto 0);
-- 1 write, 0 read
    master_passthrumstr_we              : in  std_logic;
-- 1 for each data transferred
    master_passthrumstr_stb             : in  std_logic;
    master_passthrumstr_cyc             : in  std_logic;
    master_passthrumstr_lock            : in  std_logic;
-- 000 for classic wishbone
    master_passthrumstr_cti             : in  std_logic_vector( 2 downto 0);
-- byte select
    master_passthrumstr_sel             : in  std_logic_vector( 3 downto 0);
-- burst enable, 00 linear
    master_passthrumstr_bte             : in  std_logic_vector( 1 downto 0);
    master_passthruclk                  : out std_logic;
    master_passthrurst                  : out std_logic;
    master_passthrumstr_data_from_slv   : out std_logic_vector(31 downto 0);
-- acknoledge
    master_passthrumstr_ack_from_slv    : out std_logic;
-- retry
    master_passthrumstr_rty_from_slv    : out std_logic;
-- error
    master_passthrumstr_err_from_slv    : out std_logic
);
end component;


component uart_top is
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
    Bittime  : Positive := 10;
    BittimeF : Positive :=  5;
    USE_ID    : Boolean := false; -- the lower 4 bits of lmask should match exactly what comes from the interface?
    Naddr    : Positive := 24;  -- 16 or 24, no other values allowed
    Ndata    : Positive := 32;  -- 8, 16 or 32, no other values allowed!
    Nfifo    : Natural  :=  4;  -- bits in the FIFO address
    Nwdog    : Natural  := 24;  -- number of bits in watchdog timer - counts down and when 0 => inactive
    LSBfirst : Boolean := true;
    Nfilt    : Positive := 3);
port (
    clk          : in  std_logic;
    reset        : in  std_logic;

    fast_m       : in  std_logic := '0'; -- fast mode for direct UART interface
    lmask        : in  std_logic_vector(7 downto 0);

    -- direct command via only one byte
    -- for this the MSBit should be 1, bits 6..4 code one of the 8 commands
    -- the lower 4 bits of lmask AND-ed with the lower 4 bits of lmask should have a non-zero result

    short_code   : out std_logic_vector(2 downto 0);
    short_cmd    : out std_logic;

    -- serial interface
    rx           : in  std_logic;
    tx           : out std_logic;
    tx_enable    : out std_logic;

    -- bus interface
    bus_we       : out std_logic; -- - as along as ack comes
    bus_rd       : out std_logic; -- /
    bus_cyc      : out std_logic; -- / - for WB compatibility
    bus_ack      : in  std_logic; -- is '1' when the data are written/ready
    bus_rdata    : in  std_logic_vector(31 downto 0);
    bus_addr     : out std_logic_vector(23 downto 0);
    bus_wdata    : out std_logic_vector(31 downto 0);

    debug        : out std_logic_vector(     15 downto 0);

    -- status
    timeout      : out std_logic; -- master packet broken
    busy         : out std_logic);
end component;

component top_bus is
generic (
    Nleds           : Positive := 8;
    N_TSENS         : Integer range 1 to 4 :=  4 ;  -- number of 1-wire temeprature sensors
    N_ADC_CHIPS     : Integer range 1 to 3 :=  2;  -- number of ADC chips, from 1 to 4
    FCLK_SYS        : Integer := 40000000;
    -- bus parameters
    Nbits       : Positive := 32;  -- max 8..32
    Abits       : Natural  := 16); -- 0..31
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

    -- UART output from CPU
    uart_sel        : out   std_logic_vector( 1 downto 0);
    uart_tx_cpu     : out   std_logic;
    uart_tx_ena     : out   std_logic;

    -- LEDs
    leds            : out   std_logic_vector(2*Nleds-1 downto 0);
    leds_softw      : out   std_logic_vector(  Nleds-1 downto 0);
    leds_blink      : out   std_logic_vector(  Nleds-1 downto 0);

    bus_we          : in    std_logic;
    bus_ena         : in    std_logic;
    ack             : out   std_logic;
    addr            : in    std_logic_vector(Abits-1 downto 0);
    wdata           : in    std_logic_vector(Nbits-1 downto 0);
    rdata           : out   std_logic_vector(Nbits-1 downto 0));
end component;

component uart_switch is
port(
    clk         : in    std_logic;
    reset       : in    std_logic;

    uart_busy   : in    std_logic;                    -- don't switch anything while a packet is in any UART

    uart_sel    : in    std_logic_vector(1 downto 0);
    -- 1..0 : tx mux for the enabled tx ports
    --                0 - config data only
    --                1 - config & ADC data
    --                2 - ADC data only
    --                3 - echo

    tx_opt      : out   std_logic; -- output to the optical link
    tx_usb      : out   std_logic;

    -- link to the core logic
    rx_conf     : in    std_logic;
    tx_conf     : in    std_logic;
    tx_cpu      : in    std_logic);  -- from the CPU core, output stream only
end component;

-- Signal declaration
signal reset_n       : std_logic;

signal slave_passthruslv_adr             : std_logic_vector(31 downto 0)  ;
signal slave_passthruslv_master_data     : std_logic_vector(31 downto 0)  ;
signal slave_passthruslv_slave_data      : std_logic_vector(31 downto 0)  ;
signal slave_passthruslv_strb            : std_logic                      ;
signal slave_passthruslv_cyc             : std_logic                      ;
signal slave_passthruslv_ack             : std_logic                      ;
signal slave_passthruslv_we              : std_logic                      ;
signal slave_passthruintr_active_high    : std_logic                      ;

signal slave_passthruslv_selected        : std_logic                      ;

-- master is external
-- slave is the risc32 system
-- no restrictions for the address space?
signal master_passthrumstr_adr           : std_logic_vector(31 downto 0)  ;
signal master_passthrumstr_data_to_slv   : std_logic_vector(31 downto 0)  ;
signal master_passthrumstr_we            : std_logic                      ;
signal master_passthrumstr_cyc           : std_logic                      ;
signal master_passthrumstr_lock          : std_logic                      ;
signal master_passthrumstr_cti           : std_logic_vector( 2 downto 0)  ;
signal master_passthrumstr_sel           : std_logic_vector( 3 downto 0)  ;
signal master_passthrumstr_bte           : std_logic_vector( 1 downto 0)  ;
signal master_passthrumstr_data_from_slv : std_logic_vector(31 downto 0)  ;
signal master_passthrumstr_ack_from_slv  : std_logic                      ;

signal uart_bus_addr                     : std_logic_vector(23 downto 0)  ;
signal id_mask                           : std_logic_vector( 7 downto 0);

signal reset_cpu                         : std_logic;

signal uart_sel                          : std_logic_vector( 1 downto 0);
signal uart_tx_cpu                       : std_logic;
signal uart_tx_cnf                       : std_logic;
signal uart_busy                         : std_logic;

constant Bittime    : Natural := (FCLK_SYS + UART_BaudRate/2)/UART_BaudRate;
constant ACC_DECR   : Natural := ( (2**ACC_NBITS)*UART_BaudRate + FCLK_SYS/2 ) / FCLK_SYS;

--------------------------------------------------------
------ END of CPU component declaration      ------


begin
    reset_n <= not (reset or reset_cpu);
    -- bits 7..4 should be set for short commands - not used here - therefore 0
    id_mask <= x"01";


-- Component Instantiation


------ INSERT CPU component instantiation here ------
----------------------------------------------------------

-- 1111 for all bytes selected
    master_passthrumstr_sel <= (others => '1');
-- 000 for classic wishbone
    master_passthrumstr_cti <= (others => '0');
-- burst enable, 00 linear
    master_passthrumstr_bte <= (others => '0');

    slave_passthruintr_active_high <= '0';

    -- only the lower 16 bits of the dword address
    slave_passthruslv_selected <= slave_passthruslv_strb and slave_passthruslv_cyc when slave_passthruslv_adr(31 downto 18) = (x"800" & "00") else '0';

lm32_i: lm32_xo2_vhd
port map(
    clk_i                               => clk_sys,
    reset_n                             => reset_n,

-- master is the risc32 system
-- slave is the external system
-- address space is 0x80000000 to 0x8003FFFF, size is 0x00040000 (16-bit address x 32-bit data word)
    slave_passthruclk                   => open, -- slave_passthruclk,  -- same as input clock
    slave_passthrurst                   => open, -- slave_passthrurst,  -- a bit longer reset, active high
    slave_passthruslv_adr               => slave_passthruslv_adr,  -- 32 bit address, ignore the byte part (the two LSBits), the external bus will have 16 bits
    slave_passthruslv_master_data       => slave_passthruslv_master_data,
    slave_passthruslv_slave_data        => slave_passthruslv_slave_data,
    slave_passthruslv_strb              => slave_passthruslv_strb,
    slave_passthruslv_cyc               => slave_passthruslv_cyc,
    slave_passthruslv_ack               => slave_passthruslv_ack,
    slave_passthruslv_err               => '0', -- slave_passthruslv_err,
    slave_passthruslv_rty               => '0', -- slave_passthruslv_rty,
    slave_passthruslv_sel               => open,
    slave_passthruslv_we                => slave_passthruslv_we,
    slave_passthruslv_bte               => open, -- slave_passthruslv_bte,
    slave_passthruslv_cti               => open, -- slave_passthruslv_cti,
    slave_passthruslv_lock              => open, -- slave_passthruslv_lock,
    slave_passthruintr_active_high      => slave_passthruintr_active_high,

-- master is external
-- slave is the risc32 system
-- no restrictions for the address space?
    master_passthrumstr_adr             => master_passthrumstr_adr,
    master_passthrumstr_data_to_slv     => master_passthrumstr_data_to_slv,
-- 1 write, 0 read
    master_passthrumstr_we              => master_passthrumstr_we,
-- 1 for each data transferred
    master_passthrumstr_stb             => master_passthrumstr_cyc,
    master_passthrumstr_cyc             => master_passthrumstr_cyc,
    master_passthrumstr_lock            => master_passthrumstr_lock,
-- 000 for classic wishbone
    master_passthrumstr_cti             => master_passthrumstr_cti,
-- byte select
    master_passthrumstr_sel             => master_passthrumstr_sel,
-- burst enable, 00 linear
    master_passthrumstr_bte             => master_passthrumstr_bte,
    master_passthruclk                  => open,
    master_passthrurst                  => open,
    master_passthrumstr_data_from_slv   => master_passthrumstr_data_from_slv,
-- acknoledge
    master_passthrumstr_ack_from_slv    => master_passthrumstr_ack_from_slv,
-- retry
    master_passthrumstr_rty_from_slv    => open,
-- error
    master_passthrumstr_err_from_slv    => open);

----------------------------------------------------------
------ END of CPU component instantiation    --------

top_bus_i: top_bus
generic map(
    Nleds       => Nleds,
    N_TSENS     => N_TSENS,
    N_ADC_CHIPS => N_ADC_CHIPS,
    FCLK_SYS    => FCLK_SYS,
    Nbits       => 32,
    Abits       => 16)
port map(
    clk_sys         => clk_sys,
    clk_ads         => clk_ads,
    clk_ts          => clk_ts,
    reset           => reset,

    cpu_rst         => reset_cpu,

    h_debug         => h_debug,
    -- DRV8262 dual H-bridge
    -- fault, active low, open-drain, with pull-up
    h_fault_n       => h_fault_n,

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

    -- UART output from CPU
    uart_sel        => uart_sel,
    uart_tx_cpu     => uart_tx_cpu,
    uart_tx_ena     => open,

    -- LEDs
    leds            => leds,
    leds_softw      => leds_softw,
    leds_blink      => leds_blink,

    bus_we          => slave_passthruslv_we,
    bus_ena         => slave_passthruslv_selected,
    ack             => slave_passthruslv_ack,
    -- convert from byte address to 32-bit word address, ignore the two LSBits!
    addr            => slave_passthruslv_adr(17 downto 2),
    wdata           => slave_passthruslv_master_data,
    rdata           => slave_passthruslv_slave_data);

uart_i: uart_top
generic map(
        USE_ACC     => USE_ACC,
    -- decrement the accumulator after each clock
        ACC_DECR    => ACC_DECR,
    -- size of the accumulator
        ACC_NBITS   => ACC_NBITS,
    -- the numbers here correspond to 32.768 MHz clock and 4 Mbit/s baud rate:
    -- the desired divider ratio is 32.768/4 = 8.192
    -- 8.192*ACC_DECR=2**ACC_NBITS
    -- so the "ideal" Bittime is 2**ACC_NBITS/ACC_DECR = system_clock/baud_rate

        USE_ID   => false,  -- the lower 4 bits of lmask should match exactly what comes from the interface?

        Bittime  => Bittime,
        BittimeF => Bittime,
        Nfilt    =>  1, -- there is a filter on the top
        Nfifo    => 10, -- 1024 bytes FIFO
        Nwdog    => 26) -- problems with 24 and 25 if the PC is too slow!!! 25 means 2**25/48 MHz sec watch dog period (0.7s).
port map(
    clk          => clk_sys,
    reset        => reset,

    fast_m       => '0',
    lmask        => id_mask,

    -- short command from the rx UART connected to the master
    short_code   => open,
    short_cmd    => open,

    -- serial interface
    rx           => uart_rx,
    tx           => uart_tx_cnf,
    tx_enable    => open,

    bus_we       => master_passthrumstr_we,
    bus_rd       => open,
    bus_cyc      => master_passthrumstr_cyc,
    bus_ack      => master_passthrumstr_ack_from_slv,
    bus_rdata    => master_passthrumstr_data_from_slv,
    -- convert from 32-bit word address to byte address, the two LSBits are permanently connected to 0 below
    bus_addr     => uart_bus_addr,
    bus_wdata    => master_passthrumstr_data_to_slv,

    debug        => open,

    -- status
    timeout      => open,
    busy         => uart_busy);

uart_sw_i: uart_switch
port map(
    clk         => clk_sys,
    reset       => reset,

    uart_busy   => uart_busy,

    uart_sel    => uart_sel,
    -- 1..0 : tx mux for the enabled tx ports
    --                0 - config data only
    --                1 - config & ADC data
    --                2 - ADC data only
    --                3 - echo

    tx_opt      => uart_tx,
    tx_usb      => open,

    -- link to the core logic
    rx_conf     => uart_rx,
    tx_conf     => uart_tx_cnf,
    tx_cpu      => uart_tx_cpu);

    process(all)
    begin
        master_passthrumstr_adr <= (others => '0');
        -- the UART interface has 32-bit data bus and the address is of the dwords on the bus
        -- therefore the two LSBits to the CPU bus are 00
        master_passthrumstr_adr(24 downto 2) <= uart_bus_addr(22 downto 0);
        -- the UART interface has only 24 address bits, the MSBit (23) -> MSBit (31)
        master_passthrumstr_adr(31) <= uart_bus_addr(23);
    end process;
    master_passthrumstr_lock <= '0';

end;
