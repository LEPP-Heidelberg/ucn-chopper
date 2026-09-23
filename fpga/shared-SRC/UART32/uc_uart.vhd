LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

-- $Id: uc_uart.vhd 931 2022-10-15 07:35:38Z angelov $:

-- Addr     Regname
--  0   w   txdr        write here to send data
--  1   w   tx_ascii    write here anything to send the byte as ascii text (hex, in two characters)

--  2   r   rxdr        received data
--  2   w   rxdr        write anything here to clear the rx-flag, bit 7 is clear tx fifo

--  3   w   rx clear    write anything here to clear the rx-fifo (not ready),  bit 7 is clear tx fifo, bit 5 is pause_send
--  3   r   status      Bits: 0 - send ready latched, 1 - TX fifo full, 2 - recv ready latched, 3 - recv busy, 4 - TX_FIFO_BUSY, 5 - pause_send


entity uc_uart is
generic(Bittime  : Positive := 10;
        Ntx_fifo : Natural  :=  8; -- number of address bits in the tx FIFO
        LSBfirst : Boolean  := true;
        Nfilt    : Positive := 3);
port (
    clk          : in  std_logic;
    reset        : in  std_logic;
    -- serial interface
    tx_pause     : in  std_logic := '0'; -- UART input
    rx           : in  std_logic;
    tx           : out std_logic;
    -- CPU interface
    we           : in  std_logic;
    addr         : in  std_logic_vector(1 downto 0);
    data_out     : in  std_logic_vector(7 downto 0);
    data_in      : out std_logic_vector(7 downto 0));
end uc_uart;

architecture struct of uc_uart is

component uart is
generic(Bittime  : Positive := 10;
        BittimeF : Positive :=  5;
        Nfilt    : Positive :=  3;
        LSBfirst : Boolean  := true;
        Nidle    : Positive :=  2;
        Nbits    : Positive :=  9); -- with the parity bit
port (
    clk          : in  std_logic;
    reset        : in  std_logic;
    fast_m       : in  std_logic := '0';
    -- serial interface
    rx           : in  std_logic;
    tx           : out std_logic;
    --
    break        : out std_logic;
    -- write
    ready_s      : out std_logic;
    busy_s       : out std_logic;
    we           : in  std_logic;
    din          : in  std_logic_vector(Nbits-1 downto 0);
    -- read
    busy_r       : out std_logic;
    valid_r      : out std_logic;
    dout         : out std_logic_vector(Nbits-1 downto 0) );
end component;

component sc_fifo is
generic (Na     : Positive := 4;
         Nd     : positive := 8;
       async_rd : Boolean  := true);
PORT
    (
     din     : in std_logic_vector(Nd-1 downto 0);
     wrreq   : in std_logic;   -- write din & increment the write address at the next clock
     rdreq   : in std_logic;   -- increment the read address at the next clock
     clk     : in std_logic;
     sclr    : in std_logic;   -- clear all
     dout    : out std_logic_vector(Nd-1 downto 0);
     full    : out std_logic;  -- fifo is full, do not write!
     afull   : out std_logic;  -- fifo is almost full (one one word can be stored)
     empty   : out std_logic   -- fifo is empty, do not read!
    );
end component;

signal din_stored   : std_logic_vector(7 downto 0);
signal din_ascii    : std_logic_vector(7 downto 0);
signal din_tx       : std_logic_vector(7 downto 0);
signal data_rx      : std_logic_vector(7 downto 0);
signal din_tx_fifo  : std_logic_vector(7 downto 0);
signal status       : std_logic_vector(7 downto 0);

signal start_send   : std_logic;
signal tx_pause_old : std_logic;

signal ready_s      : std_logic;
signal busy_s       : std_logic;
signal busy_r       : std_logic;
signal busy_f       : std_logic;
signal valid_r      : std_logic;
signal pause_send   : std_logic;

signal ready_r_l    : std_logic;
signal ready_s_l    : std_logic;

signal sclr_tx_fifo : std_logic;
signal we_old       : std_logic;
signal we_lsn       : std_logic;
signal we_tx_fifo   : std_logic;
signal rd_tx_fifo   : std_logic;
signal tx_fifo_empty : std_logic;

type tx_sm_type is (tx_idle, tx_send);
signal tx_sm        : tx_sm_type;

