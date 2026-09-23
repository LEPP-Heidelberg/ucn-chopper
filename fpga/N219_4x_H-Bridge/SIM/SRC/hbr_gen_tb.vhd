LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

-- $Id: hbr_gen_tb.vhd 1209 2026-08-13 09:31:10Z  $:

library fpga;
use work.hbr_gen_pkg.all;

entity hbr_gen_tb is
    generic( Td2        : time    := 10 ns;
              Na_RAM    : Integer := 10);
end hbr_gen_tb;

architecture sim of hbr_gen_tb is

component hbr_gen is
generic(Na_RAM : Integer := 10);
port(
     -- clock
    clk         : in  std_logic;
    reset       : in  std_logic;

    h_debug     : out std_logic_vector(7 downto 0);

    -- to the bus
    we          : in    std_logic;
    -- Addr(MSB..MSB-1)
    --      0, 1        config
    --      2           RAM with sequence0
    --      3           RAM with sequence1
    addr        : in    std_logic_vector(Na_RAM+1 downto 0);
    din         : in    std_logic_vector(31 downto 0);
    dout        : out   std_logic_vector(31 downto 0);

    -- status inputs
    -- active low, open-drain, with pull-up
    fault_n     : in    std_logic;

    -- Operation Modi (s. datasheet for details)
    -- TOFF - 0, 1, open, 330k to GND
    -- TOFF pin     off-time in us
    -- 0            7
    -- 1            16
    -- Hi-Z         24
    -- 330k to GND  32
    toff            : out   std_logic;
    toff_330k_gnd   : out   std_logic;

    -- decay pin        decay mode
    --  0           Slow decay (brake or high-side re-circulation)
    --  1           Smart tune dynamic decay
    -- Hi-Z         Mixed decay: 30% fast
    decay           : out   std_logic;

    -- When the OCPM pin is logic low, the device has latch-off type recovery - which means once the OCP
    -- condition is removed, normal operation resumes after applying an nSLEEP reset pulse or a power cycling.
    --
    -- When the OCPM pin is logic high, normal operation resumes automatically (driver operation and nFAULT
    -- released) after the tRETRY time has elapsed and the fault condition is removed.
    ocpm            : out   std_logic;

    -- turn all outputs off
    sleep_n         : out   std_logic;

    -- Single H-Bridge Mode (MODE1 = 1), or Dual H-Bridge Mode (MODE1 = 0)
    -- The MODE2 pin has to be grounded to select PH/EN interface.
    -- To select PWM interface, keep MODE2 pin floating or connect the MODE2 pin to DVDD.
    mode            : out   std_logic_vector(2 downto 1);
    -- 1,2 control outputs 1,2, 3,4 control outputs 3,4
    -- PH/EN MODE2=0
    -- in1/3    in2/4   out1/3  out2/4  Comment (provided sleep_n = 1)
    --  0         x       H        H    Brake (High-Side Slow Decay)
    --  1         0       L        H    Reverse (OUT2/4 -> OUT1/3)
    --  1         1       H        L    Forward (OUT1/3 -> OUT2/4)

    -- PWM MODE2=1
    -- in1/3    in2/4   out1/3  out2/4  Comment (provided sleep_n = 1)
    --  0         0     Hi-Z     Hi-Z   Coast (H-Bridge outputs Hi-Z)
    --  0         1       L        H    Reverse (OUT2/4 -> OUT1/3)
    --  1         0       H        L    Forward (OUT1/3 -> OUT2/4)
    --  1         1       H        H    Brake (High-Side Slow Decay)
    h_inp           : out   std_logic_vector(4 downto 1);
    busy            : out   std_logic_vector(2 downto 1);

    light_sw        : in    std_logic_vector(4 downto 1);

    control_ocpl    : in    std_logic_vector(2 downto 1);
    control_afbr    : in    std_logic_vector(2 downto 1) );
end component;

signal clk          : std_logic := '1';

signal reset        : std_logic := '0';

    -- to the bus
signal we           : std_logic;
    -- Addr(MSB..MSB-1)
    --      0, 1        config
    --      2           RAM with sequence0
    --      3           RAM with sequence1
subtype addr_type is std_logic_vector(Na_RAM+1 downto 0);
signal addr         : addr_type;
signal din          : std_logic_vector(31 downto 0);
signal dout         : std_logic_vector(31 downto 0);

signal h_inp        : std_logic_vector(4 downto 1);

signal control_ocpl : std_logic_vector(2 downto 1);
signal control_afbr : std_logic_vector(2 downto 1);
signal busy         : std_logic_vector(2 downto 1);

procedure write2cnf(
    signal clk  : in  std_logic;
    signal we   : out std_logic;
    constant offs : in  h_cnf_addr_type;
    signal addr : out addr_type;
    signal dout : out std_logic_vector(31 downto 0) ) is
