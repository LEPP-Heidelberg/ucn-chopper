LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_UNSIGNED.all;

-- $Id: ds_top.vhd 1182 2026-02-08 09:26:38Z angelov $:

library work;
use work.ds_pack.all;

entity ds_top is
generic (
    short_prog : boolean := true;
    PROG_EN : Boolean := true;
    ALARM_EN: Boolean := true;
    RegOut  : Boolean := false;
    Ndata   : Integer range 16 to 32  :=  32;  -- number of bits in the data interface, min 12!
    Nsens   : Integer range 1 to 8    :=   5;  -- number of sensors
    Nrst0   : Integer range 0 to 1023 := 512;  -- us, pull down time
    Nrsts   : Integer range 0 to  255 := 100;  -- us, sample time
    Nrst1   : Integer range 0 to 1023 := 512;  -- us, high Z time
    Nwr0    : Integer range 0 to  127 :=  80;  -- us, pull down time
    Nwr1    : Integer range 0 to   15 :=   8;  -- us, pull down time
    Nrd     : Integer range 0 to    3 :=   2;  -- us, pull down time
    Ntts    : Integer range 0 to  127 :=  90;  -- us, total time for a time slot read/write
    Nrds    : Integer range 0 to   15 :=   8); -- us, sample time for read
port (
    clk_sys : in    std_logic;
    rst     : in    std_logic; -- in clk_sys domain

    clk_1MHz: in    std_logic;

    alarm   : out   std_logic; -- alarm in some of the sensors
    pres_flag : out std_logic_vector(Nsens-1 downto 0);

    -- to the I/O cell
    oe      : out   std_logic;
    dout    : out   std_logic;
    din     : in    std_logic_vector(Nsens-1 downto 0);

    rd_id0  : out   std_logic_vector(63 downto 0);
    rd_id1  : out   std_logic_vector(63 downto 0);
    -- read port for the read bytes, 0..7, config 8..11
    we      : in    std_logic;
    addr    : in    std_logic_vector( 3 downto 0);
    CDin    : in    std_logic_vector(Ndata-1 downto 0);
    CDout   : out   std_logic_vector(Ndata-1 downto 0)
    );
end ds_top;

architecture a of ds_top is

component byteslots is
generic (
    Nrst0   : Integer range 0 to 1023 := 512;  -- us, pull down time
    Nrsts   : Integer range 0 to  255 := 180;  -- us, sample time
    Nrst1   : Integer range 0 to 1023 := 512;  -- us, high Z time
    Nwr0    : Integer range 0 to  127 :=  80;  -- us, pull down time
    Nwr1    : Integer range 0 to   15 :=   8;  -- us, pull down time
    Nrd     : Integer range 0 to    3 :=   2;  -- us, pull down time
    Ntts    : Integer range 0 to  127 :=  90;  -- us, total time for a time slot read/write
    Nrds    : Integer range 0 to   15 :=   8); -- us, sample time for read
port(
    clk     : in    std_logic;
    rst_n   : in    std_logic;
    -- from the master state machine
    cmd     : in    std_logic_vector(1 downto 0);
    start   : in    std_logic;
    -- to the I/O cell
    oe      : out   std_logic;
    dout    : out   std_logic;
    din     : in    std_logic;
    -- to the master state machine
    wrbyte  : in    std_logic_vector(7 downto 0);
    retbyte : out   std_logic_vector(7 downto 0);
    valid   : out   std_logic);
end component;

component program is
generic (short_prog : boolean := true);
port(
    raddr : in  std_logic_vector( 4 downto 0);
    tres  : in  std_logic_vector( 1 downto 0);
    tL    : in  std_logic_vector( 7 downto 0); -- T low
    tH    : in  std_logic_vector( 7 downto 0); -- T high
    rdata : out std_logic_vector(11 downto 0));
end component;

