LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.all;
USE IEEE.STD_LOGIC_UNSIGNED.all;

-- $Id: prot_sm.vhd 979 2023-07-10 17:44:33Z angelov $:

use work.uart_pack.all;

entity prot_sm is

port (
    clk          : in  std_logic;
    rst_n        : in  std_logic;
    slaveID      : in  std_logic_vector(ID_size-1 downto 0);
    -- uart status
    crc8recvOK   : in  std_logic;
    din          : in  std_logic_vector(byte_size-1 downto 0);
    -- send sm
    start_send   : out std_logic;
    ready_s      : in  std_logic;
    busy_s       : in  std_logic;
    -- receive sm
    break        : in  std_logic;
    busy_r       : in  std_logic;
    valid_r      : in  std_logic;
    -- crc clear
    crc_clr      : out std_logic;
    -- address counter
    cload        : out std_logic;
    high_b       : out std_logic; -- load the high byte of the address counter
    cnten        : out std_logic;
    -- bus interface
    we           : out std_logic;
    rd_req       : out std_logic; -- used to protect the read register from changes
    bus_ack      : in  std_logic; -- is '1' when the data are written/ready
    -- 0 crc8sent, 1 crc8recv, 2 data_in from the internal bus, 3 direct data out
    sel_dout     : out std_logic_vector(1 downto 0);
    -- status
    timeout      : out std_logic; -- master packet broken
    crc_err      : out std_logic; -- crc error in the incoming data (from master)
    busy         : out std_logic;

    cmd_mode     : out std_logic;

    dir_send     : in  std_logic;

    cmd_valid    : out std_logic;
    cmd_data     : out std_logic_vector(byte_size-1 downto 0) );
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


type state_type is (idle, recv_size, recv_addrH, recv_addrL, recv_data, write_data, recv_crc, send_crc_r, --> finish
                                                             read_data, send_data, send_crc_s, finish, cmd_state);

attribute syn_enum_encoding : string;
attribute syn_enum_encoding of state_type : type is "gray";
-- The syn_encoding attribute has 4 values:
-- sequential, onehot, gray and safe.

signal present_state, next_state : state_type;

signal selected, selected_brcst : std_logic;
signal cnten_i : std_logic;
signal rd1wr0  : std_logic;
signal normal_write  : std_logic;
signal bus_ack_eff   : std_logic;
signal bus_ack_int   : std_logic;
-- store a flag for received data while waiting on the bus to complete a write transaction
-- the better solution is to use a FIFO, here this will work only for the last received data byte,
-- preceeding the CRC byte.
signal was_valid_r   : std_logic;

signal   size      : std_logic_vector(pfsize_size-1 downto 0);
constant size_zero : std_logic_vector(pfsize_size-1 downto 0) := (others => '0');

begin
    bus_ack_eff <= bus_ack_int or bus_ack; -- or the external ack with internal in case of special command

    process(clk)
    variable tmp : std_logic;
    begin
        if rising_edge(clk) then
            cmd_valid   <= '0';
            bus_ack_int <= '0';
            start_send  <= '0';
            if rst_n = '0' then
                size         <= (others => '0');
                cmd_data     <= (others => '0');
                rd1wr0       <= '1';
                selected     <= '0';
                selected_brcst <= '0';
                high_b       <= '0';
                normal_write <= '1';
            else
                case present_state is
                    when idle =>
                        selected <= '0';
                        selected_brcst <= '0';

                    -- generate ack signal when switch to command mode comes, as the bus will not answer now
                    when write_data =>
                        if normal_write='0' then
                            bus_ack_int <= selected or selected_brcst;
                        end if;
                    when recv_addrL =>
                        high_b <= '0';
                    when recv_addrH =>
                        high_b <= '1';
                    when others => NULL;
                end case;

                if (present_state = recv_crc  and (valid_r = '1' or was_valid_r='1') ) or                      -- to send the crc at the end of the master request
                   (present_state = send_data and ready_s = '1' and size = size_zero) or -- to send the crc at the end of the read block
                   (present_state = read_data and bus_ack = '1') or                      -- to send the data read from the internal bus
                   (present_state = cmd_state and dir_send='1') then                     -- to send the data send directly from the internal core
                    start_send <= selected or selected_brcst;      -- only when selected!
                end if;

                if valid_r = '1' then
                    case present_state is
                        -- load the low part of the size
                        when idle       =>
                            was_valid_r <= '0';
                            size(psize_size-1 downto 0) <= din(byte_size-1 downto ID_size + 1);
                            normal_write <= din(5) or din(6) or din(7); -- block_size[2..0] is 0 for special write
                             -- the first received byte is a header
                             -- check the slave ID
                             if din(ID_size downto 1) = slaveID then
                                 selected <= '1';
                             end if;
                             -- check for broadcast
                             if din(ID_size downto 1) = IDbrcst then
                                 selected_brcst <= '1';
                             end if;
                             -- read/write bit
                             rd1wr0 <= din(0);

                        -- load the high part of the size
                        when recv_size  =>
                            -- if block_size-1 is non-zero => normal write!
                            size(pfsize_size-1 downto psize_size) <= din;
                            normal_write <= normal_write or or_reduce(din);
                        when recv_addrL =>
                            -- if the address is not 0xFFFF => normal size!
                            if and_reduce(din)='0' then normal_write <= '1'; end if;
                        when recv_addrH =>
                            -- if the address is not 0xFFFF => normal size!
                            if and_reduce(din)='0' then normal_write <= '1'; end if;

                        -- CRC byte coming when waiting on the bus to complete a write transaction!
                        when write_data =>
                            was_valid_r <= '1';

                        when recv_data =>
                            -- if the data is not 0xFF => normal size!
                            if and_reduce(din)='0' then normal_write <= '1'; end if;
                        when cmd_state =>
                            -- activate the direct output when in command mode and selected and incoming data
                            if (selected = '1' or selected_brcst = '1') then
                                cmd_valid <= '1';
                                cmd_data  <= not din;
                            end if;
                        when others     => NULL;
                    end case;
                end if;

                -- down counter for the number of rest bytes
                if cnten_i = '1' then
                    size <= size - 1;
                end if;

            end if;
        end if;
    end process;

    -- address counter load
    cload <= valid_r when (present_state = recv_addrH) or (present_state = recv_addrL) else '0';
    -- write enable, store the received data
    we    <= normal_write when present_state = write_data and (selected = '1' or selected_brcst = '1') else '0';
    -- ??? check the case of sync reading, switch the address earlier to the reading!!!
    -- address counter increment
    -- decrement the internal size counter
    cnten_i <= '1' when (present_state = write_data and ( bus_ack_eff = '1' or (selected = '0' and selected_brcst = '0') ) ) or
                        (present_state = send_data and ready_s = '1') else '0';
    cnten <= cnten_i;

    busy   <= '1' when (present_state /= idle) or  (busy_s = '1') or  (busy_r = '1') else '0';
    rd_req <= '1' when (present_state = read_data) and (selected = '1' or selected_brcst = '1') else '0';

    crc_clr <= '1' when present_state = idle and busy_r = '0' and valid_r = '0' else '0';

    crc_err <= '1' when (crc8recvOK = '0') and (present_state = recv_crc) and (valid_r = '1' or was_valid_r = '1') else '0';
    timeout <= '0'; -- not ready

    -- mux control, select the data to send
    process(present_state)
    begin
        sel_dout <= "--";
        case present_state is
            when cmd_state              => sel_dout <= "11";   -- direct back send
            when send_crc_s             => sel_dout <= "00";   -- crc8sent
            when send_crc_r | recv_crc  => sel_dout <= "01";   -- crc8recv
            when send_data  | read_data => sel_dout <= "10";   -- data_in
            when others     => NULL;
        end case;
    end process;

    -- state machine register
    process(clk)
    begin
        if rising_edge(clk) then
            if rst_n = '0' then present_state <= idle;
                           else present_state <= next_state;
            end if;
        end if;
    end process;

