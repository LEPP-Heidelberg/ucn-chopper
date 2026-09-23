-- altera vhdl_input_version vhdl_2008

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-- $Id: uc2tx.vhd 1028 2023-11-07 17:10:22Z angelov $:

-- Addr     Regname
--  0   w   tx_ascii    write here to send one byte as two ASCII characters (first the ASCII char for bits 7..4, then for bits 3..0)
--  1   w   tx_nibbleL  write here to send one nibble as ASCII character (the ASCII char for bits 3..0)
--  2   w   tx_nibbleH  write here to send one nibble as ASCII character (the ASCII char for bits 7..4)
--  3   w   txdr        write here to send one complete byte 1:1
-- Note: reading from 0..3 is for debugging and returns the last written byte/nibble there

--  4   rw  status      rw: Bit 0 : fast_mode
--                      r: Bits: 1 - TX_FIFO_FULL, 2 - TX_FIFO_ALMOST_FULL, 3 - TX_FIFO_NOT_EMPTY
--                      writing here anything clears the FIFO and resets the send sm
--                      r: bit 7..4 - number of address bits in the TX_FIFO
--  5   w               write here anything to clear the FIFO and reset the send sm

entity uc2tx is
generic(
    USE_ACC     : boolean := false;
    -- decrement the accumulator after each clock
    ACC_DECR    : Positive := 125;
    -- size of the accumulator
    ACC_NBITS   : Positive := 10;
    -- the numbers here correspond to 32.768 MHz clock and 4 Mbit/s baud rate:
    -- the desired divider ratio is 32.768/4 = 8.192
    -- 8.192*ACC_DECR=2**ACC_NBITS
    -- so the "ideal" Bittime is 2**ACC_NBITS/ACC_DECR = system_clock/baud_rate
    Bittime  : Positive := 24; -- for normal transfer, by 48 MHz system clock 2 MBit/s
    BittimeF : Positive := 12; -- for faster transfer, must be smaller than Bittime!
    Ntx_fifo : Natural  :=  8; -- number of address bits in the tx FIFO
    LSBfirst : Boolean  := true);
port (
    csi_clk_sys     : in  std_logic;
    rsi_reset       : in  std_logic;
    -- CPU interface
    avs_mm_write    : in  std_logic;
    avs_mm_read     : in  std_logic;
    avs_mm_address  : in  std_logic_vector(2 downto 0);
    avs_mm_writedata: in  std_logic_vector(31 downto 0);
    avs_mm_readdata : out std_logic_vector(31 downto 0);
    -- serial interface
    coe_tx          : out std_logic;
    coe_busy        : out std_logic);
end uc2tx;

architecture struct of uc2tx is

component serial_send is
generic(
    USE_ACC     : boolean := false;
    -- decrement the accumulator after each clock
    ACC_DECR    : Positive := 125;
    -- size of the accumulator
    ACC_NBITS   : Positive := 10;
    -- the numbers here correspond to 32.768 MHz clock and 4 Mbit/s baud rate:
    -- the desired divider ratio is 32.768/4 = 8.192
    -- 8.192*ACC_DECR=2**ACC_NBITS
    -- so the "ideal" Bittime is 2**ACC_NBITS/ACC_DECR = system_clock/baud_rate
        LSBfirst : Boolean  := true;
        Bittime  : Positive := 24; -- for normal transfer, by 48 MHz system clock 2 MBit/s
        BittimeF : Positive := 12; -- for faster transfer, must be smaller than Bittime!
        Nidle    : Positive := 2;  -- idle bits
        Nbits    : Positive := 8); -- data bits
port (
    clk     : in  std_logic;
    reset   : in  std_logic;
    -- switch to the second (smaller) BittimeF?
    fast_m  : in  std_logic := '0';
    -- parallel data input
    start   : in  std_logic;
    din     : in  std_logic_vector(Nbits-1 downto 0);
    -- serial output
    tx      : out std_logic;
    -- status
    crc_ena : out std_logic;
    parity  : out std_logic;
    busy    : out std_logic;
    ready   : out std_logic);
