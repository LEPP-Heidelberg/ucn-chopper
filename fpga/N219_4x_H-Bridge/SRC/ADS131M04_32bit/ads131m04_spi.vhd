-- altera vhdl_input_version vhdl_2008

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.all;
USE IEEE.STD_LOGIC_UNSIGNED.all;

-- $Id: ads131m04_spi.vhd 948 2022-12-21 16:58:38Z angelov $:


use work.ads131m04_pack.all;

entity ads131m04_spi is
generic (
         Nchips     : Integer range 1 to 4 := 3; -- number of ADC chips, from 1 to 4
         Ndata      : Positive := 24);           -- size of the data word, normally 24, but 16 and 32 are possible but not tested!
port (
    clk             : in  std_logic; -- 4x the desired SPI CLK

    chip_mask       : in  std_logic_vector(Nchips-1  downto 0);
    drdy            : out std_logic_vector(Nchips-1  downto 0); -- of all channels, inverted, synchron to the clk_adc
    -- decoded command, 0 - reset, 1 - start SPI transfer,
    cmd_spi_sm      : in  std_logic_vector( 1 downto 0);
    -- auto start last NULL command after DRDY_n falling edge
    auto_read       : in  std_logic;
    auto_crc        : in  std_logic;

    -- to/from the IO module
    send_addr       : out std_logic_vector( 1 downto 0); -- 0 - cmd, 1 - wdata, 2 - crc
    send_data       : in  std_logic_vector(Ndata-1 downto 0);

    recv_valid      : out std_logic;
    recv_addr       : out std_logic_vector( 2 downto 0); -- 0, 1 : Responce, CRC, 4..7 : ADC data
    recv_data       : out std_logic_vector(Nchips*Ndata-1 downto 0);

    -- SPI status
    busy            : out std_logic;
    -- if crc_is_0(i) = 1, the CRC checksum on the received data from chip(i) was ok!
    crc_is_0        : out std_logic_vector(Nchips-1 downto 0);

    -- control outputs
    cs_n            : out std_logic;
    -- ADC master clock
    mclk            : out std_logic;
    -- ADC spi interface, CS_n permanently low
    mosi            : out std_logic;
    sclk            : out std_logic_vector(Nchips-1 downto 0);
    miso            : in  std_logic_vector(Nchips-1 downto 0);
    drdy_n          : in  std_logic_vector(Nchips-1 downto 0));
end ads131m04_spi;

architecture a of ads131m04_spi is

component crc16reg is
generic(LSBfirst : Boolean := false);
port (
    clk    : in  std_logic;
    ansi   : in  std_logic; -- 1 for ANSI, 0 for CCITT, this bit is static while calculating the CRC
    load   : in  std_logic; -- load the initial word
    din    : in  std_logic; -- the new bit
    ena    : in  std_logic; -- new bit present
    crc16  : out std_logic_vector(15 downto 0);
    crc_is0: out std_logic);
end component;

subtype shift_reg_type is std_logic_vector(Ndata-1 downto 0);
type arr_4x24_type is array(0 to Nchips-1) of shift_reg_type;

signal out_shift_reg    : shift_reg_type;
signal inp_shift_reg    : arr_4x24_type;
signal load_out_ena     : std_logic;

