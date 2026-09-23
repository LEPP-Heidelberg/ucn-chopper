-- $Id: uart_switch.vhd 1208 2026-08-08 16:11:40Z  $:

-- this is the switch on the HV side

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

entity uart_switch is
port(
    clk         : in    std_logic;
    reset       : in    std_logic;

    uart_busy   : in    std_logic;                    -- don't switch anything while a packet is in any UART

    uart_sel    : in    std_logic_vector(1 downto 0);
    -- 1..0 : tx mux for the enabled tx ports
    --                0 - config data only
    --                1 - config & ADC data
    --                2 - ADC data only
    --                3 - echo

    tx_opt      : out   std_logic; -- output to the optical link
    tx_usb      : out   std_logic;

    -- link to the core logic
    rx_conf     : in    std_logic;
    tx_conf     : in    std_logic;
    tx_cpu      : in    std_logic);  -- from the CPU core, output stream only
end uart_switch;

architecture a of uart_switch is

signal uart_sel_s   : std_logic_vector(uart_sel'range);

begin
    -- don't change the uart_sel for the mux below while a uart packet is running!
    process(clk)
    begin
        if rising_edge(clk) then
            if uart_busy='0' then
                uart_sel_s <= uart_sel;
            end if;
        end if;
    end process;

    process(clk)
    variable tx_eff   : std_logic;
    begin
        if rising_edge(clk) then
            case uart_sel_s is

                when "00" => -- only config data
                    tx_eff := tx_conf;

                when "01" => -- mixed config & CPU data
                    tx_eff := tx_cpu and tx_conf;

                when "10" => -- only CPU data
                    tx_eff := tx_cpu;

                when others => -- echo
                    tx_eff := rx_conf;
            end case;
            tx_opt <= tx_eff;
            tx_usb <= tx_eff;
        end if;
    end process;
end;