-- For Precision!
-- The FSM_STATE attribute has 6 possible values:
-- auto, binary, onehot, twohot, random, and gray

type sm_type is (idle, resets,  writeb,  readb, waitp, pullH, finish);

attribute FSM_STATE : string;
attribute FSM_STATE of sm_type : type is "gray";

attribute SAFE_FSM : boolean;
attribute SAFE_FSM of sm_type : type is true;

signal sm : sm_type;

type reg_arr12bit is array(0 to Nsens-1) of temp_reg;
type reg_arr8bit  is array(0 to Nsens-1) of std_logic_vector( 7 downto 0);

signal read_reg12   : reg_arr12bit;
signal read_reg8b   : reg_arr8bit;

signal tres         : resol_type;

signal pdata        : std_logic_vector(11 downto 0);
signal paddr        : std_logic_vector( 4 downto 0);
signal retbyte      : reg_arr8bit;
signal start_byte   : std_logic;
signal valid_byte   : std_logic_vector(0 to Nsens-1);
signal pcmd         : std_logic_vector(3 downto 0);

signal counter      : std_logic_vector(19 downto 0);

signal valid, start : std_logic;
signal rst_n        : std_logic;

signal start_man    : std_logic;
signal auto_start   : std_logic;

signal presence     : std_logic_vector(Nsens-1 downto 0);
signal oe_i         : std_logic_vector(Nsens-1 downto 0);
signal dout_i       : std_logic_vector(Nsens-1 downto 0);
signal alarm_mask   : std_logic_vector(Nsens-1 downto 0);
signal alarm_maskL  : std_logic_vector(Nsens-1 downto 0);
signal alarm_tot    : std_logic;

signal rst_1MHz     : std_logic;
signal rst_1        : std_logic;
signal alarm_thresh : std_logic_vector(11 downto 0); -- programmable

signal rdat         : std_logic_vector(Ndata-1 downto 0);

subtype read_id_type is std_logic_vector(63 downto 0);
type read_id_vector is array(0 to Nsens-1) of read_id_type;
signal read_id      : read_id_vector;

begin
    pres_flag <= not presence;

    process(clk_sys)
    variable new_th : std_logic_vector(11 downto 0);
    begin
        if rising_edge(clk_sys) then
            if rst='1' then
                alarm_thresh <= INIT_THRESH;
                tres <= TRES_INI;
                auto_start <= '1';
                start_man <= '0';
            elsif we='1' then
                alarm_maskL <= (others => '0');
                case addr(1 downto 0) is

                    when ADDR_CONFIG =>
                        if PROG_EN then
                            tres <= CDin(BIT_CNF_TRES+1 downto BIT_CNF_TRES);
                            start_man <= CDin(BIT_CNF_START);
                            auto_start <= CDin(BIT_CNF_AUTO);
                        end if;

                    when ADDR_PRESENCE => NULL;

                    when ADDR_ALARM_THRESH =>
                        if PROG_EN then
                            alarm_mask  <= (others => '0');
                            new_th     := CDin(11 downto 0);
                            new_th(11) := '0';
                            if new_th < MAX_THRESH then
                                alarm_thresh <= new_th;
                            else
                                alarm_thresh <= MAX_THRESH;
                            end if;
                        end if;

                    when ADDR_ALARM_MASK => NULL;

                    when others => NULL;
                end case;
            else

                if start='1' then start_man <= '0'; end if;

                alarm_mask <= (others => '0');
                alarm_tot  <= '0';
                if ALARM_EN then
                    for i in 0 to Nsens-1 loop
                        if read_reg12(i) > alarm_thresh then
                            alarm_mask(i) <= '1';
                            alarm_tot     <= '1';
                        end if;
                    end loop;
                    alarm_maskL <= alarm_maskL or alarm_mask;
                else
                    alarm_maskL <= (others => '0');
                end if;
            end if;
            alarm_thresh(11) <= '0'; -- no negative temperatures

            if rst='1' then -- long reset for the 1 MHz domain
                rst_1 <= '1';
            elsif rst_1MHz ='1' then
                rst_1 <= '0';
            end if;

        end if;
    end process;

    -- the long reset & start in the 1MHz domain
    process(clk_1MHz)
    begin
        if rising_edge(clk_1MHz) then
            rst_1MHz <= rst_1;
            start <= (valid and auto_start) or start_man;
        end if;
    end process;

    alarm <= alarm_tot;

    process(clk_1MHz, rst_1MHz)
    begin
        if rst_1MHz = '1' then
            valid      <= '0';
            start_byte <= '0';
            sm         <= idle;
            paddr      <= (others => '0');
            counter    <= (others => '0');
            rst_n      <= '0';
        elsif rising_edge(clk_1MHz) then
            rst_n <= '1';
            valid <= '0';
            start_byte <= '0';
            case sm is
            when idle =>
                case pcmd is
                when reset  => start_byte <= '1'; if valid_byte(0)='0' then sm <= resets; end if;
                when rd_cmd => start_byte <= '1'; if valid_byte(0)='0' then sm <= readb;  end if;
                when wr_cmd => start_byte <= '1'; if valid_byte(0)='0' then sm <= writeb; end if;
                when h_high => start_byte <= '1'; if valid_byte(0)='0' then sm <= pullH;  end if;
                when stop   => sm <= finish;
                when others => sm <= finish;
                end case;
            when resets | readb | writeb =>
                if valid_byte(0) = '1' then
                    paddr <= paddr + 1;
                    sm <= idle;
                end if;
            when pullH =>
                if valid_byte(0) = '1' then
                    counter <= pdata(7 downto 0) & X"000";
