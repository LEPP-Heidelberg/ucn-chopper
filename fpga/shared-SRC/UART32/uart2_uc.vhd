LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

-- $Id: uart2_uc.vhd 1125 2024-11-14 07:05:44Z angelov $:

entity uart2_uc is
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
    Bittime0 : Positive := 10;  -- for rx/tx 0
    Bittime1 : Positive := 10;  -- for rx/tx 1..Nuart-1 (if any)
    USE_ID   : Boolean  := false; -- the lower 4 bits of lmask should match exactly what comes from the interface?
    LSBfirst : Boolean  := true;
    Naddr    : Positive := 24;  -- 16 or 24, no other values allowed
    Ndata    : Positive := 32;  -- 8, 16 or 32, no other values allowed!
    Nuart    : Positive :=  3;  -- 1..
    Nfifo    : Natural  :=  9;  -- bits in the rx FIFO address (when 0 - without FIFO)
    Nwdog    : Natural  := 24;  -- number of bits in watchdog timer - counts down and when 0 => inactive
    Nfilt    : Positive := 3);  -- samples in the digital filter at rx - the signal must be stable for at leas Nfilt samples
                                    -- in order to be accepted
port (
    clk          : in  std_logic;
    reset        : in  std_logic;
    lmask        : in  std_logic_vector(8*Nuart-1 downto 0) := (others => '0');

    -- direct command via only one byte from rx0 (Nuart=1) or rx0 and rx1 (Nuart=2) !!!
    -- for this the MSBit should be 1, bits 6..4 code one of the 8 commands
    -- the lower 4 bits of lmask AND-ed with the lower 4 bits of lmask should have a non-zero result
    short_code   : out std_logic_vector(2 downto 0);
    short_cmd    : out std_logic;
    -- uController serial interface (master)
    we_uc        : in  std_logic;
    addr_uc      : in  std_logic_vector(Naddr-1 downto 0);
    data_out_uc  : in  std_logic_vector(Ndata-1 downto 0);
    rd_req_uc    : in  std_logic; -- used to protect the read register from changes ???
    bus_ack_uc   : out std_logic; -- is '1' when the data are written/ready
--  data_in_uc   : out std_logic_vector(byte_size-1 downto 0); - connected directly
    -- serial interface(s)
    rx           : in  std_logic_vector(Nuart-1 downto 0);
    tx           : out std_logic_vector(Nuart-1 downto 0);
    -- bus interface (master)
    we           : out std_logic;
    rd           : out std_logic;
    ready        : in  std_logic;
    addr         : out std_logic_vector(Naddr-1 downto 0);
    data_out     : out std_logic_vector(Ndata-1 downto 0);
    data_in      : in  std_logic_vector(Ndata-1 downto 0);
    busy         : out std_logic);
end uart2_uc;

architecture struct of uart2_uc is

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
    USE_ID   : Boolean  := false; -- the lower 4 bits of lmask should match exactly what comes from the interface?
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
    lmask        : in  std_logic_vector(7 downto 0) := (others => '0');

    -- direct command via only one byte
    -- for this the MSBit should be 1, bits 6..4 code one of the 8 commands
    -- the lower 4 bits of lmask AND-ed with the lower 4 bits of lmask should have a non-zero result
    -- cmd0 - latch ADC data
    -- cmd1 - send ADC data
    -- cmd2 - pause sending data

    short_code  : out std_logic_vector(2 downto 0);
    short_cmd   : out std_logic;

    -- serial interface
    rx           : in  std_logic;
    tx           : out std_logic;

    -- bus interface
    bus_we       : out std_logic; -- - as along as ack comes
    bus_rd       : out std_logic; -- /
    bus_ack      : in  std_logic; -- is '1' when the data are written/ready
    bus_rdata    : in  std_logic_vector(Ndata-1 downto 0);
    bus_addr     : out std_logic_vector(Naddr-1 downto 0);
    bus_wdata    : out std_logic_vector(Ndata-1 downto 0);

    -- status
    timeout      : out std_logic; -- master packet broken
    busy         : out std_logic);
end component;

component arbiter is
generic (rd_clocks : Positive := 3;
         wr_clocks : Natural  := 2;
         Naddr     : Positive := 24;
         Ndata     : Positive := 32;
         Nmast     : Positive := 4;
         latch_a_d : boolean  := true);
port(clk     : in  std_logic;
     reset   : in  std_logic;

     we_ua   : in  std_logic_vector(Nmast-1 downto 0);
     rd_ua   : in  std_logic_vector(Nmast-1 downto 0);
     ack_ua  : out std_logic_vector(Nmast-1 downto 0);
     -- read/write address
     addr_i  : in  std_logic_vector(Nmast*Naddr-1 downto 0);
     -- write data
     wdata_i : in  std_logic_vector(Nmast*Ndata-1 downto 0);
     -- to the bus
     addr    : out std_logic_vector(Naddr-1 downto 0);
     wdata   : out std_logic_vector(Ndata-1 downto 0);
     ready   : in  std_logic;
     rd      : out std_logic;
     we      : out std_logic);
