LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

use work.uart_pack.all;

-- $Id: uart_top.vhd 979 2023-07-10 17:44:33Z angelov $:

entity uart_top is
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

    fast_m       : in  std_logic := '0'; -- fast mode for direct UART interface

    -- serial interface
    rx           : in  std_logic;
    tx           : out std_logic;

    -- direct interface
    cmd_mode     : out std_logic;

    cmd_valid    : out std_logic;
    cmd_data     : out std_logic_vector(byte_size-1 downto 0);

    dir_backd_s  : in  std_logic := '0';   -- send a byte back
    dir_backd_d  : in  std_logic_vector(7 downto 0) := (others => '0');  -- the byte to be sent back
    dir_backd_b  : out std_logic;   -- the buffer for back data is busy!

    -- bus interface
    we           : out std_logic;
    addr         : out std_logic_vector(addr_size-1 downto 0);
    data_out     : out std_logic_vector(byte_size-1 downto 0);
    rd_req       : out std_logic; -- used to protect the read register from changes ???
    bus_ack      : in  std_logic; -- is '1' when the data are written/ready
    data_in      : in  std_logic_vector(byte_size-1 downto 0);
    break        : out std_logic;
    -- status
    timeout      : out std_logic; -- master packet broken
    crc_err      : out std_logic; -- crc error incoming data (from master)
    busy         : out std_logic);
end uart_top;

architecture struct of uart_top is

component uart is
generic(Bittime  : Positive := 10;
        BittimeF : Positive :=  5;
        Nfilt    : Positive :=  3;
        LSBfirst : Boolean  := true;
        Nidle   : Positive :=   1;
        Nbits    : Positive :=  9); -- with the parity bit
port (
    clk          : in  std_logic;
    rst_n        : in  std_logic;
    fast_m       : in  std_logic := '0'; -- fast mode for direct UART interface
    -- serial interface
    rx           : in  std_logic;
    tx           : out std_logic;
    -- uP interface
    ready_s      : out std_logic;
    busy_s       : out std_logic;
    busy_r       : out std_logic;
    valid_r      : out std_logic;
    break        : out std_logic;
    -- write
    crc_sent_ini : in  std_logic;
    we           : in  std_logic;
    din          : in  std_logic_vector(Nbits-1 downto 0);
    -- read
    crc_recv_ini : in  std_logic;
    dout         : out std_logic_vector(Nbits-1 downto 0);
    crc8sent     : out std_logic_vector(7 downto 0);
    crc8recv     : out std_logic_vector(7 downto 0));
end component;

component prot_sm is
port (
    clk          : in  std_logic;
    rst_n        : in  std_logic;
    slaveID      : in  std_logic_vector(ID_size-1 downto 0);

    -- uart status
    crc8recvOK   : in  std_logic;
    din          : in  std_logic_vector(byte_size-1 downto 0);
    ready_s      : in  std_logic;
    busy_s       : in  std_logic;
    busy_r       : in  std_logic;
    valid_r      : in  std_logic;
    start_send   : out std_logic;
    break        : in  std_logic;
    -- crc clear
    crc_clr      : out std_logic;
    -- address counter
    cload        : out std_logic;
    high_b       : out std_logic; -- load the high byte of the address counter
    cnten        : out std_logic;
    -- bus interface
    we           : out std_logic;
    rd_req       : out std_logic; -- used to protect the read register from changes
    bus_ack      : in  std_logic; -- is '1' when the data are written/ready
    -- 0 crc8sent, 1 crc8recv, 2 data_in
    sel_dout     : out std_logic_vector(1 downto 0);
    -- status
    timeout      : out std_logic; -- master packet broken
    crc_err      : out std_logic; -- crc error in the incoming data (from master)
    busy         : out std_logic;

    cmd_mode     : out std_logic;

    dir_send     : in  std_logic;

    cmd_valid    : out std_logic;
    cmd_data     : out std_logic_vector(byte_size-1 downto 0) );
end component;

component counter is
generic (N : Positive := 8);
port (
    clk    : in  std_logic;
    sload  : in  std_logic;
    high_b : in  std_logic; -- load the high byte
    cnten  : in  std_logic;
    d       : in  std_logic_vector(  N-1 downto 0);
    q       : out std_logic_vector(2*N-1 downto 0) );
end component;

component mux31 is
generic (N : Positive := 8);
port (
    I0  : in  std_logic_vector(N-1 downto 0);
    I1  : in  std_logic_vector(N-1 downto 0);
    I2  : in  std_logic_vector(N-1 downto 0);
    SEL : in  std_logic_vector(  1 downto 0);
    Y   : out std_logic_vector(N-1 downto 0));
end component;

component mux41 is
generic (N : Positive := 8);
port (
    I0  : in  std_logic_vector(N-1 downto 0);
    I1  : in  std_logic_vector(N-1 downto 0);
    I2  : in  std_logic_vector(N-1 downto 0);
    I3  : in  std_logic_vector(N-1 downto 0);
    SEL : in  std_logic_vector(  1 downto 0);
    Y   : out std_logic_vector(N-1 downto 0));
