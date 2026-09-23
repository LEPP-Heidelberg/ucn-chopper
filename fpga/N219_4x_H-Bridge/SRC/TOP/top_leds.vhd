-- $Id: top_leds.vhd 1217 2026-09-03 13:17:29Z  $:

library ieee;
use ieee.std_logic_1164.all;

use work.DateTime_pkg.all;
use work.config_pkg.all;

entity top_leds is
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
    -- LED2 - LEMO inp J3
    -- LED3 - LEMO inp J2
    -- LED4 - AFBR inp U7
    -- LED5 - AFBR inp U9
    -- LED6 - AFBR out TX
    -- LED7 - AFBR inp RX

    -- LED8-11 - DB15 - temp. sensor, end switches?
    -- LED12-13 - H out   R22
    -- LED14-15 - H out   R37
    -- LED16 - power, alive?
    led_out         : out   std_logic);
end top_leds;

architecture a of top_leds is

component clk_div is
GENERIC (Nd : Integer := 50);
PORT(
        clk, en : IN  STD_LOGIC;
        div     : OUT STD_LOGIC);
end component;

component clock_div_ena is
generic (
    Ndiv        : Positive := 5);
port(
     -- clock
    clk         : in  std_logic;
    rst         : in  std_logic;
    ena         : in  std_logic := '1';
    q           : out std_logic);
end component;

component LED is
generic (
    RISING_ENABLED   : Boolean := true;
    FALLING_ENABLED  : Boolean := true;
    STATIC_ENABLED   : Boolean := true;
    invert_in   : Boolean := false;
    invert_out  : Boolean := false);
Port (
    CLK         : in  std_logic;
    Tick        : in  std_logic;
    -- Sig
    I           : in  std_logic;
    O           : out std_logic);
end component;


component we_leds_4_lev is
generic(
    SWAP_ORDER      : Boolean  := false;
    FCLK            : Positive := 40000000; -- Hz
    -- for 10 MHz clock:
    Nleds           : Positive :=   2);
port (
    clk             : in    std_logic;
    reset           : in    std_logic;
    blink           : in    std_logic;

    -- typically the codes below are constants, eventually programmable, but static
    -- code to be sent when intensity is 1
    code_1_g        : in    std_logic_vector(7 downto 0);
    code_1_r        : in    std_logic_vector(7 downto 0);
    code_1_b        : in    std_logic_vector(7 downto 0);

    -- code to be sent when intensity is 2
    code_2_g        : in    std_logic_vector(7 downto 0);
    code_2_r        : in    std_logic_vector(7 downto 0);
    code_2_b        : in    std_logic_vector(7 downto 0);

    -- code to be sent when intensity is 3
    code_3_g        : in    std_logic_vector(7 downto 0);
    code_3_r        : in    std_logic_vector(7 downto 0);
    code_3_b        : in    std_logic_vector(7 downto 0);

    -- 2 bits/LED: 0 - off, 1, 2, 3 - code_x_g|r|b
    leds_in         : in    std_logic_vector(2*Nleds-1 downto 0);
    -- blink flag, one bit/LED, 1 for blinking
    leds_blink      : in    std_logic_vector(Nleds-1 downto 0);
    -- to the chain of led-ics
    led_ic_in       : out   std_logic);
end component;

signal blink        : std_logic;
signal TickF        : std_logic;

signal leds_slive   : std_logic_vector(  Nleds-1 downto 0);
signal leds_live    : std_logic_vector(2*Nleds-1 downto 0);
signal leds_live_bl : std_logic_vector(  Nleds-1 downto 0);

signal leds_we      : std_logic_vector(2*Nleds-1 downto 0);
signal leds_we_bl   : std_logic_vector(  Nleds-1 downto 0);

