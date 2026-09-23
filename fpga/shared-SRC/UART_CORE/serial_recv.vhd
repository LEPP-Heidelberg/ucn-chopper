LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

-- $Id: serial_recv.vhd 915 2022-08-03 05:38:20Z angelov $:

entity serial_recv is
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
    dbg          : out std_logic_vector(      1 downto 0);
    dout         : out std_logic_vector(Nbits-1 downto 0);

    -- optional CRC8 on the received data, calculated on the fly
    crc_recv_ini : in  std_logic;
    crc8recv     : out std_logic_vector(7 downto 0));
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
    rst_n  : in  std_logic;
    rx     : in  std_logic;
    sample : in  std_logic;
    parity : out std_logic;
    dout   : out std_logic_vector(Nbits-1 downto 0));
end component;

component recvsm is
generic(Bittime : Positive := 100;
        Nbits   : Positive := 8);
port (
    clk    : in  std_logic;
    rst_n  : in  std_logic;
    start  : in  std_logic; -- falling detected, used as start
    redge  : in  std_logic; -- rising edge detected
    rx     : in  std_logic; -- input, used to detect timeouts (break)
    break  : out std_logic;
    sample : out std_logic;
    busy   : out std_logic;
    ready  : out std_logic);
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

crc8rec: crc8reg
generic map(LSBfirst => LSBfirst)
port map(
    clk    => clk,
    load   => crc_recv_ini,
    din    => rx_filtered,
    ena    => sample,
    crc8   => crc8recv);

rsm: recvsm
generic map(Bittime => Bittime,
            Nbits   => Nbits)
port map(
    clk    => clk,
    rst_n  => rst_n,
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
    rst_n  => rst_n,
    rx     => rx_filtered,
    sample => sample,
    parity => open,
    dout   => dout);

    dbg <= sample & rx_filtered;

end;
