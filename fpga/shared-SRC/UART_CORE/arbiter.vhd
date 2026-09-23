LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

use work.uart_pack.all;

-- $Id: arbiter.vhd 65 2016-08-30 13:15:36Z angelov $:

-- after some we_ua:
-- 1) mux addr1..3 and data1..3 to addr and wdata
-- 2) set we and the corresponding ack
-- 3) clear we and ack and go to idle

-- after some rd_ua:
-- 1) mux addr1..3 to addr
-- 2) set rd, wait n-clocks (2 may be are enough)
-- 3) set the corresponding ack
-- 4) clear rd, ack and go to idle

entity arbiter is
generic (rd_clocks : Positive := 3;
         wr_clocks : Natural  := 2;
         Nmast     : Positive := 4;
         latch_a_d : boolean  := true);
port(clk     : in  std_logic;
     reset   : in  std_logic;

     we_ua   : in  std_logic_vector(Nmast-1 downto 0);
     rd_ua   : in  std_logic_vector(Nmast-1 downto 0);
     ack_ua  : out std_logic_vector(Nmast-1 downto 0);
     -- read/write address
     addr_i  : in  std_logic_vector(Nmast*addr_size-1 downto 0);
     -- write data
     wdata_i : in  std_logic_vector(Nmast*byte_size-1 downto 0);
     -- to the bus
     addr    : out std_logic_vector(addr_size-1 downto 0);
     wdata   : out std_logic_vector(byte_size-1 downto 0);
     ready   : in  std_logic;
     rd      : out std_logic;
     we      : out std_logic);
end arbiter;

architecture a of arbiter is

component prior_reg is
generic(N : Positive := 4);
port(clk    : in  std_logic;
     ena    : in  std_logic;
     sclr   : in  std_logic;
     invec  : in  std_logic_vector(N-1 downto 0);
     outvec : out std_logic_vector(N-1 downto 0) );
end component;

component muxNto1_and_or is
generic (Nbus : Positive := 8;
         Ninp : Positive := 4);
port (
    DIN     : in  std_logic_vector(Ninp*Nbus-1 downto 0);
    SMASK   : in  std_logic_vector(Ninp-1      downto 0);
    Y       : out std_logic_vector(Nbus-1      downto 0));
end component;

type sm_type is (st_idle, st_write, st_read);

-- The syn_encoding attribute has 4 values:
-- sequential, onehot, gray and safe.
attribute syn_enum_encoding : string;
attribute syn_enum_encoding of sm_type : type is "gray";

signal sm           : sm_type;

signal rd_ua_reg    : std_logic_vector(Nmast-1 downto 0);
signal we_ua_reg    : std_logic_vector(Nmast-1 downto 0);
signal mux_mask     : std_logic_vector(Nmast-1 downto 0);
signal zero_mask    : std_logic_vector(Nmast-1 downto 0);

signal addr_muxed   : std_logic_vector(addr_size-1 downto 0);
signal wdata_muxed  : std_logic_vector(byte_size-1 downto 0);

signal sclr_rq      : std_logic;
signal ena_rq       : std_logic;

signal some_rd_rq   : std_logic;
signal some_wr_rq   : std_logic;

signal clk_cnt      : Integer range 0 to 3;

begin
    zero_mask <= (others => '0');

    ena_rq  <= '1' when sm = st_idle and some_rd_rq = '0' and some_wr_rq = '0' else '0';
    sclr_rq <= '1' when ((sm = st_write or sm = st_read) and clk_cnt = 0) or reset = '1' else '0';

rd_rq_rg: prior_reg
generic map(N => Nmast)
port map(
     clk    => clk,
     ena    => ena_rq,
     sclr   => sclr_rq,
     invec  => rd_ua,
     outvec => rd_ua_reg);

    some_rd_rq <= '1' when rd_ua_reg /= zero_mask else '0';

wr_rq_rg: prior_reg
generic map(N => Nmast)
port map(
     clk    => clk,
     ena    => ena_rq,
     sclr   => sclr_rq,
     invec  => we_ua,
     outvec => we_ua_reg);

    some_wr_rq <= '1' when we_ua_reg /= zero_mask else '0';

    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then sm <= st_idle;
            else
                case sm is
                    when st_idle =>
                        if    some_rd_rq = '1' then sm <= st_read;  clk_cnt <= rd_clocks;
                        elsif some_wr_rq = '1' then sm <= st_write; clk_cnt <= wr_clocks;
                        end if;
                    when st_read =>
                        if (clk_cnt > 1 or ready='1') and (clk_cnt /= 0) then clk_cnt <= clk_cnt - 1; end if;
                        if (rd_ua and mux_mask) = zero_mask and clk_cnt=0 then sm <= st_idle; end if;
                    when st_write =>
                        if (clk_cnt > 1 or ready='1') and (clk_cnt /= 0) then clk_cnt <= clk_cnt - 1; end if;
                        if (we_ua and mux_mask) = zero_mask and clk_cnt=0 then sm <= st_idle; end if;
                    when others => sm <= st_idle;
                end case;
            end if;
        end if;
    end process;

    with sm select
    mux_mask <= rd_ua_reg when st_read ,
                we_ua_reg when st_write,
                (others => '0') when others;

amux: muxNto1_and_or
generic map(
    Nbus => addr_size,
    Ninp => Nmast)
port map(
    DIN     => addr_i,
    SMASK   => mux_mask,
    Y       => addr_muxed);

dmux: muxNto1_and_or
generic map(
    Nbus => byte_size,
    Ninp => Nmast)
port map(
    DIN     => wdata_i,
    SMASK   => mux_mask,
    Y       => wdata_muxed);

nl: if not latch_a_d generate

    addr  <= addr_muxed;
    wdata <= wdata_muxed;

end generate;

lad: if latch_a_d generate

    process(clk)
    begin
        if rising_edge(clk) then
            addr  <= addr_muxed;
            wdata <= wdata_muxed;
        end if;
    end process;
end generate;

    we <= '1' when sm = st_write and clk_cnt = 1 else '0';
    rd <= '1' when sm = st_read  and clk_cnt = 1 else '0';

    process(sm, clk_cnt, rd_ua_reg, we_ua_reg, zero_mask)
    begin
        ack_ua <= zero_mask;
        case sm is
            when st_write => if clk_cnt = 0 then ack_ua <= we_ua_reg; end if;
            when st_read  => if clk_cnt = 0 then ack_ua <= rd_ua_reg; end if;
            when others => NULL;
        end case;
    end process;
end;
