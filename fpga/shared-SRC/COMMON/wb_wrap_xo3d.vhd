-- $Id: wb_wrap_xo3d.vhd 1091 2024-07-04 13:46:08Z angelov $:

library ieee;
use ieee.std_logic_1164.all;

entity wb_wrap_xo3d is
generic(
    DEV_DENSITY          : in String  := "9400L"; -- or 4300L
    EFB_WB_CLK_FREQ      : in String  := "32.0";
    UFM0_INIT_START_PAGE : in Integer := 3581;    -- 766 for 4300
    UFM1_INIT_START_PAGE : in Integer := 3581;    -- /
    UFM2_INIT_START_PAGE : in Integer := 1149;
    UFM3_INIT_START_PAGE : in Integer :=  190);
port(
    clk           : in    std_logic;
    rst           : in    std_logic;

    debug         : out   std_logic_vector(27 downto 0);

    we            : in    std_logic;
    rd_req        : in    std_logic;
    bus_ack       : out   std_logic;
    addr          : in    std_logic_vector( 6 downto 0);
    din           : in    std_logic_vector( 7 downto 0);
    dout          : out   std_logic_vector( 7 downto 0));
end wb_wrap_xo3d;

architecture behav of wb_wrap_xo3d is

component efb_flash_xo3d is
generic(
    DEV_DENSITY          : in String  := "9400L"; -- or 4300L
    EFB_WB_CLK_FREQ      : in String  := "32.0";
    UFM0_INIT_START_PAGE : in Integer := 3581;    -- 766 for 4300
    UFM1_INIT_START_PAGE : in Integer := 3581;    -- /
    UFM2_INIT_START_PAGE : in Integer := 1149;
    UFM3_INIT_START_PAGE : in Integer :=  190);
    port (
        wb_clk_i    : in    std_logic;
        wb_rst_i    : in    std_logic;
        wb_cyc_i    : in    std_logic;
        wb_stb_i    : in    std_logic;
        wb_we_i     : in    std_logic;
        wb_adr_i    : in    std_logic_vector(7 downto 0);
        wb_dat_i    : in    std_logic_vector(7 downto 0);
        wb_dat_o    : out   std_logic_vector(7 downto 0);
        wb_ack_o    : out   std_logic;
        wbc_ufm_irq : out   std_logic);
end component;

component wb2mybus is
port(
    clk           : in    std_logic;
    rst           : in    std_logic;

    debug         : out   std_logic_vector(27 downto 0);

    wb_cyc_i      : out   std_logic;
    wb_stb_i      : out   std_logic;
    wb_we_i       : out   std_logic;
    wb_adr_i      : out   std_logic_vector(7 downto 0);
    wb_dat_i      : out   std_logic_vector(7 downto 0);
    wb_dat_o      : in    std_logic_vector(7 downto 0);
    wb_ack_o      : in    std_logic;

    we            : in    std_logic;
    rd_req        : in    std_logic;
    bus_ack       : out   std_logic;
    addr          : in    std_logic_vector( 6 downto 0);
    din           : in    std_logic_vector( 7 downto 0);
    dout          : out   std_logic_vector( 7 downto 0));
end component;

signal  wb_cyc_i    : std_logic;
signal  wb_stb_i    : std_logic;
signal  wb_we_i     : std_logic;
signal  wb_adr_i    : std_logic_vector(7 downto 0);
signal  wb_dat_o    : std_logic_vector(7 downto 0);
signal  wb_dat_i    : std_logic_vector(7 downto 0);
signal  wb_ack_o    : std_logic;

begin

wb_i: efb_flash_xo3d
generic map(
    DEV_DENSITY          => DEV_DENSITY,
    EFB_WB_CLK_FREQ      => EFB_WB_CLK_FREQ,
    UFM0_INIT_START_PAGE => UFM0_INIT_START_PAGE,
    UFM1_INIT_START_PAGE => UFM1_INIT_START_PAGE,
    UFM2_INIT_START_PAGE => UFM2_INIT_START_PAGE,
    UFM3_INIT_START_PAGE => UFM3_INIT_START_PAGE)
    port map(
        wb_clk_i    => clk,
        wb_rst_i    => rst,
        wb_cyc_i    => wb_cyc_i,
        wb_stb_i    => wb_stb_i,
        wb_we_i     => wb_we_i,
        wb_adr_i    => wb_adr_i,
        wb_dat_i    => wb_dat_i,
        wb_dat_o    => wb_dat_o,
        wb_ack_o    => wb_ack_o,
        wbc_ufm_irq => open);

wb2bus: wb2mybus
port map(
    clk           => clk,
    rst           => rst,

    debug         => debug,

    wb_cyc_i      => wb_cyc_i,
    wb_stb_i      => wb_stb_i,
    wb_we_i       => wb_we_i,
    wb_adr_i      => wb_adr_i,
    wb_dat_i      => wb_dat_i,
    wb_dat_o      => wb_dat_o,
    wb_ack_o      => wb_ack_o,

    we            => we,
    rd_req        => rd_req,
    bus_ack       => bus_ack,
    addr          => addr,
    din           => din,
    dout          => dout);
end;
