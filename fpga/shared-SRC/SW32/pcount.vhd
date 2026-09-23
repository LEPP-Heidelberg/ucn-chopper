LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.all;
USE IEEE.STD_LOGIC_UNSIGNED.all;

entity pcount is
GENERIC (Np : Integer := 8; IRQ_ADR : Integer := 1);
port
    (
        RTSA, JMPA      : IN  STD_LOGIC_VECTOR(Np-1 downto 0);
        JUMP, RTSorRTI  : IN  STD_LOGIC;
        CLK, PCE, RST   : IN  STD_LOGIC;
        J_IRQ           : IN  STD_LOGIC; -- jump to interrupt handler
        PC_next, PC     : OUT STD_LOGIC_VECTOR(Np-1 downto 0)
        );
end pcount;

architecture a of pcount is

SIGNAL PCP1V, D, PCint, PC_IRQ, PC_D  : STD_LOGIC_VECTOR(Np-1 downto 0);
SIGNAL SEL : STD_LOGIC_VECTOR(1 downto 0);

begin
        PC_IRQ <= CONV_STD_LOGIC_VECTOR(IRQ_ADR, Np);
        PCP1V  <= PCint + 1;
        SEL    <= RTSorRTI & JUMP;

        with  SEL select
        D <= PCP1V when "00",
             JMPA  when "01",
             RTSA  when others;

        PC_next <= PCP1V when J_IRQ='0' else D;

        PC_D <= (others => '0') when RST  ='1' else
                PCint           when PCE  ='0' else
                PC_IRQ          when J_IRQ='1' else
                D;

        process(CLK)
        begin
            if rising_edge(clk) then
                PCint <= PC_D;
            end if;
        end process;

        PC  <= PC_D; -- for synchronous memory

end;
