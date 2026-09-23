LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

-- $Id: uart_top.vhd 1205 2026-07-03 14:41:40Z  $:

entity uart_top is
generic(
    USE_ACC     : boolean := false;
    -- decrement the accumulator after each clock
    ACC_DECR    : Positive := 125;
    -- size of the accumulator
    ACC_NBITS   : Positive := 10;
    -- the numbers here correspond to 32.768 MHz clock and 4 Mbit/s baud rate:
    -- the desired divider ratio is 32.768/4 = 8.192
    -- 8.192*ACC_DECR=2**ACC_NBITS
    -- so the "ideal" floating point Bittime is 2**ACC_NBITS/ACC_DECR = system_clock/baud_rate
    USE_ID    : Boolean := false; -- the lower 4 bits of lmask should match exactly what comes from the interface?
    Bittime  : Positive := 10;  -- normal bittime (when fast_m=0)
    BittimeF : Positive :=  5;  -- bittime in fast mode (when the input fast_m is 1)
    Naddr    : Positive := 24;  -- 16 or 24, no other values allowed
    Ndata    : Positive := 32;  -- 8, 16 or 32, no other values allowed!
    Nfifo    : Natural  :=  4;  -- bits in the FIFO address
    Nwdog    : Natural  := 24;  -- number of bits in watchdog timer - counts down and when 0 => inactive
    LSBfirst : Boolean := true;
    Nfilt    : Positive := 3);
port (
    clk          : in  std_logic;
    reset        : in  std_logic;

    fast_m       : in  std_logic := '0'; -- fast mode for direct UART interface, used only when USE_ACC is false!
    lmask        : in  std_logic_vector(7 downto 0) := (others => '0');

    -- direct command via only one byte
    -- for this the MSBit should be 1, bits 6..4 code one of the 8 commands
    -- the lower 4 bits of lmask AND-ed with the lower 4 bits of lmask should have a non-zero result

    short_code  : out std_logic_vector(2 downto 0);
    short_cmd   : out std_logic;

    -- serial interface
    rx           : in  std_logic;
    tx           : out std_logic;
    tx_enable    : out std_logic;

    -- bus interface
    bus_we       : out std_logic; -- - as along as ack comes
    bus_rd       : out std_logic; -- /
    bus_cyc      : out std_logic; -- / - for WB compatibility
    bus_ack      : in  std_logic; -- is '1' when the data are written/ready
    bus_rdata    : in  std_logic_vector(Ndata-1 downto 0);
    bus_addr     : out std_logic_vector(Naddr-1 downto 0);
    bus_wdata    : out std_logic_vector(Ndata-1 downto 0);

    debug        : out std_logic_vector(     15 downto 0);

    -- status
    timeout      : out std_logic; -- master packet broken
    busy         : out std_logic);
end uart_top;

architecture struct of uart_top is

component uart is
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
    LSBfirst : Boolean := true;
    Nidle    : Positive :=  2;
    Nbits    : Positive :=  8);
port (
    clk          : in  std_logic;
    reset        : in  std_logic;
    fast_m       : in  std_logic := '0';
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
end component;

component prot_sm is
generic (
    USE_ID      : Boolean := false; -- the lower 4 bits of lmask should match exactly what comes from the interface?
    Naddr       : Positive := 24;  -- 16 or 24, no other values allowed!
    Ndata       : Positive := 32); -- 8, 16 or 32, no other values allowed!
port (
    clk         : in  std_logic;
    reset       : in  std_logic;
    lmask       : in  std_logic_vector(7 downto 0);

    -- direct command via only one byte
    -- for this the MSBit should be 1, bits 6..4 code one of the 8 commands
    -- the lower 4 bits of lmask AND-ed with the lower 4 bits of lmask should have a non-zero result

    short_code  : out std_logic_vector(2 downto 0);
    short_cmd   : out std_logic;

    -- uart status & data
    -- receive sm
    st_din_v    : in  std_logic;
    st_din      : in  std_logic_vector(7 downto 0);
    busy_rcv    : out std_logic; -- can not receive more bytes on st_din

    -- send sm
    st_dout_v   : out std_logic;
    st_dout     : out std_logic_vector(7 downto 0);
    st_dout_rdy : in  std_logic;

    -- bus interface
    bus_we      : out std_logic; -- - as along as ack comes
    bus_rd      : out std_logic; -- /
    bus_cyc     : out std_logic; -- / - for WB compatibility
    bus_ack     : in  std_logic; -- is '1' when the data are written/ready
    bus_rdata   : in  std_logic_vector(Ndata-1 downto 0);
    bus_addr    : out std_logic_vector(Naddr-1 downto 0);
    bus_wdata   : out std_logic_vector(Ndata-1 downto 0);

    -- status
    timeout     : out std_logic; -- master packet broken
    busy        : out std_logic);
end component;

component sc_fifo is
generic (Na     : Positive := 4;
         Nd     : positive := 8;
       async_rd : Boolean  := true);
PORT
    (
     din     : in std_logic_vector(Nd-1 downto 0);
     wrreq   : in std_logic;   -- write din & increment the write address at the next clock
     rdreq   : in std_logic;   -- increment the read address at the next clock
     clk     : in std_logic;
     sclr    : in std_logic;   -- clear all
     dout    : out std_logic_vector(Nd-1 downto 0);
     full    : out std_logic;  -- fifo is full, do not write!
     afull   : out std_logic;  -- fifo is almost full (one one word can be stored)
     empty   : out std_logic   -- fifo is empty, do not read!
    );
end component;

component wdog is
generic(
    Nwdog       : Natural := 24  -- number of bits in watchdog timer - counts down and when 0 => inactive
);
port (
    clk         : in  std_logic;
    reset       : in  std_logic;
    disable     : in  std_logic;
    rx          : in  std_logic;
    rst_out     : out std_logic);
end component;

    -- receive sm
signal fifo_empty       : std_logic;
signal fifo_in_valid    : std_logic;
signal prot_in_valid    : std_logic;
signal fifo_in_data     : std_logic_vector(7 downto 0);
signal prot_in_data     : std_logic_vector(7 downto 0);

    -- send sm
signal st_dout_v   : std_logic;
signal st_dout     : std_logic_vector(7 downto 0);
signal st_dout_rdy : std_logic;

signal reset_out   : std_logic;
signal busy_rcv    : std_logic;
signal busy_send   : std_logic;
signal rdreq       : std_logic;

type fifo_sm_type is (fifo_sm_idle, fifo_sm_rdfifo);
signal fifo_sm      : fifo_sm_type;

begin

wdog_i: wdog
generic map(
        Nwdog    => Nwdog)
port map(
    clk          => clk,
    reset        => reset,
    disable      => '0',
    rx           => rx,
    rst_out      => reset_out);

uart_i: uart
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
    BittimeF => BittimeF,
    Nbits    => 8,
    LSBfirst => LSBfirst,
    Nfilt    => Nfilt)
