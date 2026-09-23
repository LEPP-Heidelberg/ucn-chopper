LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

-- $Id: serial_send.vhd 979 2023-07-10 17:44:33Z angelov $:

entity serial_send is
generic(
        LSBfirst    : Boolean  := true;
        Bittime     : Positive := 10;
        BittimeF    : Positive :=  5;
        Nidle       : Positive :=  1;
        Nbits       : Positive :=  8);
port (
    clk     : in  std_logic;
    rst_n   : in  std_logic;
    -- witch to the second (smaller) BittimeF?
    fast_m  : in  std_logic := '0';
    -- parallel data input
    start   : in  std_logic;
    din     : in  std_logic_vector(Nbits-1 downto 0);
    -- serial output
    tx      : out std_logic;
    -- status
    parity  : out std_logic;
    busy    : out std_logic;
    crc_ena : out std_logic;
    ready   : out std_logic);
end serial_send;

architecture struct of serial_send is

component ser_send is
generic(Nbits    : Positive := 8;
        LSBfirst : Boolean  := true);
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

signal shift  : std_logic;

begin

sms: sendsm
generic map(Bittime => Bittime,
            BittimeF=> BittimeF,
            Nbits   => Nbits,
            Nidle   => Nidle)
port map(
    clk     => clk,
    rst_n   => rst_n,
    fast_m  => fast_m,
    start   => start,
    busy    => busy,
    shift   => shift,
    crc_ena => crc_ena,
    ready   => ready);

sbuf: ser_send
generic map(
    Nbits    => Nbits,
    LSBfirst => LSBfirst)  -- the start bit is internally added
port map(
    clk    => clk,
    rst_n  => rst_n,
    load   => start,
    din    => din,
    shift  => shift,
    parity => parity,
    tx     => tx);

end;
