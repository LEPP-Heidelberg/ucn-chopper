library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity sc_fifo is
generic (Na     : Positive := 4;
         Nd     : positive := 8;
       async_rd : Boolean  := false);
PORT
    (
     din     : in std_logic_vector(Nd-1 downto 0);
     wrreq   : in std_logic;   -- write din & increment the write address at the next clock
     rdreq   : in std_logic;   -- increment the read address at the next clock
     clk     : in std_logic;
     sclr    : in std_logic;   -- clear all
     -- data valid normally, rdreq increments the read pointer
     dout    : out std_logic_vector(Nd-1 downto 0);
     full    : out std_logic;  -- fifo is full, do not write!
     afull   : out std_logic;  -- fifo is almost full (one word more can be stored)
     empty   : out std_logic   -- fifo is empty, do not read!
    );
end sc_fifo;

architecture a of sc_fifo is

-- disable the GSR in Lattice XO2/XO3D/XO4, otherwise it can be that
-- the EBR outputs are permanently resettet returning 0's.
ATTRIBUTE GSR : string;
ATTRIBUTE GSR OF dpr: label IS "DISABLED";

component dpram is
generic (Na     : Positive := 4;
         Nd     : positive := 8;
         LATTICE : boolean := true;
       async_rd : Boolean := true);
port(
    clk_r   : in  std_logic;
    clk_w   : in  std_logic;
    we      : in  std_logic;
    raddr   : in  std_logic_vector(Na-1 downto 0);
    waddr   : in  std_logic_vector(Na-1 downto 0);
    din     : in  std_logic_vector(Nd-1 downto 0);
    dout    : out std_logic_vector(Nd-1 downto 0) );
end component;

signal almost_full  : std_logic_vector(Na-1 downto 0);
signal almost_empty : std_logic_vector(Na-1 downto 0);
signal wpointer     : std_logic_vector(Na-1 downto 0);
signal rpointer     : std_logic_vector(Na-1 downto 0);
signal nwords       : std_logic_vector(Na   downto 0);
signal nwords_sh    : std_logic_vector(Na-1 downto 0);

signal fifo_cmd     : std_logic_vector(   1 downto 0);
signal fifo_status  : std_logic_vector(   1 downto 0);

signal fifo_full    : std_logic;
signal fifo_empty   : std_logic;
signal wr_mem       : std_logic;

begin
    almost_full  <= (others => '1');
    almost_empty <= (0 => '1', others => '0');

    fifo_cmd    <= wrreq & rdreq;
    fifo_status <= fifo_full & fifo_empty;

    fifo_full   <= nwords(nwords'high);
    nwords_sh   <= nwords(nwords_sh'range);

    afull <= '1' when nwords_sh=almost_full else '0';

    process(clk)
    begin
        if clk'event and clk='1' then
            if sclr = '1' then
                wpointer   <= (others => '0');
                rpointer   <= (others => '0');
                nwords     <= (others => '0');
                fifo_empty <= '1';
            else
                case fifo_cmd is
                when "10"   => -- write
                    if fifo_full='0' then
                        wpointer <= wpointer+1;
                        nwords   <= nwords  +1;
                        fifo_empty <= '0';
                    end if;
                when "01"   => -- read
                    if fifo_empty='0' then
                        rpointer <= rpointer+1;
                        if nwords_sh = almost_empty then fifo_empty <= '1'; end if;
                        nwords   <= nwords  -1;
                    end if;
                when "11"   => -- read & write
                    case fifo_status is
                    when "00" => -- not full, not empty
                        wpointer <= wpointer+1;
                        rpointer <= rpointer+1;
                    when "10" => --     full, not empty
                        nwords   <= nwords  -1;
                        rpointer <= rpointer+1;
                    when "01" => -- not full,     empty
                        nwords     <= nwords  +1;
                        wpointer   <= wpointer+1;
                        fifo_empty <= '0';
                    when others => NULL; -- should not happen!!!
                    end case;
                when "00"   => NULL;
                when others => wpointer   <= (others => '-');
                               rpointer   <= (others => '-');
                               nwords     <= (others => '-');
                               fifo_empty <= '-';
                end case;
            end if;
        end if;
    end process;

    wr_mem <= wrreq and not fifo_full;

dpr: dpram
    generic map(
      async_rd => async_rd,
      LATTICE => true,
      Na    => Na,
      Nd    => Nd)
     PORT map(
      din   => din,
      waddr => wpointer,
      raddr => rpointer,
      we    => wr_mem,
      clk_r => clk,
      clk_w => clk,
      dout  => dout);

    empty <= fifo_empty;
    full  <= fifo_full;

end;

