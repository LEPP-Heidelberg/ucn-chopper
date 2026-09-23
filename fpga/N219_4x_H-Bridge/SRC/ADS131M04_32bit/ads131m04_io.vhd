-- altera vhdl_input_version vhdl_2008

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.all;
USE IEEE.STD_LOGIC_UNSIGNED.all;

-- $Id: ads131m04_io.vhd 1216 2026-09-02 16:57:27Z  $:


use work.ads131m04_pack.all;

entity ads131m04_io is
generic (
         SignFlag   : Boolean := true;
         Nchips     : Integer range 1 to 4 := 3; -- number of ADCs, from 1 to 4
         Ndata      : Positive := 24;
         UNSORTED   : Boolean := true;
         FCLK_ADC   : Positive := 32768000);
port (
    clk             : in  std_logic; -- system clock
    rst             : in  std_logic;

    -- Bus interface
    we              : in  std_logic;
    addr            : in  std_logic_vector( 4 downto 0);
    wdata           : in  std_logic_vector(31 downto 0);
    rdata           : out std_logic_vector(31 downto 0);

    clk_adc         : in  std_logic; -- 4x the desired SPI CLK (32.768 MHz when SPI clock is 8.192 MHz)

    -- to/from the SPI master
    chip_mask       : out std_logic_vector(Nchips-1 downto 0);
    drdy            : in  std_logic_vector(Nchips-1 downto 0); -- of all channels, inverted and synchron to the clk_adc
    cmd_spi_sm      : out std_logic_vector( 1 downto 0);
    auto_read       : out std_logic;
    auto_crc        : out std_logic;
    busy            : in  std_logic;
    -- if crc_is_0(i) = 1, the CRC checksum on the received data from chip(i) was ok!
    crc_is_0        : in  std_logic_vector(Nchips-1 downto 0);

    sync_n          : out std_logic;

    send_addr       : in  std_logic_vector( 1 downto 0); -- 0 - cmd, 1 - wdata, 2 - crc
    send_data       : out std_logic_vector(Ndata-1 downto 0);

    recv_valid      : in  std_logic;
    recv_addr       : in  std_logic_vector( 2 downto 0); -- 0 : Responce, 1, 4..6: ADC data, 7: CRC
    recv_data       : in  std_logic_vector(Nchips*Ndata-1 downto 0);

    -- ADC output direct
    adc_data_valid  : out std_logic; -- 1 clock long, new ADC data present
    adc_data        : out std_logic_vector(CHS_PER_ADC_CHIP*Nchips*Ndata-1 downto 0)); -- new ADC data
end ads131m04_io;

architecture a of ads131m04_io is

constant Mchips     : Integer := 4; -- max number of chips

signal addri        : Integer range 0 to 2**addr'length-1;
signal sync_rst_cnt : Integer range 0 to REST_PULSE_LEN;

signal cmd_reg      : ADS131_cmd_type;
signal dat_reg      : ADS131_reg_type;
signal crc_reg      : ADS131_reg_type;

signal cnt_drdy     : std_logic_vector(15 downto 0); -- max sampling rate is 2^15 S/s
signal cnt_drdy_w   : std_logic_vector(15 downto 0); -- max sampling rate is 2^15 S/s
signal cnt_1sec     : std_logic_vector(24 downto 0); -- max sampling rate is 2^15 S/s
signal tick_1s      : std_logic;
signal cnt_pmeter   : std_logic_vector(19 downto 0); -- period of the DRDY for down to 50 S/s
signal cnt_pmeter_w : std_logic_vector(19 downto 0); -- period of the DRDY for down to 50 S/s

signal drdy_re      : std_logic_vector(Nchips-1 downto 0); -- was a rising_egde on the drdy_n after activ sync_n
signal drdy_prev    : std_logic_vector(Nchips-1 downto 0); -- was a rising_egde on the drdy_n after activ sync_n
signal chip_mask_i  : std_logic_vector(Nchips-1 downto 0); -- selected chips for ADC acquisition
signal chip_sel     : std_logic_vector(       1 downto 0); -- selected chip for counter & period

signal cmd_sm       : std_logic_vector(4 downto 0);
signal cmd_sm_adc   : std_logic_vector(4 downto 0);