end component;

component wdog is
generic(
        Nwdog    : Natural := 24  -- number of bits in watchdog timer - counts down and when 0 => inactive
);
port (
    clk          : in  std_logic;
    rst_n        : in  std_logic;
    disable      : in  std_logic;
    rx           : in  std_logic;
    rstout_n     : out std_logic);
end component;

signal dout     : std_logic_vector(byte_size-1 downto 0);
signal din_mux  : std_logic_vector(byte_size-1 downto 0);
signal crc8sent : std_logic_vector(7 downto 0);
signal crc8recv : std_logic_vector(7 downto 0);
signal sel_sm   : std_logic_vector(1 downto 0);

signal start_send : std_logic;

signal ready_s      : std_logic;
signal busy_s       : std_logic;
signal busy_r       : std_logic;
signal valid_r      : std_logic;

signal crc_clr      : std_logic;
signal crc8recvOK   : std_logic;

signal cload        : std_logic;
signal cnten        : std_logic;
signal break_i      : std_logic;

signal high_b       : std_logic; -- load the high byte

signal rst_n        : std_logic;
signal rstout_n     : std_logic;
signal cmd_mode_i   : std_logic;
signal fast_m_i     : std_logic;

signal dir_backd_s_r  : std_logic;   -- send a byte back
signal dir_backd_d_r  : std_logic_vector(7 downto 0);  -- the byte to be sent back

begin
    crc8recvOK <= '1' when crc8recv = X"00" else '0';

    process(clk)
    begin
        if rising_edge(clk) then
            rst_n <= not reset;
        end if;
    end process;

wdog_i: wdog
generic map(
        Nwdog    => Nwdog)
port map(
    clk          => clk,
    rst_n        => rst_n,
    disable      => cmd_mode_i,
    rx           => rx,
    rstout_n     => rstout_n);

uart_i: uart
generic map(Bittime  => Bittime,
            BittimeF => BittimeF,
            Nbits    => byte_size,
            LSBfirst => LSBfirst,
            Nidle    => Nidle,
            Nfilt    => Nfilt)
port map(
    clk          => clk,
    rst_n        => rstout_n,
    fast_m       => fast_m_i,
    -- serial interface
    rx           => rx,
    tx           => tx,
    -- uP interface
    ready_s      => ready_s,
    busy_s       => busy_s,
    busy_r       => busy_r,
    valid_r      => valid_r,
    break        => break_i,
    -- write
    crc_sent_ini => crc_clr,
    we           => start_send,
    din          => din_mux,
    -- read
    crc_recv_ini => crc_clr,
    dout         => dout,
    crc8sent     => crc8sent,
    crc8recv     => crc8recv);

sm: prot_sm
port map(
    clk          => clk,
    rst_n        => rstout_n,
    slaveID      => slaveID,
    -- uart status
    crc8recvOK   => crc8recvOK,
    din          => dout,
    start_send   => start_send,
    ready_s      => ready_s,
    busy_s       => busy_s,
    busy_r       => busy_r,
    valid_r      => valid_r,
    break        => break_i,
    -- crc clear
    crc_clr      => crc_clr,
    cload        => cload,
    high_b       => high_b,
    cnten        => cnten,
    -- bus interface
    we           => we,
    rd_req       => rd_req,
    sel_dout     => sel_sm,
    bus_ack      => bus_ack,
    -- status
    timeout      => open,
    crc_err      => crc_err,
    busy         => busy,

    cmd_mode     => cmd_mode_i,

    dir_send     => dir_backd_s_r,

    cmd_valid    => cmd_valid,
    cmd_data     => cmd_data);

    timeout <= not rstout_n;

    -- address register/counter
cnt: counter
generic map(N => byte_size)
port map(
    clk    => clk,
    sload  => cload,
    cnten  => cnten,
    high_b => high_b,
    d      => dout,
    q      => addr);

    data_out <= dout;

mx41: mux41
generic map(N => byte_size)
port map(
    I0  => crc8sent,
    I1  => crc8recv,
    I2  => data_in,
    I3  => dir_backd_d_r,
    SEL => sel_sm,
    Y   => din_mux);

    break <= break_i;

    -- generate busy for the user design
    dir_backd_b <= (busy_s and cmd_mode_i) or dir_backd_s_r;

    process(clk)
    begin
        if rising_edge(clk) then
            fast_m_i <= fast_m and cmd_mode_i;

            if dir_backd_s='1' and cmd_mode_i='1' and busy_s='0' and dir_backd_s_r='0' then
                dir_backd_d_r <= dir_backd_d;
                dir_backd_s_r <= '1';
                -- later some FIFO can be made here
            end if;

            if busy_s='1' or ready_s='1' or reset='1' or dir_backd_s_r='1' then
                dir_backd_s_r <= '0';
            end if;

        end if;
    end process;

    cmd_mode <= cmd_mode_i;


end;
