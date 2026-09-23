
-- $Id: s_d_top.vhd 1172 2025-12-29 08:58:29Z angelov $:

library ieee;
use ieee.std_logic_1164.all;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-- with clk 32.768 MHz and mclk_hper=0 we get Fmod=16.384 MHz (no Manch. encoding)

-- Address      R/W         Bits        Comment
--   0          r/w         2..0        OSR code 0..7
--              r/w           4         Enable
--              r/w         6..5        Zoom code 0..3
--              r/w        15..8        Decimation-1
--              r            16         compiled for Manchester encoding?
--              r            17         compiled with long latency?
--              r           19..18      modulation clk divider code: 0..3 for 1/2, 1/4, 1/6 and 1/8
--              r            20         use the ADC clock for modulation clock (only when Manchester encoding used)
-- writing anything to this address resets the digital filters and clears the valid flag!

-- when writing:
-- bit 4 - 1 to clear the valid flag (auto cleared)
-- bit 5 - 1 to reset (auto cleared)
-- bit 4 - enable the I/Os of SU connector for the Sigma-Delta Modulator
-- bits 2..0 - OSR code
-- when LOG2OSR_MAX=12:
    -- osr code        OSR           Sampling Rate, kS/s, when Fmod=16.384 MHz
    --    0            32            512
    --    1            64            256
    --    2           128            128
    --    3           256             64
    --    4           512             32
    --    5          1024             16
    --    6          2048              8
    --    7          4096              4

-- when LOG2OSR_MAX=13:
    -- osr code        OSR           Sampling Rate, kS/s, when Fmod=16.384 MHz
    --    0            64            256
    --    1           128            128
    --    2           256             64
    --    3           512             32
    --    4          1024             16
    --    5          2048              8
    --    6          4096              4
    --    7          8192              2

-- when LOG2OSR_MAX=14:
    -- osr code        OSR           Sampling Rate, kS/s, when Fmod=16.384 MHz
    --    0           128            128
    --    1           256             64
    --    2           512             32
    --    3          1024             16
    --    4          2048              8
    --    5          4096              4
    --    6          8192              2
    --    7         16384              1

-- Address
--  0       r/w     OSR(2..0), Enable(4), decimation (15..8)
--                  writing activates a reset and clear!

--  1       w cmd   RST(bit 0), clears the valid flag
--  1       r       data(15..0), Valid(16), Overflow(17), OSRcode(20..18)

entity s_d_top is
generic(
        -- long latency, as in the original Xilinx code?
        LONG_LAT    : boolean := false;
        LOG2OSR_MAX : Integer range 12 to 14 := 12;
        UNIPOLAR    : boolean := true;
        TWO_S_COMPL : boolean := false; -- ignored when unipolar
        -- use the ADC clock in design when generating the modulator clock, otherwise use the system clock (only in Manch. coding)
        USE_ADC_CLK4GEN : boolean := false;
        -- Manchester encoded data, use s_d_mod_d_n as samples at the falling edge
        Manch_Enc   : boolean := false);

port(
    clk_sys     : in  std_logic; -- about 48 MHz
    reset       : in  std_logic;

    clk_adc     : in  std_logic; -- 32.768 MHz

    -- sigma delta modulator data output, MCE pin to GND! (no Manchester encoding)
    -- - changes 6 to 25 ns after mclk rising edge
    -- - therefore should be sampled shortly before the rising edge of mclk
    s_d_mod_dat : in  std_logic;
    s_d_mod_d_n : in  std_logic := '0'; -- at falling edge, in case of Manch. encoded data
    s_d_mod_clk : out std_logic;
    sigm_del_en : out std_logic;

    -- modulator clock 9-21 MHz, here the half-period-1 in system clocks
    -- mclk_hper      Fmod
    --    0          1/2 of sys clock
    --    1          1/4 of sys clock
    --    2          1/6 of sys clock
    --    3          1/8 of sys clock
    mclk_hper   : in  std_logic_vector( 1 downto 0);

    -- write configuration (OSR, enable, decimation, reset & clear), read data & status
    we          : in  std_logic;
    addr0       : in  std_logic;
    din         : in  std_logic_vector(31 downto 0);
    -- combined output, 15..0 - ADC, Valid(16), Overflow(17), OSRcode(20..18)
    dout        : out std_logic_vector(31 downto 0);

--                clr_valid & dec_ok & reset_adc & tgl_valid
    debug       : out std_logic_vector( 3 downto 0);

    -- ADC output, in clk_sys domain
    adc_ovfl    : out std_logic;
    adc_valid   : out std_logic;
    adc_dout    : out std_logic_vector(15 downto 0) );