end component;

component crc8reg is
generic(LSBfirst : Boolean := true);
port (
    clk    : in  std_logic;
    load   : in  std_logic;
    din    : in  std_logic;
    ena    : in  std_logic;
    crc8   : out std_logic_vector(7 downto 0));
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

subtype nibble is std_logic_vector(3 downto 0);
subtype byte   is std_logic_vector(7 downto 0);

subtype addr_type is std_logic_vector(2 downto 0);
constant ADDR_TX_ASCII  : addr_type := 3x"0";
constant ADDR_TX_NIB_L  : addr_type := 3x"1";
constant ADDR_TX_NIB_H  : addr_type := 3x"2";
constant ADDR_TX_BYTE   : addr_type := 3x"3";
constant ADDR_CNF_STA   : addr_type := 3x"4";
constant ADDR_CNF_STA1  : addr_type := 3x"5";
constant ADDR_INI_CRC8  : addr_type := 3x"6";
constant ADDR_TX_CRC8   : addr_type := 3x"7";
constant BIT_CNF_TURBO  : Integer := 0;
constant BIT_STA_FULL   : Integer := 1;
constant BIT_STA_AFULL  : Integer := 2;
constant BIT_STA_NEMPTY : Integer := 3;
constant BIT_STA_SIZE   : Integer := 4;  -- 7..4

signal din_byte     : byte;
signal din_ascii    : byte;
signal din_nibble   : byte;
signal din_tx       : byte;
signal din_tx_fifo  : byte;
signal crc8sent     : byte;
signal dout_tx_fifo : byte;

signal flag_din     : std_logic;
signal flag_dout    : std_logic;

signal start_send   : std_logic;
signal turbo_bit    : std_logic;

signal ready_s      : std_logic;
signal fifo_al_full : std_logic;
signal fifo_full    : std_logic;
signal fifo_empty   : std_logic;
signal busy_f       : std_logic;

signal sclr_tx_fifo : std_logic;
signal we_old       : std_logic;
signal we_tx_fifo   : std_logic;
signal rd_tx_fifo   : std_logic;

type tx_sm_type is (tx_idle, tx_send, tx_fifo_rd, tx_init_crc);
signal tx_sm        : tx_sm_type;

signal tx           : std_logic;
signal clk          : std_logic;
signal reset        : std_logic;
    -- CPU interface
signal we           : std_logic;
signal we_1         : std_logic;
signal addr         : std_logic_vector(2 downto 0);
signal wdata        : byte;
signal rdata        : byte;
signal d2send       : byte;
signal status       : byte;

signal crc_ena      : std_logic;
signal tx_i         : std_logic;
signal crc_ini      : std_logic;


function nibble2ascii(nib : nibble) return byte is
variable tmp : byte;
begin
    case nib is      -- convert nibble to ASCII code
                                                -- ASCII code of
        when x"0" => tmp := x"30";     -- 0
        when x"1" => tmp := x"31";     -- 1
        when x"2" => tmp := x"32";     -- 2
        when x"3" => tmp := x"33";     -- 3
        when x"4" => tmp := x"34";     -- 4
        when x"5" => tmp := x"35";     -- 5
        when x"6" => tmp := x"36";     -- 6
        when x"7" => tmp := x"37";     -- 7
        when x"8" => tmp := x"38";     -- 8
        when x"9" => tmp := x"39";     -- 9
        when x"A" => tmp := x"41";     -- A
        when x"B" => tmp := x"42";     -- B
        when x"C" => tmp := x"43";     -- C
        when x"D" => tmp := x"44";     -- D
        when x"E" => tmp := x"45";     -- E
        when x"F" => tmp := x"46";     -- F
        when others => tmp := (others => '-');
    end case;
    return tmp;
end;