-- write
-- idle -> recv_size -> recv_addrL/H -> recv_data -> write_data -> recv_crc -> send_crc_r -> finish -> idle
-- idle -> recv_size (size-1=0) -> recv_addrL/H (addr=FFFF) -> recv_data (data=FF) -> write_data (don't write) -> recv_crc -> send_crc_r -> cmd_state
-- command
-- cmd_state (when cmd=00) -> idle
-- read
-- idle -> recv_size -> recv_addrL/H -> recv_crc -> send_crc_r -> read_data -> send_data -> send_crc_s -> finish -> idle

    process(present_state, valid_r, ready_s, size, rd1wr0, busy_s, busy_r, selected_brcst, selected,
            break, bus_ack_eff, normal_write, din)
    begin
        cmd_mode <= '0';
        if break = '1' then next_state <= idle;
        else

        next_state <= present_state;

        case present_state is
            when idle =>
                if valid_r = '1' then
                    next_state <= recv_size;
                end if;

            when recv_size =>
                if valid_r = '1' then
                    next_state <= recv_addrL;
                end if;

            when recv_addrL =>
                if valid_r = '1' then
                    next_state <= recv_addrH;
                end if;

            when recv_addrH =>
                if valid_r = '1' then
                    if rd1wr0 = '1' then
                        next_state <= recv_crc;
                    else
                        next_state <= recv_data;
                    end if;
                end if;

            when recv_crc =>
                if valid_r = '1' or was_valid_r='1' then
                    if selected = '1' or selected_brcst = '1' then
                        next_state <= send_crc_r;
                    else
                        if rd1wr0='0' and normal_write='0' then
                            next_state <= cmd_state;
                        else
                            next_state <= finish;
                        end if;
                    end if;
                end if;

            when send_crc_r =>
                if ready_s = '1' then
                    if rd1wr0 = '1' then
                        next_state <= read_data;
                    else
                        if normal_write='0' then
                            next_state <= cmd_state;
                        else
                            next_state <= finish;
                        end if;
                    end if;
                end if;

            when recv_data =>
                if valid_r = '1' then
                    next_state <= write_data;
                end if;

            when write_data =>
                if bus_ack_eff = '1' or (selected = '0' and selected_brcst = '0') then
                    if size = size_zero then next_state <= recv_crc; -- one clock later is "111"
                                        else next_state <= recv_data;
                    end if;
                end if;

            when read_data =>
                if bus_ack_eff = '1' then
                    next_state <= send_data;
                end if;

            when send_data =>
                if ready_s = '1' then
                    if size = size_zero then next_state <= send_crc_s;
                                        else next_state <= read_data;
                    end if;
                end if;

            when send_crc_s =>
                if ready_s = '1' then
                    next_state <= finish;
                end if;

            when cmd_state =>
                cmd_mode <= '1';
                if valid_r = '1' and din=x"FF" then
                    next_state <= finish;
                end if;

            when finish =>
                if busy_s = '0' and busy_r = '0' then next_state <= idle; end if;
            when others => NULL;
        end case;
        end if;
    end process;

end;