type arr_Cx24bit is array(0 to   Mchips-1) of std_logic_vector(23 downto 0);
type arr_Nx24bit is array(0 to CHS_PER_ADC_CHIP*Mchips-1) of std_logic_vector(23 downto 0);

-- responce data
signal rd_resp      : arr_Cx24bit;
-- CRC data
--signal rd_crc       : arr_Cx24bit;
-- ADC data
signal rd_adc       : arr_Nx24bit;
signal rd_adc_r     : arr_Nx24bit;

signal clr_freq_rdy : std_logic;
signal clr_freq_rdy_adc : std_logic;
signal freq_adc_busy : std_logic_vector(1 downto 0);
signal per_adc_busy  : std_logic_vector(1 downto 0);
signal new_sample   : std_logic;
signal auto_read_i  : std_logic;
signal auto_crc_i   : std_logic;
signal drdy_old     : std_logic;
signal sync         : std_logic;
signal adc_v_adc    : std_logic;
signal early_adc_v  : std_logic;
signal adc_v_sys    : std_logic;
signal adc_v_syse   : std_logic;
signal adc_dv       : std_logic;  -- data valid in system clock, all data
signal adc_ev       : std_logic;  -- data valid in system clock, first data
signal sync_s       : std_logic;
signal clr_tmr32kHz : std_logic;
signal tick32kHz    : std_logic;
signal tmr_32kHz    : std_logic_vector(31 downto 0);
signal tmr_32kHz_r  : std_logic_vector(31 downto 0);
signal cnt_32kHz    : std_logic_vector( 9 downto 0);
signal adc_v_pipe   : std_logic_vector(2 downto 0);
signal adc_v_pipe_e : std_logic_vector( 2 downto 0);
signal r32k         : std_logic_vector( 2 downto 0);