--                  counter <= X"000" & pdata(7 downto 0); -- for simulation
                    sm <= waitp;
                end if;
            when waitp =>
                if counter = 0 then
                    paddr <= paddr + 1;
                    sm <= idle;
                else
                    counter <= counter - 1;
                end if;
            when finish =>
                valid <= '1';
                if start = '1' then
                    paddr <= (others => '0');
                    sm <= idle;
                end if;
            when others => sm <= finish;
            end case;
        end if;
    end process;

prg: program
generic map (short_prog => short_prog)
port map(
    raddr => paddr,
    tres  => tres,
    tL    => tL,
    tH    => tH,
    rdata => pdata);

    pcmd <= pdata(11 downto 8);

nsensors: for i in 0 to Nsens-1 generate

wrg:process(clk_1MHz)
    begin
        if rising_edge(clk_1MHz) then

            if sm = resets and valid_byte(0)='1' then
                presence(i) <= retbyte(i)(0);
            end if;

            if sm = readb and valid_byte(0)='1' then
            case pdata(3 downto 0) is
                when x"0" => -- store the lower byte of the result
                    read_reg8b(i) <= retbyte(i);
                    -- when the resolution is < 12 bits, the LSBits are undefined => clear them
                    case tres is
                        when "00" => -- 9 bit
                            read_reg8b(i)(2 downto 0) <= "000";
                        when "01" => -- 10 bit
                            read_reg8b(i)(1 downto 0) <= "00";
                        when "10" => -- 11 bit
                            read_reg8b(i)(0) <= '0';
                        when others => NULL;
                    end case;
                when x"1" => -- copy the full 12-bit code to the output register
                    read_reg12(i) <= retbyte(i)(3 downto 0) & read_reg8b(i);

                -- 5..C - unique ID
                when x"5" => if not short_prog then read_id(i)( 7 downto  0) <= retbyte(i); end if;
                when x"6" => if not short_prog then read_id(i)(15 downto  8) <= retbyte(i); end if;
                when x"7" => if not short_prog then read_id(i)(23 downto 16) <= retbyte(i); end if;
                when x"8" => if not short_prog then read_id(i)(31 downto 24) <= retbyte(i); end if;
                when x"9" => if not short_prog then read_id(i)(39 downto 32) <= retbyte(i); end if;
                when x"A" => if not short_prog then read_id(i)(47 downto 40) <= retbyte(i); end if;
                when x"B" => if not short_prog then read_id(i)(55 downto 48) <= retbyte(i); end if;
                when x"C" => if not short_prog then read_id(i)(63 downto 56) <= retbyte(i); end if;
                when others => NULL;
            end case;

            end if;
        end if;
    end process;