end s_d_top;

architecture struct of s_d_top is

-- for AMC1035 sigma-delta modulator from TI
-- when mclk 10 MHz, OSR 128, sampling rate about 80 kS/s and resolution 16 bit
component s_d_clock_gen is
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
end component;

component sinc3xil is
generic(
        LOG2OSR_MAX : Integer range 12 to 14 := 12;
        UNIPOLAR    : boolean := true;
        TWO_S_COMPL : boolean := false; -- ignored when unipolar
        LONG_LAT    : boolean := false);
port(
    clk         : in  std_logic;
    reset       : in  std_logic;

    mod_inp_dat : in  std_logic;
    mod_inp_val : in  std_logic;

    -- osr code        OSR
    --    0            32
    --    1            64
    --    2           128
    --    3           256
    --    4           512
    --    5          1024
    --    6          2048
    --    7          4096
    osr_code    : in  std_logic_vector( 2 downto 0);
    zoom_code   : in  std_logic_vector( 1 downto 0);
    -- ADC output
    adc_ovfl    : out std_logic;
    adc_rng_ok  : out std_logic; -- when zooming
    adc_valid   : out std_logic;
    adc_dout    : out std_logic_vector(15 downto 0) );

end component;

component manch_dec_ddr is
generic(BIT_CLKS : Positive := 8);  -- system DDR transitions in one serial bit, +/- 1 clocks are acceptable
port(
    clk         : in  std_logic;
    reset       : in  std_logic;

    inp_dat     : in  std_logic_vector(0 to 1); -- 0 - older sample, 1 - newer sample from the input DDR cell
    -- ADC output
    out_valid   : out std_logic;
    out_data    : out std_logic );
end component;

-- at addr 1
-- adc data in bits 15..0
constant BIT_VALID : Integer := 16;
constant BIT_OVFL  : Integer := 17;
constant BIT_RNG_OK: Integer := 18;
constant BIT_OSRS  : Integer := 19;
-- at addr 0
constant BIT_OSRC  : Integer :=  0;
constant BIT_ENAC  : Integer :=  4;
constant BIT_ZOOMC : Integer :=  5; -- 5..6 zoom code
-- decimation 0..255 for 1:1 to 1:256, program decimation-1 at bits 15..8 in the config register!
constant BIT_DEC   : Integer :=  8; -- start bit for decimation of the samples at the sinc3 filter output
constant BITS_DEC  : Integer :=  8; -- number of bits in decimation /
constant BIT_MANCH : Integer :=  BIT_DEC+BITS_DEC;
constant BIT_LONG_L: Integer :=  BIT_MANCH+1;
constant BIT_CLK_S : Integer :=  BIT_LONG_L+1; -- 5..6 mclk_hper, 7 - 1 when USE_ADC_CLK4GEN


signal mdat_valid  : std_logic;
signal mdat        : std_logic;

