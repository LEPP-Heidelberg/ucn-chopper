LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

-- $Id: i2c_top32_tb.vhd 1211 2026-08-19 14:35:56Z  $:

library fpga;
--use work.i2c_pack.all;

entity i2c_top32_tb is
    generic( FCLK_SYS    : Integer := 20000000; -- 20 MHz
             WITH_REP_ST : Boolean := true;
             SLV_ADR     : Integer range 0 to 127 := 16#42#);
end i2c_top32_tb;

architecture sim of i2c_top32_tb is


-- writing:
-- Offs     Bits    Name        Comment
-- 0        7 .. 0  din0        first  byte to be sent
--         15 .. 8  din1        second byte to be sent
--         23 ..16  din2        third  byte to be sent
--         31 ..24  din3        fourth byte to be sent

-- 1       7..0     saddr       the 7-bit slave address, R/W at bit 0
-- 1       10..8    cmd         command in bits 2..0 : 0 for read/write and 7 for write & repeated start & read
-- 1       13..12   length      length-1 (0..3) for read or write
-- 1       15..14   length2     length-1 (0..3) after repeated start
-- 1       16       reset       reset, ignore all other bits

-- reading:
-- Offs     Name        Comment
-- 2,3      dout0       last   byte received
--          dout1
--          dout2
--          dout3
-- 1                    bit 28 is busy

component i2c_top32 is
generic (
    waittime    : Positive := 400;
    timeoutmax  : Positive := 10;
    Nfil        : Positive := 3;
    DEL_READY   : Positive := 3);
port(
    clk     : in    std_logic;

    reset   : in    std_logic;

    we      : in    std_logic;
    addr    : in    std_logic_vector( 1 downto 0);
    CDin    : in    std_logic_vector(31 downto 0);
    CDout   : out   std_logic_vector(31 downto 0);


    scl     : out   std_logic;  -- 1 means Z, 0 means 0
    sda_i   : in    std_logic;
    sda_o   : out   std_logic); -- 1 means Z, 0 means 0
end component;

component i2c_slave is
generic (
    WITH_REP_ST     : Boolean := true;
    NFILT           : Integer range 1 to 16 := 5;
      -- I2C Slave-Adresse, 7 Bit
    SLV_ADR        : Integer range 0 to 127 := 16#42#);
port
   (
      clk            : in std_logic;
      reset          : in std_logic;

      -- I2C Takt und Daten (SDA ist open Drain)
      scl            : in  std_logic;
      -- buid the tri-stated port on the top
      sda_i          : in  std_logic;
      sda_o          : out std_logic;

      -- TX, read something
      tx_data        : in  std_logic_vector(7 downto 0);
      -- when high - data latched, can prepare the next byte
      tx_next        : out std_logic;

      -- RX
      rx_data        : out std_logic_vector(7 downto 0);
      rx_valid       : out std_logic;

      -- Slave-Status
      busy_bus       : out std_logic;
      busy_local     : out std_logic
   );
end component;

constant Tperiod        : time    := 1000000000 ns/FCLK_SYS;

constant I2C_SCL_FREQ   : Integer := 110000;
constant WAITT_I2C  : Integer := FCLK_SYS/(3*I2C_SCL_FREQ); -- 3 clocks/I2C clock period, SCL frequency = 400kHz

signal clk          : std_logic := '1';

signal reset        : std_logic := '0';

    -- to the bus
signal we           : std_logic;
    -- Addr(MSB..MSB-1)
    --      0, 1        config
    --      2           RAM with sequence0
    --      3           RAM with sequence1
subtype addr_type is std_logic_vector( 1 downto 0);
signal addr             : addr_type;
signal din              : std_logic_vector(31 downto 0);
signal dout             : std_logic_vector(31 downto 0);

      -- I2C Takt und Daten (SDA ist open Drain)
signal  scl             : std_logic;
signal  sda             : std_logic;
      -- buid the tri-stated port on the top
signal  sda_m_i         : std_logic;
signal  sda_s_i         : std_logic;
signal  sda_m_o         : std_logic;
signal  sda_s_o         : std_logic;

      -- TX, read something
signal  s_tx_data       : std_logic_vector(7 downto 0);
      -- when high - expect data at the next clock
signal  s_tx_next       : std_logic;

      -- RX
constant SLAVE_W        : std_logic_vector(7 downto 0) := conv_std_logic_vector(SLV_ADR, 7) & '0';
constant SLAVE_W_BAD    : std_logic_vector(7 downto 0) := conv_std_logic_vector(SLV_ADR+1, 7) & '0';
signal  s_rx_data       : std_logic_vector(7 downto 0);
signal  s_rx_valid      : std_logic;

      -- Slave-Status
signal  s_busy_bus      : std_logic;
signal  s_busy_local    : std_logic;

procedure write2cnf(
    signal clk  : in  std_logic;
    signal we   : out std_logic) is
begin
    wait until falling_edge(clk);
    we <= '1';
    wait until falling_edge(clk);
    we <= '0';
    wait until falling_edge(clk);
end;

procedure write_i2c(
    signal clk          : in  std_logic;
    signal we           : out std_logic;
    signal addr         : out std_logic_vector( 1 downto 0);
    constant wdata      : in  std_logic_vector(31 downto 0);
    signal bdata        : out std_logic_vector(31 downto 0);
    constant Nbytes     : in  Integer range 1 to 4;
    constant Slv_Adr    : in  Integer range 0 to 127) is
begin
    bdata <= wdata;
    addr  <= "00";
    wait until falling_edge(clk);
    we <= '1';
    wait until falling_edge(clk);
    we <= '0';
    wait until falling_edge(clk);
    bdata <= (others => '0');
    bdata( 7 downto  1) <= conv_std_logic_vector(Slv_Adr, 7);
    bdata(0) <= '0';
    bdata(13 downto 12) <= conv_std_logic_vector(Nbytes-1 , 2);
    addr  <= "01";
    wait until falling_edge(clk);
    we <= '1';
    wait until falling_edge(clk);
    we <= '0';
    wait until falling_edge(clk);
end;

procedure write_read_i2c(
    signal clk          : in  std_logic;
    signal we           : out std_logic;
    signal addr         : out std_logic_vector( 1 downto 0);
    constant wdata      : in  std_logic_vector(31 downto 0);
    signal bdata        : out std_logic_vector(31 downto 0);
    constant Nwbytes    : in  Integer range 1 to 4;
    constant Nrbytes    : in  Integer range 1 to 4;
    constant Slv_Adr    : in  Integer range 0 to 127) is
begin
    bdata <= wdata;
    addr  <= "00";
    wait until falling_edge(clk);
    we <= '1';
    wait until falling_edge(clk);
    we <= '0';
    wait until falling_edge(clk);
    bdata <= (others => '0');
    bdata( 7 downto  1) <= conv_std_logic_vector(Slv_Adr, 7);
    bdata(0) <= '0';
    bdata(10 downto  8) <= "111"; -- write, repeated start and read
    bdata(13 downto 12) <= conv_std_logic_vector(Nwbytes-1 , 2);
    bdata(15 downto 14) <= conv_std_logic_vector(Nrbytes-1 , 2);
    addr  <= "01";
    wait until falling_edge(clk);
    we <= '1';
    wait until falling_edge(clk);
    we <= '0';
    wait until falling_edge(clk);
end;

procedure read_i2c(
    signal clk          : in  std_logic;
    signal we           : out std_logic;
    signal addr         : out std_logic_vector( 1 downto 0);
    signal bdata        : out std_logic_vector(31 downto 0);
    constant Nbytes     : in  Integer range 1 to 4;
    constant Slv_Adr    : in  Integer range 0 to 127) is
begin
    bdata <= (others => '0');
    bdata( 7 downto  1) <= conv_std_logic_vector(Slv_Adr, 7);
    bdata(0) <= '1';
    bdata(13 downto 12) <= conv_std_logic_vector(Nbytes-1 , 2);
    addr  <= "01";
    wait until falling_edge(clk);
    we <= '1';
    wait until falling_edge(clk);
    we <= '0';
    wait until falling_edge(clk);
end;

procedure wait_i2c_ready(
    signal clk          : in  std_logic;
    signal addr         : out std_logic_vector( 1 downto 0);
    signal rdata        : in  std_logic_vector(31 downto 0)) is
begin
    addr  <= "01";
    wait until falling_edge(clk);
    wait until falling_edge(clk);
    wait until falling_edge(rdata(28));
end;


begin

    clk <= not clk after Tperiod/2;
    reset <= '1' after Tperiod/2, '0' after 5.5*Tperiod/2;

i2c_mast: i2c_top32
generic map(
    waittime    => WAITT_I2C)
--    timeoutmax  : Positive := 10;
--    Nfil        : Positive := 3;
--    DEL_READY   : Positive := 3);
port map(
    clk     => clk,

    reset   => reset,

    we      => we,
    addr    => addr,
    CDin    => din,
    CDout   => dout,

    scl     => scl,
    sda_i   => sda_m_i,
    sda_o   => sda_m_o);

    sda     <= '0' when sda_m_o='0' or sda_s_o='0' else 'H';
    sda_m_i <= '0' when sda='0' else '1' when sda='H' else 'X';
    sda_s_i <= '0' when sda='0' else '1' when sda='H' else 'X';

i2c_slv: i2c_slave
generic map(
      WITH_REP_ST    => WITH_REP_ST,
--    NFILT           : Integer range 1 to 16 := 5;
      -- I2C Slave-Adresse, 7 Bit
      SLV_ADR        => SLV_ADR)
port map
   (
      clk            => clk,
      reset          => reset,

      -- I2C Takt und Daten (SDA ist open Drain)
      scl            => scl,
      -- buid the tri-stated port on the top
      sda_i          => sda_s_i,
      sda_o          => sda_s_o,

      -- TX, read something
      tx_data        => s_tx_data,
      -- when high - expect data at the next clock
      tx_next        => s_tx_next,

      -- RX
      rx_data        => s_rx_data,
      rx_valid       => s_rx_valid,

      -- Slave-Status
      busy_bus       => s_busy_bus,
      busy_local     => s_busy_local);

    process(s_tx_next)
    begin
        if reset='1' then
            s_tx_data <= x"40";
        elsif falling_edge(s_tx_next) then
            s_tx_data <= s_tx_data + 1;
        end if;
    end process;

    process
    begin
        addr <= (others => '0');
        din  <= (others => '0');
        we   <= '0';
        wait until falling_edge(reset);
        wait until falling_edge(clk);

        write_i2c(clk, we, addr, x"0000ABCD", din, 2, SLV_ADR+1);

        wait_i2c_ready(clk, addr, dout);

        wait for 100*Tperiod;

        read_i2c(clk, we, addr, din, 2, SLV_ADR+2);

        wait_i2c_ready(clk, addr, dout);

        if WITH_REP_ST then
            wait for 100*Tperiod;
            write_read_i2c(clk, we, addr, x"12345678", din, 4, 3, SLV_ADR+3);
        end if;
        wait;
    end process;

end;