begin
    addr <= (others => '0');
    addr(offs'range) <= offs;
    wait until falling_edge(clk);
    we <= '1';
    wait until falling_edge(clk);
    we <= '0';
    wait until falling_edge(clk);
end;

procedure write2table(
    signal clk  : in  std_logic;
    signal we   : out std_logic;
    signal dout : out std_logic_vector(31 downto 0);
    signal addr : inout addr_type;
    constant st   : in  Integer range 0 to 3;
    constant dur  : in  Integer range 0 to 255;
    constant pwr  : in  Integer range 0 to 255) is
begin
    wait until falling_edge(clk);
    we <= '1';
    dout <= (others => '0');
    dout(17 downto 0) <= conv_std_logic_vector(st , 2) &
                         conv_std_logic_vector(dur-1, 8) &
                         conv_std_logic_vector(pwr, 8);

    wait until falling_edge(clk);
    we <= '0';
    addr <= addr + 1;
    wait until falling_edge(clk);
end;

procedure write2single(
    signal clk  : in  std_logic;
    signal we   : out std_logic;
    signal dout : out std_logic_vector(31 downto 0);
    signal addr : out addr_type;
    constant ch   : in  Integer range 0 to 1;
    constant st   : in  Integer range 0 to 3;
    constant dur  : in  Integer range 0 to 255;
    constant pwr  : in  Integer range 0 to 255) is
begin
    wait until falling_edge(clk);
    we <= '1';
    dout <= (others => '0');
    dout(17 downto 0) <= conv_std_logic_vector(st , 2) &
                         conv_std_logic_vector(dur-1, 8) &
                         conv_std_logic_vector(pwr, 8);
    addr <= (others => '0');
    if ch=0 then
        addr(h_cnf_addr_type'range) <= ADDR_H_OUTP_1;
    else
        addr(h_cnf_addr_type'range) <= ADDR_H_OUTP_2;
    end if;
    wait until falling_edge(clk);
    we <= '0';
    wait until falling_edge(clk);
end;


begin

    clk <= not clk after Td2;
    reset <= '1' after Td2, '0' after 5.5*Td2;

dut: hbr_gen
--    generic(Na_RAM : Integer := 10);
port map(
     -- clock
    clk         => clk,
    reset       => reset,

    h_debug     => open,

    -- to the bus
    we          => we,
    -- Addr(MSB..MSB-1)
    --      0, 1        config
    --      2           RAM with sequence0
    --      3           RAM with sequence1
    addr            => addr,
    din             => din,
    dout            => dout,

    fault_n         => '1',
    toff            => open,
    toff_330k_gnd   => open,
    decay           => open,
    ocpm            => open,
    sleep_n         => open,
    mode            => open,
    h_inp           => h_inp,
    busy            => busy,

    light_sw        => x"0",

    control_ocpl    => control_ocpl,
    control_afbr    => control_afbr);

    process
    variable sa, len :  std_logic_vector(Na_RAM-1 downto 0);
    begin
        control_ocpl <= "00";
        control_afbr <= "00";
        addr         <= (others => '0');
        din          <= (others => '0');
        wait until falling_edge(reset);
        din(HBR_BIT_ENA_AFBR) <= '1'; -- enable
        write2cnf(clk, we, ADDR_H_CONF, addr, din);
        din <= (others => '0');
        din(2 downto 0) <= "111";
        write2cnf(clk, we, ADDR_PWM_FREQ_DIV, addr, din);

        write2single(clk, we, din, addr, 0, 1, 5, 32);
        wait until falling_edge(busy(1));

        addr <= (others => '0');
        addr(addr'high downto addr'high-1) <= "10"; -- first table
        wait until falling_edge(clk);
        sa := addr(Na_RAM-1 downto 0);
        -- put several writes here to fill the table
        --                             st  len pwr
        write2table(clk, we, din, addr, 1, 1, 120);
        write2table(clk, we, din, addr, 1, 1,  80);
        write2table(clk, we, din, addr, 2, 1,  64);
        write2table(clk, we, din, addr, 1, 1,  20);

        len := addr(Na_RAM-1 downto 0) - sa;
        --addr <= (others => '0');
        din <= (others => '0');
        -- write length - 1
        din(len'high+16 downto 16) <= len-1;
        din(sa'range) <= sa;

        write2cnf(clk, we, ADDR_SEQ_AD_RANGE_ON_1, addr, din);

        --write2cnf(clk, we, ADDR_START_ON_OFF, addr, din);

        control_afbr(1) <= '1';
        wait until falling_edge(clk);
        wait until falling_edge(clk);
        wait until falling_edge(clk);
        control_afbr(1) <= '0';

        wait;
    end process;

end;
