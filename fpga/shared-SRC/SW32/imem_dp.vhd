-- $Id: imem_dp.vhd 1125 2024-11-14 07:05:44Z angelov $:

library ieee;
USE IEEE.std_logic_1164.ALL;
USE IEEE.std_logic_unsigned.ALL;

entity imem_dp is
generic (Ndat  : Positive := 24;
         Nrom  : Positive := 12);
port(
     WrAddress      : in  std_logic_vector(Nrom-1 downto 0);
     RdAddress      : in  std_logic_vector(Nrom-1 downto 0);
     Data           : in  std_logic_vector(Ndat-1 downto 0);
     WE             : in  std_logic;
     RdClock        : in  std_logic;
     RdClockEn      : in  std_logic;
     Reset          : in  std_logic;
     WrClock        : in  std_logic;
     WrClockEn      : in  std_logic;
     Q              : out std_logic_vector(Ndat-1 downto 0) );
end imem_dp;

architecture a of imem_dp is

component dpram is
generic (Na     : Positive := 4;
         Nd     : positive := 8;
       async_rd : Boolean := true);
port(
    clk_r   : in  std_logic;
    clk_w   : in  std_logic;
    we      : in  std_logic;
    raddr   : in  std_logic_vector(Na-1 downto 0);
    waddr   : in  std_logic_vector(Na-1 downto 0);
    din     : in  std_logic_vector(Nd-1 downto 0);
    dout    : out std_logic_vector(Nd-1 downto 0) );
end component;

begin

ram_b: dpram
generic map(Na => Nrom,
            Nd => Ndat,
            async_rd => false)
port map(
    clk_r   => RdClock,
    clk_w   => WrClock,
    we      => we,
    raddr   => RdAddress,
    waddr   => WrAddress,
    din     => Data,
    dout    => Q );

end;
