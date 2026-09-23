LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

-- $Id: serial_recv.vhd 975 2023-06-29 05:57:14Z angelov $:

entity serial_recv is
generic(
    -- use the phase accumulator or simple counter (Bittime)
    USE_ACC     : boolean := false;
    -- decrement the accumulator after each clock
    ACC_DECR    : Positive := 125;
    -- size of the accumulator
    ACC_NBITS   : Positive := 10;
    -- the numbers here correspond to 32.768 MHz clock and 4 Mbit/s baud rate:
    -- the desired divider ratio is 32.768/4 = 8.192
    -- 8.192*ACC_DECR=2**ACC_NBITS
    -- so the "ideal" Bittime is 2**ACC_NBITS/ACC_DECR = system_clock/baud_rate
    Bittime     : Positive := 10;
    Nfilt       : Positive := 3;
    LSBfirst    : Boolean := true;
    Nbits       : Positive := 8);
port (
    clk         : in  std_logic;
    reset       : in  std_logic;
    -- serial interface
    rx          : in  std_logic;
    -- uP interface
    busy_r      : out std_logic;
    valid_r     : out std_logic;
    break       : out std_logic;
    -- read
    dout        : out std_logic_vector(Nbits-1 downto 0) );
end serial_recv;

architecture struct of serial_recv is

component filt_long is
generic (N     : Positive := 3);
port(
     clk        : in  std_logic;
     d          : in  std_logic;
     inv_q      : in  std_logic;
     ena_edge   : in  std_logic;
     pos_edge   : out std_logic;
     neg_edge   : out std_logic;
     q          : out std_logic);
end component;

component ser_recv is
generic(Nbits   : Positive := 8; LSBfirst : Boolean := true);
port (
    clk    : in  std_logic;
    reset  : in  std_logic;
    rx     : in  std_logic;
    sample : in  std_logic;
    parity : out std_logic;
    dout   : out std_logic_vector(Nbits-1 downto 0));
end component;

component recvsm is
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
    Bittime : Positive := 100;
    Nbits   : Positive := 8);
port (
    clk    : in  std_logic;
    reset  : in  std_logic;
    start  : in  std_logic; -- falling detected, used as start
    redge  : in  std_logic; -- rising edge detected
    rx     : in  std_logic; -- input, used to detect timeouts (break)
    break  : out std_logic;
    sample : out std_logic;
    busy   : out std_logic;
    ready  : out std_logic);
end component;

signal rx2sample    : std_logic;
signal rx_filtered  : std_logic;
signal sample       : std_logic;
signal neg_edge     : std_logic;
signal pos_edge     : std_logic;

signal Log1         : std_logic;
signal Log0         : std_logic;

begin
    Log0 <= '0';
    Log1 <= '1';

filt_rx : filt_long
generic map(N => Nfilt)
port map(
     clk      => clk,
     d        => rx,
     inv_q    => Log0,
     ena_edge => Log1,
     pos_edge => pos_edge,
     neg_edge => neg_edge,
     q        => rx_filtered);

rsm: recvsm
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
    Bittime => Bittime,
    Nbits   => Nbits)
port map(
    clk    => clk,
    reset  => reset,
    start  => neg_edge,
    redge  => pos_edge,
    rx     => rx_filtered,
    break  => break,
    sample => sample,
    busy   => busy_r,
    ready  => valid_r);

recb: ser_recv
generic map(Nbits => Nbits, LSBfirst => LSBfirst)
port map(
    clk    => clk,
    reset  => reset,
    rx     => rx2sample,
    sample => sample,
    parity => open,
    dout   => dout);

    process(clk)
    begin
        if rising_edge(clk) then
            if pos_edge='1' or reset='1' then
                rx2sample <= '1';
            elsif neg_edge='1' then
                rx2sample <= '0';
            end if;
        end if;
    end process;

end;
