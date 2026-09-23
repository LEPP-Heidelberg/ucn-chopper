-- $Id: program.vhd 1180 2026-01-28 17:54:04Z angelov $:

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

library work;
use work.ds_pack.all;

entity program is
generic (short_prog : boolean := true);
port(
    raddr : in  std_logic_vector( 4 downto 0);
    tres  : in  std_logic_vector( 1 downto 0);
    tL    : in  std_logic_vector( 7 downto 0); -- T low
    tH    : in  std_logic_vector( 7 downto 0); -- T high
    rdata : out std_logic_vector(11 downto 0));

end program;

architecture a of program is


constant skipROM : std_logic_vector(11 downto 0) := wr_cmd & X"CC";
constant stConv  : std_logic_vector(11 downto 0) := wr_cmd & X"44";
constant wtConv  : std_logic_vector(11 downto 0) := h_high & X"FF";
constant wrScrPd : std_logic_vector(11 downto 0) := wr_cmd & X"4E";
constant rdScrPd : std_logic_vector(11 downto 0) := wr_cmd & X"BE";
constant rdROM   : std_logic_vector(11 downto 0) := wr_cmd & X"33";

signal   wrConf  : std_logic_vector(11 downto 0);
signal   wr_tL   : std_logic_vector(11 downto 0);
signal   wr_tH   : std_logic_vector(11 downto 0);
signal   wtime   : std_logic_vector( 7 downto 0);

begin
    wrConf <= wr_cmd & '0' & tres & "11111";

    wr_tL  <= wr_cmd & tL;
    wr_tH  <= wr_cmd & tH;

    with tres select
    wtime  <= X"E0" when "11",
              X"70" when "10",
              X"38" when "01",
              X"1C" when "00",
              (others => '-') when others;

    process(raddr, wr_tL, wr_tH, wrConf, wtime)
    begin
        rdata <= stop & X"FF";
        case raddr is
        when 5x"00"  => rdata(rdata'high downto rdata'high-3) <= reset;
        when 5x"01"  => rdata <= skipROM;
        when 5x"02"  => rdata <= wrScrPd;
        when 5x"03"  => rdata <= wr_tH;
        when 5x"04"  => rdata <= wr_tL;
        when 5x"05"  => rdata <= wrConf;
        when 5x"06"  => rdata(rdata'high downto rdata'high-3) <= reset;
        when 5x"07"  => rdata <= skipROM;
        when 5x"08"  => rdata <= stConv;
        when 5x"09"  => rdata <= h_high & wtime;
        when 5x"0A"  => rdata(rdata'high downto rdata'high-3) <= reset;
        when 5x"0B"  => rdata <= skipROM;
        when 5x"0C"  => rdata <= rdScrPd;
        when 5x"0D"  => rdata <= rd_cmd & X"00";
        when 5x"0E"  => rdata <= rd_cmd & X"01";
        when 5x"0F"  => rdata <= rd_cmd & X"02";
        when 5x"10"  => rdata <= rd_cmd & X"03";
        when 5x"11"  => rdata <= rd_cmd & X"04";
        when 5x"12"  => if short_prog then
                            rdata(rdata'high downto rdata'high-3) <= stop;
                        else
                            rdata(rdata'high downto rdata'high-3) <= reset;
                        end if;

        when 5x"13"  => if not short_prog then rdata <= rdROM; end if;
        when 5x"14"  => if not short_prog then rdata <= rd_cmd & X"05"; end if;
        when 5x"15"  => if not short_prog then rdata <= rd_cmd & X"06"; end if;
        when 5x"16"  => if not short_prog then rdata <= rd_cmd & X"07"; end if;
        when 5x"17"  => if not short_prog then rdata <= rd_cmd & X"08"; end if;
        when 5x"18"  => if not short_prog then rdata <= rd_cmd & X"09"; end if;
        when 5x"19"  => if not short_prog then rdata <= rd_cmd & X"0A"; end if;
        when 5x"1A"  => if not short_prog then rdata <= rd_cmd & X"0B"; end if;
        when 5x"1B"  => if not short_prog then rdata <= rd_cmd & X"0C"; end if;
        when 5x"1C"  => if not short_prog then rdata(rdata'high downto rdata'high-3) <= stop; end if;
        when others => NULL;
        end case;
    end process;
end;
