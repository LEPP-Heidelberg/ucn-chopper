-- $Id: timeslots.vhd 842 2022-01-24 18:39:46Z angelov $:

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

-- commands
--  00  reset, returns 0 if slaves detected
--  01  read, returns the read bit
--  10  write 0
--  11  write 1

entity timeslots is
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
end timeslots;

architecture a of timeslots is

function max_of_2int(int1 : Integer; int2 : Integer) return Integer is

begin
    if int1 > int2 then
        return int1;
    else
        return int2;
    end if;
end;

type sm_type is (idle, reset_low, reset_sense, reset_high,
                       read_low, read_sense,
                       write_0, write_1, finish);

-- For Precision!
-- The FSM_STATE attribute has 6 possible values:
-- auto, binary, onehot, twohot, random, and gray

attribute FSM_STATE : string;
attribute FSM_STATE of sm_type : type is "gray";

attribute SAFE_FSM : boolean;
attribute SAFE_FSM of sm_type : type is true;

signal sm : sm_type;
signal counter : Integer range 0 to max_of_2int(Nrst0, Nrst1);

begin
    process(clk, rst_n)
    begin
        if rst_n = '0' then
                valid <= '1';
                counter <= 0;
                sm <= idle;
                counter <= 0;
                retbit <= '0';
        elsif rising_edge(clk) then
            counter <= counter + 1;
            case sm is
            when idle =>
                valid <= '1';
                counter <= 0;
                if start = '1' then
                    valid <= '0'; -- like ack
                    case cmd is
                    when "00" => sm <= reset_low;
                    when "01" => sm <= read_low;
                    when "10" => sm <= write_0;
                    when "11" => sm <= write_1;
                    when others => valid <= '1'; -- no ack
                    end case;
                end if;
            when reset_low => if counter = Nrst0 then
                                counter <= 0;
                                sm <= reset_sense;
                              end if;
            when reset_sense => if counter = Nrsts then
                                retbit <= din;
                                sm <= reset_high;
                               end if;
            when reset_high => if counter = Nrst1 then
                                sm <= idle;
                               end if;
            when read_low   => if counter = Nrd then sm <= read_sense; end if;
            when read_sense => if counter = Nrds then
                                retbit <= din;
                                sm <= finish;
                               end if;
            when write_0    => if counter = Nwr0 then sm <= finish; end if;
            when write_1    => if counter = Nwr1 then sm <= finish; end if;
            when finish     => if counter = Ntts then sm <= idle; end if;
            when others     => sm <= idle;
            end case;
        end if;
    end process;

    process(clk)
    begin
        if rising_edge(clk) then -- later for power supply over the data line
            case sm is
            when idle => oe   <= '0';
                         dout <= '-';
            when reset_low =>
                         oe   <= '1';
                         dout <= '0';
            when reset_sense =>
                         oe   <= '0';
                         dout <= '-';
            when reset_high =>
                         oe   <= '0';
                         dout <= '-';
            when read_low =>
                         oe   <= '1';
                         dout <= '0';
            when read_sense =>
                         oe   <= '0';
                         dout <= '-';
            when write_0 =>
                         oe   <= '1';
                         dout <= '0';
            when write_1 =>
                         oe   <= '1';
                         dout <= '0';
            when finish =>
                         oe   <= '0';
                         dout <= '-';
            when others =>
                         oe   <= '0';
                         dout <= '-';
            end case;
        end if;
    end process;
end;
