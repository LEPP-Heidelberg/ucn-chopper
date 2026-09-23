LIBRARY ieee;
USE ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
USE ieee.std_logic_unsigned.all;

entity stack_cntrl is
GENERIC (Nramt  : Integer := 16;  -- total width of the RAM address bus
         Nstack : Integer :=  4;  -- the part controlled by the stack pointer
         Ndata  : Integer := 32;  -- data width
         Nflag  : Integer :=  2;  -- number of flags
         Nrom   : Integer :=  8); -- the width of the ROM address bus
PORT(
        clk             : IN  STD_LOGIC;
        reset           : IN  STD_LOGIC;
        AE              : IN  STD_LOGIC;
        CE              : IN  STD_LOGIC;
        PUSH            : IN  STD_LOGIC;
        CZ_new          : IN  STD_LOGIC_VECTOR(Nflag-1 downto 0);
        Adr_in          : IN  STD_LOGIC_VECTOR(Nramt-1 downto 0);
        JS              : IN  STD_LOGIC;
        NxPC            : IN  STD_LOGIC_VECTOR(Nrom-1 downto 0);
        DataFromReg     : IN  STD_LOGIC_VECTOR(Ndata-1 downto 0);
        RAMD            : OUT STD_LOGIC_VECTOR(Ndata-1 downto 0);
        SPO             : OUT STD_LOGIC_VECTOR(Nstack-1 downto 0);
        Adr_out         : OUT STD_LOGIC_VECTOR(Nramt-1 downto 0)
        );
end stack_cntrl;

architecture a of stack_cntrl is

SIGNAL SP, A  : STD_LOGIC_VECTOR(Nstack-1 downto 0);
SIGNAL HiAddr : STD_LOGIC_VECTOR(Nramt-1  downto Nstack);
SIGNAL PANULL : STD_LOGIC_VECTOR(Ndata-Nflag-1 downto Nrom);
begin

        PANULL <= (others => '0');
        with JS select
        RAMD <= DataFromReg            when '0',
                CZ_new & PANULL & NxPC when others;

        -- stack segment will be at the end of the RAM
        HiAddr <= (others => '1');
        SPO <= SP;

        process(clk)
        begin
            if clk'event and clk='1' then
                if reset='1' then SP <= (others => '0');
                elsif (CE='1') then
                    if PUSH='1' then SP <= SP - 1;
                                else SP <= SP + 1;
                    end if;
                end if;
            end if;
        end process;

        process(PUSH, SP)
        begin
                if PUSH='1' then A <= SP - 1;
                            else A <= SP;
                end if;
        end process;

        with AE select
        Adr_out <= Adr_in     when '0',
                   HiAddr & A when others;
end;

