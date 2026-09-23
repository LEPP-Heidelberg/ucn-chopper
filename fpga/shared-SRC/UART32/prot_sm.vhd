LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.all;
USE IEEE.STD_LOGIC_UNSIGNED.all;

-- $Id: prot_sm.vhd 1205 2026-07-03 14:41:40Z  $:

entity prot_sm is
generic (
    USE_ID      : Boolean := false; -- the lower 4 bits of lmask should match exactly what comes from the interface?
    Naddr       : Positive := 24;  -- 16 or 24, no other values allowed
    Ndata       : Positive := 32); -- 8, 16 or 32, no other values allowed!
port (
    clk         : in  std_logic;
    reset       : in  std_logic;
    -- local mask, used as address, if bits 3..0 are all 0 - use the old protocol, without this additional byte at the beginning
    -- bits 3..0 anded with the mask from the interface should be non-zero (for USE_ID=false) or exactly match (for USE_ID=true) to
    -- select this node
    -- bit 7 unused now
    -- bits 6..4 are anded with bits 6..4 of the received byte, use to disable some or all commands temporary?
    lmask       : in  std_logic_vector(7 downto 0);

    -- direct command via only one byte
    -- for this the MSBit should be 1, bits 6..4 code one of the 8 commands
    -- the lower 4 bits of lmask AND-ed with the lower 4 bits of lmask should have a non-zero result
    -- cmd0 - latch ADC data
    -- cmd1 - send ADC data
    -- cmd2 - pause sending data

    short_code  : out std_logic_vector(2 downto 0);
    short_cmd   : out std_logic;

    -- uart status & data
    -- receive sm
    st_din_v    : in  std_logic;
    st_din      : in  std_logic_vector(7 downto 0);
    busy_rcv    : out std_logic; -- can not receive more bytes on st_din

    -- send sm
    st_dout_v   : out std_logic;
    st_dout     : out std_logic_vector(7 downto 0);
    st_dout_rdy : in  std_logic;
--    busy_s       : in  std_logic;

    -- bus interface
    bus_we      : out std_logic; -- - as along as ack comes
    bus_cyc     : out std_logic; -- / - for WB compatibility
    bus_rd      : out std_logic; -- /
    bus_ack     : in  std_logic; -- is '1' when the data are written/ready
    bus_rdata   : in  std_logic_vector(Ndata-1 downto 0);
    bus_addr    : out std_logic_vector(Naddr-1 downto 0);
    bus_wdata   : out std_logic_vector(Ndata-1 downto 0);

    -- status
    timeout     : out std_logic; -- master packet broken
    busy        : out std_logic);
end prot_sm;

architecture a of prot_sm is

  -- should exist in VHDL-2008???
  FUNCTION or_reduce(arg: STD_LOGIC_VECTOR) RETURN STD_LOGIC IS
    VARIABLE result: STD_LOGIC;
  BEGIN
    result := '0';
    FOR i IN arg'RANGE LOOP
      result := result OR arg(i);
    END LOOP;
    RETURN result;
  END;

-- should exist in VHDL-2008???
  FUNCTION and_reduce(arg: STD_LOGIC_VECTOR) RETURN STD_LOGIC IS
    VARIABLE result: STD_LOGIC;
  BEGIN
    result := '1';
    FOR i IN arg'RANGE LOOP
      result := result AND arg(i);
    END LOOP;
    RETURN result;
  END;


type state_type is (idle, recv_smsk, recv_cmd, recv_bsizeH, recv_addrL, recv_addrM, recv_addrH,
                    recv_data, bus_write_data, bus_read_data, send_data,
                    incr_addr, check_addr);

signal present_state, next_state : state_type;

attribute syn_encoding : string;
attribute syn_encoding of present_state : signal is "gray";
attribute syn_encoding of next_state    : signal is "gray";

-- The syn_encoding attribute has 4 values:
-- sequential, onehot, gray and safe.

-- bits in the block size in words
constant Nblk       : Positive := 11;

