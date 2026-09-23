-- $Id: sinc3xil.vhd 1201 2026-06-09 13:21:07Z angelov $:

library ieee;
use ieee.std_logic_1164.all;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-- for AMC1035 sigma-delta modulator from TI
-- when mclk 10 MHz, OSR 128, sampling rate about 80 kS/s and resolution 16 bit
entity sinc3xil is
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

    -- osr code   OSR table depends on LOG2OSR_MAX
    --                for 12     for 13
    --    0            32          64
    --    1            64         128
    --    2           128         256
    --    3           256         512
    --    4           512        1024
    --    5          1024        2048
    --    6          2048        4096
    --    7          4096        8192
    osr_code    : in  std_logic_vector( 2 downto 0);
    zoom_code   : in  std_logic_vector( 1 downto 0); -- used only for osr codes 4..7
    -- ADC output
    adc_ovfl    : out std_logic;
    adc_rng_ok  : out std_logic; -- when zooming
    adc_valid   : out std_logic;
    adc_dout    : out std_logic_vector(15 downto 0) );

end sinc3xil;

architecture behav of sinc3xil is

constant Nobits   : Integer range 8 to 24 := adc_dout'length;  -- bits in the output word
constant More_Bits : Integer := 3*(LOG2OSR_MAX-12);
constant Nibits   : Integer               := Nobits + 21 + More_Bits;      -- bits in the internal words
-- in the example from TI/Xilinx - 37 internal bits for 16 output and OSRmax=4096
-- in other examples - 25 internal bits for 16 output and OSRmax=256
-- achieved resolution is about 2.5 times log2(oversampling) ????

-- data size should be 3*log2(OSR) according to datasheet of ADUM7811

-- -3dB in freq resp should be at 0.262 * fDATA

constant OUT_WORD_OVL : std_logic_vector(16 downto 0) := 17x"10000";

