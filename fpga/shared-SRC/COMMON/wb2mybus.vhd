-- $Id: wb2mybus.vhd 84 2016-10-24 15:19:40Z angelov $:

library ieee;
use ieee.std_logic_1164.all;

entity wb2mybus is
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
end wb2mybus;

architecture behav of wb2mybus is

signal  wb_we_int   : std_logic;
signal  wb_cyc_int  : std_logic;
signal  wb_stb_int  : std_logic;
signal  we_old      : std_logic;
signal  rd_req_old  : std_logic;
signal  wb_adr_int  : std_logic_vector(7 downto 0);
signal  wb_dat_int  : std_logic_vector(7 downto 0);

begin

    process(clk)
    variable we_pe, rd_pe : std_logic;
    begin
        if rising_edge(clk) then
            we_old     <= we;
            rd_req_old <= rd_req;
            we_pe := we and not we_old;
            rd_pe := rd_req and not rd_req_old;
            if wb_ack_o='1' and wb_we_int='0' then
                dout <= wb_dat_o;
            end if;
            bus_ack <= wb_ack_o;
            if we_pe='1' then
                wb_dat_int <= din;
            end if;
            if we_pe='1' or rd_pe='1' then
                wb_cyc_int <= '1';
                wb_stb_int <= '1';
                wb_we_int  <= we;
                wb_adr_int <= '0' & addr;
            elsif wb_ack_o='1' then
                wb_cyc_int <= '0';
                wb_stb_int <= '0';
                wb_we_int  <= '0';
            end if;
            if rst='1' then
                wb_cyc_int <= '0';
                wb_stb_int <= '0';
                wb_we_int  <= '0';
                we_old     <= '0';
                rd_req_old <= '0';
            end if;
            debug <= wb_cyc_int & wb_stb_int & wb_we_int & wb_ack_o & wb_adr_int & wb_dat_int & wb_dat_o;
        end if;
    end process;

    wb_we_i  <= wb_we_int;
    wb_cyc_i <= wb_cyc_int;
    wb_stb_i <= wb_stb_int;
    wb_adr_i <= wb_adr_int;
    wb_dat_i <= wb_dat_int;

end;