begin
    -- wrapper
    clk   <= csi_clk_sys     ;
    reset <= rsi_reset       ;
    we    <= avs_mm_write    ;
    addr  <= avs_mm_address  ;
    wdata <= avs_mm_writedata(7 downto 0);
    coe_tx<= tx;
    avs_mm_readdata <= x"000000" & rdata ;

    process(clk)
    variable we_re : std_logic;
    begin
        if rising_edge(clk) then
            we_tx_fifo <= '0';
            sclr_tx_fifo <= reset; -- clear fifo flag
            we_old <= we;
            we_re := we and not we_old;
            we_1 <= we_re;
            case addr is
                when ADDR_TX_ASCII =>
                    flag_din    <= '0';
                    if we_re='1' then  -- immediately with WE write the left half of the byte as ASCII to the FIFO
                        din_ascii   <= wdata;
                        din_tx_fifo <= nibble2ascii(wdata(7 downto 4));
                        we_tx_fifo <= '1';
                    elsif we_1='1' then -- one clock later write the second half of the byte as ASCII to the FIFO
                        din_tx_fifo <= nibble2ascii(din_ascii(3 downto 0));
                        we_tx_fifo <= '1';
                    end if;
                when ADDR_TX_NIB_L =>
                    flag_din    <= '0';
                    if we_re='1' then
                        din_nibble  <= nibble2ascii(wdata(3 downto 0)); -- only for debugging!
                        din_tx_fifo <= nibble2ascii(wdata(3 downto 0));
                        we_tx_fifo <= '1';
                    end if;
                when ADDR_TX_NIB_H =>
                    flag_din    <= '0';
                    if we_re='1' then
                        din_nibble  <= nibble2ascii(wdata(7 downto 4)); -- only for debugging!
                        din_tx_fifo <= nibble2ascii(wdata(7 downto 4));
                        we_tx_fifo <= '1';
                    end if;
                when ADDR_TX_BYTE =>
                    flag_din    <= '0';
                    if we_re='1' then
                        din_byte    <= wdata; -- only for debugging!
                        din_tx_fifo <= wdata;
                        we_tx_fifo <= '1';
                    end if;

                when ADDR_TX_CRC8 =>
                    flag_din    <= '1';
                    if we_re='1' then
                        din_byte(0) <= '1'; -- only for debugging!
                        din_tx_fifo(0) <= '1';
                        we_tx_fifo  <= '1';
                    end if;
                when ADDR_INI_CRC8 =>
                    flag_din    <= '1';
                    if we_re='1' then
                        din_byte(0) <= '0'; -- only for debugging!
                        din_tx_fifo(0) <= '0';
                        we_tx_fifo  <= '1';
                    end if;

                when ADDR_CNF_STA =>
                    sclr_tx_fifo  <= we; -- clear fifo flag
                    if we_re='1' then
                        if BittimeF < Bittime then
                            turbo_bit <= wdata(BIT_CNF_TURBO);
                        else
                            turbo_bit <= '0';
                        end if;
                    end if;
                when ADDR_CNF_STA1 =>
                    sclr_tx_fifo  <= we; -- clear fifo flag
                when others => NULL;
            end case;

            if reset='1' then
                turbo_bit <= '0';
            end if;

        end if;
    end process;

    -- state machine
    process(clk)
    begin
        if rising_edge(clk) then
            -- state machine to read from the tx FIFO and start the UART TX
            start_send <= '0';
            rd_tx_fifo <= '0';
            crc_ini    <= '0';

            -- for debugging
            if start_send='1' then
                d2send <= din_tx;
            end if;

            -- reset
            if sclr_tx_fifo='1' then
                tx_sm   <= tx_idle;
                busy_f  <= '0';
                crc_ini <= '1';
            else
                -- states
                case tx_sm is
                    when tx_idle =>
                        busy_f <= '0';
                        if fifo_empty='0' and busy_f = '0' then -- some data in TX fifo
                            tx_sm <= tx_fifo_rd;
                        end if;

                    when tx_fifo_rd =>
                        if flag_dout='0' then   -- normal data
                            tx_sm      <= tx_send;  -- start sending
                            din_tx     <= dout_tx_fifo;
                            start_send <= '1';
                            busy_f     <= '1';
                        else
                            if dout_tx_fifo(0)='0' then -- init CRC
                                tx_sm   <= tx_init_crc;
                                crc_ini <= '1';
                                busy_f  <= '1';
                            else -- send CRC
                                tx_sm      <= tx_send;  -- start sending
                                din_tx     <= crc8sent;
                                start_send <= '1';
                                busy_f     <= '1';
                            end if;
                        end if;

                    when tx_init_crc =>
                        rd_tx_fifo <= '1';
                        tx_sm      <= tx_idle;

                    when tx_send =>
                        rd_tx_fifo <= start_send;
                        if ready_s = '1' then
                            tx_sm <= tx_idle;
                        end if;
                end case;
            end if;
        end if;
    end process;

