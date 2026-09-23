-- $Id: i2c_top32.vhd 1211 2026-08-19 14:35:56Z  $:
-- from IF38A_ECP5

LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library work;
use work.i2c_pack.all;

-- writing:
-- Offs     Bits    Name        Comment
-- 0        7 .. 0  din0        first  byte to be sent
--         15 .. 8  din1        second byte to be sent
--         23 ..16  din2        third  byte to be sent
--         31 ..24  din3        fourth byte to be sent

-- 1       7..0     saddr       the 7-bit slave address, R/W at bit 0
-- 1       10..8    cmd_len     command in bits 2..0 : 0 for read/write and 7 for write & repeated start & read
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

entity i2c_top32 is
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
end i2c_top32;

architecture a of i2c_top32 is

component i2c_master is
generic (waittime : Positive := 2; timeoutmax : Positive := 2; Nfil : Positive := 3; DEL_READY : Positive := 1);
port(
        clk     : in    std_logic;
        srst    : in    std_logic;
        cmd     : in    std_logic_vector(2 downto 0);
        din     : in    std_logic_vector(7 downto 0);
        status  : out   std_logic_vector(3 downto 0);
        start   : in    std_logic;
        ready   : out   std_logic;
        timeout : out   std_logic;
        dout    : out   std_logic_vector(7 downto 0);
        scl     : out   std_logic;  -- 1 means Z, 0 means 0
        sda_i   : in    std_logic;
        sda_o   : out   std_logic); -- 1 means Z, 0 means 0
end component;

component filt_short is
port(
        clk     : in    std_logic;
        din     : in    std_logic;
        dout    : out   std_logic);
end component;


type i2c_top_smtype is (idle, short,
                        rbyte1, rbyte2, rbyte3, rbyte4,
                        wbyte1, wbyte2, wbyte3, wbyte4, wbyte_s, finish);

attribute syn_enum_encoding : string;
attribute syn_enum_encoding of i2c_top_smtype : type is "gray";

subtype byte is std_logic_vector( 7 downto 0);
subtype word is std_logic_vector(15 downto 0);

signal sm       : i2c_top_smtype;

signal din_s    : byte;
signal dout_i2c : byte;

signal start_s  : std_logic;
signal ready_s  : std_logic;

signal statM    : std_logic_vector(3 downto 0);
signal statS    : std_logic_vector(3 downto 0);

