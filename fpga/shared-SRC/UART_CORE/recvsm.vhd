LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

-- $Id: recvsm.vhd 663 2021-02-23 18:34:03Z angelov $:

entity recvsm is
generic(Bittime : Positive := 100;
        Nbits   : Positive := 8);
port (
    clk    : in  std_logic;
    rst_n  : in  std_logic;
    start  : in  std_logic; -- falling edge detected, used as start
    redge  : in  std_logic; -- rising edge detected, used to resynchronize
    rx     : in  std_logic; -- input, used to detect timeouts (break)
    break  : out std_logic;  -- long frame detected
    sample : out std_logic;  -- 1 clock long
    busy   : out std_logic;
    ready  : out std_logic); -- 1 clock long
end recvsm;

architecture a of recvsm is

signal bitcounter : Integer range 0 to Nbits;
signal bittimer   : Integer range 0 to Bittime-1;

type recv_state_type is (idle, wordpar, finish);
-- The syn_encoding attribute has 4 values:
-- sequential, onehot, gray and safe.
attribute syn_enum_encoding : string;
attribute syn_enum_encoding of recv_state_type : type is "gray";

signal recv_statem : recv_state_type;

signal norising  : std_logic;
signal was_break : std_logic;

begin
    process(clk)
    begin
        if rising_edge(clk) then
            sample <= '0';
            ready  <= '0';
            norising <= norising and not redge;
            case recv_statem is
                when idle =>
                    busy       <= '0';
                    norising   <= '1';
                    was_break  <= '0';
                    bittimer   <= (Bittime-1)/2;  -- was -2?
                    bitcounter <= Nbits;
                    if start = '1' then
                        recv_statem <= wordpar;
                        busy   <= '1';
                    end if;
                when wordpar =>
                    if bittimer /= 0 then
                        bittimer <= bittimer - 1;
                    else
                        bittimer <= Bittime-1;      -- init the bit timer for the next bit
                        if bitcounter /= Nbits then -- skip the start bit!
                            sample <= '1';
                        end if;
                        if bitcounter /= 0 then
                            bitcounter  <= bitcounter - 1;
                        else
                            recv_statem <= finish;
                        end if;
                    end if;
                when finish  =>
                    if bittimer = 0 then
                        if rx = '1' then
                            recv_statem <= idle;
                            ready <= not was_break;
                        else
                            was_break <= norising;
                        end if;
                    else
                        bittimer <= bittimer - 1;
                    end if;
                when others => recv_statem <= idle;
            end case;
            -- resynchronize
            if (start = '1' or redge = '1') and (Bittime > 7) then
                bittimer <= (Bittime-1)/2;
            end if;

            if rst_n = '0' then
                busy        <= '0';
                recv_statem <= idle;
                bittimer    <= (Bittime-1)/2;
                bitcounter  <= Nbits;
                norising    <= '1';
                was_break   <= '0';
            end if;
        end if;
    end process;
    break <= was_break;
end;