begin
    process(clk)
    begin
        if rising_edge(clk) then
            for i in 0 to Nleds-1 loop
                if leds_softw(i)='1' then
                    leds_we(2*i+1 downto 2*i) <= leds_conf(2*i+1 downto 2*i);
                    leds_we_bl(i) <= leds_blink(i);
                else
                    leds_we(2*i+1 downto 2*i) <= leds_live(2*i+1 downto 2*i);
                    leds_we_bl(i) <= leds_live_bl(i);
                end if;
            end loop;
        end if;
    end process;

    -- the tick is one clock period long and with 50 Hz
    -- used to generate the LED pulses below
cdiv_1i: clock_div_ena
generic map(
    Ndiv => SYS_CLK/50)
port map(
     -- clock
    clk     => clk,
    rst     => '0',
    ena     => '1',
    q       => TickF);


div_sys: clk_div
GENERIC map(Nd => 50/2)
PORT map(
        clk     => clk,
        en      => TickF,
        div     => blink);


-- LED for USB UART
led_usb_uart: LED
generic map(
    RISING_ENABLED   => false,
    FALLING_ENABLED  => true,
    STATIC_ENABLED   => false,
    invert_in        => false,
    invert_out       => false)
Port map(
    CLK         => CLK,
    Tick        => TickF,
    -- Sig
    I           => uart_usb_rx and (uart_usb_tx or uart_opt_act),
    O           => leds_slive(0) );

    leds_live(2*0+1 downto 2*0) <= "10" when leds_slive(0)='1' and uart_opt_act='0' else "00";
    leds_live_bl(0) <= '0';

-- LED for LEMO input 2
led_lemo1_f: LED
generic map(
    RISING_ENABLED   => false,
    FALLING_ENABLED  => true,
    STATIC_ENABLED   => false,
    invert_in        => false,
    invert_out       => false)
Port map(
    CLK         => CLK,
    Tick        => TickF,
    -- Sig
    I           => control_ocpl(2),
    O           => leds_live(2*1+0) );

led_lemo1_r: LED
generic map(
    RISING_ENABLED   => true,
    FALLING_ENABLED  => false,
    STATIC_ENABLED   => false,
    invert_in        => false,
    invert_out       => false)
Port map(
    CLK         => CLK,
    Tick        => TickF,
    -- Sig
    I           => control_ocpl(2),
    O           => leds_live(2*1+1) );

    leds_live_bl(1) <= '0';

-- LED for LEMO input 1
led_lemo2_f: LED
generic map(
    RISING_ENABLED   => false,
    FALLING_ENABLED  => true,
    STATIC_ENABLED   => false,
    invert_in        => false,
    invert_out       => false)
Port map(
    CLK         => CLK,
    Tick        => TickF,
    -- Sig
    I           => control_ocpl(1),
    O           => leds_live(2*2+0) );

led_lemo2_r: LED
generic map(
    RISING_ENABLED   => true,
    FALLING_ENABLED  => false,
    STATIC_ENABLED   => false,
    invert_in        => false,
    invert_out       => false)
Port map(
    CLK         => CLK,
    Tick        => TickF,
    -- Sig
    I           => control_ocpl(1),
    O           => leds_live(2*2+1) );

    leds_live_bl(2) <= '0';

-- LED for AFBR input 1
led_afbr1_f: LED
generic map(
    RISING_ENABLED   => false,
    FALLING_ENABLED  => true,
    STATIC_ENABLED   => false,
    invert_in        => false,
    invert_out       => false)
Port map(
    CLK         => CLK,
    Tick        => TickF,
    -- Sig
    I           => control_afbr(1),
    O           => leds_live(2*3+0) );

led_afbr1_r: LED
generic map(
    RISING_ENABLED   => true,
    FALLING_ENABLED  => false,
    STATIC_ENABLED   => false,
    invert_in        => false,
    invert_out       => false)
Port map(
    CLK         => CLK,
    Tick        => TickF,
    -- Sig
    I           => control_afbr(1),
    O           => leds_live(2*3+1) );

    leds_live_bl(3) <= '0';

-- LED for AFBR input 2
led_afbr2_f: LED
generic map(
    RISING_ENABLED   => false,
    FALLING_ENABLED  => true,
    STATIC_ENABLED   => false,
    invert_in        => false,
    invert_out       => false)
