LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.all;
USE IEEE.STD_LOGIC_UNSIGNED.all;

-- $Id: test_reg.vhd 849 2022-02-08 10:08:53Z angelov $:

entity test_reg is
generic (
    Nbits       : Positive :=  8;  -- max 8..32
    Abits       : Positive range 2 to 16);
port (
    clk         : in  std_logic;
    reset       : in  std_logic;

    we          : in  std_logic;
    rd          : in  std_logic;
    ack         : out std_logic;
    addr        : in  std_logic_vector(Abits-1 downto 0);
    wdata       : in  std_logic_vector(Nbits-1 downto 0);
    rdata       : out std_logic_vector(Nbits-1 downto 0));
end test_reg;

architecture a of test_reg is

function psrg(lenM1 : integer; sr : std_logic_vector) return std_logic is
variable bit0 : std_logic;
begin
    case lenM1 is
        when 31 => bit0 := sr(31) xor sr(21) xor sr( 1) xor sr( 0);
        when 30 => bit0 := sr(30) xor sr(27);
        when 29 => bit0 := sr(29) xor sr( 5) xor sr( 3) xor sr( 0);
        when 28 => bit0 := sr(28) xor sr(26);
        when 27 => bit0 := sr(27) xor sr(24);
        when 26 => bit0 := sr(26) xor sr( 4) xor sr( 1) xor sr( 0);
        when 25 => bit0 := sr(25) xor sr( 5) xor sr( 1) xor sr( 0);
        when 24 => bit0 := sr(24) xor sr(21);
        when 23 => bit0 := sr(23) xor sr(22) xor sr(21) xor sr(16);
        when 22 => bit0 := sr(22) xor sr(17);
        when 21 => bit0 := sr(21) xor sr(20);
        when 20 => bit0 := sr(20) xor sr(18);
        when 19 => bit0 := sr(19) xor sr(16);
        when 18 => bit0 := sr(18) xor sr( 5) xor sr( 1) xor sr( 0);
        when 17 => bit0 := sr(17) xor sr(10);
        when 16 => bit0 := sr(16) xor sr(13);
        when 15 => bit0 := sr(15) xor sr(14) xor sr(12) xor sr( 3);
        when 13 => bit0 := sr(13) xor sr( 4) xor sr( 2) xor sr( 0);
        when 12 => bit0 := sr(12) xor sr( 3) xor sr( 2) xor sr( 0);
        when 11 => bit0 := sr(11) xor sr( 5) xor sr( 3) xor sr( 0);
        when 10 => bit0 := sr(10) xor sr( 8);
        when  9 => bit0 := sr( 9) xor sr( 6);
        when  8 => bit0 := sr( 8) xor sr( 4);
        when  7 => bit0 := sr( 7) xor sr( 5) xor sr( 4) xor sr( 3);
        when  4 => bit0 := sr( 4) xor sr( 2);
        when 14 | 6 | 5 | 3 | 2 =>
                  bit0 := sr(lenM1) xor sr(lenM1-1);
        when others => bit0 := '-';
    end case;
    return bit0;
end;


-- Abits=2 means no memory like port, only FIFO port

-- Offset 0 - FIFO output register (FIFO read),  seed point (write once)
--                \ reading from here delivers the data from the pattern generator

-- Offset 1 - FIFO input  register (FIFO write), number of errors (read once)
--                \ writing here checks the input data against the test pattern generator (counting errors)

-- Offset 2 - config register
-- Bits 1..0: TP (0 - count down, 1 - count up, 2 - walking 1, 3 - psrg)
-- Bits 6..2: number of bits in TP, from 4-1 to max Nbits-1 for 4..Nbits
-- writing anything here clears the error counter for incoming data and the word counter (both FIFO modes)

-- Offset 3 - word counter for the last FIFO transactions, cleared when writing to the config register


-- Abits>2 means emulate memory of size 2**(Abits-1) words
-- offset 0..2**(Abits-2)-1 are for configuration & status, only offsets 0..3 are used as above
-- offset 2**(Abits-2)..2**(Abits-1)-1 is "memory",

--  writing there from Offset 0..2**(Abits-2)-1 checks the input data against the test pattern generator
--  reading from there delivers the data from the pattern generator



constant tp_data0 : std_logic_vector(Nbits-1 downto 0) := (others => '0');
signal mask     : std_logic_vector(Nbits-1 downto 0);
signal tp_data  : std_logic_vector(Nbits-1 downto 0);
signal w_tp     : std_logic_vector(Nbits-1 downto 0);
signal err_cnt  : std_logic_vector(Nbits-1 downto 0);
signal all_cnt  : std_logic_vector(Nbits-1 downto 0);
signal seed_pt  : std_logic_vector(Nbits-1 downto 0);
signal cfg_reg  : std_logic_vector(      6 downto 0);

