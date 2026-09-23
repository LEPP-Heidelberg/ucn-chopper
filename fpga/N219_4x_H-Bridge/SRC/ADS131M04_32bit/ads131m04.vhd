-- altera vhdl_input_version vhdl_2008

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

use work.ads131m04_pack.all;

-- $Id: ads131m04.vhd 1031 2023-11-15 17:56:08Z angelov $:

entity ads131m04 is
generic (
         SignFlag   : Boolean  := true;
         FCLK_ADC   : Positive := 32768000;
         Ndata      : Positive := 24; -- ADC data bus width
         Nchips     : Integer range 1 to 4 :=  1;  -- number of ADC chips, from 1 to 4
         UNSORTED   : Boolean := false;
         Nchannels  : Integer              := 12); -- from 4*(Nchips-1)+1 to 4*Nchips
port (
    clk             : in  std_logic;
    clk_adc         : in  std_logic; -- 2 x ADC clock out (2 x 8.192 MHz)
    rst             : in  std_logic;

    -- config bus
    we              : in  std_logic;
    addr            : in  std_logic_vector( 4 downto 0);
    wdata           : in  std_logic_vector(31 downto 0);
    rdata           : out std_logic_vector(31 downto 0);

--    debug           : out std_logic_vector(7 downto 0);
    -- SPI status
    busy            : out std_logic;

    -- ADC output direct
    adc_data_valid  : out std_logic; -- 1 clock long, new ADC data present
    adc_data        : out std_logic_vector(Nchannels*Ndata-1 downto 0); -- new ADC data

    -- ADC signals
    cs_n            : out std_logic;
    -- ADC master clock
    mclk            : out std_logic;
    sync_n          : out std_logic;
    -- ADC spi interface
    mosi            : out std_logic;
    sclk            : out std_logic_vector(Nchips-1 downto 0);
    miso            : in  std_logic_vector(Nchips-1 downto 0);
    drdy_n          : in  std_logic_vector(Nchips-1 downto 0));

end ads131m04;

architecture struct of ads131m04 is

component ads131m04_io is
generic (
         SignFlag   : Boolean  := true;
         Nchips     : Integer range 1 to 4 := 3; -- number of ADCs, from 1 to 4
         Ndata      : Positive := 24;
         UNSORTED   : Boolean := true;
         FCLK_ADC   : Positive := 32768000);
port (
    clk             : in  std_logic; -- system clock
    rst             : in  std_logic;

    -- Bus interface
    we              : in  std_logic;
    addr            : in  std_logic_vector( 4 downto 0);
    wdata           : in  std_logic_vector(31 downto 0);
    rdata           : out std_logic_vector(31 downto 0);

    clk_adc         : in  std_logic; -- 4x the desired SPI CLK (32.768 MHz when SPI clock is 8.192 MHz)

    -- to/from the SPI master
    chip_mask       : out std_logic_vector(Nchips-1 downto 0);
    drdy            : in  std_logic_vector(Nchips-1 downto 0); -- of all channels, inverted and synchron to the clk_adc
    cmd_spi_sm      : out std_logic_vector( 1 downto 0);
    auto_read       : out std_logic;
    auto_crc        : out std_logic;
    busy            : in  std_logic;
    -- if crc_is_0(i) = 1, the CRC checksum on the received data from chip(i) was ok!
    crc_is_0        : in  std_logic_vector(Nchips-1 downto 0);

    sync_n          : out std_logic;

    send_addr       : in  std_logic_vector( 1 downto 0); -- 0 - cmd, 1 - wdata, 2 - crc
    send_data       : out std_logic_vector(Ndata-1 downto 0);

    recv_valid      : in  std_logic;
    recv_addr       : in  std_logic_vector( 2 downto 0); -- 0 : Responce, 1-4: ADC data, 5: CRC
    recv_data       : in  std_logic_vector(Nchips*Ndata-1 downto 0);

    -- ADC output direct
    adc_data_valid  : out std_logic; -- 1 clock long, new ADC data present
    adc_data        : out std_logic_vector(4*Nchips*Ndata-1 downto 0)); -- new ADC data
end component;

component ads131m04_spi is
generic (
         Nchips     : Integer range 1 to 4 := 3; -- number of ADCs, from 1 to 4
         Ndata      : Positive := 24); -- number of ADCs, from 1 to 8