signal rdata_i      : std_logic_vector(rdata'range);

begin
    addri <= conv_integer(addr);

    -- write data & commands from the bus
    process(clk)
    begin
        if rising_edge(clk) then
            clr_tmr32kHz <= '0';
            if adc_ev='1' then
                new_sample <= '1';
            end if;

            if we='1' then
                case addri is
                    when ADDR_CMD_WR  => cmd_reg <= wdata(cmd_reg'range);
                                         cmd_sm(BIT_START) <= wdata(16+BIT_START);
                                         cmd_sm(BIT_RESET) <= wdata(16+BIT_RESET);
                                         if wdata(BIT_CMD_WMASK_ENA)='1' then
                                            chip_mask_i <= wdata(BIT_CMD_WMASK+chip_mask'high downto BIT_CMD_WMASK+chip_mask'low);
                                         end if;

                    when ADDR_WREG    => dat_reg <= wdata(dat_reg'range);
                                         cmd_sm(BIT_START) <= wdata(16+BIT_START);
                                         cmd_sm(BIT_RESET) <= wdata(16+BIT_RESET);
                                         if wdata(BIT_CMD_WMASK_ENA)='1' then
                                            chip_mask_i <= wdata(BIT_CMD_WMASK+chip_mask'high downto BIT_CMD_WMASK+chip_mask'low);
                                         end if;

                    when ADDR_CRC_WR  => crc_reg <= wdata(crc_reg'range);
                                         cmd_sm(BIT_START) <= wdata(16+BIT_START);
                                         cmd_sm(BIT_RESET) <= wdata(16+BIT_RESET);
                                         if wdata(BIT_CMD_WMASK_ENA)='1' then
                                            chip_mask_i <= wdata(BIT_CMD_WMASK+chip_mask'high downto BIT_CMD_WMASK+chip_mask'low);
                                         end if;

                    when ADDR_AUTO_READ=> auto_read_i <= wdata(BIT_AUTO_RD);
                                          auto_crc_i  <= wdata(BIT_AUTO_CRC);
                                          cmd_sm(BIT_SYNC) <= wdata(BIT_SYNC);
                                          new_sample <= new_sample and not wdata(BIT_CLR_NEW_SAMPLE);
                                          if wdata(BIT_CMD_WMASK_ENA)='1' then
                                             chip_mask_i <= wdata(BIT_CMD_WMASK+chip_mask'high downto BIT_CMD_WMASK+chip_mask'low);
                                          end if;

                    when ADDR_ADC_MSK => chip_mask_i <= wdata(chip_mask'range); -- max 3..0, for all SPI transactions!
                                         chip_sel  <= wdata(5 downto 4);  -- only for monitoring
                                         clr_freq_rdy <= '1';
                    when ADDR_P_METER | ADDR_F_METER =>
                                         clr_freq_rdy <= '1';
                                         chip_sel     <= wdata(5 downto 4);  -- only for monitoring


                    when ADDR_CMD_SM  => cmd_sm <= wdata(cmd_sm'range);
                                         if wdata(BIT_CMD_WMASK_ENA)='1' then
                                            chip_mask_i <= wdata(BIT_CMD_WMASK+chip_mask'high downto BIT_CMD_WMASK+chip_mask'low);
                                         end if;

                    when ADDR_TMR_32KHZ | ADDR_TMR_32KHZ_L => clr_tmr32kHz <= '1';
                    
                    when ADDR_RD_ADC0 to ADDR_RD_ADCF  =>
                                          new_sample <= '0';
                    when others => NULL;
                end case;
            end if;

            if rst='1' then
                cmd_sm    <= (others => '0');
                cmd_sm(BIT_RESET) <= '1';
                cmd_sm(BIT_RESET_SYNC) <= '1';
                new_sample <= '0';
                auto_read_i <= '0';
                auto_crc_i  <= '0';
                clr_freq_rdy <= '1';
                chip_sel  <= (others => '0');
                chip_mask_i<= (others => '1');
                cmd_reg   <= (others => '0');
                dat_reg   <= (others => '0');
                crc_reg   <= (others => '0');
            end if;

            for i in cmd_sm'range loop
                if cmd_sm_adc(i)='1' then cmd_sm(i) <= '0'; end if;
            end loop;

            if clr_freq_rdy_adc='1' then clr_freq_rdy <= '0'; end if;

        end if;
    end process;

    auto_read <= auto_read_i;
    auto_crc  <= auto_crc_i;
    chip_mask <= chip_mask_i;

    -- prolong the pulses in the clk_adc domain
    process(clk_adc) -- normally slower than clk
    begin
        if rising_edge(clk_adc) then
            clr_freq_rdy_adc <= clr_freq_rdy;
            cmd_sm_adc  <= cmd_sm;
            cmd_spi_sm  <= cmd_sm_adc(cmd_spi_sm'range);

            if cmd_sm_adc(BIT_RESET_SYNC)='1' then
                sync_rst_cnt <= REST_PULSE_LEN;
            elsif cmd_sm_adc(BIT_SYNC)='1' then
                sync_rst_cnt <= SYNC_PULSE_LEN;
            elsif sync_rst_cnt /= 0 then
                sync_rst_cnt <= sync_rst_cnt - 1;
                sync_n <= '0';
                sync   <= '1';
            else
                sync_n <= '1';
                sync   <= '0';
            end if;

        end if;
    end process;

    -- read mux for the SPI master send data
    process(send_addr, cmd_reg, dat_reg, crc_reg)
    begin
        send_data <= (others => '0');
        case send_addr is
            -- the word size is 24, the registers and commands are 16, data should be alligned left (MSB)
            when "00" => send_data(23 downto 8) <= cmd_reg;
            when "01" => send_data(23 downto 8) <= dat_reg;
            when "10" => send_data(23 downto 8) <= crc_reg;
            when others => NULL;
        end case;
    end process;


    process(all)
    begin
        if Nchips<Mchips then
            for i in Nchips to Mchips-1 loop
                rd_resp(i   ) <= (others => '0');
--                rd_crc( i   ) <= (others => '0');
                rd_adc(CHS_PER_ADC_CHIP*i  ) <= (others => '0');
                rd_adc(CHS_PER_ADC_CHIP*i+1) <= (others => '0');
                rd_adc(CHS_PER_ADC_CHIP*i+2) <= (others => '0');
                rd_adc(CHS_PER_ADC_CHIP*i+3) <= (others => '0');
            end loop;
        end if;
    end process;

    -- store the incoming data from SPI master (operates with clk_adc)
    process(clk_adc) -- normally slower than clk
    begin
        if rising_edge(clk_adc) then
            adc_v_adc <= '0';
            early_adc_v <= '0';
            if recv_valid='1' then
                case recv_addr is

                    when "000" =>
                        for i in 0 to Nchips-1 loop
                            rd_resp(i) <= recv_data((i+1)*Ndata-1 downto i*Ndata);
                        end loop;

                    when "001" => -- ADC0, ADC4, ADC8, ADC12 (if any)
                        for i in 0 to Nchips-1 loop
                            rd_adc(CHS_PER_ADC_CHIP*i  ) <= recv_data((i+1)*Ndata-1 downto i*Ndata);
                        end loop;
                        early_adc_v <= '1'; -- CPU can start reading and sending
                    when "100" => -- ADC1, ADC5, ADC9, ADC13 (if any)
                        for i in 0 to Nchips-1 loop
                            rd_adc(CHS_PER_ADC_CHIP*i+1) <= recv_data((i+1)*Ndata-1 downto i*Ndata);
                        end loop;
                    when "101" => -- ADC2, ADC6, ADC10, ADC14 (if any)
                        for i in 0 to Nchips-1 loop
                            rd_adc(CHS_PER_ADC_CHIP*i+2) <= recv_data((i+1)*Ndata-1 downto i*Ndata);
                        end loop;
                    when "110" => -- ADC3, ADC7, ADC11, ADC15 (if any)
                        for i in 0 to Nchips-1 loop
                            rd_adc(CHS_PER_ADC_CHIP*i+3) <= recv_data((i+1)*Ndata-1 downto i*Ndata);
                        end loop;
                        -- valid signal in ADC clock domain, 1 clock long
                        adc_v_adc <= '1';
                    when "111" => NULL;
--                      for i in 0 to Nchips-1 loop
--                          rd_crc(i) <= recv_data((i+1)*Ndata-1 downto i*Ndata);
--                      end loop;

                    when others => NULL;
                end case;
            end if;
        end if;
    end process;

    process(all)
    begin
        rdata_i <= (others => '0');
        case addri is

            when ADDR_CMD_WR   => rdata_i(cmd_reg'range) <= cmd_reg;
            when ADDR_WREG     => rdata_i(dat_reg'range) <= dat_reg;
            when ADDR_CRC_WR   => rdata_i(crc_reg'range) <= crc_reg;
            when ADDR_AUTO_READ=> rdata_i(0) <= auto_read_i;
            when ADDR_ADC_MSK  => rdata_i(BIT_MASK+chip_mask'length-1 downto BIT_MASK) <= chip_mask_i;
                                  rdata_i(BIT_SEL +chip_sel'length -1 downto BIT_SEL ) <= chip_sel;
            when ADDR_STA_SM   => rdata_i(BIT_STA_RECV_AD+recv_addr'length-1 downto BIT_STA_RECV_AD) <= recv_addr;
                                  rdata_i(BIT_STA_SEND_AD+send_addr'length-1 downto BIT_STA_SEND_AD) <= send_addr;
                                  rdata_i(BIT_STA_BUSY) <= busy;
                                  rdata_i(BIT_STA_SYNC) <= sync;
                                  rdata_i(BIT_STA_SYNC2) <= sync;
                                  rdata_i(BIT_STA_DRDY+Nchips-1 downto BIT_STA_DRDY) <= drdy;
                                  rdata_i(BIT_STA_DRDY_RE+Nchips-1 downto BIT_STA_DRDY_RE) <= not drdy_re;
                                  rdata_i(BIT_STA_NEW_SAMPLE) <= new_sample;
                                  rdata_i(BIT_STA_NO_NEW_SAMPLE) <= not new_sample;
                                  rdata_i(BIT_STA_PMET_BUSY) <= per_adc_busy(per_adc_busy'high);
                                  rdata_i(BIT_STA_FMET_BUSY) <= freq_adc_busy(freq_adc_busy'high);
                                  rdata_i(BIT_STA_CRC_0_INP+Nchips-1 downto BIT_STA_CRC_0_INP) <= crc_is_0;

            when ADDR_P_METER  => rdata_i(cnt_pmeter'range) <= cnt_pmeter;
                                  rdata_i(25 downto 24) <= chip_sel;
                                  rdata_i(31) <= per_adc_busy(per_adc_busy'high);
            when ADDR_F_METER  => rdata_i(cnt_drdy'range) <= cnt_drdy;
                                  rdata_i(25 downto 24) <= chip_sel;
                                  rdata_i(31) <= freq_adc_busy(freq_adc_busy'high);

            when ADDR_RD_RESP0 => rdata_i(23 downto 0) <= rd_resp(0);
            when ADDR_RD_RESP1 => rdata_i(23 downto 0) <= rd_resp(1); -- when 2 ADCs or more
            when ADDR_RD_RESP2 => rdata_i(23 downto 0) <= rd_resp(2); -- when 3 ADCs or more
            when ADDR_RD_RESP3 => rdata_i(23 downto 0) <= rd_resp(3); -- when 4 ADCs
			when ADDR_TMR_32KHZ=> rdata_i(tmr_32kHz'range) <= tmr_32kHz;
            when ADDR_TMR_32KHZ_L=> rdata_i(tmr_32kHz'range) <= tmr_32kHz_r;
--            when ADDR_RD_CRC1  => rdata_i(23 downto 0) <= rd_crc(1); -- when 2 ADCs or more
            --when ADDR_RD_CRC2  => rdata_i(23 downto 0) <= rd_crc(2); -- when 3 ADCs or more
            --when ADDR_RD_CRC3  => rdata_i(23 downto 0) <= rd_crc(3); -- when 4 ADCs

            when ADDR_RD_ADC0  => rdata_i <= se(rd_adc( 0), rdata_i'length, SignFlag);
            when ADDR_RD_ADC1  => rdata_i <= se(rd_adc( 1), rdata_i'length, SignFlag);
            when ADDR_RD_ADC2  => rdata_i <= se(rd_adc( 2), rdata_i'length, SignFlag);
            when ADDR_RD_ADC3  => rdata_i <= se(rd_adc( 3), rdata_i'length, SignFlag);
            -- when 2 ADCs or more
            when ADDR_RD_ADC4  => rdata_i <= se(rd_adc( 4), rdata_i'length, SignFlag);
            when ADDR_RD_ADC5  => rdata_i <= se(rd_adc( 5), rdata_i'length, SignFlag);
            when ADDR_RD_ADC6  => rdata_i <= se(rd_adc( 6), rdata_i'length, SignFlag);
            when ADDR_RD_ADC7  => rdata_i <= se(rd_adc( 7), rdata_i'length, SignFlag);
            -- when 3 ADCs or more
            when ADDR_RD_ADC8  => rdata_i <= se(rd_adc( 8), rdata_i'length, SignFlag);
            when ADDR_RD_ADC9  => rdata_i <= se(rd_adc( 9), rdata_i'length, SignFlag);
            when ADDR_RD_ADCA  => rdata_i <= se(rd_adc(10), rdata_i'length, SignFlag);
            when ADDR_RD_ADCB  => rdata_i <= se(rd_adc(11), rdata_i'length, SignFlag);
            -- when 4 ADCs
            when ADDR_RD_ADCC  => rdata_i <= se(rd_adc(12), rdata_i'length, SignFlag);
            when ADDR_RD_ADCD  => rdata_i <= se(rd_adc(13), rdata_i'length, SignFlag);
            when ADDR_RD_ADCE  => rdata_i <= se(rd_adc(14), rdata_i'length, SignFlag);
            when ADDR_RD_ADCF  => rdata_i <= se(rd_adc(15), rdata_i'length, SignFlag);

            when others => NULL;
        end case;
    end process;


    -- valid signal in system clock domain, 1 clock long
    process(clk)
    begin
        if rising_edge(clk) then
            -- reg at the mux output
            rdata <= rdata_i;

            -- registered ADC data, all valid simultaneously
            adc_data_valid <= adc_dv;
            if adc_dv='1' then
                rd_adc_r <= rd_adc;
            end if;
        end if;
    end process;

    -- convert from vector of vectors to a single vector
    process(rd_adc_r)
    begin
        for i in 0 to CHS_PER_ADC_CHIP*Nchips-1 loop
            adc_data(Ndata*i+Ndata-1 downto Ndata*i) <= rd_adc_r(i);
        end loop;
    end process;

    -- sync the valid to the system clock domain
    process(clk)
    begin
        if rising_edge(clk) then
            adc_dv <= '0';
            adc_ev <= '0';
            adc_v_pipe <= adc_v_pipe(adc_v_pipe'high-1 downto 0) & adc_v_adc;
            adc_v_pipe_e <= adc_v_pipe_e(adc_v_pipe_e'high-1 downto 0) & early_adc_v;

            if adc_v_pipe="000" then
                adc_v_sys <= '0';
            else
                if adc_v_sys='0' then
                    adc_dv <= '1';
                end if;
                adc_v_sys <= '1';
            end if;


            if adc_v_pipe_e="000" then
                adc_v_syse <= '0';

            else
                if adc_v_syse='0' then
                    adc_ev <= '1';
                end if;
                adc_v_syse <= '1';
            end if;
        end if;
    end process;

    -- period and frequency measurement of the DRDY of one selected ADC chip
    process(clk_adc)
    variable drdy_sel, drdy1clk : std_logic;
    begin
        if rising_edge(clk_adc) then
            -- note: when we take the MSBit of cnt_32kHz we divide clk_adc exactly by 1024!
            -- clear while sync/reset command activ
            if sync='1' then
                cnt_32kHz <= (others => '1');
            else
                cnt_32kHz <= cnt_32kHz - 1;
            end if;

            drdy_prev <= drdy;
            if sync='1' then
                drdy_re <= (others => '0');
            else -- rising_edge on drdy_n means falling_edge on drdy
                drdy_re <= drdy_re or (drdy_prev and not drdy);
            end if;

            -- mux for period measurement
            drdy_sel := '0';
            for i in 0 to Nchips-1 loop
                if conv_integer(chip_sel)=i then
                    drdy_sel := drdy(i);
                end if;
            end loop;

            drdy_old <= drdy_sel;
            drdy1clk := drdy_sel and not drdy_old;
            -- measure the period of DRDY of the selected ADC chip
            if drdy1clk='1' then
                cnt_pmeter_w <= (0 => '1', others => '0');   -- in order to avoid adding 1 at the end of the measurement period (s. below)
                cnt_pmeter <= cnt_pmeter_w; -- should be +1, but in order to simplify the design avoid another incrementer and add the 1 at the beginning (s. above)
            else
                cnt_pmeter_w <= cnt_pmeter_w + 1;
            end if;

            -- measure the frequency of the DRDY of the selected ADC chip
            tick_1s <= '0';
            if cnt_1sec /= 0 then
                cnt_1sec <= cnt_1sec - 1;
            else
                tick_1s <= '1';
                cnt_1sec <= conv_std_logic_vector(FCLK_ADC, cnt_1sec'length);
            end if;

            if clr_freq_rdy_adc='1' then
                freq_adc_busy <= (others => '1');
            elsif tick_1s='1' then
                freq_adc_busy <= freq_adc_busy(freq_adc_busy'high-1 downto 0) & '0';
            end if;

            if clr_freq_rdy_adc='1' then
                per_adc_busy <= (others => '1');
            elsif drdy1clk='1' then
                per_adc_busy <= per_adc_busy(per_adc_busy'high-1 downto 0) & '0';
            end if;

            if tick_1s='1' then
                cnt_drdy   <= cnt_drdy_w;
                cnt_drdy_w <= (others => '0');
                cnt_drdy_w(0) <= drdy1clk;
            elsif drdy1clk='1' then
                cnt_drdy_w <= cnt_drdy_w + 1;
            end if;
        end if;
    end process;
    process(clk)
    begin
        if rising_edge(clk) then
            -- note: we divide clk_adc exactly by 1024!
            r32k(0) <= cnt_32kHz(cnt_32kHz'high);
            r32k(1) <= r32k(0);
            r32k(2) <= r32k(1);

            -- one clock long tick
            tick32kHz <= r32k(1) and not r32k(2);
            -- clear synchronous to system clock
            -- while sync/reset command activ or when was a write to the timer
            sync_s  <= sync or clr_tmr32kHz;

            if sync_s='1' then
                tmr_32kHz <= (others => '0');
            elsif tick32kHz='1' then
                tmr_32kHz <= tmr_32kHz + 1;
            end if;
            if adc_ev = '1' then -- new ADC data
                -- latch the timer
                tmr_32kHz_r <= tmr_32kHz;
            end if;
        end if;
    end process;


end;
