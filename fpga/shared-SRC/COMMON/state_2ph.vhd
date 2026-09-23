LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

entity state_2ph is
port (
    clk   : in  std_logic;
    rst   : in  std_logic;
    P1    : in  std_logic;
    P2    : in  std_logic;
    EN    : out std_logic;
    UP    : out std_logic);
end state_2ph;

architecture a of state_2ph is

type state_type is (S00, S01, S11, S10);

signal present_st, next_st : state_type;

signal p1s, p2s : std_logic;

begin

process(present_st, p1s, p2s)
begin
    EN <= '0'; -- the default is no counting
    UP <= '-';
    -- the outputs are active only when doing a state transition
    next_st <= present_st;
    case present_st is

    when S00 => if   p1s = '1' then next_st <= S10; EN <= '1'; UP <= '0';
               elsif p2s = '1' then next_st <= S01; EN <= '1'; UP <= '1';
               end if;

    when S01 => if   p1s = '1' then next_st <= S11; EN <= '1'; UP <= '1';
               elsif p2s = '0' then next_st <= S00; EN <= '1'; UP <= '0';
               end if;

    when S11 => if   p1s = '0' then next_st <= S01; EN <= '1'; UP <= '0';
               elsif p2s = '0' then next_st <= S10; EN <= '1'; UP <= '1';
               end if;

    when S10 => if   p1s = '0' then next_st <= S00; EN <= '1'; UP <= '1';
               elsif p2s = '1' then next_st <= S11; EN <= '1'; UP <= '0';
               end if;
    end case;
end process;

process(clk)
variable p12s : std_logic_vector(1 downto 0);
begin
    if clk'event and clk='1' then
        p1s <= P1; -- synchronize the inputs
        p2s <= P2; -- to the Mealy machine!
        p12s := p1s & p2s;
        if rst = '1' then -- jump to the correct state
            case p12s is
            when "00" => present_st <= S00;
            when "01" => present_st <= S01;
            when "10" => present_st <= S10;
            when "11" => present_st <= S11;
            when others => NULL;
            end case;
        else
            present_st <= next_st; -- store the next state
        end if;
    end if;
end process;

end;
