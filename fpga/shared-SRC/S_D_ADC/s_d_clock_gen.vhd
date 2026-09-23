-- $Id: s_d_clock_gen.vhd 1158 2025-09-12 15:45:29Z angelov $:

library ieee;
use ieee.std_logic_1164.all;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-- for AMC1035 sigma-delta modulator from TI
-- when mclk 10 MHz, OSR 128, sampling rate about 80 kS/s and resolution 16 bit
entity s_d_clock_gen is
port(
    clk         : in  std_logic;
    reset       : in  std_logic;

    -- sigma delta modulator data output, MCE pin to GND! (no Manchester encoding)
    -- - changes 6 to 25 ns after mclk rising edge
    -- - therefore should be sampled shortly before the rising edge of mclk
    s_d_mod_dat : in  std_logic;
    s_d_mod_clk : out std_logic;

    -- modulator clock 9-21 MHz, here the half-period-1 in system clocks
    -- mclk_hper      Fmod
    --    0          1/2 of sys clock
    --    1          1/4 of sys clock
    --    2          1/6 of sys clock
    --    3          1/8 of sys clock
    mclk_hper   : in  std_logic_vector( 1 downto 0);

    -- to the SINC3 filter
    mdat_valid  : out std_logic;
    mdat        : out std_logic );

end s_d_clock_gen;

architecture behav of s_d_clock_gen is

signal re_mclk      : std_logic;
signal re_mclk_d    : std_logic;
signal mod_clk      : std_logic;
signal mclk_cnt     : std_logic_vector(mclk_hper'range);

signal mod_inp_reg  : std_logic;
-- to the core logic
signal mod_in_val   : std_logic;
signal mod_inp_dat  : std_logic;

begin

    process(clk)
    begin
        if rising_edge(clk) then
            -- generate the modulator clock
            re_mclk  <= '0';
            if mclk_cnt=0 then
                mclk_cnt <= mclk_hper;
                mod_clk  <= not mod_clk;
                re_mclk  <= not mod_clk; -- rising edge of mod_clk signal
            else
                mclk_cnt <= mclk_cnt - 1;
            end if;
            -- output register for clock
            s_d_mod_clk <= mod_clk;
            re_mclk_d   <= re_mclk;

            -- latch the input data, MCE=0 (no Manchester coding!)
            mod_in_val <= '0';
            -- input register, without enable
            mod_inp_reg <= s_d_mod_dat;
            -- freeze the input data
            if re_mclk_d='1' then
                mod_inp_dat <= mod_inp_reg;
                mod_in_val  <= '1';
            end if;

            if reset='1' then
                mod_inp_dat <= '0';
                mod_in_val  <= '0';
                re_mclk     <= '0';
                re_mclk_d   <= '0';
                mod_clk     <= '0';
                mclk_cnt    <= (others => '0');
            end if;

        end if;
    end process;

    mdat_valid <= mod_in_val;
    mdat       <= mod_inp_dat;

end;