port (
    clk             : in  std_logic; -- 4x the desired SPI CLK

    chip_mask       : in  std_logic_vector(Nchips-1  downto 0);
    drdy            : out std_logic_vector(Nchips-1  downto 0); -- of all channels, inverted and synchron to the clk_adc
    -- decoded command, 0 - reset, 1 - start SPI transfer, 2 - send ADC SYNC, 3 - send ADC RESET
    cmd_spi_sm      : in  std_logic_vector( 1 downto 0);
    auto_read       : in  std_logic;
    auto_crc        : in  std_logic;

    -- to/from the IO module
    send_addr       : out std_logic_vector( 1 downto 0); -- 0 - cmd, 1 - wdata, 2 - crc
    send_data       : in  std_logic_vector(Ndata-1 downto 0);

    recv_valid      : out std_logic;
    recv_addr       : out std_logic_vector( 2 downto 0); -- 0, 1 : Responce, CRC, 4..7 : ADC data
    recv_data       : out std_logic_vector(Nchips*Ndata-1 downto 0);

    -- SPI status
    busy            : out std_logic;
    -- if crc_is_0(i) = 1, the CRC checksum on the received data from chip(i) was ok!
    crc_is_0        : out std_logic_vector(Nchips-1 downto 0);

    -- control outputs
    cs_n            : out std_logic;
    -- ADC master clock
    mclk            : out std_logic;
    -- ADC spi interface, CS_n permanently low
    mosi            : out std_logic;
    sclk            : out std_logic_vector(Nchips-1 downto 0);
    miso            : in  std_logic_vector(Nchips-1 downto 0);
    drdy_n          : in  std_logic_vector(Nchips-1 downto 0));
end component;

    -- to/from the SPI master
signal chip_mask    : std_logic_vector(Nchips-1  downto 0);
signal drdy         : std_logic_vector(Nchips-1  downto 0);
signal cmd_spi_sm   : std_logic_vector( 1 downto 0);
signal busy_i       : std_logic;
signal auto_read    : std_logic;
signal auto_crc     : std_logic;
signal crc_is_0     : std_logic_vector(Nchips-1 downto 0);

signal send_addr    : std_logic_vector( 1 downto 0); -- 0 - cmd, 1 - wdata, 2 - crc
signal send_data    : std_logic_vector(Ndata-1 downto 0);

signal recv_valid   : std_logic;
signal recv_addr    : std_logic_vector( 2 downto 0); -- 0 : Responce, 1-4: ADC data, 5: CRC
signal recv_data    : std_logic_vector(Nchips*Ndata-1 downto 0);

signal adc_data_i   : std_logic_vector(4*Nchips*Ndata-1 downto 0);

begin

ads131m04_io_inst: ads131m04_io
generic map(
         SignFlag   => SignFlag,
         Nchips     => Nchips,
         Ndata      => Ndata,
         UNSORTED   => UNSORTED,
         FCLK_ADC   => FCLK_ADC)
port map(
    clk             => clk,
    rst             => rst,

    -- Bus interface
    we              => we,
    addr            => addr,
    wdata           => wdata,
    rdata           => rdata,

    clk_adc         => clk_adc,

    -- to/from the SPI master
    chip_mask       => chip_mask,
    drdy            => drdy,
    cmd_spi_sm      => cmd_spi_sm,
    auto_read       => auto_read,
    auto_crc        => auto_crc,
    busy            => busy_i,
    crc_is_0        => crc_is_0,

    sync_n          => sync_n,

    send_addr       => send_addr,
    send_data       => send_data,

    recv_valid      => recv_valid,
    recv_addr       => recv_addr,
    recv_data       => recv_data,

    -- ADC output direct
    adc_data_valid  => adc_data_valid,
    adc_data        => adc_data_i);

    adc_data <= adc_data_i(Nchannels*Ndata-1 downto 0);

ads131m04_spi_inst: ads131m04_spi
generic map(
         Nchips     => Nchips,
         Ndata      => Ndata)
port map(
    clk             => clk_adc,

    chip_mask       => chip_mask,
    drdy            => drdy,
    -- decoded command, 0 - reset, 1 - start SPI transfer
    cmd_spi_sm      => cmd_spi_sm,
    auto_read       => auto_read,
    auto_crc        => auto_crc,

    -- to/from the IO module
    send_addr       => send_addr,
    send_data       => send_data,

    recv_valid      => recv_valid,
    recv_addr       => recv_addr,
    recv_data       => recv_data,

    -- SPI status
    busy            => busy_i,
    crc_is_0        => crc_is_0,

    -- control outputs
    cs_n            => cs_n,
    -- ADC master clock
    mclk            => mclk,
    -- ADC spi interface, CS_n permanently low
    mosi            => mosi,
    sclk            => sclk,
    miso            => miso,
    drdy_n          => drdy_n);

    busy <= busy_i;

end;