signal rd1_wr0      : std_logic;
signal go_next      : std_logic;
signal long_tr      : std_logic;
signal auto_incr    : std_logic;
signal addr         : std_logic_vector(23 downto 0);
signal word_size    : std_logic_vector( 1 downto 0);
signal word_cnt_r   : std_logic_vector( 1 downto 0);
signal word_cnt_s   : std_logic_vector( 1 downto 0);
signal bus_rdata_s  : std_logic_vector(31 downto 0);
signal bus_wdata_s  : std_logic_vector(31 downto 0);
signal blk_size     : std_logic_vector(Nblk-1 downto 0); -- stores the block_size-1!
signal blk_cnt      : std_logic_vector(Nblk-1 downto 0); -- stores the remaining words
constant blk_cnt_0  : std_logic_vector(Nblk-1 downto 0) := (others => '0'); -- stores the remaining words
signal blk_end      : std_logic;
signal selected     : std_logic;
signal smask        : std_logic_vector(st_din'range);
signal smask4       : std_logic_vector(3 downto 0);
signal lmask4       : std_logic_vector(3 downto 0);
--signal set_busy_rcv : std_logic;
--signal clr_busy_rcv : std_logic;
signal use_lmask    : std_logic;
signal short_cmd_i  : std_logic;
signal was_short_c  : std_logic;
signal node_selected  : std_logic;
signal short_cmd_c  : std_logic_vector(2 downto 0);

begin
    process(clk)
    begin
        if rising_edge(clk) then
            short_code <= (others => '0');
            short_cmd  <= '0';
            if short_cmd_i='1' then
--                short_code(conv_integer(short_cmd_c)) <= '1';
                short_code <= short_cmd_c;
                short_cmd <= '1';
            end if;
        end if;
    end process;

    lmask4 <= lmask(3 downto 0);
    smask4 <= smask(3 downto 0);

    process(all)
    begin
        case USE_ID is
        when false =>
            use_lmask <= or_reduce(lmask4);
            node_selected <= or_reduce(smask4 and lmask4) or not use_lmask;
        when true =>
            use_lmask <= '1';
            if smask4=lmask4 then node_selected <= '1'; else node_selected <= '0'; end if;
        end case;
    end process;

    bus_addr  <= addr(bus_addr'range);

    process(clk)
    begin
        if rising_edge(clk) then
            short_cmd_i <= '0';
            if present_state = idle then
                selected <= '0';
            else
                selected <= node_selected;
            end if;

            go_next <= st_din_v; -- or ready_s;

            if st_din_v='1' then
                case present_state is
                    -- all expected data are
                    -- rd1_wr0=0, long_tr=0 => 2 + blk_size(2 downto 0)*(word_size+1)
                    -- rd1_wr0=1, long_tr=0 => 2
                    when recv_smsk =>
                        smask <= st_din;
--                        short_cmd_i <= st_din(7) and node_selected;
                        short_cmd_i <= st_din(7) and or_reduce(st_din(3 downto 0) and lmask4) and use_lmask;
                        short_cmd_c <= st_din(6 downto 4) and lmask(6 downto 4);
                        was_short_c <= st_din(7) and use_lmask;

                    when recv_cmd =>
                        busy        <= '1';
                        rd1_wr0     <= st_din(0);

                        case Ndata is
                            when 32 =>
                                word_size   <= st_din(2 downto 1);
                            when 16 =>
                                word_size   <= '0' & st_din(1);
                            when 8 =>
                                word_size   <= "00";
                            when others =>
                                word_size   <= "00";
                        end case;

                        auto_incr   <= st_din(6);
                        long_tr     <= st_din(7);
                        word_cnt_r  <= "00";
                        blk_size    <= (others => '0');
                        blk_size(2 downto 0) <= st_din(5 downto 3);
                        blk_end     <= '0';
                    when recv_bsizeH =>
                        blk_size(10 downto 3) <= st_din;
                    when recv_addrL =>
                        addr( 7 downto  0) <= st_din;
                        blk_cnt <= blk_size;
                    when recv_addrM =>
                        addr(15 downto  8) <= st_din;
                    when recv_addrH =>
                        addr(23 downto 16) <= st_din;
                    when recv_data =>
                        case word_cnt_r is
                            when "00" =>
                                bus_wdata_s  <= x"000000" & st_din;
                            when "01" =>
                                bus_wdata_s(15 downto  8) <= st_din;
                            when "10" =>
                                bus_wdata_s(23 downto 16) <= st_din;
                            when "11" =>
                                bus_wdata_s(31 downto 24) <= st_din;
                            when others => NULL;
                        end case;
                        if word_cnt_r >= word_size then
                            word_cnt_r <= "00";
                            bus_we  <= selected;
                            bus_cyc <= selected;
                        else
                            word_cnt_r <= word_cnt_r + 1;
                        end if;
                    when others => NULL;
                end case;
            end if;

            case present_state is

                when bus_read_data =>
                    bus_cyc <= '1';
                    if bus_ack='1' then
                        bus_cyc <= '0';
                    end if;

                when incr_addr =>
                    if blk_cnt /= blk_cnt_0 then
                        blk_cnt <= blk_cnt - 1;
                    else
                        blk_end <= '1';
                    end if;
                    if auto_incr='1' then
                        addr <= addr + 1;
                    end if;
                when idle =>
                    busy <= '0';
                when others => NULL;
            end case;

            if bus_ack='1' or reset='1' then
                bus_we  <= '0';
                bus_cyc <= '0';
            end if;

            if reset='1' then
                busy   <= '0';
                smask  <= (others => '0');
                selected <= '0';
            end if;

        end if;
    end process;

    bus_wdata <= bus_wdata_s(bus_wdata'range);

    process(clk)
    begin
        if rising_edge(clk) then
            if reset='1' then
                present_state <= idle;
            else
                present_state <= next_state;
            end if;
        end if;
    end process;

    with present_state select
        busy_rcv <= '1' when bus_write_data | bus_read_data | send_data | incr_addr | check_addr,
                    go_next or st_din_v when others;

    -- reading from the bus, sending data to the UART
    process(clk)
    begin
        if rising_edge(clk) then

            st_dout_v <= '0';
            bus_rd    <= '0';

            case present_state is

                when bus_read_data =>
                    bus_rd  <= '1';
                    word_cnt_s  <= "00";
                    if bus_ack='1' then
                        bus_rd  <= '0';
                        bus_rdata_s <= (others => '0');
                        bus_rdata_s(bus_rdata'range) <= bus_rdata;
                        st_dout_v  <= '1';
                    end if;

                when send_data =>
                    if st_dout_rdy='1' then
                        case Ndata is
                            when 32 =>
                                bus_rdata_s <= x"00" & bus_rdata_s(31 downto 8);
                                if word_cnt_s /= word_size then
                                    word_cnt_s <= word_cnt_s + 1;
                                    st_dout_v  <= '1';
                                end if;
                            when 16 =>
                                bus_rdata_s <= x"000000" & bus_rdata_s(15 downto 8);
                                if word_cnt_s /= word_size then
                                    word_cnt_s <= word_cnt_s + 1;
                                    st_dout_v  <= '1';
                                end if;
                            when 8 => NULL;
                            when others => NULL;
                        end case;
                    end if;
                when others => NULL;
            end case;
        end if;
    end process;
    -- send the LSByte first
    st_dout <= bus_rdata_s(7 downto 0);

-- long transaction (up to 2048 words, use the full 16/24 bit address):
-- power_up -> idle -> recv_cmd -> recv_bsizeH -> recv_addrL -> recv_addrM -> recv_addrH ->

-- short transaction (up to 4 words, modify only the lower 8 bits of the address):
-- power_up -> idle -> recv_cmd -> recv_addrL ->

-- write
--   Nwords x (-> recv_data (1..4x) -> bus_write_data -> incr_addr -> check_addr) -> finish

-- read
--   Nwords x (-> bus_read_data -> send_data (1..4x)  -> incr_addr -> check_addr) -> finish

    process(present_state, go_next, long_tr, rd1_wr0, word_size, bus_ack, st_din_v, st_dout_rdy, use_lmask, selected,
                word_cnt_s, word_cnt_r, blk_end, was_short_c)
    begin
        next_state <= present_state;

        case present_state is

            when idle =>
                if use_lmask='1' then
                    next_state <= recv_smsk;
                else
                    next_state <= recv_cmd;
                end if;

            when recv_smsk =>
                if go_next='1' then
                    if was_short_c='0' then
                        next_state <= recv_cmd;
                    end if;
                end if;

            when recv_cmd =>
                if go_next='1' then
                    if long_tr='0' then
                        next_state <= recv_addrL;
                    else
                        next_state <= recv_bsizeH;
                    end if;
                end if;

            when recv_bsizeH =>
                if go_next = '1' then
                    next_state <= recv_addrL;
                end if;

            when recv_addrL =>
                if go_next = '1' then
                    if long_tr='0' then
                        if rd1_wr0='0' then
                            next_state <= recv_data;
                        else
                            next_state <= bus_read_data;
                        end if;
                    else
                        next_state <= recv_addrM;
                    end if;
                end if;

            when recv_addrM =>
                if Naddr=24 then
                    if go_next = '1' then
                        next_state <= recv_addrH;
                    end if;
                else
                    if go_next = '1' then
                        if rd1_wr0='0' then
                            next_state <= recv_data;
                        else
                            if selected='0' then
                                next_state <= idle;
                            else
                                next_state <= bus_read_data;
                            end if;
                        end if;
                    end if;
                end if;
            -- only in case Naddr=24
            when recv_addrH =>
                if go_next = '1' then
                    if rd1_wr0='0' then
                        next_state <= recv_data;
                    else
                        if selected='0' then
                            next_state <= idle;
                        else
                            next_state <= bus_read_data;
                        end if;
                    end if;
                end if;

            when recv_data =>
                if st_din_v = '1' then
                    if word_cnt_r=word_size then
                        next_state <= bus_write_data;
                    end if;
                end if;

            when bus_write_data =>
                if bus_ack='1' or selected='0' then
                    next_state <= incr_addr;
                end if;

            when incr_addr =>
                next_state <= check_addr;

            when check_addr =>
                if blk_end='1' then
                    next_state <= idle;
                elsif rd1_wr0='0' then
                    next_state <= recv_data;
                else
                    next_state <= bus_read_data;
                end if;

            when bus_read_data =>
                if bus_ack='1' then
                    next_state <= send_data;
                end if;

            when send_data =>
                if st_dout_rdy = '1' then
                    if word_cnt_s=word_size then
                        next_state <= incr_addr;
                    end if;
                end if;

            when others =>
                next_state <= idle;
        end case;

    end process;

    timeout <= '0';

end;
