-- $Id: regreg16.vhd 1136 2025-01-27 18:19:13Z angelov $:
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.all;
USE IEEE.STD_LOGIC_UNSIGNED.all;

entity regreg16 is
GENERIC (Nwidth : Integer := 32;   -- data path width
         Nr1mod : Integer :=  3;   -- up to Nwidth-1, number of bits in r1 that can be modified
         Nreg   : Integer := 16);  -- number of registers, possible values are 8 (smallest), 12 and 16 (max)
PORT (
        D         : IN  STD_LOGIC_VECTOR(Nwidth-1 downto 0);
        CLK       : IN  STD_LOGIC;
        WE        : IN  STD_LOGIC;
        DWORD     : IN  STD_LOGIC; -- WORD operation
        SEL_M     : IN  STD_LOGIC; -- selects the Byte
        WADDR     : IN  STD_LOGIC_VECTOR(3 downto 0);
        RADDR_A   : IN  STD_LOGIC_VECTOR(3 downto 0);
        RADDR_B   : IN  STD_LOGIC_VECTOR(3 downto 0);
        R1_MODIF  : IN  STD_LOGIC_VECTOR(Nr1mod-1 downto 0);
        RESET     : IN  STD_LOGIC; -- global reset
        QA        : OUT STD_LOGIC_VECTOR(Nwidth-1 downto 0);
        QB        : OUT STD_LOGIC_VECTOR(Nwidth-1 downto 0)
        );
end regreg16;

architecture a of regreg16 is

subtype reg_half is STD_LOGIC_VECTOR(Nwidth/2-1 downto 0);
subtype reg_full is STD_LOGIC_VECTOR(Nwidth-1   downto 0);
type reg16x_half is ARRAY (0 to Nreg-1) of reg_half;
type reg16x_full is ARRAY (0 to Nreg-1) of reg_full;
SIGNAL reg_L    : reg16x_half;
SIGNAL reg_H    : reg16x_half;
SIGNAL regw     : reg16x_full;
SIGNAL CLK_ENi  : STD_LOGIC_VECTOR(Nreg-1 downto 2);
SIGNAL CLK_EN_L : STD_LOGIC_VECTOR(Nreg-1 downto 2);
SIGNAL CLK_EN_H : STD_LOGIC_VECTOR(Nreg-1 downto 2);
constant NULL_HALF : reg_half := (others => '0');
SIGNAL D_INH    : reg_half;
begin
        reg_L(0) <= NULL_HALF; -- reg(0) is always 0
        reg_H(1) <= NULL_HALF; -- reg(0) is always 0

        process(R1_MODIF)
        begin
            reg_L(1) <= (others => '0');
            reg_L(1)(R1_MODIF'range) <= R1_MODIF;
            reg_H(1) <= NULL_HALF;
        end process;

        D_INH <= D(Nwidth-1 downto Nwidth/2) when DWORD='1' else D(Nwidth/2-1 downto 0);

        regw(0) <= reg_H( 0) & reg_L( 0);
        regw(1) <= reg_H( 1) & reg_L( 1);

drg: -- D-registers with clock enable
        for i in 2 to Nreg-1 generate

            CLK_ENi(i)  <= WE when (i=WADDR) else '0';
            CLK_EN_L(i) <= CLK_ENi(i) and (DWORD or (not DWORD and not SEL_M)); -- low
            CLK_EN_H(i) <= CLK_ENi(i) and (DWORD or (not DWORD and     SEL_M)); -- high

            process(CLK)
            begin
                if rising_edge(clk) then
                    if RESET='1' then
                        reg_L(i) <= NULL_HALF;
                    elsif CLK_EN_L(i)='1' then
                        reg_L(i) <= D(Nwidth/2-1 downto 0);
                    end if;

                    if RESET='1' then
                        reg_H(i) <= NULL_HALF;
                    elsif CLK_EN_H(i)='1' then
                        reg_H(i) <= D_INH;
                    end if;
                end if;
            end process;

            regw(i) <= reg_H(i) & reg_L(i);

        end generate;

        l16: if Nreg < 16 generate
            l16clr: for i in Nreg to 15 generate
                regw(i) <= (others => '0');
            end generate;
        end generate;

        qa <= regw(conv_integer(raddr_a));
        qb <= regw(conv_integer(raddr_b));
end;