signal r1w0     : std_logic;
signal cmd      : std_logic_vector( 2 downto 0);
signal cmd_s    : std_logic_vector(cmd'range);
signal saddr    : std_logic_vector( 7 downto 1);

signal start    : std_logic;

signal len      : std_logic_vector(1 downto 0); -- 1..4
signal len2     : std_logic_vector(1 downto 0); -- 1..4
signal len_s    : std_logic_vector(1 downto 0); -- 1..4
constant len00  : std_logic_vector(len_s'range) := (others => '0');

signal timeout  : std_logic;
signal timeout_l: std_logic;
signal mast_rst : std_logic;

signal sda_i_f  : std_logic;

type dout_arr_type is array(0 to 3) of byte;
signal dout     : dout_arr_type;
signal din      : dout_arr_type;


signal sm_is_idle   : std_logic;
signal CDout_i      : std_logic_vector(CDout'range);

begin
    process(clk)
    variable wdata      : std_logic_vector(15 downto 0);
    variable slv_a_v    : std_logic_vector( 6 downto 0);
    variable cmd_v      : std_logic_vector( 2 downto 0);
    variable len_v      : std_logic_vector( 1 downto 0);
    variable r1w0_v     : std_logic;
    begin
        if rising_edge(clk) then
            start <= '0';
            mast_rst <= reset;
            if we='1' then
                case addr is
                    when "00" | "10" =>
                        if sm_is_idle='1' then -- up to 4 bytes to be sent
                            din(0) <= CDin( 7 downto  0);
                            din(1) <= CDin(15 downto  8);
                            din(2) <= CDin(23 downto 16);
                            din(3) <= CDin(31 downto 24);
                        end if;
                    when "01" | "11" =>
                        r1w0_v  := CDin(0); -- r/w for the first phase of the transaction
                        slv_a_v := CDin( 7 downto  1); -- slave address without the r/w bit, same in the optional second phase!
                        saddr   <= slv_a_v;
                        cmd_v   := CDin(10 downto  8); -- 000 for simple read or write, 111 for repeated start with read (only when r1w0=0)
                                                       --     else special command (s. the package code)
                        cmd     <= cmd_v;

                        if cmd_v=CMD_RSTRT then r1w0_v := '0'; end if; -- repeated start only for write in the first phase
                        r1w0    <= r1w0_v;

                        len_v   := CDin(13 downto 12); -- 0..3 for 1..4 bytes transferred in the first phase (slave address not counted here)
                        len     <= len_v;
                        len2    <= CDin(15 downto 14); -- 0..3 for 1..4 bytes transferred in the second (read) phase

                        start   <= sm_is_idle and not CDin(16);
                        mast_rst <= CDin(16);
                    when others => NULL;
                end case;
            end if;
        end if;
    end process;

    process(all)
    variable status : std_logic_vector(31 downto 0);
    begin
        status := (others => '0');
        if sm_is_idle = '0' then
            status(28) := '1';
        end if; -- busy
        status(26 downto 25) := timeout_l & timeout;
        status(23 downto 16) := statM & statS;
        status(15 downto 14) := len2;
        status(13 downto 12) := len;
        status(10 downto  8) := cmd;
        status( 7 downto  0) := saddr & r1w0;
        CDout_i <= (others => '0');
        case addr is
            when "00" => -- what came back from the chip
                CDout_i <= din( 3) & din( 2) & din( 1) & din( 0);
            when "10" | "11" =>
                CDout_i <= dout(3) & dout(2) & dout(1) & dout(0);
            when "01" => -- status, incl slave address
                CDout_i(status'range) <= status;
--          when "11" => -- mask the unused bytes
--              case len2 is
--                  when "11" => CDout_i <= dout(3) & dout(2) & dout(1) & dout(0);
--                  when "10" => CDout_i <= x"00"   & dout(2) & dout(1) & dout(0);
--                  when "01" => CDout_i <= x"00"   & x"00"   & dout(1) & dout(0);
--                  when "00" => CDout_i <= x"00"   & x"00"   & x"00"   & dout(0);
--                  when others => CDout_i <= (others => '-');
--              end case;
            when others => NULL;
        end case;
    end process;

    process(clk)
    begin
        if rising_edge(clk) then
            CDout <= CDout_i;
        end if;
    end process;

    with sm select
    statM  <= X"0" when idle,
              X"1" when short,
              X"2" when rbyte1,
              X"3" when rbyte2,
              X"4" when rbyte3,
              X"5" when rbyte4,
              X"6" when wbyte1,
              X"7" when wbyte2,
              X"8" when wbyte3,
              X"9" when wbyte4,
              X"A" when wbyte_s,
              X"B" when others;

    process(clk)
    begin
        if rising_edge(clk) then
            start_s <= '0';
            if mast_rst='1' then
                sm <= idle;
                timeout_l <= '0';
            else
            case sm is
                when idle =>
                    sm_is_idle <= not start;
                    if start = '1' then
                        timeout_l <= '0';
                        case cmd is
                            -- NULL means simple read or write, CMD_RSTRT means write, repeated start, then read
                            when CMD_NULL | CMD_RSTRT =>
                                start_s <= '1';
                                din_s <= saddr & r1w0;
                                cmd_s <= cmd_start;
                                len_s <= len;
                                for i in 0 to 3 loop
                                    dout(i) <= (others => '0');
                                end loop;
                                if r1w0='1' then sm <= rbyte1;
                                            else sm <= wbyte1; end if;

                            when others => sm <= short; din_s <= din(0); cmd_s <= cmd; start_s <= '1';
                        end case;
                    end if;
                when rbyte1 =>
                    if ready_s = '1' then
                        sm <= rbyte2;
                        cmd_s <= cmd_putb;
                        start_s <= '1';
                    end if;
                when rbyte2 =>
                    if ready_s = '1' then
                        cmd_s <= cmd_geta;
                        start_s <= '1';
                        sm <= rbyte3;
                    end if;
                when rbyte3 =>
                    if ready_s = '1' then
                        timeout_l <= timeout_l or timeout;
                        cmd_s <= cmd_getb;
                        start_s <= '1';
                        sm <= rbyte4;
                    end if;
                when rbyte4 =>
                    if ready_s = '1' then
                        start_s <= '1';
                        dout(conv_integer(len_s)) <= dout_i2c;
                        if len_s /= len00 then
                            cmd_s <= cmd_giva;
                            sm    <= rbyte3;
                            len_s <= len_s - 1;
                        else
                            cmd_s <= cmd_stop;
                            sm <= finish;
                        end if;
                    end if;
                when short =>
                    if ready_s = '1' then
                        if cmd_s = CMD_RSTRT then -- start again a read transaction
                            din_s <= saddr & '1';
                            len_s <= len2;
                            sm    <= rbyte2;
                            cmd_s <= cmd_putb;
                            start_s <= '1';
                        else
                        sm <= idle;
                        --ready <= '1';
                        end if;
                    end if;
                when wbyte1 =>
                    if ready_s = '1' then
                        sm <= wbyte2;
                        cmd_s <= cmd_putb;
                        start_s <= '1';
                    end if;
                when wbyte2 =>
                    if ready_s = '1' then
                        cmd_s <= cmd_geta;
                        start_s <= '1';
                        sm <= wbyte3;
                    end if;
                when wbyte3 =>
                    if ready_s = '1' then
                        timeout_l <= timeout_l or timeout;
                        sm <= wbyte4;
                        din_s <= din(conv_integer(len_s));
                        cmd_s <= cmd_putb;
                        start_s <= '1';
                    end if;
                when wbyte4 =>
                    if ready_s = '1' then
                        cmd_s <= cmd_geta;
                        start_s <= '1';
                        if len_s /= len00 then
                            sm <= wbyte3;
                            len_s <= len_s - 1;
                        else
                            sm <= wbyte_s;
                        end if;
                    end if;
                when wbyte_s =>
                    if ready_s = '1' then
                        timeout_l <= timeout_l or timeout;
                        if cmd=CMD_RSTRT then
                            cmd_s <= CMD_RSTRT;
                            sm    <= short;
                        else
                            cmd_s <= cmd_stop;
                            sm    <= finish;
                        end if;
                        start_s <= '1';
                    end if;
                when finish =>
                    if stats=x"0" and ready_s='1' then
                        sm <= idle;
                    end if;
                end case;
            end if;
        end if;
    end process;

sda_fil_s: filt_short
port map(
        clk     => clk,
        din     => sda_i,
        dout    => sda_i_f);

i2c_m: i2c_master
generic map(waittime   => waittime,
            timeoutmax => timeoutmax,
            Nfil       => Nfil,
            DEL_READY  => DEL_READY)
port map(
        clk     => clk,
        srst    => mast_rst,
        cmd     => cmd_s,
        din     => din_s,
        start   => start_s,
        ready   => ready_s,
        timeout => timeout,
        dout    => dout_i2c,
        status  => statS,
        scl     => scl,
        sda_i   => sda_i_f,
        sda_o   => sda_o);

end;
