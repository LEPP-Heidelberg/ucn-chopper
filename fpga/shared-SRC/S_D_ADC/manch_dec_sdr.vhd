library ieee;
use ieee.std_logic_1164.all;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-- for AMC1035 sigma-delta modulator from TI
-- decoder when the stream is Manchester encoded
-- using SDR input cells in FPGA, so x8 system clock should be enough
entity manch_dec_sdr is
generic(BIT_CLKS : Positive := 8);  -- system clocks in one serial bit, +/- 1 clocks are acceptable
port(
    clk         : in  std_logic;
    reset       : in  std_logic;

    inp_dat     : in  std_logic;
    -- ADC output
    out_val     : out std_logic;
    out_dat     : out std_logic );
end manch_dec_sdr;

architecture behav of manch_dec_sdr is

type sm_type is (sm_idle, sm_wait4edge);
signal sm   : sm_type;
constant MIN_BIT_WIDTH  : Positive := BIT_CLKS-2;
constant MAX_BIT_WIDTH  : Positive := BIT_CLKS  ;

constant OLDER          : Integer  := 0;
constant NEWER          : Integer  := 1;

constant POS_EDGE       : std_logic := '1';   -- positive edge of data means 1
constant NEG_EDGE       : std_logic := '0';   -- negative edge of data means 0
signal in_dat           : std_logic_vector(OLDER to NEWER);  -- input pileline
signal lst_edge         : std_logic;          -- the type of the new edge
signal new_edge         : std_logic;          -- the type of the new edge
signal last_out         : std_logic; -- the type of the new edge
signal valid_edge       : std_logic;          -- there is a valid edge
signal check4new_bit    : std_logic;          -- check the new bit
constant MAX_DURATION   : Integer := 15;      -- upper margin for the pulse width duration
signal no_trans_durat   : Integer range 0 to MAX_DURATION;
signal no_trans_cnt     : Integer range 0 to MAX_DURATION;

signal out_valid        : std_logic;
signal out_data         : std_logic;

begin
    -- sync input data, count the time without transitions
    process(clk)
    begin
        if rising_edge(clk) then
            in_dat(NEWER) <= inp_dat;
            in_dat(OLDER) <= in_dat(NEWER);
            valid_edge <= in_dat(OLDER) xor in_dat(NEWER);
            if in_dat(NEWER)='1' and in_dat(OLDER)='0' then lst_edge <= POS_EDGE; end if;
            if in_dat(NEWER)='0' and in_dat(OLDER)='1' then lst_edge <= NEG_EDGE; end if;
            check4new_bit <= '0';
            if valid_edge='1' then
                no_trans_durat <= no_trans_cnt;
                check4new_bit <= '1';
                no_trans_cnt <= 0;
                new_edge <= lst_edge;
            else
                if no_trans_cnt /= MAX_DURATION then
                    no_trans_cnt <= no_trans_cnt + 1;
                end if;
            end if;
        end if;
    end process;

    -- here we have:
    --  - check4new_bit is 1 after any transition, otherwise 0
    --  - no_trans_durat contains the number of system clocks from the previous transition
    --  - new_edge contains the type of the edge - pos/neg
    --  - last_out is actually identical with out_data

    process(clk)
    begin
        if rising_edge(clk) then
            out_valid <= '0';

            case sm is
                when sm_idle =>
                if check4new_bit='1' and (no_trans_durat <= MAX_BIT_WIDTH) and
                                         (no_trans_durat >= MIN_BIT_WIDTH) then
                    sm <= sm_wait4edge;
                    out_valid <= '1';
                    out_data  <= new_edge;
                    last_out  <= new_edge;
                end if;

                when sm_wait4edge =>
                    if check4new_bit='1' then
                        if no_trans_durat < MIN_BIT_WIDTH then
                            if new_edge /= last_out then -- ignore
                                NULL;
                            else -- repeat
                                out_valid <= '1';
                                out_data  <= new_edge;
                            end if;
                        else -- longer pulse, change the output
                            out_valid <= '1';
                            out_data  <= new_edge;
                            last_out  <= new_edge;
                        end if;
                    end if;
                when others => sm <= sm_idle;
            end case;

            -- conditions with higher priority
            if reset='1' then
                sm <= sm_idle;
            end if;

            -- additional register stage
            out_val <= out_valid ;
            out_dat <= out_data  ;
        end if;
    end process;

end;
