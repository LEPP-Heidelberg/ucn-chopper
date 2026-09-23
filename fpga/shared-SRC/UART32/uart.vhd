LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

-- $Id: uart.vhd 1162 2025-11-08 08:12:51Z angelov $:

entity uart is
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
    Nfilt    : Positive :=  3;
    LSBfirst : Boolean  := true;
    Nidle    : Positive :=  2;
    Nbits    : Positive :=  8);
port (
    clk          : in  std_logic;
    reset        : in  std_logic;
    fast_m       : in  std_logic := '0'; -- used only when USE_ACC is false!
    -- serial interface
    rx           : in  std_logic;
    tx           : out std_logic;
    --
    break        : out std_logic;
    -- write
    ready_s      : out std_logic;
    busy_s       : out std_logic;
    we           : in  std_logic;
    din          : in  std_logic_vector(Nbits-1 downto 0);
    -- read
    busy_r       : out std_logic;
    valid_r      : out std_logic;
    dout         : out std_logic_vector(Nbits-1 downto 0) );
end uart;

architecture struct of uart is

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
    -- witch to the second (smaller) BittimeF?
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

component serial_recv is
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
    Nfilt    : Positive := 3;
    LSBfirst : Boolean := true;
    Nbits    : Positive := 8);
port (
    clk          : in  std_logic;
    reset        : in  std_logic;
    -- serial interface
    rx           : in  std_logic;
    -- uP interface
    busy_r       : out std_logic;
    valid_r      : out std_logic;
    break        : out std_logic;
    -- read
    dout         : out std_logic_vector(Nbits-1 downto 0) );
end component;

begin

ser_send_i: serial_send
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

    LSBfirst    => LSBfirst,
    Bittime     => Bittime,
    BittimeF    => BittimeF,
    Nidle       => Nidle,
    Nbits       => Nbits)
port map(
    clk     => clk,
    reset   => reset,
    -- witch to the second (smaller) BittimeF?
    fast_m  => fast_m,
    -- parallel data input
    start   => we,
    din     => din,
    -- serial output
    tx      => tx,
    -- status
    crc_ena => open,
    parity  => open,
    busy    => busy_s,
    ready   => ready_s);

ser_rcv_i: serial_recv
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

    Bittime  => Bittime,
    Nfilt    => Nfilt,
    LSBfirst => LSBfirst,
    Nbits    => Nbits)
port map(
    clk          => clk,
    reset        => reset,
    -- serial interface
    rx           => rx,
    -- uP interface
    busy_r       => busy_r,
    valid_r      => valid_r,
    break        => break,
    -- read
    dout         => dout);

end;