port map(
    clk          => clk,
    reset        => reset_out,
    fast_m       => fast_m,
    -- serial interface
    rx           => rx,
    tx           => tx,
    break        => open,

    -- write
    ready_s      => st_dout_rdy,
    busy_s       => busy_send,
    we           => st_dout_v,
--    we           => fifo_in_valid,
    din          => st_dout,
--    din          => fifo_in_data,
    -- read
    busy_r       => open,
    valid_r      => fifo_in_valid,
    dout         => fifo_in_data);

    tx_enable <= busy_send or st_dout_v;

with_fifo: if Nfifo > 1 generate

    process(clk)
    begin
        if rising_edge(clk) then
            prot_in_valid <= '0';
            rdreq <= prot_in_valid;
            if reset_out='1' then
                fifo_sm <= fifo_sm_idle;
            else
                case fifo_sm is
                    when fifo_sm_idle =>
                        if fifo_empty='0' and busy_rcv='0' then
                            prot_in_valid <= '1';
                            fifo_sm <= fifo_sm_rdfifo;
                        end if;
                    when fifo_sm_rdfifo =>
--                        if busy_rcv='0' then
                        -- wait longer
                        if busy_rcv='0' and rdreq='0' and prot_in_valid='0' then
                            fifo_sm <= fifo_sm_idle;
                        end if;
                    when others => fifo_sm <= fifo_sm_idle;
                end case;
            end if;
        end if;
    end process;

fifo_i: sc_fifo
generic map(
        Na     => Nfifo,
        Nd     => 8,
        async_rd => (Nfifo < 5) )
PORT map
    (
     din     => fifo_in_data,
     wrreq   => fifo_in_valid,

     rdreq   => rdreq,  -- request the next fifo position

     clk     => clk,
     sclr    => reset_out,
     dout    => prot_in_data,
     full    => open,
     afull   => open,
     empty   => fifo_empty);
else generate

--    prot_in_valid <= fifo_in_valid;
    rdreq <= fifo_in_valid;
    prot_in_data  <= fifo_in_data ;

end generate;

    process(clk)
    begin
        if rising_edge(clk) then

            if fifo_in_valid='1' then
                debug(7 downto 0) <= fifo_in_data;
            else
                debug(7 downto 0) <= prot_in_data;
            end if;
            debug(8) <= fifo_in_valid;
            debug(9) <= rdreq;
            debug(10) <= fifo_empty;
            debug(11) <= reset_out;
            if fifo_sm = fifo_sm_idle then
                debug(12) <= '0';
            else
                debug(12) <= '1';
            end if;
            debug(13) <= busy_rcv;
            debug(14) <= st_dout_v;
            debug(15) <= busy_send;
        end if;
    end process;


sm: prot_sm
generic map(
    USE_ID      => USE_ID,
    Naddr       => Naddr,
    Ndata       => Ndata)
port map(
    clk         => clk,
    reset       => reset_out,
    lmask       => lmask,

    -- direct command via only one byte
    -- for this the MSBit should be 1, bits 6..4 code one of the 8 commands
    -- the lower 4 bits of lmask AND-ed with the lower 4 bits of lmask should have a non-zero result

    short_code  => short_code,
    short_cmd   => short_cmd,

    -- uart status & data
    -- receive sm
--    st_din_v    => prot_in_valid, -- may be too early?
    st_din_v    => rdreq,           -- so is one clock later but more sure to have valid data at fifo output
    st_din      => prot_in_data,
    busy_rcv    => busy_rcv,

    -- send sm
    st_dout_v   => st_dout_v,
    st_dout     => st_dout,
    st_dout_rdy => st_dout_rdy,

    -- bus interface
    bus_we      => bus_we,
    bus_rd      => bus_rd,
    bus_cyc     => bus_cyc,
    bus_ack     => bus_ack,
    bus_rdata   => bus_rdata,
    bus_addr    => bus_addr,
    bus_wdata   => bus_wdata,

    -- status
    timeout     => timeout,
    busy        => busy);

end;