Port map(
    CLK         => CLK,
    Tick        => TickF,
    -- Sig
    I           => control_afbr(2),
    O           => leds_live(2*4+0) );

led_afbr2_r: LED
generic map(
    RISING_ENABLED   => true,
    FALLING_ENABLED  => false,
    STATIC_ENABLED   => false,
    invert_in        => false,
    invert_out       => false)
Port map(
    CLK         => CLK,
    Tick        => TickF,
    -- Sig
    I           => control_afbr(2),
    O           => leds_live(2*4+1) );

    leds_live_bl(4) <= '0';

-- LED for OPT UART TX
led_opt_tx: LED
generic map(
    RISING_ENABLED   => false,
    FALLING_ENABLED  => true,
    STATIC_ENABLED   => false,
    invert_in        => false,
    invert_out       => false)
Port map(
    CLK         => CLK,
    Tick        => TickF,
    -- Sig
    I           => uart_opt_tx,
    O           => leds_slive(5) );

    leds_live(2*5+1 downto 2*5) <= "10" when leds_slive(5)='1' and uart_opt_act='1' else "00";
    leds_live_bl(5) <= '0';

-- LED for OPT UART RX
led_opt_rx: LED
generic map(
    RISING_ENABLED   => false,
    FALLING_ENABLED  => true,
    STATIC_ENABLED   => false,
    invert_in        => false,
    invert_out       => false)
Port map(
    CLK         => CLK,
    Tick        => TickF,
    -- Sig
    I           => uart_opt_rx,
    O           => leds_slive(6) );

    leds_live(2*6+1 downto 2*6) <= "10" when leds_slive(6)='1' else "00";
    leds_live_bl(6) <= '0';

    -- light switches
    process(all)
    begin
        for i in 1 to 4 loop
            if light_sw(i)='1' then
                leds_live(2*(6+i)+1 downto 2*(6+i)) <= "10";
            else
                leds_live(2*(6+i)+1 downto 2*(6+i)) <= "01";
            end if;
            leds_live_bl(6+i) <= '0';
        end loop;
    end process;

    -- h_inp
    process(all)
    begin
        for i in 1 to 4 loop
            if h_sleep_n='1' then
                if h_inp(i)='1' then
                    leds_live(2*(10+i)+1 downto 2*(10+i)) <= "10";
                else
                    leds_live(2*(10+i)+1 downto 2*(10+i)) <= "01";
                end if;
            else
                leds_live(2*(10+i)+1 downto 2*(10+i)) <= "00";
            end if;
            leds_live_bl(10+i) <= '0';
        end loop;
    end process;

    leds_live(2*15+1 downto 2*15) <= "11";
    leds_live_bl(15) <= '1';

we_leds_i: we_leds_4_lev
generic map(
    SWAP_ORDER      => true,
    FCLK            => SYS_CLK,
    -- for 10 MHz clock:
    Nleds           => Nleds)
port map(
    clk             => clk,
    reset           => reset,
    blink           => blink,

    -- typically the codes below are constants, eventually programmable, but static
    -- code to be sent when intensity is 1
    code_1_g        => CODE_1_G,
    code_1_r        => CODE_1_R,
    code_1_b        => CODE_1_B,

    -- code to be sent when intensity is 2
    code_2_g        => CODE_2_G,
    code_2_r        => CODE_2_R,
    code_2_b        => CODE_2_B,

    -- code to be sent when intensity is 3
    code_3_g        => CODE_3_G,
    code_3_r        => CODE_3_R,
    code_3_b        => CODE_3_B,

    -- 2 bits/LED: 0 - off, 1, 2, 3 - code_x_g|r|b
    leds_in         => leds_we,
    -- blink flag, one bit/LED, 1 for blinking
    leds_blink      => leds_we_bl,
    -- to the chain of led-ics
    led_ic_in       => led_out);

end;
