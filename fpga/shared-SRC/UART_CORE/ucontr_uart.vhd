LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

use work.uart_pack.all;

-- $Id: ucontr_uart.vhd 65 2016-08-30 13:15:36Z angelov $:

-- Addr     Regname
--  0   w   txdr        write here to send data
--  0   r   rxdr        received data

--  1   w   txcrc       write here anything to send the CRC
--  1   r   txcrc       read the accumulated CRC of all sent data

--  2   r   rxcrc       read the accumulated CRC of all received data

--  3   w   control     Bits: 0 - clear CRC, 1 - send break (not ready)
--  3   r   status      Bits: 0 - send ready, 1 - send busy, 2 - recv ready, 3 - recv busy, 4 - recv CRC ok, 5 - recv break



entity ucontr_uart is
generic(Bittime  : Positive := 10;
        LSBfirst : Boolean  := true;
        Nfilt    : Positive := 3);
port (
    clk          : in  std_logic;
    reset        : in  std_logic;
    -- serial interface
    rx           : in  std_logic;
    tx           : out std_logic;
    -- CPU interface
    we           : in  std_logic;
--    rd           : in  std_logic; -- used to clear the flags
    addr         : in  std_logic_vector(          1 downto 0);
    data_out     : in  std_logic_vector(byte_size-1 downto 0);
    data_in      : out std_logic_vector(byte_size-1 downto 0));
end ucontr_uart;

architecture struct of ucontr_uart is

component uart is
generic(Bittime  : Positive := 10;
        Nfilt    : Positive :=  3;
        LSBfirst : Boolean  := true;
        Nbits    : Positive :=  9); -- with the parity bit
port (
    clk          : in  std_logic;
    rst_n        : in  std_logic;
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

signal dout     : std_logic_vector(byte_size-1 downto 0);
signal din_mux  : std_logic_vector(byte_size-1 downto 0);
signal status   : std_logic_vector(byte_size-1 downto 0);
signal crc8sent : std_logic_vector(7 downto 0);
signal crc8recv : std_logic_vector(7 downto 0);

signal start_send   : std_logic;

signal ready_s      : std_logic;
signal busy_s       : std_logic;
signal busy_r       : std_logic;
signal valid_r      : std_logic;

signal crc_clr      : std_logic;
signal crc8recvOK   : std_logic;
signal break_i      : std_logic;
--signal break_s      : std_logic;

signal rst_n        : std_logic;
signal ready_r_l    : std_logic;
signal ready_s_l    : std_logic;

begin
    crc8recvOK <= '1' when crc8recv = X"00" else '0';

    process(clk)
    begin
        if rising_edge(clk) then
            rst_n <= not reset;
        end if;
    end process;

uart_i: uart
generic map(Bittime  => Bittime,
            Nbits    => byte_size,
            LSBfirst => LSBfirst,
            Nfilt    => Nfilt)
port map(
    clk          => clk,
    rst_n        => rst_n,
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

    din_mux <= data_out when addr(0) = '0' else crc8sent;

    status <= "00" & break_i & crc8recvOK & busy_r & ready_r_l & busy_s & ready_s_l;

    crc_clr <= we and data_out(0) when addr="11" else '0';
--    break_s <= we and data_out(1) when addr="11" else '0';

    start_send <= we when addr(1)='0' else '0';

    process(clk)
    begin
        if rising_edge(clk) then
            if rst_n = '0' or we = '1' then
                ready_r_l <= '0';
                ready_s_l <= '0';
            else
                ready_r_l <= ready_r_l or valid_r;
                ready_s_l <= ready_s_l or ready_s;
            end if;
        end if;
    end process;


mx41: mux41
generic map(N => byte_size)
port map(
    I0  => dout,
    I1  => crc8sent,
    I2  => crc8recv,
    I3  => status,
    SEL => addr,
    Y   => data_in);

 --   break <= break_i;

end;