begin

    -- with FIFO, with ASCII mode, no CRC generator
    process(clk)
    begin
        if rising_edge(clk) then
            we_old <= we;                    -- old we to detect rising edge

            if addr="01" then
                we_lsn <= we and not we_old; -- set write enable for the less significant nibble
            else
                we_lsn <= '0';               -- no nibble write at the other addresses
            end if;
        end if;
    end process;

    process(data_out, we, we_old, addr, we_lsn)
    variable nibble_ascii : std_logic_vector(7 downto 0);
    variable din_tx_digit : std_logic_vector(3 downto 0);
    begin

        if we='1' and we_old='0' then
            din_tx_digit := data_out(7 downto 4);   -- send upper nibble first
        else
            din_tx_digit := data_out(3 downto 0);   -- then lower nibble
        end if;

        case din_tx_digit is                        -- convert nibble to ASCII code
            when x"0" => nibble_ascii := x"30";     -- ASCII code of 0
            when x"1" => nibble_ascii := x"31";
            when x"2" => nibble_ascii := x"32";
            when x"3" => nibble_ascii := x"33";
            when x"4" => nibble_ascii := x"34";
            when x"5" => nibble_ascii := x"35";
            when x"6" => nibble_ascii := x"36";
            when x"7" => nibble_ascii := x"37";
            when x"8" => nibble_ascii := x"38";
            when x"9" => nibble_ascii := x"39";
            when x"A" => nibble_ascii := x"41";
            when x"B" => nibble_ascii := x"42";
            when x"C" => nibble_ascii := x"43";
            when x"D" => nibble_ascii := x"44";
            when x"E" => nibble_ascii := x"45";
            when x"F" => nibble_ascii := x"46";
            when others => nibble_ascii := (others => '-');
        end case;

        if we='1' and addr="00" then
            din_tx_fifo <= data_out;                -- send binary
        else
            din_tx_fifo <= nibble_ascii;            -- send as ASCII in two characters
        end if;

        if we='1' and we_old='0' and (addr="00" or addr="01") then
            we_tx_fifo <= '1';                      -- write to the FIFO the byte (or ASCII char of the nibble)
        else
            we_tx_fifo <= we_lsn;                   -- eventually write to the FIFO the second nibble ASCII char
        end if;
    end process;

    process(clk)
    begin
        if rising_edge(clk) then
            tx_pause_old <= tx_pause;
            sclr_tx_fifo <= reset;
            if we='1' then
                case addr is
                when "00" => din_stored <= data_out; -- store here the written bytes only for debugging
                when "01" => din_ascii  <= data_out;
                when "10" | "11" => sclr_tx_fifo  <= data_out(7) or reset; -- clear fifo flag
                                    pause_send    <= data_out(5);          -- software control of pause in TX
                when others => NULL;
                end case;
            end if;

            if tx_pause='1' and tx_pause_old='0' then pause_send <= '1'; end if; -- rising edge of tx_pause
            if tx_pause='0' and tx_pause_old='1' then pause_send <= '0'; end if; -- falling edge of tx_pause

            -- state machine to read from the tx FIFO and start the UART TX
            start_send <= '0';
            rd_tx_fifo <= start_send;
            if sclr_tx_fifo='1' then
                tx_sm <= tx_idle;
                busy_f <= '0';
            else
                case tx_sm is
                when tx_idle =>
                    if tx_fifo_empty='0' and pause_send = '0' then -- some data in TX fifo
                        tx_sm <= tx_send;     -- start sending
                        start_send <= '1';
                        busy_f <= '1';
                    else
                        busy_f <= '0';
                    end if;
                when tx_send =>
                    busy_f <= '1';
                    if ready_s = '1' then
                        tx_sm <= tx_idle;
                    end if;
                end case;
            end if;

            if reset='1' then
                pause_send <= '0';
            end if;

        end if;
    end process;

tx_fifo: sc_fifo  -- FIFO for the TX data
generic map(
        Na     => Ntx_fifo,
        Nd     => 8,
       async_rd => false)
port map
    (
     din     => din_tx_fifo,
     wrreq   => we_tx_fifo,
     rdreq   => rd_tx_fifo,
     clk     => clk,
     sclr    => sclr_tx_fifo,
     dout    => din_tx,
     full    => busy_s,
     afull   => open,
     empty   => tx_fifo_empty);

uart_i: uart
generic map(Bittime  => Bittime,
            Nbits    => 8,
            LSBfirst => LSBfirst,
            Nfilt    => Nfilt)
port map(
    clk          => clk,
    reset        => reset,
    -- serial interface
    rx           => rx,
    tx           => tx,
    -- uP interface
    ready_s      => ready_s,
    busy_s       => open,
    busy_r       => busy_r,
    valid_r      => valid_r,
    break        => open,
    -- write
    we           => start_send,
    din          => din_tx,
    -- read
    dout         => data_rx);

    process(addr, data_rx, status, din_tx_fifo, din_stored, din_ascii)
    begin
        data_in <= (others => '0');
        case addr is
        when "00" => data_in <= din_stored; -- only for debugging
        when "01" => data_in <= din_ascii;  -- only for debugging
        when "10" => data_in <= data_rx;    -- received data
        when "11" => data_in <= status;     -- status flags
        when others => NULL;
        end case;
    end process;

    status <= "00" & pause_send & busy_f & busy_r & ready_r_l & busy_s & tx_fifo_empty;

    process(clk)  -- latch the ready flags until the next write command
    begin
        if rising_edge(clk) then
            if reset = '1' or we = '1' then -- clear both flags if anything written
                ready_r_l <= '0';
                ready_s_l <= '0';
            else
                ready_r_l <= ready_r_l or valid_r;
                ready_s_l <= ready_s_l or ready_s;
            end if;
        end if;
    end process;

end;