tx_fifo: sc_fifo  -- FIFO for the TX data
generic map(
        Na     => Ntx_fifo,
        Nd     => din_tx'length + 1,
       async_rd => false)
port map
    (
     din     => flag_din & din_tx_fifo,
     wrreq   => we_tx_fifo,
     rdreq   => rd_tx_fifo,
     clk     => clk,
     sclr    => sclr_tx_fifo,
     dout(7 downto 0) => dout_tx_fifo,
     dout(8)          => flag_dout,
     full    => fifo_full,
     afull   => fifo_al_full,
     empty   => fifo_empty);

crc8snt: crc8reg
generic map(LSBfirst => LSBfirst)
port map(
    clk    => clk,
    load   => crc_ini,
    din    => tx_i,
    ena    => crc_ena,
    crc8   => crc8sent);

uart_i: serial_send
generic map(
    USE_ACC     => USE_ACC,
    -- decrement the accumulator after each clock
    ACC_DECR    => ACC_DECR,
    -- size of the accumulator
    ACC_NBITS   => ACC_NBITS,
    -- the numbers here correspond to 32.768 MHz clock and 4 Mbit/s baud rate:
    -- the desired divider ratio is 32.768/4 = 8.192
    -- 8.192*ACC_DECR=2**ACC_NBITS
    -- so the "ideal" Bittime is 2**ACC_NBITS/ACC_DECR = system_clock/baud_rate
    LSBfirst    => LSBfirst,
    Bittime     => Bittime,
    BittimeF    => BittimeF,
    Nidle       => 2,
    Nbits       => din_tx'length)
port map(
    clk     => clk,
    reset   => sclr_tx_fifo,
    -- switch to the second (smaller) BittimeF?
    fast_m  => turbo_bit,
    -- parallel data input
    start   => start_send,
    din     => din_tx,
    -- serial output
    tx      => tx_i,
    -- status
    crc_ena => crc_ena,
    parity  => open,
    busy    => coe_busy,
    ready   => ready_s);

    tx <= tx_i;

    -- read process
    process(all)
    begin
        status <= (others => '0');
        status(BIT_CNF_TURBO)  <= turbo_bit;
        status(BIT_STA_NEMPTY) <= not fifo_empty;
--        status(BIT_STA_NEMPTY) <= busy_f;
        status(BIT_STA_FULL)   <= fifo_full;
        status(BIT_STA_AFULL)  <= fifo_al_full;
        status(BIT_STA_SIZE+3 downto BIT_STA_SIZE) <= conv_std_logic_vector(Ntx_fifo, 4);
    end process;

    process(clk)
    begin
        if rising_edge(clk) then
            rdata  <= (others => '0');
            case addr is
                when ADDR_TX_BYTE  => rdata <= din_byte;    -- only for debugging
                when ADDR_TX_CRC8  => rdata <= crc8sent;    -- only for debugging
                when ADDR_INI_CRC8 => rdata <= crc8sent;    -- only for debugging
                when ADDR_TX_ASCII => rdata <= din_ascii;   -- only for debugging
                when ADDR_TX_NIB_L => rdata <= din_nibble;  -- only for debugging
                when ADDR_TX_NIB_H => rdata <= din_nibble;  -- only for debugging
                when ADDR_CNF_STA  => rdata <= status;      -- status flags and turbo bit
                when ADDR_CNF_STA1 => rdata <= d2send;      -- the last sent data
                when others => NULL;
            end case;
        end if;
    end process;
end;
