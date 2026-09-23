library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity LED is
generic (
    RISING_ENABLED   : Boolean := true;
    FALLING_ENABLED  : Boolean := true;
    INVERT_IN  : Boolean := false;
    INVERT_OUT : Boolean := false); -- false for active high, true for active low
Port (
    CLK     : in  std_logic;
    Tick    : in  std_logic;  -- 1 clock long, period about 10-20 ms
    -- Sig
    I       : in  std_logic;  -- a change in the input will produce a short pulse at the output
    O       : out std_logic); -- if the input remains active (1 when invert_in is false), the output will be turned on again
end LED;

architecture a of LED is

type sm_type is (idle, triggered, pause, dauer);
signal sm : sm_type;

signal pipe : std_logic_vector(1 downto 0);

signal led_on, led_off : std_logic;
signal pipe11, pipe00  : std_logic_vector(pipe'range);

begin
    led_on  <= '0' when invert_out else '1';
    led_off <= '1' when invert_out else '0';

    pipe00  <= "00";
    pipe11  <= "11";

    process(clk)
    begin
        if rising_edge(clk) then

            if invert_in then
                pipe(0) <= not I;
            else
                pipe(0) <= I;
            end if;

            pipe(1) <= pipe(0);
            O <= led_off;
            case sm is
            when idle =>                        -- triggered by edge
                if (pipe(0)='1' and pipe(1)='0' and RISING_ENABLED ) or
                   (pipe(0)='0' and pipe(1)='1' and FALLING_ENABLED) then
                    sm <= triggered;
                elsif pipe=pipe11 then
                    sm <= dauer;
                end if;
            when triggered =>
                if tick='1' then
                    sm <= pause;
                end if;
                O <= led_on;
            when pause =>
                if tick='1' then
                    sm <= idle;
                end if;
            when dauer =>
                if pipe=pipe00 then
                    sm <= idle;
                end if;
                O <= led_on;
            end case;
        end if;
    end process;

end;
