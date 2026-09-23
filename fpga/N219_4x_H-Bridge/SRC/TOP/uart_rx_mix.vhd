-- $Id: uart_rx_mix.vhd 1217 2026-09-03 13:17:29Z  $:
library ieee;
use ieee.std_logic_1164.all;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-- Now will mix the two rx interfaces, provided the one is inactive
-- the tx from core will be routed to the corresponding interface
entity uart_mix is
generic(
    Nint    : Integer := 2;
    Nfilt   : Integer := 3);
port(
    clk           : in  std_logic;
    reset         : in  std_logic;

    -- _dbg without inversion & filter & activity check to minimize the ressource usage,
    --      rx_dbg direct and-ed with the result of the mixing
    rx_dbg        : in  std_logic := '1';
    --      tx_dbg is just registered tx_core, tri-stated when inactive
    tx_dbg        : out std_logic;

    rx_pin        : in  std_logic_vector(Nint-1 downto 0);
    rx_inv        : in  std_logic_vector(Nint-1 downto 0);  -- static config, normally constants

    -- to/from the core logic, only once
    rx_core       : out std_logic;
    tx_core       : in  std_logic;
    tx_enable     : in  std_logic;  -- used to tri-state the TX outputs when inactive

    tx_pin        : out std_logic_vector(Nint-1 downto 0);   -- the TX pins, when inactive - tri-stated
    tx_inv        : in  std_logic_vector(Nint-1 downto 0);   -- static config, normally constants
    mask_act      : out std_logic_vector(Nint-1 downto 0) ); -- status
end uart_mix;

architecture a of uart_mix is

component filt_long is
generic (N     : Positive := 3);
port(
     clk        : in  std_logic;
     d          : in  std_logic; -- input
     inv_q      : in  std_logic; -- invert (1) or not (0) the input
     ena_edge   : in  std_logic; -- enable edge detection
     pos_edge   : out std_logic; -- rising edge of the output
     neg_edge   : out std_logic; -- falling edge of the output
     q          : out std_logic);-- filtered (eventually inverted) output
end component;

signal rx_filt      : std_logic_vector(Nint-1 downto 0);
signal pos_edge     : std_logic_vector(Nint-1 downto 0);
signal neg_edge     : std_logic_vector(Nint-1 downto 0);
signal flag_activ   : std_logic_vector(Nint-1 downto 0);
signal mask_act_i   : std_logic_vector(Nint-1 downto 0);

constant CNT_MAX   : Integer := 2**10-1;
type cnt_mat is array(0 to Nint-1) of Integer range 0 to CNT_MAX;
signal counts       : cnt_mat;

begin
-- filter and eventually invert the input pins (RX)
rx_filt_g: for i in 0 to Nint-1 generate
rx_filt_i: filt_long
generic map(N  => Nfilt)
port map(
     clk        => clk,
     d          => rx_pin(i),
     inv_q      => rx_inv(i),
     ena_edge   => '1',
     pos_edge   => pos_edge(i),
     neg_edge   => neg_edge(i),
     q          => open );

    process(clk)
    begin
        if rising_edge(clk) then

            if flag_activ(i)='0' then
                rx_filt(i) <= '1';
            end if;

            if pos_edge(i)='1' then
                rx_filt(i) <= '1';
            elsif neg_edge(i)='1' then
                rx_filt(i) <= '0';
            end if;

            if reset='1' then
                rx_filt(i) <= '1';
            end if;

        end if;
    end process;

end generate;

    process(clk)
    begin
        if rising_edge(clk) then

            for i in Nint-1 downto 0 loop
                -- mark which channels are active
                if pos_edge(i)='1' or neg_edge(i)='1' then
                    -- load the activite timer with the max value
                    counts(i)     <= CNT_MAX;
                    -- set the flag as the input changes
                    flag_activ(i) <= '1';
                elsif counts(i) /= 0 then
                    -- wait
                    counts(i) <= counts(i) - 1;
                else
                    -- clear the flag when inactive for a long time
                    flag_activ(i) <= '0';
                end if;

                -- priority encoder, find the smalles index corresponding
                -- to an still active channel
                -- when no active channel present, the last one remains unchanged!
                if flag_activ(i)='1' then
                    mask_act_i <= (others => '0');
                    mask_act_i(i) <= '1';
                end if;

                -- mux the rx to the core from the last active channel with the smalles index
                if mask_act_i(i)='1' then
                    rx_core <= rx_filt(i) and rx_dbg;
                end if;

                -- here we could activate only one of the tx pins
                -- this is not very important
                if tx_enable='1' then
                    for i in tx_pin'range loop
                        if tx_inv(i)='1' then
                            tx_pin(i) <= not tx_core;
                        else
                            tx_pin(i) <=     tx_core;
                        end if;
                    end loop;
                else
                    tx_pin <= (others => 'Z');
                end if;

            end loop;
            if tx_enable='1' then
                tx_dbg <= tx_core;
            else
                tx_dbg <= 'Z';
            end if;
        end if;
    end process;

    mask_act <= mask_act_i;

end;