signal osr          : std_logic_vector(LOG2OSR_MAX-1 downto 0);
signal osr_cnt      : std_logic_vector(osr'range);
signal osr_tick     : std_logic;
signal osr_tick_d   : std_logic;
signal osr_tick_dd  : std_logic;
signal adc_valid_i  : std_logic;
signal adc_valid_d  : std_logic;
signal adc_valid_dd : std_logic;
signal adc_ovfl_i   : std_logic;

signal inp_cnt      : std_logic_vector(Nibits-1 downto 0);
signal acc1         : std_logic_vector(Nibits-1 downto 0);
signal acc2         : std_logic_vector(Nibits-1 downto 0);
signal acc2_d       : std_logic_vector(Nibits-1 downto 0);

signal dif1         : std_logic_vector(Nibits-1 downto 0);
signal dif1_d       : std_logic_vector(Nibits-1 downto 0);
signal dif2         : std_logic_vector(Nibits-1 downto 0);
signal dif2_d       : std_logic_vector(Nibits-1 downto 0);
signal dif3         : std_logic_vector(Nibits-1 downto 0);

signal shifted_out  : std_logic_vector(Nobits   downto 0);
signal zoomed_out   : std_logic_vector(       3 downto 0);

signal invert_msb   : std_logic;
signal inv_msb_zm   : std_logic;
signal adc_negative : std_logic;
signal adc_gt_half  : std_logic;
signal adc_gt_1_4th : std_logic;
signal adc_gt_1_8th : std_logic;
signal adc_lt_mhalf : std_logic;
signal adc_lt_m1_4th: std_logic;
signal adc_lt_m1_8th: std_logic;

begin

    -- here we have:
    -- modulator input in mod_inp_dat, valid when mod_inp_val=1;
    process(clk)
    begin
        if rising_edge(clk) then
            if mod_inp_val='1' then
                -- input stage - an up counter
                if mod_inp_dat='1' then
                    inp_cnt <= inp_cnt + 1;
                end if;
                -- next stage, accumulator
                acc1 <= acc1 + inp_cnt;
                -- last stage, accumulator
                acc2 <= acc2 + acc1;
            end if;

            if reset='1' then
                inp_cnt <= (others => '0');
                acc1    <= (others => '0');
                acc2    <= (others => '0');
            end if;
        end if;
    end process;

    -- decode 3-bit OSR-code to OSR (8..1024)-1
    process(clk)
    begin
        if rising_edge(clk) then
            osr <= (others => '1');
            case osr_code is
            when "000" => osr(osr'high downto osr'high-6) <= (others => '0');
            when "001" => osr(osr'high downto osr'high-5) <= (others => '0');
            when "010" => osr(osr'high downto osr'high-4) <= (others => '0');
            when "011" => osr(osr'high downto osr'high-3) <= (others => '0');
            when "100" => osr(osr'high downto osr'high-2) <= (others => '0');
            when "101" => osr(osr'high downto osr'high-1) <= (others => '0');
            when "110" => osr(osr'high downto osr'high-0) <= (others => '0');
            when "111" => NULL;

         -- when "001" => osr <= "000000111111";  --   64
         -- when "010" => osr <= "000001111111";  --  128
         -- when "011" => osr <= "000011111111";  --  256
         -- when "100" => osr <= "000111111111";  --  512
         -- when "101" => osr <= "001111111111";  -- 1024
         -- when "110" => osr <= "011111111111";  -- 2048
         -- when "111" => osr <= "111111111111";  -- 4096
            when others => osr <= (others => '-');
            end case;
        end if;
    end process;

    -- OSR counter, enables for the next stages
    process(clk)
    begin
        if rising_edge(clk) then
            osr_tick <= '0';
            if LONG_LAT then
                osr_tick_d <= '0';
                osr_tick_dd <= '0';
                adc_valid_i <= '0';
            end if;
            if mod_inp_val='1' then
                if osr_cnt = 0 then
                    osr_cnt <= osr;
                    osr_tick <= '1';
                    if LONG_LAT then
                    -- activate the enables for all pipeline stages
                    -- so it takes more slow clocks to settle
                    -- so was the original code from Xilinx, AD and many others
                        osr_tick_d  <= '1';
                        osr_tick_dd <= '1';
                        adc_valid_i <= '1';
                    end if;
                else
                    osr_cnt <= osr_cnt - 1;
                end if;
            end if;
            if not LONG_LAT then
            -- the enables like shift register
            -- there are a lot of system clocks between
            -- two slow clocks (ADC samples) and so we
            -- shorten the latency substantially
                osr_tick_d  <= osr_tick;
                osr_tick_dd <= osr_tick_d;
                adc_valid_i <= osr_tick_dd;
            end if;
            if reset='1' then
                osr_tick <= '0';
                osr_tick_d <= '0';
                osr_tick_dd <= '0';
                adc_valid_i <= '0';
                osr_cnt  <= (others => '0');
            end if;
        end if;
    end process;

    -- diff stages
    process(clk)
    begin
        if rising_edge(clk) then
            -- in case of low latency, the enables
            -- are activated in a shift register
            -- in case of long latency, the enables
            -- are activated simultaneously
            if osr_tick='1' then
                acc2_d <= acc2;
                dif1   <= acc2 - acc2_d;
            end if;

            if osr_tick_d='1' then
                dif1_d <= dif1;
                dif2   <= dif1 - dif1_d;
            end if;

            if osr_tick_dd='1' then
                dif2_d <= dif2;
                dif3   <= dif2 - dif2_d;
            end if;

            if reset='1' then
                acc2_d      <= (others => '0');
                dif1        <= (others => '0');
                dif1_d      <= (others => '0');
                dif2        <= (others => '0');
                dif2_d      <= (others => '0');
                dif3        <= (others => '0');
            end if;
        end if;
    end process;

    -- shift the output according to OSR, preserve one bit more
    -- -> to have 17 instead of 16 bit, the 17-th bit is used
    -- to detect overflow
    process(clk)
    begin
        if rising_edge(clk) then
            adc_valid_d <= '0';
            if adc_valid_i = '1' then
                adc_valid_d <= '1';
                zoomed_out  <= (others => '0');
                case osr_code is
                    when "000" =>
                        -- to maintain the scale put a 0 as LSBit. Usable are about 10 MSBits
                        case LOG2OSR_MAX is
                        when 12 =>
                            shifted_out  <= dif3(Nobits- 1 downto  0) & '0';
                        when 13 =>
                            shifted_out  <= dif3(Nobits+ 2 downto  2);
                        when 14 =>
                            shifted_out  <= dif3(Nobits+ 5 downto  5);
                        end case;

                    when "001" =>  --   64/128
                        -- usable about 11 MSBits
                        shifted_out  <= dif3(Nobits+ 2 + More_Bits downto  2 + More_Bits);
                        zoomed_out   <= dif3(        1 + More_Bits downto  0 + More_Bits) & "00";

                    when "010" =>  --  128/256
                        -- usable about 12 MSBits
                        shifted_out  <= dif3(Nobits+ 5 + More_Bits downto  5 + More_Bits);
                        zoomed_out   <= dif3(        4 + More_Bits downto  1 + More_Bits);

                    when "011" =>  --  256/512
                        -- usable about 13 MSBits
                        shifted_out  <= dif3(Nobits+ 8 + More_Bits downto  8 + More_Bits);
                        zoomed_out   <= dif3(        7 + More_Bits downto  4 + More_Bits);

                    when "100" =>  --  512/1024
                        -- usable about 14 MSBits
                        shifted_out  <= dif3(Nobits+11 + More_Bits downto 11 + More_Bits);
                        zoomed_out   <= dif3(       10 + More_Bits downto  7 + More_Bits);

                    when "101" =>  -- 1024/2048
                        -- usable about 15 MSBits
                        shifted_out  <= dif3(Nobits+14 + More_Bits downto 14 + More_Bits);
                        zoomed_out   <= dif3(       13 + More_Bits downto 10 + More_Bits);

                    when "110" =>  -- 2048/4096
                        -- usable about 16 MSBits
                        shifted_out  <= dif3(Nobits+17 + More_Bits downto 17 + More_Bits);
                        zoomed_out   <= dif3(       16 + More_Bits downto 13 + More_Bits);

                    when "111" =>  -- 4096/8192
                        -- usable about 16 MSBits, less noise
                        shifted_out  <= dif3(Nobits+20 + More_Bits downto 20 + More_Bits);
                        zoomed_out   <= dif3(       19 + More_Bits downto 16 + More_Bits);

                    when others => shifted_out <= (others => '-');
                end case;
            end if;
        end if;
    end process;

-- the compares and substitutions, taken from AD7402 datasheet
-- as the values can saturate at these levels
-- OUT_WORD_OVL = 17x"10000"
    process(clk)
    begin
        if rising_edge(clk) then
            adc_valid_dd <= '0';

            if adc_valid_d = '1' then
                adc_ovfl_i   <= '0';
                adc_valid_dd <= '1';
                if shifted_out = OUT_WORD_OVL then
                    adc_ovfl_i <= '1';
                end if;

                adc_negative <= not shifted_out(shifted_out'high-1);
                adc_gt_half  <= shifted_out(shifted_out'high-1) and  shifted_out(shifted_out'high-2);
                adc_gt_1_4th <= shifted_out(shifted_out'high-1) and (shifted_out(shifted_out'high-2) or shifted_out(shifted_out'high-3) );
                adc_gt_1_8th <= shifted_out(shifted_out'high-1) and (shifted_out(shifted_out'high-2) or shifted_out(shifted_out'high-3) or shifted_out(shifted_out'high-4) );

                adc_lt_mhalf  <= not (shifted_out(shifted_out'high-1) or  shifted_out(shifted_out'high-2) );
                adc_lt_m1_4th <= not (shifted_out(shifted_out'high-1) or (shifted_out(shifted_out'high-2) and shifted_out(shifted_out'high-3) ) );
                adc_lt_m1_8th <= not (shifted_out(shifted_out'high-1) or (shifted_out(shifted_out'high-2) and shifted_out(shifted_out'high-3) and shifted_out(shifted_out'high-4) ) );

            end if;
        end if;
    end process;

    -- store the output, either the lower 16 bits of the shifted word
    -- or in case of overflow - the max 0xFFFF

    -- original coding: BOB : Bipolar Offset Binary
    -- possible : convert to BTC (two's complement) by inverting the MSBit


bipolar_case: if not UNIPOLAR generate

    invert_msb <= '1' when TWO_S_COMPL else '0'; -- invert the MSBit when converting from BOB to BTC the full word  BTC 1, BOB 0
    inv_msb_zm <= not invert_msb;                -- invert the new MSBit to have BOB after zooming                  BTC 0, BOB 1

    process(clk)
    begin
        if rising_edge(clk) then
            adc_valid <= '0';
            if adc_valid_dd = '1' then
                adc_valid  <= '1';
                adc_rng_ok <= '1';
                adc_ovfl <= adc_ovfl_i;
                if adc_ovfl_i='1' then
                    adc_dout <= (others => '1');
                    adc_rng_ok <= '0';
                else
                    adc_dout <= shifted_out(adc_dout'range); -- for osr 0..3
                    if osr_code(osr_code'high)='1' then -- osr 4..7 with zoom
                        case zoom_code is
                        when "00" =>
                            adc_dout <= (invert_msb xor shifted_out(adc_dout'high  )) & shifted_out(adc_dout'high-1 downto 0) ;
                        when "01" =>
                            adc_dout <= (inv_msb_zm xor shifted_out(adc_dout'high-1)) & shifted_out(adc_dout'high-2 downto 0) & zoomed_out(3);
                            if adc_gt_half ='1' then adc_dout <= (adc_dout'high => inv_msb_zm, others => '1'); adc_rng_ok <= '0'; end if;
                            if adc_lt_mhalf='1' then adc_dout <= (adc_dout'high => invert_msb, others => '0'); adc_rng_ok <= '0'; end if;
                        when "10" =>
                            adc_dout <= (inv_msb_zm xor shifted_out(adc_dout'high-2)) & shifted_out(adc_dout'high-3 downto 0) & zoomed_out(3 downto 2);
                            if adc_gt_1_4th ='1' then adc_dout <= (adc_dout'high => inv_msb_zm, others => '1'); adc_rng_ok <= '0'; end if;
                            if adc_lt_m1_4th='1' then adc_dout <= (adc_dout'high => invert_msb, others => '0'); adc_rng_ok <= '0'; end if;
                        when "11" =>
                            adc_dout <= (inv_msb_zm xor shifted_out(adc_dout'high-3)) & shifted_out(adc_dout'high-4 downto 0) & zoomed_out(3 downto 1);
                            if adc_gt_1_8th ='1' then adc_dout <= (adc_dout'high => inv_msb_zm, others => '1'); adc_rng_ok <= '0'; end if;
                            if adc_lt_m1_8th='1' then adc_dout <= (adc_dout'high => invert_msb, others => '0'); adc_rng_ok <= '0'; end if;
                        when others => NULL;
                        end case;
                    end if;
                end if;
            end if;
        end if;
    end process;

else generate

    invert_msb <= '0'; -- not used
    inv_msb_zm <= '0';

    process(clk)
    begin
        if rising_edge(clk) then
            adc_valid <= '0';
            if adc_valid_dd = '1' then
                adc_valid  <= '1';
                adc_rng_ok <= '1';
                adc_ovfl <= adc_ovfl_i;
                if adc_ovfl_i='1' then
                    adc_dout <= (others => '1');
                    adc_rng_ok <= '0';
                else
                    if adc_negative='1' then
                        adc_dout <= (others => '0');
                    else
                        adc_dout <= shifted_out(adc_dout'high-1 downto 0) & zoomed_out(3) ;

                        if osr_code(osr_code'high)='1' then -- osr 4..7 with zoom
                            case zoom_code is
                            when "00" =>
                                NULL;
                            when "01" =>
                                adc_dout <= shifted_out(adc_dout'high-2 downto 0) & zoomed_out(3 downto 2);
                                if adc_gt_half ='1' then adc_dout <= (others => '1'); adc_rng_ok <= '0'; end if;
                            when "10" =>
                                adc_dout <= shifted_out(adc_dout'high-3 downto 0) & zoomed_out(3 downto 1);
                                if adc_gt_1_4th ='1' then adc_dout <= (others => '1'); adc_rng_ok <= '0'; end if;
                            when "11" =>
                                adc_dout <= shifted_out(adc_dout'high-4 downto 0) & zoomed_out(3 downto 0);
                                if adc_gt_1_8th ='1' then adc_dout <= (others => '1'); adc_rng_ok <= '0'; end if;
                            when others => NULL;
                            end case;
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process;

end generate;

end;
