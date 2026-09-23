-- $Id: byteslots.vhd 842 2022-01-24 18:39:46Z angelov $:

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

-- commands
--  00  reset, returns 0 if slaves detected
--  01  read byte, returns the read bit
--  10  write byte
--  11  output 1

entity byteslots is
generic (
    Nrst0   : Integer range 0 to 1023 := 512;  -- us, pull down time
    Nrsts   : Integer range 0 to  255 :=  80;  -- us, sample time
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
end byteslots;

architecture a of byteslots is

component timeslots is
generic (
    Nrst0   : Integer range 0 to 1023 := 512;  -- us, pull down time
    Nrsts   : Integer range 0 to  255 :=  80;  -- us, sample time
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
    retbit  : out   std_logic;
    valid   : out   std_logic);
end component;

signal retbit       : std_logic;
signal valid_bit    : std_logic;
signal start_bit    : std_logic;
signal cmd_bit      : std_logic_vector(1 downto 0);

type sm_type is (idle, wait_bitsm, reset, send_byte, recv_byte);

-- For Precision!
-- The FSM_STATE attribute has 6 possible values:
-- auto, binary, onehot, twohot, random, and gray

attribute FSM_STATE : string;
attribute FSM_STATE of sm_type : type is "gray";

attribute SAFE_FSM : boolean;
attribute SAFE_FSM of sm_type : type is true;

signal sm : sm_type;
signal bitcnt : Integer range 0 to 7;
--signal sendbuf, recvbuf : std_logic_vector(7 downto 0);
signal hold_high : std_logic;
signal oe_i, dout_i : std_logic;

begin
    oe <= oe_i or hold_high;
    dout <= dout_i or hold_high;

ts: timeslots
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
    clk     => clk,
    rst_n   => rst_n,
    -- from the master state machine
    cmd     => cmd_bit,
    start   => start_bit,
    -- to the I/O cell
    oe      => oe_i,
    dout    => dout_i,
    din     => din,
    -- to the master state machine
    retbit  => retbit,
    valid   => valid_bit);

    process(clk, rst_n)
    begin
        if rst_n = '0' then
                bitcnt <= 0;
                valid <= '1';
                start_bit <= '0';
                sm <= idle;
                hold_high <= '0';
                cmd_bit <= "00";
                retbyte <= (others => '0');
        elsif rising_edge(clk) then
            case sm is
            when idle =>
                bitcnt <= 0;
                valid <= '1';
                start_bit <= '0';
                if start='1' then
                    hold_high <= '0';
                    valid <= '0';
                    case cmd is
                    when "00" => sm <= reset;
                    when "01" => sm <= recv_byte;
                    when "10" => sm <= send_byte;
                                 --sendbuf <= wrbyte;
                    when "11" => hold_high <= '1';
                    when others => NULL;
                    end case;
                end if;
            when reset =>
                cmd_bit <= "00";
                start_bit <= '1';
                if valid_bit = '0' then
                    sm <= wait_bitsm;
                    start_bit <= '0';
                end if;
            when recv_byte =>
                cmd_bit <= "01";
                start_bit <= '1';
                if valid_bit = '0' then
                    sm <= wait_bitsm;
                    start_bit <= '0';
                end if;
            when send_byte =>
                cmd_bit <= '1' & wrbyte(bitcnt); -- write 0 ot 1
                start_bit <= '1';
                if valid_bit = '0' then
                    sm <= wait_bitsm;
                    start_bit <= '0';
                end if;
            when wait_bitsm =>
                if valid_bit = '1' then -- bit sm is ready
                    case cmd is
                    when "00" => -- reset
                        retbyte <= "0000000" & retbit; -- presence detected
                       -- retbyte <= "00000000" ; -- presence detected
                        sm <= idle;
                    when "01" => -- read
                        retbyte(bitcnt) <= retbit;
                        if bitcnt=7 then sm <= idle;
                        else
                            bitcnt <= bitcnt + 1;
                            sm <= recv_byte;
                        end if;
                    when "10" => -- write
                        if bitcnt=7 then sm <= idle;
                        else
                            bitcnt <= bitcnt + 1;
                            sm <= send_byte;
                        end if;
                    when others => sm <= idle;
                    end case;
                end if;
            when others => sm <= idle;
            end case;
        end if;
    end process;
end;
