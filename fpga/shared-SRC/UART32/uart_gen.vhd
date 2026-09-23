-- $Id: uart_gen.vhd 1092 2024-07-08 17:46:13Z angelov $:

library ieee;
use ieee.std_logic_1164.all;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity uart_gen is
generic(
    QCLK            : Positive := 32000000;
    UART_BaudRate   : Positive := 4000000);
port(
    clk           : in  std_logic;
    rst           : in  std_logic;

    uart_gen_go   : in  std_logic; -- enable periodical command
    uart_cmd_go   : in  std_logic; -- send a single command

    -- period of the sent commands
    uart_gen      : in  std_logic_vector(22 downto 0);
    -- the byte to be sent
    uart_cmd      : in  std_logic_vector( 7 downto 0);

    tx_cmd        : out std_logic);
end uart_gen;

architecture behav of uart_gen is

component serial_send is
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
    LSBfirst    : Boolean  := true;
    Bittime     : Positive := 10;
    BittimeF    : Positive :=  5;
    Nidle       : Positive :=  2;
    Nbits       : Positive :=  8);
port (
    clk     : in  std_logic;
    reset   : in  std_logic;
    -- switch to the second (smaller) BittimeF?
    fast_m  : in  std_logic := '0';
    -- parallel data input
    start   : in  std_logic;
    din     : in  std_logic_vector(Nbits-1 downto 0);
    -- serial output
    tx      : out std_logic;
    -- status
    crc_ena : out std_logic;
    parity  : out std_logic;
    busy    : out std_logic;
    ready   : out std_logic);
end component;

constant Bittime         : Natural := (QCLK+UART_BaudRate/2)/UART_BaudRate;

signal start_tx          : std_logic;
signal uart_gen_is0      : std_logic;
signal uart_geng         : std_logic_vector(uart_gen'range);
constant uart_gen_eq1    : std_logic_vector(uart_gen'range) := (0 => '1', others => '0');

begin
    -- generate periodically UART command
    process(clk)
    begin
        if rising_edge(clk) then
            -- synchronous detect if next state is 0
            if uart_geng = uart_gen_eq1 then
                uart_gen_is0 <= '1';
            else
                 uart_gen_is0 <= '0';
            end if;
            -- check the condition to load the initial value for count down
            if uart_gen_go='0' or uart_gen_is0='1' then
                -- load the counter with the preset value when 0 or when disabled
                uart_geng <= uart_gen(uart_geng'range);
            else
                -- just decrement the counter
                uart_geng <= uart_geng - 1;
            end if;
        end if;
    end process;

    -- periodicall or single start to send a byte as command
    start_tx <= uart_gen_is0 when uart_gen_go='1' else uart_cmd_go;

ser_send_i: serial_send
generic map(
--  USE_ACC     => false,
--  -- decrement the accumulator after each clock
--  ACC_DECR    : Positive := 125;
--  -- size of the accumulator
--  ACC_NBITS   : Positive := 10;
--  -- the numbers here correspond to 32.768 MHz clock and 4 Mbit/s baud rate:
--  -- the desired divider ratio is 32.768/4 = 8.192
--  -- 8.192*ACC_DECR=2**ACC_NBITS
--  -- so the "ideal" Bittime is 2**ACC_NBITS/ACC_DECR = system_clock/baud_rate
--  LSBfirst    : Boolean  := true;
    Bittime     => Bittime,
    BittimeF    => Bittime,
--    Nidle       : Positive :=  2;
    Nbits       => 8)
port map(
    clk     => clk,
    reset   => rst,
    -- switch to the second (smaller) BittimeF?
--  fast_m  : in  std_logic := '0';
    -- parallel data input
    start   => start_tx,
    din     => uart_cmd,
    -- serial output
    tx      => tx_cmd,
    -- status
    crc_ena => open,
    parity  => open,
    busy    => open,
    ready   => open);

end;
