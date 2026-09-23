LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

-- $Id: uart.vhd 979 2023-07-10 17:44:33Z angelov $:

entity uart is
generic(Bittime  : Positive := 10;
        BittimeF : Positive :=  5;
        Nfilt    : Positive := 3;
        LSBfirst : Boolean := true;
        Nidle   : Positive :=   1;
        Nbits    : Positive := 8);
port (
    clk          : in  std_logic;
    rst_n        : in  std_logic;
    fast_m       : in  std_logic := '0';
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
end uart;

architecture struct of uart is

component ser_send is
generic(Nbits   : Positive := 8; LSBfirst : Boolean := true);
port (
    clk    : in  std_logic;
    rst_n  : in  std_logic;
    load   : in  std_logic;
    din    : in  std_logic_vector(Nbits-1 downto 0);
    shift  : in  std_logic;
    parity : out std_logic;
    tx     : out std_logic);
end component;

component sendsm is
generic(Bittime : Positive := 100;
        BittimeF: Positive :=  50;
        Nidle   : Positive :=   2;
        Nbits   : Positive :=   8);
port (
    clk     : in  std_logic;
    rst_n   : in  std_logic;
    fast_m  : in  std_logic := '0';
    start   : in  std_logic;
    busy    : out std_logic;
    crc_ena : out std_logic;
    shift   : out std_logic;
    ready   : out std_logic);
end component;

component crc8reg is
generic(LSBfirst : Boolean := true);
port (
    clk    : in  std_logic;
    load   : in  std_logic;
    din    : in  std_logic;
    ena    : in  std_logic;
    crc8   : out std_logic_vector(7 downto 0));
end component;

component serial_recv is
generic(Bittime  : Positive := 10;
        Nfilt    : Positive := 3;
        LSBfirst : Boolean := true;
        Nbits    : Positive := 8);
port (
    clk          : in  std_logic;
    rst_n        : in  std_logic;
    -- serial interface
    rx           : in  std_logic;
    -- uP interface
    busy_r       : out std_logic;
    valid_r      : out std_logic;
    break        : out std_logic;
    -- read
    dout         : out std_logic_vector(Nbits-1 downto 0);

    -- optional CRC8 on the received data, calculated on the fly
    crc_recv_ini : in  std_logic;
    crc8recv     : out std_logic_vector(7 downto 0));
end component;

signal shift        : std_logic;
signal crc_sent_ena : std_logic;
signal tx_i         : std_logic;

begin

crc8snt: crc8reg
generic map(LSBfirst => LSBfirst)
port map(
    clk    => clk,
    load   => crc_sent_ini,
    din    => tx_i,
    ena    => crc_sent_ena,
    crc8   => crc8sent);

sms: sendsm
generic map(Bittime => Bittime,
            BittimeF=> BittimeF,
            Nbits   => Nbits,
            Nidle   => Nidle)
port map(
    clk     => clk,
    rst_n   => rst_n,
    fast_m  => fast_m,
    start   => we,
    busy    => busy_s,
    shift   => shift,
    crc_ena => crc_sent_ena,
    ready   => ready_s);

sbuf: ser_send
generic map(
    Nbits    => Nbits,
    LSBfirst => LSBfirst)  -- the start bit is internally added
port map(
    clk    => clk,
    rst_n  => rst_n,
    load   => we,
    din    => din,
    shift  => shift,
    parity => open,
    tx     => tx_i);

    tx <= tx_i;

ser_rcv: serial_recv
generic map(
        Bittime  => Bittime,
        Nfilt    => Nfilt,
        LSBfirst => LSBfirst,
        Nbits    => Nbits)
port map(
    clk          => clk,
    rst_n        => rst_n,
    -- serial interface
    rx           => rx,
    -- uP interface
    busy_r       => busy_r,
    valid_r      => valid_r,
    break        => break,
    -- read
    dout         => dout,

    -- optional CRC8 on the received data, calculated on the fly
    crc_recv_ini => crc_recv_ini,
    crc8recv     => crc8recv);

end;