signal clr_err  : std_logic;
signal err_flg  : std_logic;
signal new_in   : std_logic;
signal new_out  : std_logic;
signal load_tp  : std_logic;
signal we_old   : std_logic;
signal rd_old   : std_logic;

signal lenM1    : Integer range 0 to 31;

begin
    process(clk)
    variable we_re : std_logic;
    variable rd_re : std_logic;
    variable ad_cf : std_logic_vector(2 downto 0);
    begin
        if rising_edge(clk) then
            new_in  <= '0';
            new_out <= '0';
            load_tp <= '0';
            clr_err <= reset;
            if Abits=2 then
                ad_cf := '0' & addr;
            else
                ad_cf := addr(addr'high) & addr(1 downto 0);
            end if;

            we_old <= we;
            rd_old <= rd;
            we_re := we and not we_old;
            rd_re := rd and not rd_old;
            ack <= we_re or rd_re;

            if we_re='1' then
                case? ad_cf is
                    when "000" =>  -- FIFO out, seed reg in
                        seed_pt <= wdata;
                        load_tp <= '1';
                    when "001" =>  -- FIFO in, err cnt out
                        w_tp    <= wdata;
                        new_in  <= '1';
                    when "010" =>
                        cfg_reg <= wdata(cfg_reg'range);
                        load_tp <= '1';
                        case wdata(1 downto 0) is
                            when "00" => seed_pt <= (others => '1');
                            when "01" => seed_pt <= (others => '0');
                            when "10" => seed_pt <= (0 => '1', others => '0');  -- walking 0
                            when "11" => seed_pt <= (0 => '1', others => '0');  -- psrg
                            when others => NULL;
                        end case;
                        clr_err <= '1';
                    when "011" =>
                        clr_err <= '1';
                    when "1--" =>
                        w_tp    <= wdata;
                        new_in  <= '1';
                    when others => NULL;
                end case?;
            end if;

            if rd_re='1' then
                rdata <= (others => '0');
                case? ad_cf is
                    when "000" =>
                        rdata <= tp_data;
                        new_out <= '1';
                    when "001" =>
                        rdata <= err_cnt;
                    when "010" =>
                        rdata(cfg_reg'range) <= cfg_reg;
                    when "011" =>
                        rdata <= all_cnt;
                    when "1--" =>
                        rdata <= tp_data;
                        new_out <= '1';
                    when others => NULL;
                end case?;
            end if;

        end if;
    end process;

    process(clk)
    variable bits : Integer range 0 to 31;
    begin
        if rising_edge(clk) then

            if clr_err='1' then
                all_cnt <= (others => '0');
                err_cnt <= (others => '0');
            else
                if err_flg='1' then
                    err_cnt <= err_cnt + 1;
                end if;

                if new_in='1' or new_out='1' then
                    all_cnt <= all_cnt + 1;
                end if;

            end if;

            if load_tp='1' then
                mask <= (others => '0');
                bits := conv_integer(cfg_reg(6 downto 2));
                lenM1 <= bits;
                for i in 0 to Nbits-1 loop
                    if i <= bits then
                        mask(i) <= '1';
                    end if;
                end loop;
            end if;

        end if;
    end process;

    process(clk)
    variable new_tp : std_logic_vector(Nbits-1 downto 0);
    begin
        if rising_edge(clk) then

            err_flg <= '0';

            if new_in='1' then
                if w_tp /= tp_data then
                    err_flg <= '1';
                end if;
            end if;

            new_tp := tp_data;

            if load_tp='1' then
                new_tp := seed_pt and mask;
            elsif new_in='1' or new_out='1' then
                case cfg_reg(1 downto 0) is
                    when "00" => -- count down
                        new_tp := tp_data - 1;
                        new_tp := new_tp and mask;
                    when "01" => -- count up
                        new_tp := tp_data + 1;
                        new_tp := new_tp and mask;
                    when "10" => -- walking 1
                        new_tp := tp_data(tp_data'high-1 downto 0) & '0';
                        new_tp := new_tp and mask;
                        if new_tp=tp_data0 then
                            new_tp(0) := '1';
                        end if;
                    when "11" => -- psrg
                        new_tp := tp_data(tp_data'high-1 downto 0) & psrg(lenM1, tp_data);
                        new_tp := new_tp and mask;
                        if new_tp=tp_data0 then
                            new_tp(0) := '1';
                        end if;
                    when others => NULL;
                end case;
            end if;

            tp_data <= new_tp;

        end if;
    end process;
end;