signal drdy_r           : std_logic_vector(Nchips-1 downto 0);
signal drdy_m           : std_logic_vector(Nchips-1 downto 0);
signal any_rdy          : std_logic;
constant chip_mask0     : std_logic_vector(chip_mask'range) := (others => '0');
signal spi_phase        : std_logic_vector(       1 downto 0);
-- must be defined in the simulation!
constant PHASE0         : std_logic_vector(spi_phase'range) := "00";
constant PHASE1         : std_logic_vector(spi_phase'range) := "10";
signal clk_phase        : std_logic_vector(       1 downto 0);
signal reset            : std_logic;
signal start            : std_logic;
signal auto_ena         : std_logic;
signal disabled         : std_logic;

signal cmd_is_reset     : std_logic;
signal cmd_is_null      : std_logic;
signal cmd_is_other     : std_logic;
signal cmd_is_rreg      : std_logic;
signal cmd_is_wreg      : std_logic;
signal cmd_is_err       : std_logic;
signal cmd_is_ok        : std_logic;
signal was_load_out_ena : std_logic;

signal send_ad          : std_logic_vector(send_addr'range);
signal recv_ad          : std_logic_vector(recv_addr'range);

type top_sm_type is (sm_idle,
                    sm_ld_word,  sm_sr_word,
                    sm_fin);

signal top_sm       : top_sm_type;
signal top_sm_next  : top_sm_type;

type spi_sm_type is (spi_idle,
                     spi_beg, spi_sclk1, spi_sclk0, spi_end);
signal spi_sm, spi_sm_next   : spi_sm_type;

type sm_auto_type is (sm_auto_idle, sm_auto_wt_drdy, sm_auto_read);
signal sm_auto          : sm_auto_type;

signal bit_ena_crc_in   : std_logic;
signal crc_din          : std_logic;
signal crc_is0          : std_logic_vector(Nchips-1 downto 0);
signal start_spi        : std_logic;
signal start_auto       : std_logic;
signal spi_sm_ready     : std_logic;
signal shift_out_ena    : std_logic;
signal shift_inp_ena    : std_logic;
signal load_bit_cnt     : std_logic;
signal bit_cnt          : Integer range 0 to Ndata-1;
signal send_MSW         : std_logic_vector(15 downto 0);

signal ena_crc_shift, load_crc, ena_crc : std_logic;
signal crc16out : std_logic_vector(15 downto 0);

begin
    reset     <= cmd_spi_sm(BIT_RESET);
    start     <= cmd_spi_sm(BIT_START) or start_auto;
    auto_ena  <= auto_read;

    process(drdy_m)
    variable tmp : std_logic;
    begin
        -- check if at least one chip has new data
        tmp := '0';
        for i in drdy_m'range loop
            tmp := tmp or drdy_m(i);
        end loop;
        any_rdy <= tmp;
    end process;

    -- top state machine for auto read new data
    process(clk)
    begin
        if rising_edge(clk) then
            -- store the drdy_n to register
            drdy_r <= drdy_n;
            start_auto <= '0';
            if auto_ena='0' then
                -- disable this state machine
                sm_auto <= sm_auto_idle;
                drdy_m <= (others => '0');
            else
                case sm_auto is
                    when sm_auto_idle =>
                        drdy_m <= (others => '0');
                        if auto_ena='1' then
                            sm_auto <= sm_auto_wt_drdy;
                        end if;
                    when sm_auto_wt_drdy =>
                        -- this mask stores the activated drdy
                        drdy_m <= drdy_m or ((not drdy_r) and chip_mask);

                        if any_rdy = '1' then -- at least one of the active ADC chips is ready
--                        if drdy_m=chip_mask then -- all active ADC chips are ready
                            sm_auto <= sm_auto_read;
                            start_auto <= '1';
                        end if;
                    when sm_auto_read => -- wait until the SPI state machine is ready with the reading of the data
                        if top_sm = sm_fin then
                            sm_auto <= sm_auto_idle;
                        end if;
                    when others =>
                        sm_auto <= sm_auto_idle;
                end case;
            end if;
        end if;
    end process;

    -- assign the drdy output of the entity
    drdy <= drdy_r;

    -- next state and outputs calculation
    process(all)
    begin
        spi_sm_next   <= spi_sm;
        shift_out_ena <= '0';
        shift_inp_ena <= '0';
        load_bit_cnt  <= '0';
        case spi_sm is
            when spi_idle =>
                if start_spi='1' then spi_sm_next <= spi_beg; end if;
            when spi_beg  =>
                if spi_phase = PHASE1 then
                    spi_sm_next <= spi_sclk1;
                    load_bit_cnt <= '1';
                    shift_out_ena <= '1';
                end if;
            when spi_sclk1  =>
                if spi_phase = PHASE0 then
                    spi_sm_next <= spi_sclk0;
                    shift_inp_ena <= '1';
                end if;
            when spi_sclk0  =>
                if spi_phase = PHASE1 then
                    shift_out_ena <= '1';
                    if bit_cnt = 0 then
                        spi_sm_next <= spi_end;
                    else
                        spi_sm_next <= spi_sclk1;
                    end if;
                end if;
            when spi_end  =>
                if spi_phase = PHASE0 then
                    spi_sm_next <= spi_idle;
                end if;
            when others =>
                spi_sm_next <= spi_idle;
        end case;
    end process;

    -- control outputs
    process(clk)
    begin
        if rising_edge(clk) then
            -- bit counter
            if load_bit_cnt='1' then
                bit_cnt <= Ndata-1;
            elsif shift_out_ena='1' and bit_cnt /= 0 then
                bit_cnt <= bit_cnt - 1;
            end if;

            -- auto disable when the mask is 000
            if chip_mask=chip_mask0 then
                disabled <= '1';
            else
                disabled <= '0';
            end if;

            -- phase for the SCLK
            if start='1' or disabled='1' then
                spi_phase <= "00";
            elsif disabled='0' then
                spi_phase <= spi_phase + 1;
            end if;

            -- phase for the MCLK
            if reset='1' or disabled='1' then
                clk_phase <= "00";
            else
                clk_phase <= clk_phase + 1;
            end if;

            -- output cell register
            mclk <= clk_phase(1);

            -- state machine register
            if reset='1' then
                spi_sm <= spi_idle;
            else
                spi_sm <= spi_sm_next;
            end if;

            -- SCLK as a function of the next state
            if spi_sm_next=spi_sclk1 then
                sclk <= chip_mask;
            else
                sclk <= (others => '0');
            end if;

            if spi_sm = spi_end then
                spi_sm_ready <= '1';
            else
                spi_sm_ready <= '0';
            end if;
        end if;
    end process;

    -- shift registers - 1x for output and Nchips x for input
    process(clk)
    begin
        if rising_edge(clk) then
            -- Nchips x input shift register
            if shift_inp_ena='1' then
                for i in 0 to Nchips-1 loop
                    inp_shift_reg(i) <= inp_shift_reg(i)(Ndata-2 downto 0) & miso(i);
                end loop;
            end if;

            -- output shift register, load
            if load_out_ena='1' then
                if auto_ena='1' then
                    -- load the NULL command when just reading ADC data
                    out_shift_reg <= ADS131_NULL & x"00";
                else
                    -- when loading the CRC, two possible sources:
                    if send_ad="10" and auto_crc='1' then
                    -- - the local calculated CRC (auto_crc=1)
                        out_shift_reg <= crc16out & x"00";
                    else
                    -- - or the programmed via the bus CRC
                        out_shift_reg <= send_data;
                    end if;
                end if;
            -- shift and copy the bit to be send to the serial output
            elsif shift_out_ena='1' then
                out_shift_reg <= out_shift_reg(Ndata-2 downto 0) & '0';
                mosi          <= out_shift_reg(Ndata-1); -- to the FPGA output
                crc_din       <= out_shift_reg(Ndata-1); -- to the CRC register here
            end if;

        end if;
    end process;

-- up to 4 CRC16 registers, attached to the SPI input stream
crc_inp: for i in 0 to Nchips-1 generate
crc_inp_i: crc16reg
generic map(
    LSBfirst => false)
port map(
    clk    => clk,
    ansi   => '0',           -- we work now only with CCITT format
    load   => load_crc,      -- the beginning of the stream
    din    => miso(i),       -- serial input data stream
    ena    => shift_inp_ena, -- the same enable as for the serial input registers
    crc16  => open,          -- the CRC16 will be not used or read
    crc_is0=> crc_is0(i));   -- only the flag if the CRC is 0 at the end (together with the CRC sent by the ADC)
                             -- so if crc_is0 = 1, the CRC checksum was ok!
end generate;

    load_crc <= load_out_ena when send_ad="00" else '0';

    process(clk)
    begin
        if rising_edge(clk) then
            -- store the crc_is_0 flags in output registers at the end of the SPI transaction
            if top_sm = sm_fin then
                crc_is_0 <= crc_is0 or not chip_mask;
            end if;

            -- build the enable for the CRC on the sent command & data
            if reset='1' then
                ena_crc <='0';
            -- ena_crc=1 marks the beginning of the time interval
            elsif load_crc='1' then
                ena_crc <='1';
            -- loading the CRC word marks the end of the time interval
            elsif load_out_ena='1' and send_ad="10" then
                ena_crc <='0';
            end if;

            -- CRC of the sent data - enable for each bit
            if spi_sm = spi_sclk1 and spi_sm_next = spi_sclk0 then
                bit_ena_crc_in <= '1';
            else
                bit_ena_crc_in <= '0';
            end if;

        end if;
    end process;

    ena_crc_shift <= bit_ena_crc_in and ena_crc;
    -- calculate the CRC on the output data on the fly, only once as all
    -- enabled (at the time for SPI) ADC chips get the same data
crc_out: crc16reg
generic map(
    LSBfirst => false)
port map(
    clk    => clk,
    ansi   => '0',
    load   => load_crc,
    din    => crc_din,
    ena    => ena_crc_shift,
    crc_is0=> open,
    crc16  => crc16out);

    -- copy direct, it will be anyway stored in registers
    process(inp_shift_reg)
    begin
        for i in 0 to Nchips-1 loop
            recv_data( (i+1)*Ndata-1 downto i*Ndata) <= inp_shift_reg(i);
        end loop;
    end process;

    -- command is 16-bit
    -- in WREG and RREG bits 12..7 contain the register address
    --                  bits 6..0 contain number of registers-1 to be read/write
    -- we will read/write only single registers!
    -- => bits 6..0 are 0
    send_MSW <= send_data(23 downto 8) when auto_ena='0' else
                ADS131_NULL; -- in auto read mode, send the NULL command to receive the ADC data

    process(clk)
    begin
        if rising_edge(clk) then
            was_load_out_ena <= load_out_ena;
            if top_sm = sm_idle and start='1' then
                -- these signals were mostly used in the simulation
                cmd_is_reset<='0';
                cmd_is_null <='0';
                cmd_is_other<='0';
                cmd_is_rreg <='0';
                cmd_is_wreg <='0';
                cmd_is_err  <='0';
                cmd_is_ok   <='1';
                case? send_MSW is
                    when ADS131_RESET   => cmd_is_reset<='1';

                    when ADS131_NULL    => cmd_is_null <='1';

                    when ADS131_STANDBY |
                         ADS131_WAKEUP  |
                         ADS131_LOCK    |
                         ADS131_UNLOCK  => cmd_is_other<='1';

                    when ADS131_RREG_C  => cmd_is_rreg <='1';

                    when ADS131_WREG_C  => cmd_is_wreg <='1';
                    when others         => cmd_is_err  <='1';
                                           cmd_is_ok   <='0';
                end case?;
            end if;

            if top_sm = sm_idle then
                recv_ad <= (others => '0');
            elsif top_sm = sm_sr_word and spi_sm_ready='1' then
                if recv_ad="001" then
                    recv_ad <= "100";
                else
                    recv_ad <= recv_ad + 1;
                end if;
            end if;

            if top_sm = sm_idle then
                send_ad <= (others => '0');
--                send_ad(0) <= load_out_ena;
            elsif was_load_out_ena='1' then
                if cmd_is_wreg='0' and send_ad="00" then
                    send_ad <= "10";
                else
                    send_ad <= send_ad + 1;
                end if;
            end if;

            if reset='1' or top_sm = sm_fin then
                cmd_is_reset<='0';
                cmd_is_null <='0';
                cmd_is_other<='0';
                cmd_is_rreg <='0';
                cmd_is_wreg <='0';
                cmd_is_err  <='0';
                cmd_is_ok   <='0';
                send_ad     <= (others => '0');
                recv_ad     <= (others => '0');
            end if;

        end if;
    end process;

    -- connect the outputs to the internal signals
    recv_addr <= recv_ad;
    send_addr <= send_ad;

    -- except for wreg, all other commands:
    -- send: command  -> crc -> 4xwords don't care
    -- recv: responce -> 4xADC -> crc OR 5 x don't care

    -- wreg
    -- send: command  -> wdata -> crc -> 3xwords don't care
    -- recv: responce -> 4xADC -> crc

    -- for reading of ADC data use the NULL command, then the responce is the status register

    -- actually here: cmd_is_ok   can be used to start any correct command and
    --                cmd_is_wreg can be used to distinguish between the two formats. That's all.
    process(all)
    begin
        top_sm_next <= top_sm;
        load_out_ena<= '0'; -- can be used as "command is ok"
        start_spi   <= '0';
        recv_valid  <= '0';
        case top_sm is
            when sm_idle =>
                if cmd_is_ok='1' then -- the start command was correct
                    top_sm_next <= sm_ld_word;
                    load_out_ena<='1';
                end if;

            when sm_ld_word =>
                top_sm_next <= sm_sr_word;
                start_spi   <= '1';

            when sm_sr_word =>

                if spi_sm_ready='1' then
                    if send_ad /= "11" then
                        load_out_ena<='1';
                    end if;
                    recv_valid  <='1';
                    if recv_ad /= "111" then
                        top_sm_next <= sm_ld_word;
                    else
                        top_sm_next <= sm_fin;
                    end if;
                end if;

            when sm_fin =>
                top_sm_next <= sm_idle;

            when others =>
                top_sm_next <= sm_idle;

        end case;
    end process;

    -- register for the top state machine, build the busy and cs_n signals
    process(clk)
    begin
        if rising_edge(clk) then
            if reset='1' then
                top_sm <= sm_idle;
                busy <= '0';
                cs_n <= '1';
            else
                top_sm <= top_sm_next;
                if top_sm_next /= sm_idle then
                    busy <= '1';
                    cs_n <= '0';
                else
                    busy <= '0';
                    cs_n <= '1';
                end if;
            end if;
        end if;
    end process;

end;
