LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

-- to do
-- interpret crc error

-- $Id: uart2_uc.vhd 979 2023-07-10 17:44:33Z angelov $:

use work.uart_pack.all;

entity uart2_uc is
generic(Bittime  : Positive := 10;
        Nwdog    : Natural  := 24;  -- number of bits in watchdog timer - counts down and when 0 => inactive
        LSBfirst : Boolean  := true;
        Nuart    : Positive := 3;
        Nidle    : Positive := 1;
        Nfilt    : Positive := 3);
port (
    clk          : in  std_logic;
    reset        : in  std_logic;
    slaveID      : in  std_logic_vector(Nuart*ID_size-1 downto 0);
    -- uController serial interface
    we_uc        : in  std_logic;
    addr_uc      : in  std_logic_vector(addr_size-1 downto 0);
    data_out_uc  : in  std_logic_vector(byte_size-1 downto 0);
    rd_req_uc    : in  std_logic; -- used to protect the read register from changes ???
    bus_ack_uc   : out std_logic; -- is '1' when the data are written/ready
--    data_in_uc   : out std_logic_vector(byte_size-1 downto 0);
    -- serial interface
    rx           : in  std_logic_vector(Nuart-1 downto 0);
    tx           : out std_logic_vector(Nuart-1 downto 0);
    tx_oe        : out std_logic_vector(Nuart-1 downto 0);
    -- bus interface
    we           : out std_logic;
    rd           : out std_logic;
    ready        : in  std_logic;
    addr         : out std_logic_vector(addr_size-1 downto 0);
    data_out     : out std_logic_vector(byte_size-1 downto 0);
    data_in      : in  std_logic_vector(byte_size-1 downto 0);
    busy         : out std_logic;
    break        : out std_logic);
end uart2_uc;

architecture struct of uart2_uc is

component uart_top is
generic(Bittime  : Positive := 10;
        BittimeF : Positive :=  5;
        Nwdog    : Natural  := 24;  -- number of bits in watchdog timer - counts down and when 0 => inactive
        LSBfirst : Boolean := true;
        Nidle   : Positive :=   1;
        Nfilt    : Positive := 3);
port (
    clk          : in  std_logic;
    reset        : in  std_logic;
    slaveID      : in  std_logic_vector(ID_size-1 downto 0);
    -- serial interface
    rx           : in  std_logic;
    tx           : out std_logic;
    -- bus interface
    we           : out std_logic;
    addr         : out std_logic_vector(addr_size-1 downto 0);
    data_out     : out std_logic_vector(byte_size-1 downto 0);
    rd_req       : out std_logic; -- used to protect the read register from changes ???
    bus_ack      : in  std_logic; -- is '1' when the data are written/ready
    data_in      : in  std_logic_vector(byte_size-1 downto 0);
    -- status
    break        : out std_logic;
    timeout      : out std_logic; -- master packet broken
    crc_err      : out std_logic; -- crc error incoming data (from master)
    busy         : out std_logic);
end component;

component arbiter is
generic (rd_clocks : Positive := 3;
         wr_clocks : Natural  := 2;
         Nmast     : Positive := 4;
         latch_a_d : boolean  := true);
port(clk     : in  std_logic;
     reset   : in  std_logic;

     we_ua   : in  std_logic_vector(Nmast-1 downto 0);
     rd_ua   : in  std_logic_vector(Nmast-1 downto 0);
     ack_ua  : out std_logic_vector(Nmast-1 downto 0);
     -- read/write address
     addr_i  : in  std_logic_vector(Nmast*addr_size-1 downto 0);
     -- write data
     wdata_i : in  std_logic_vector(Nmast*byte_size-1 downto 0);
     -- to the bus
     addr    : out std_logic_vector(addr_size-1 downto 0);
     wdata   : out std_logic_vector(byte_size-1 downto 0);
     ready   : in  std_logic;
     rd      : out std_logic;
     we      : out std_logic);
end component;

signal addr_in : std_logic_vector((Nuart+1)*addr_size-1 downto 0);
signal wdata   : std_logic_vector((Nuart+1)*byte_size-1 downto 0);

signal we_ua   : std_logic_vector(Nuart   downto 0);
signal rd_ua   : std_logic_vector(Nuart   downto 0);
signal ack_ua  : std_logic_vector(Nuart   downto 0);
signal break_i : std_logic_vector(Nuart-1 downto 0);
signal busy_i  : std_logic_vector(Nuart-1 downto 0);
signal busy_old: std_logic_vector(Nuart-1 downto 0);

signal bb_zero : std_logic_vector(Nuart-1 downto 0);

begin
    bb_zero <= (others => '0');

ua3: for i in 0 to Nuart-1 generate
ua_i: uart_top
generic map(
        Bittime  => Bittime,
        BittimeF => Bittime,
        LSBfirst => LSBfirst,
        Nwdog    => Nwdog,
        Nidle    => Nidle,
        Nfilt    => Nfilt)
port map(
    clk          => clk,
    reset        => reset,
    slaveID      => slaveID((i+1)*ID_size-1 downto i*ID_size),
    -- serial interface
    rx           => rx(i),
    tx           => tx(i),
    -- bus interface
    we           => we_ua(i),
    addr         => addr_in((i+1)*addr_size-1 downto i*addr_size),
    data_out     => wdata(  (i+1)*byte_size-1 downto i*byte_size),
    rd_req       => rd_ua(i),
    bus_ack      => ack_ua(i),
    data_in      => data_in,
    -- status
    break        => break_i(i),
    timeout      => open,
    crc_err      => open,
    busy         => busy_i(i));
end generate;

    we_ua(Nuart)   <=  we_uc;
    rd_ua(Nuart)   <=  rd_req_uc;

    addr_in((Nuart+1)*addr_size-1 downto Nuart*addr_size) <=  addr_uc;
    wdata((Nuart+1)*byte_size-1 downto Nuart*byte_size)   <=  data_out_uc;

    bus_ack_uc     <=  ack_ua(Nuart);

    break <= '1' when break_i /= bb_zero else '0';
--    busy  <= '1' when busy_i  /= bb_zero else '0';
    tx_oe <= busy_i;

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