end component;

type pos_array_t is array(0 to Nuart-1) of Positive;
constant bittimes : pos_array_t := (0 => Bittime0, others => Bittime1);

signal addr_in : std_logic_vector((Nuart+1)*Naddr-1 downto 0);
signal wdata   : std_logic_vector((Nuart+1)*Ndata-1 downto 0);

signal we_ua   : std_logic_vector(Nuart   downto 0);
signal rd_ua   : std_logic_vector(Nuart   downto 0);
signal ack_ua  : std_logic_vector(Nuart   downto 0);
signal busy_i  : std_logic_vector(Nuart-1 downto 0);
signal busy_old: std_logic_vector(Nuart-1 downto 0);

signal bb_zero : std_logic_vector(Nuart-1 downto 0);
signal short_code_a : std_logic_vector(3*Nuart-1 downto 0);
signal short_cmd_a  : std_logic_vector(  Nuart-1 downto 0);

begin
    bb_zero <= (others => '0');

Nuart_is_1: if Nuart=1 generate
    short_code <= short_code_a(2 downto 0);
    short_cmd  <= short_cmd_a(0);
end generate;

Nuart_is_gt1: if Nuart>1 generate
    -- output codes
    short_code <= short_code_a(2 downto 0) or short_code_a(5 downto 3);
    short_cmd  <= short_cmd_a(0) or short_cmd_a(1);
end generate;

ua3: for i in 0 to Nuart-1 generate
ua_i: uart_top
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
    Bittime  => bittimes(i),
    BittimeF => bittimes(i),
    USE_ID   => USE_ID,
    Naddr    => Naddr,
    Ndata    => Ndata,
    Nfifo    => Nfifo,
    Nwdog    => Nwdog,
    LSBfirst => LSBfirst,
    Nfilt    => Nfilt)
port map(
    clk          => clk,
    reset        => reset,
    lmask        => lmask((i+1)*8-1 downto i*8),

    -- direct command via only one byte
    -- for this the MSBit should be 1, bits 6..4 code one of the 8 commands
    -- the lower 4 bits of lmask AND-ed with the lower 4 bits of lmask should have a non-zero result

    short_code  => short_code_a(3*i+2 downto 3*i),
    short_cmd   => short_cmd_a(i),

    -- serial interface
    rx           => rx(i),
    tx           => tx(i),
    -- bus interface
    bus_we       => we_ua(i),
    bus_addr     => addr_in((i+1)*Naddr-1 downto i*Naddr),
    bus_wdata    => wdata(  (i+1)*Ndata-1 downto i*Ndata),
    bus_rd       => rd_ua(i),
    bus_ack      => ack_ua(i),
    bus_rdata    => data_in,
    -- status
    timeout      => open,
    busy         => busy_i(i));
end generate;

    we_ua(Nuart) <= we_uc;
    rd_ua(Nuart) <= rd_req_uc;

    addr_in((Nuart+1)*Naddr-1 downto Nuart*Naddr) <= addr_uc;
    wdata((Nuart+1)*Ndata-1 downto Nuart*Ndata)   <= data_out_uc;

    bus_ack_uc   <=  ack_ua(Nuart);

    process(clk)
    variable busy_ne : std_logic_vector(busy_i'range);
    begin
        if rising_edge(clk) then
            busy_old <= busy_i;
            busy_ne := busy_old and not busy_i; -- some busy was deactivated
            if busy_i /= bb_zero then
                busy <= '1';                    -- set busy if any busy is high
            else
                busy <= '0';                    -- else reset the busy
            end if;
            if busy_ne /= bb_zero then          -- and reset shortly the busy if any busy was just deactivated, to enable to switch
                busy <= '0';                    -- the link mask or slave mask
            end if;
        end if;
    end process;

arb: arbiter
generic map(rd_clocks => 3,
            wr_clocks => 2,
            Naddr     => Naddr,
            Ndata     => Ndata,
            Nmast     => Nuart+1,
            latch_a_d => true)
port map(
     clk     => clk,
     reset   => reset,

     we_ua   => we_ua,
     rd_ua   => rd_ua,
     ack_ua  => ack_ua,
     -- read/write address
     addr_i  => addr_in,
     -- write data
     wdata_i => wdata,
     -- to the bus
     addr    => addr,
     wdata   => data_out,
     ready   => ready,
     rd      => rd,
     we      => we);

end;
