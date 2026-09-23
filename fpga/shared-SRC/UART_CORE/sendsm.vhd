LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

-- $Id: sendsm.vhd 979 2023-07-10 17:44:33Z angelov $:

entity sendsm is
generic(Bittime : Positive := 100;
        BittimeF : Positive := 50;
        Nidle   : Positive := 1;
        Nbits   : Positive := 8);
port (
    clk     : in  std_logic;
    rst_n   : in  std_logic;
    fast_m  : in  std_logic := '0';
    start   : in  std_logic;
    busy    : out std_logic;
    shift   : out std_logic;
    crc_ena : out std_logic;
    ready   : out std_logic);
end sendsm;

architecture a of sendsm is

signal bitcounter : Integer range 0 to Nbits+Nidle;
signal bittimer   : Integer range 0 to Bittime-1;
signal bittimer_ini : Integer range 0 to Bittime-1;

type send_state_type is (idle, wordpar);
-- The syn_encoding attribute has 4 values:
-- sequential, onehot, gray and safe.
attribute syn_enum_encoding : string;
attribute syn_enum_encoding of send_state_type : type is "gray";

signal send_statem : send_state_type;

begin

    bittimer_ini <= Bittime-1 when fast_m='0' else BittimeF-1;

    process(clk)
    begin
        if rising_edge(clk) then
            shift <= '0';
            ready <= '0';
            crc_ena <= '0';
            if rst_n = '0' then
                send_statem <= idle;
                bittimer    <= bittimer_ini;
                bitcounter  <= Nbits+Nidle; -- including the start bit
                ready       <= '0';
                crc_ena     <= '0';
                busy        <= '0';
            else
            case send_statem is
            when idle =>
                busy  <= '0';
                bittimer   <= bittimer_ini;
                bitcounter <= Nbits+Nidle; -- including the start bit;
                if start = '1' then
                    send_statem <= wordpar;
                    busy  <= '1';
                end if;
            when wordpar =>
                if bittimer /= 0 then
                    bittimer <= bittimer - 1;
                else
                    bittimer <= bittimer_ini;
                    shift <= '1';

                    if bitcounter /= (Nbits+Nidle) and -- start bit
                       bitcounter >= Nidle then crc_ena <= '1'; end if;

                    if bitcounter /= 0 then
                        bitcounter  <= bitcounter - 1;
                    else
                        send_statem <= idle;
                        ready <= '1';
                        busy  <= '0';
                    end if;
                end if;
            when others => send_statem <= idle;
            end case;
            end if;
        end if;
    end process;
end;