signal adc_ovfl_i  : std_logic;
signal adc_ovfl_r  : std_logic;
signal adc_valid_a : std_logic;
signal adc_dout_a  : std_logic_vector(15 downto 0);
signal adc_dout_r  : std_logic_vector(adc_dout_a'range);

signal dout_r      : std_logic_vector(dout'range);

signal tgl_valid   : std_logic := '0';
signal adc_val2    : std_logic;
signal reset_adc   : std_logic;
signal tgl_val_s   : std_logic;
signal tgl_val_2   : std_logic;
signal reset_pip   : std_logic_vector(3 downto 0);

signal dec_cnt     : std_logic_vector(BITS_DEC-1 downto 0);
signal dec_ini     : std_logic_vector(BITS_DEC-1 downto 0);

signal dec_ok      : std_logic;

signal io_ena      : std_logic;
signal clr_valid   : std_logic;
signal sft_reset   : std_logic;
    -- osr code        OSR           Sampling Rate, kS/s, when Fmod=16.384 MHz
    --    0            32            512
    --    1            64            256
    --    2           128            128
    --    3           256             64
    --    4           512             32
    --    5          1024             16
    --    6          2048              8
    --    7          4096              4
signal osr_code    : std_logic_vector( 2 downto 0);
signal osr_code_a  : std_logic_vector( 2 downto 0);
signal zoom_code   : std_logic_vector( 1 downto 0);
signal zoom_code_a : std_logic_vector( 1 downto 0);

signal clk_gen     : std_logic;

signal adc_rng_ok  : std_logic; -- when zooming

begin

with_manch: if Manch_Enc generate
manch_dec_i: manch_dec_ddr
--generic(BIT_CLKS : Positive := 8);  -- system DDR transitions in one serial bit, +/- 1 clocks are acceptable
port map(
    clk         => clk_adc,
    reset       => reset_adc,

    inp_dat(0)  => s_d_mod_dat, -- older data
    inp_dat(1)  => s_d_mod_d_n, -- newer data
    -- ADC output
    out_valid   => mdat_valid,
    out_data    => mdat);

    clk_gen <= clk_adc when USE_ADC_CLK4GEN else clk_sys;

-- for AMC1035 sigma-delta modulator from TI
-- when mclk 10 MHz, OSR 128, sampling rate about 80 kS/s and resolution 16 bit
clk_gen_i: s_d_clock_gen
port map(
    clk         => clk_gen, -- or clk_adc
    reset       => reset_adc,

    -- sigma delta modulator data output, MCE pin to GND! (no Manchester encoding)
    -- - changes 6 to 25 ns after mclk rising edge
    -- - therefore should be sampled shortly before the rising edge of mclk
    s_d_mod_dat => '0', -- not used in this case
    s_d_mod_clk => s_d_mod_clk,

    -- modulator clock 9-21 MHz, here the half-period-1 in system clocks
    -- mclk_hper      Fmod
    --    0          1/2 of sys clock
    --    1          1/4 of sys clock
    --    2          1/6 of sys clock
    --    3          1/8 of sys clock
    mclk_hper   => mclk_hper,

    -- to the SINC3 filter - these outputs not used in this case
    mdat_valid  => open,
    mdat        => open);

else generate
-- for AMC1035 sigma-delta modulator from TI
-- when mclk 10 MHz, OSR 128, sampling rate about 80 kS/s and resolution 16 bit
clk_gen_i: s_d_clock_gen
port map(
    clk         => clk_adc,
    reset       => reset_adc,

    -- sigma delta modulator data output, MCE pin to GND! (no Manchester encoding)
    -- - changes 6 to 25 ns after mclk rising edge
    -- - therefore should be sampled shortly before the rising edge of mclk
    s_d_mod_dat => s_d_mod_dat,
    s_d_mod_clk => s_d_mod_clk,

    -- modulator clock 9-21 MHz, here the half-period-1 in system clocks
    -- mclk_hper      Fmod
    --    0          1/2 of sys clock
    --    1          1/4 of sys clock
    --    2          1/6 of sys clock
    --    3          1/8 of sys clock
    mclk_hper   => mclk_hper,

    -- to the SINC3 filter
    mdat_valid  => mdat_valid,
    mdat        => mdat);

end generate;

    -- DEBUG
    debug <= clr_valid & dec_ok & s_d_mod_d_n & s_d_mod_dat;

sinc3_i: sinc3xil
generic map(LONG_LAT    => LONG_LAT,
            UNIPOLAR    => UNIPOLAR,
            TWO_S_COMPL => TWO_S_COMPL,
            LOG2OSR_MAX => LOG2OSR_MAX)
port map(
    clk         => clk_adc,
    reset       => reset_adc,

    mod_inp_dat => mdat,
    mod_inp_val => mdat_valid,

    -- osr code        OSR
    --    0            32
    --    1            64
    --    2           128
    --    3           256
    --    4           512
    --    5          1024
    --    6          2048
    --    7          4096
    osr_code    => osr_code_a,
    zoom_code   => zoom_code_a,
    -- ADC output
    adc_ovfl    => adc_ovfl_i,
    adc_rng_ok  => adc_rng_ok,
    adc_valid   => adc_valid_a,
    adc_dout    => adc_dout_a);

    process(clk_adc)
    begin
        if rising_edge(clk_adc) then
            adc_val2 <= adc_valid_a;
            if adc_valid_a='1' and adc_val2='0' then -- new valid
                tgl_valid <= not tgl_valid;
                adc_dout_r <= adc_dout_a;
                adc_ovfl_r <= adc_ovfl_i;
            end if;
            reset_adc   <= reset_pip(0);
            osr_code_a  <= osr_code;
            zoom_code_a <= zoom_code;
        end if;
    end process;

    process(clk_sys)
    begin
        if rising_edge(clk_sys) then
            tgl_val_s <= tgl_valid;
            tgl_val_2 <= tgl_val_s;
            adc_valid <= '0';

            if clr_valid='1' then
                dout_r(BIT_VALID) <= '0';
            end if;

            if (tgl_val_s xor tgl_val_2)='1' then -- new valid
                adc_valid <= '1';
                adc_dout  <= adc_dout_r;
                adc_ovfl  <= adc_ovfl_r;
                if dec_cnt /= 0 then
                    dec_cnt <= dec_cnt - 1;
                else
                    dec_cnt <= dec_ini;
                    dec_ok <= '1';
                end if;
            end if;

            if dec_ok='1' then
                dout_r <= (others => '0');
                dout_r(BIT_VALID) <= '1';
                dout_r(BIT_OVFL ) <= adc_ovfl_r;
                dout_r(BIT_RNG_OK) <= adc_rng_ok;
                dout_r(BIT_OSRS+osr_code'length-1 downto BIT_OSRS) <= osr_code;
                dout_r(adc_dout_r'range) <= adc_dout_r;
                dec_ok <= '0';
            end if;

            if reset='1' or sft_reset='1' then
                reset_pip <= (others => '1');
                dec_cnt <= (others => '0');
            else
                reset_pip <= '0' & reset_pip(reset_pip'high downto 1);
            end if;
        end if;
    end process;

    process(dout_r, osr_code, io_ena, dec_ini, dec_cnt, mclk_hper, zoom_code)
    begin
        dout <= (others => '0');
        case addr0 is
            -- programmable and hard wired configuration & status
            when '0' => dout(osr_code'range) <= osr_code;
                        dout(BIT_ENAC) <= io_ena;
                        dout(BIT_CLK_S+1 downto BIT_CLK_S) <= mclk_hper;
                        dout(BIT_ZOOMC+1 downto BIT_ZOOMC) <= zoom_code;
                        if Manch_Enc       then
                            dout(BIT_MANCH)   <= '1';
                            if USE_ADC_CLK4GEN then
                                -- this option exists only when Manch encoding is active!
                                dout(BIT_CLK_S+2) <= '1';
                            end if;
                        else
                            -- here the modulator clock is always generated from the clk_adc
                            dout(BIT_CLK_S+2) <= '1';
                        end if;
                        if LONG_LAT then dout(BIT_LONG_L)  <= '1'; end if;
                        dout(dec_cnt'length-1+BIT_DEC downto BIT_DEC) <= dec_ini;
                        dout(dec_cnt'length-1+BIT_DEC+BITS_DEC downto BIT_DEC+BITS_DEC) <= dec_cnt;
            -- ADC output data and status
            when '1' => dout(dout_r'range) <= dout_r;
            when others => NULL;
        end case;
    end process;

    process(clk_sys)
    begin
        if rising_edge(clk_sys) then
            --io_ena    <= '1';
            clr_valid <= '0';
            sft_reset <= '0';
            if we='1' then
                case addr0 is
                when '0' =>
                    clr_valid <= '1';
                    sft_reset <= '1';
                    osr_code  <= din(osr_code'range);
                    zoom_code <= din(BIT_ZOOMC+1 downto BIT_ZOOMC);
                    io_ena    <= din(BIT_ENAC);
                    dec_ini   <= din(dec_ini'length-1+BIT_DEC downto BIT_DEC);
                when '1' =>
                    clr_valid <= '1';
                    sft_reset <= din(0);
                when others => NULL;
                end case;
            end if;
            if reset='1' then
                io_ena    <= '1';
                clr_valid <= '1';
                sft_reset <= '1';
                osr_code  <= "100";
                zoom_code <= "00";
                dec_ini <= (others => '1');
            end if;
        end if;
    end process;

    sigm_del_en <= io_ena;
end;