with_id: if not short_prog generate
    rd_id0 <= read_id(0);

more_than1: if Nsens > 1 generate
            rd_id1 <= read_id(1);
        else generate
            rd_id1 <= (others => '0');
        end generate;

else generate
        rd_id0 <= (others => '0');
        rd_id1 <= (others => '0');
end generate;

bsl: byteslots
generic map(
    Nrst0   => Nrst0,
    Nrsts   => Nrsts,
    Nrst1   => Nrst1,
    Nwr0    => Nwr0,
    Nwr1    => Nwr1,
    Nrd     => Nrd,
    Ntts    => Ntts,
    Nrds    => Nrds)
port map(
    clk     => clk_1MHz,
    rst_n   => rst_n,
    -- from the master state machine
    cmd     => pdata(9 downto 8),
    start   => start_byte,
    -- to the I/O cell
    oe      => oe_i(i),
    dout    => dout_i(i),
    din     => din(i),
    -- to the master state machine
    wrbyte  => pdata(7 downto 0),
    retbyte => retbyte(i),
    valid   => valid_byte(i));
end generate;

    oe   <= oe_i(0);
    dout <= dout_i(0);

    process(addr, read_reg12, presence, alarm_thresh, alarm_mask, tres, auto_start, start_man, alarm_maskL)
    variable saddr : std_logic_vector(addr'high-1 downto 0);
--    variable dual_mask : std_logic_vector(2*Nsens-1 downto 0);
    begin
        rdat <= (others => '0');
        saddr := addr(addr'high-1 downto 0);
--        dual_mask := alarm_mask & alarm_maskL;

        if addr(addr'high)='1' then
            case addr(1 downto 0) is

            when ADDR_CONFIG =>
                rdat(BIT_CNF_TRES+tres'length-1 downto BIT_CNF_TRES) <= tres;
                rdat(BIT_CNF_AUTO)  <= auto_start;
                rdat(BIT_CNF_START) <= start_man;
                rdat(BIT_NSENSORS+3 downto BIT_NSENSORS) <= conv_std_logic_vector(Nsens, 4);

            when ADDR_PRESENCE =>
                rdat(Nsens-1 downto 0) <= not presence;
                rdat(BIT_NSENSORS+3 downto BIT_NSENSORS) <= conv_std_logic_vector(Nsens, 4);

            when ADDR_ALARM_THRESH =>
                if ALARM_EN then
                    rdat(alarm_thresh'range) <= alarm_thresh;
                    rdat(BIT_NSENSORS+3 downto BIT_NSENSORS) <= conv_std_logic_vector(Nsens, 4);
                else
                    NULL;
                end if;

            when ADDR_ALARM_MASK =>
                if ALARM_EN then
                    rdat(alarm_maskL'range) <= alarm_maskL;
                    rdat(Nsens+8-1 downto 8) <= alarm_mask;
                else
                    NULL;
                end if;

            when others => NULL;
            end case;
        else
            for i in 0 to Nsens-1 loop
                if conv_integer(saddr)=i then
                    rdat(11 downto 0) <= read_reg12(i);
                end if;
            end loop;
        end if;
    end process;


with_o_reg: if RegOut generate
    process(clk_sys)
    begin
        if rising_edge(clk_sys) then
            CDout <= rdat;
        end if;
    end process;
else generate

    CDout <= rdat;

end generate;

end;
