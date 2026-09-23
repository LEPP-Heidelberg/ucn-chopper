-- $Id: dec_mux.vhd 1208 2026-08-08 16:11:40Z  $:

library ieee;
use ieee.std_logic_1164.all;

use work.config_pkg.all;

entity dec_mux is
generic (Na  : Positive := 16;
         Ndc : Integer range 16 to 32 := 16;
         Nd  : Positive := 32);
port(
    clk             : in  std_logic;
    -- from/to the bus master
    bus_we          : in  std_logic;
    bus_ena         : in  std_logic;
    -- 2 clocks delay for ack, 1 clock in each device and 1 clock here
    -- when more necessary - the device must have an own bus_ack!
    bus_ack         : out std_logic;

    addr            : in  std_logic_vector(Na-1 downto 0);
    data_read       : out std_logic_vector(Nd-1 downto 0);

    -- to the bus devices
    -- to the EFB
    we_wb           : out std_logic;
    rd_wb           : out std_logic;
    bus_ack_wb      : in  std_logic;

    drd_wb          : in  std_logic_vector(   7 downto 0);

    -- common config
    we_conf         : out std_logic;
    drd_conf        : in  std_logic_vector(Ndc-1 downto 0);

    -- I2C master to the dual DAC
    we_i2c          : out std_logic;
    drd_i2c         : in  std_logic_vector(Nd-1 downto 0);

    -- two H-bridges in the same chip DRV8262
    we_hbr          : out std_logic;
    drd_hbr         : in  std_logic_vector(Nd-1 downto 0);

    -- ADS131M04 ADCs
    we_ads          : out std_logic;
    drd_ads         : in  std_logic_vector(Nd-1 downto 0);

    -- UART output port of the CPU
    we_tx_cpu       : out std_logic;
    drd_tx_cpu      : in  std_logic_vector(Nd-1 downto 0);

    -- digital temperature sensor with 1-wire interface
    we_dtemp        : out std_logic;
    drd_dtemp       : in  std_logic_vector(Nd-1 downto 0);

    -- Pseudorandom generator to test the interface
    we_psrg_tst     : out std_logic;
    rd_psrg_tst     : out std_logic;
    bus_ack_psrg    : in  std_logic;
    drd_psrg_tst    : in  std_logic_vector(Nd-1 downto 0);

    -- Small Shared memory 512x32
    we_sh_small     : out std_logic;
    drd_sh_small    : in  std_logic_vector(Nd-1 downto 0) );
end dec_mux;

architecture a of dec_mux is

signal bus_ack_i    : std_logic;
signal bus_ack_psrg_d : std_logic;
signal bus_ack_wb_d : std_logic;
signal rd_req_del   : std_logic;

signal rd, we       : std_logic;
signal bus_ena_old  : std_logic;

signal data_rd_i    : std_logic_vector(data_read'range);

constant NO_DATA    : std_logic_vector(31 downto 16) := x"AFFE";

begin
    -- convert from wishbone-like bus to our bus
    rd <= bus_ena and not bus_ena_old and not bus_we;
    we <= bus_ena and not bus_ena_old and     bus_we;

    -- write/read enable and output data mux
    process(all)
    begin
        -- to avoid latches, clear the mux output
        data_rd_i <= (others => '0');
        -- ... and all output we/rd control signals
        we_conf     <= '0';
        we_sh_small <= '0';
        we_psrg_tst <= '0';
        we_wb       <= '0';
        rd_wb       <= '0';
        we_i2c      <= '0';
        we_ads      <= '0';
        we_hbr      <= '0';
        we_tx_cpu   <= '0';
        we_dtemp    <= '0';

        rd_psrg_tst <= '0';

        bus_ack     <= '0';

        case? addr is

            -- wishbone
            when ADDR_WB =>
                 we_wb     <= we;
                 rd_wb     <= rd;
                 bus_ack   <= bus_ack_wb_d;
                 data_rd_i(drd_wb'range) <= drd_wb;

            -- config                 0x0100..0x1FF
            when ADDR_CONF =>
                 we_conf   <= we;
                 bus_ack   <= bus_ack_i;
                 data_rd_i(drd_conf'range) <= drd_conf;

            -- Shared memory small at 0x0200..0x2FF
            when ADDR_SMALL_MEM =>
                 we_sh_small <= we;
                 data_rd_i(drd_sh_small'range) <= drd_sh_small;
                 bus_ack     <= bus_ack_i;

            when ADDR_PSRG_TST =>  -- 0x2000 .. 0x3FFF
                 we_psrg_tst <= we;
                 rd_psrg_tst <= rd;
                 data_rd_i(drd_psrg_tst'range) <= drd_psrg_tst;
                 bus_ack     <= bus_ack_psrg_d;

            when ADDR_I2C   =>
                 we_i2c    <= we;
                 bus_ack   <= bus_ack_i;
                 data_rd_i(drd_i2c'range) <= drd_i2c ;

            when ADDR_DTEMP =>
                 we_dtemp    <= we;
                 bus_ack   <= bus_ack_i;
                 data_rd_i(drd_i2c'range) <= drd_dtemp ;

            when ADDR_HBR  =>
                 we_hbr    <= we;
                 bus_ack   <= bus_ack_i;
                 data_rd_i(drd_hbr'range) <= drd_hbr;

            when ADDR_ADS =>
                 we_ads    <= we;
                 bus_ack   <= bus_ack_i;
                 data_rd_i(drd_ads'range) <= drd_ads;

            when ADDR_TX_CPU =>
                 we_tx_cpu <= we;
                 bus_ack   <= bus_ack_i;
                 data_rd_i(drd_ads'range) <= drd_tx_cpu;

            when others =>
                -- don't block the bus!
                 bus_ack   <= bus_ack_i;
                 data_rd_i(addr'range) <= addr;
                 data_rd_i(data_rd_i'high downto data_rd_i'high-7) <= x"EE";
        end case?;
    end process;

    -- bus acknoledge generation
    -- and output register
    process(clk)
    begin
        if rising_edge(clk) then
            bus_ena_old <= bus_ena;
            rd_req_del  <= rd;
            bus_ack_i   <= rd_req_del or we;
            data_read   <= data_rd_i;
            bus_ack_psrg_d <= bus_ack_psrg;
            bus_ack_wb_d <= bus_ack_wb;
        end if;
    end process;

end;
