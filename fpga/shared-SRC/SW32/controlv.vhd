-- $Id: controlv.vhd 1136 2025-01-27 18:19:13Z angelov $:
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

use work.sw32_pack.all;

entity controlv is
GENERIC( Nd     : Integer := 32;  -- data path width
         Nf     : Integer :=  2); -- number of flags
port
    (
    CLK             : IN  STD_LOGIC;                       -- global clk
    RESET           : IN  STD_LOGIC;                       -- global reset
    PDAT            : IN  STD_LOGIC_VECTOR(  23 downto 0);   -- program data
    ARES            : IN  STD_LOGIC_VECTOR(Nd-1 downto 0); -- result in ALU
    RAMQ            : IN  STD_LOGIC_VECTOR(Nd-1 downto 0); -- output from RAM
    IO_Q            : IN  STD_LOGIC_VECTOR(Nd-1 downto 0); -- output from I/O dev
    CZ_stored       : IN  STD_LOGIC_VECTOR(Nf-1 downto 0); -- carry & zero from ALU
    IRQ             : IN  STD_LOGIC;               -- IRQ, positive edge sensitive
    IO_rdy          : IN  STD_LOGIC;
    REG_WE          : OUT STD_LOGIC;                       -- register write enable
    RAM_WE          : OUT STD_LOGIC;                       -- RAM write enable
    RAM_RD          : OUT STD_LOGIC;
    IO_WE           : OUT STD_LOGIC;                       -- I/O write enable
    IO_RD           : OUT STD_LOGIC;                       -- 1 for external dev read
    WA              : OUT STD_LOGIC_VECTOR(3 downto 0);    -- write register #
    RB              : OUT STD_LOGIC_VECTOR(3 downto 0);    -- read register B #
    RC              : OUT STD_LOGIC_VECTOR(3 downto 0);    -- read register C #
    R1_MODIF        : OUT STD_LOGIC_VECTOR(R1MD_WIDTH-1 downto 0);    -- modify r1 to another constant
    OPCODE          : OUT STD_LOGIC_VECTOR(4 downto 0);    -- operation code to ALU
    OPINFO          : OUT STD_LOGIC_VECTOR(OP_INFO_WIDTH-1 downto 0);    -- additional op info
    RG_IN           : OUT STD_LOGIC_VECTOR(Nd-1 downto 0); -- output to register file
    JUMP            : OUT STD_LOGIC;               -- jump
    RTSorRTI        : OUT STD_LOGIC;               -- return from subroutine/irq
    RTI             : OUT STD_LOGIC;               -- return from interrupt
    JS              : OUT STD_LOGIC;               -- jump to subroutine
    PCE             : OUT STD_LOGIC;               -- program counter enable
    DWORD           : OUT STD_LOGIC;               -- DWORD write
    SEL_M           : OUT STD_LOGIC;               -- select MSWord
    STACK_AE        : OUT STD_LOGIC;               -- stack addr enable
    STACK_CE        : OUT STD_LOGIC;               -- stack count enable
    PUSH            : OUT STD_LOGIC;               -- push in stack
    J_IRQ           : OUT STD_LOGIC                -- jump to interrupt handler
    );
end controlv;

architecture a of controlv is

SIGNAL CJMP, JSorJMP, RTSorRTI_i, JS_i, COUT, ZERO : std_logic;
SIGNAL RAM_RDi, PCE1, IRQ1, IRQ2, J_IRQ_i, RTI_i, IRQ_PROC, HLT : std_logic;
SIGNAL OPC      : opcode_type;
SIGNAL DIS_IRQ, INT_REQ, LD_IRQF, DIS_IRQ_F : std_logic;

signal IO_WEi, IO_RDi   : std_logic;
signal IO_wait          : std_logic;
type sm_type is (idle, pce_wait1, pce_wait2);
signal pce_sm : sm_type;

signal WA_i     : std_logic_vector(WA'range);
signal RB_i     : std_logic_vector(RB'range);
signal RC_i     : std_logic_vector(RC'range);

begin
        COUT    <= CZ_stored(CARRY_FLAG_BIT);
        ZERO    <= CZ_stored(ZERO_FLAG_BIT);
        WA      <= WA_i;
        RB      <= RB_i;
        RC      <= RC_i;

        OPC     <= PDAT(OP_CODE_MSB downto OP_CODE_LSB); -- 23..19, extract the operation code
        OPINFO  <= PDAT(OP_INFO_MSB downto OP_INFO_LSB); --  4.. 0, additional immediate data to the operation
        OPCODE  <= OPC;                     -- output of the OPC

        process(pdat, opc, COUT, ZERO, IO_Q, RAMQ, ARES, PCE1, J_IRQ_i, OPINFO, WA_i)
        begin
            WA_i <= PDAT(OP_RG_TARG_MSB downto OP_RG_TARG_LSB);   -- write reg #
            RB_i <= PDAT(OP_RG_SRC1_MSB downto OP_RG_SRC1_LSB);   -- read reg #B
            RC_i <= PDAT(OP_RG_SRC2_MSB downto OP_RG_SRC2_LSB);   -- read reg #C
            R1_MODIF <= (others => '0');
            R1_MODIF(0) <= '1'; -- r1 is almost always 1
            RG_IN   <= ARES;
            REG_WE  <= '0';
            RAM_WE  <= '0';
            JSorJMP <= '0';
            CJMP    <= '0';
            IO_RDi  <= '0';
            IO_WEi  <= '0';
            RAM_RDi <= '0';
            RTSorRTI_i   <= '0';
            RTI_i   <= '0';
            LD_IRQF <= '0';
            DWORD   <= '1';
            STACK_AE <= '0';
            HLT     <= '0';
            JS_i    <= '0';
            DIS_IRQ <= '0';
            STACK_CE <= '0';

            case OPC is

            when INSTR_NOT =>  -- swp, sxn, mov
                        REG_WE <= '1';

            when INSTR_XOR | INSTR_OR | INSTR_AND =>
                        REG_WE <= '1';
                        R1_MODIF <= PDAT(OP_R1MD_MSB downto OP_R1MD_LSB);

            when INSTR_MKB | INSTR_INB | INSTR_SEB | INSTR_CLB =>
                        REG_WE <= '1';

            when INSTR_SHL | INSTR_SHR | INSTR_ROL | INSTR_ROR =>
                        REG_WE <= '1';

            when INSTR_SUB | INSTR_ADD | INSTR_SBB | INSTR_ADC =>
                        REG_WE <= '1';
                        R1_MODIF <= PDAT(OP_R1MD_MSB downto OP_R1MD_LSB);

            when INSTR_LDL | INSTR_LDH | INSTR_LDL1 | INSTR_LDH1 =>
                        WA_i(0) <= PDAT(OP_RG_TARG_LSB_LC);
                        DWORD  <= '0';
                        RG_IN <= (others => '0');
                        RG_IN(15 downto 0) <= PDAT(OP_IMMW_MSB downto OP_IMMW_LSB);
                        REG_WE <= '1';
                        if WA_i="0001" then LD_IRQF  <= '1'; end if; -- set/clear IRQ enable ?

            -- store to I/O or memory
            when INSTR_STO =>
                        WA_i <= "0000"; -- write to R0
                        DIS_IRQ <= '1';
                        RAM_WE  <= not PDAT(OP_CODE_I_O);
                        IO_WEi  <=     PDAT(OP_CODE_I_O);

            -- read from I/O or memory
            when INSTR_LDD =>
                        REG_WE  <= '1';
                        if PDAT(OP_CODE_I_O)='1' then
                            RG_IN <= IO_Q;
                        else
                            RG_IN <= RAMQ;
                        end if;
                        IO_RDi  <=     PDAT(OP_CODE_I_O);
                        RAM_RDi <= not PDAT(OP_CODE_I_O);
                        DIS_IRQ  <= '1';

            when INSTR_PSH =>
                        DIS_IRQ  <= '1';
                        RAM_WE  <= '1';
                        STACK_AE <= '1';
                        STACK_CE <= '1';

            when INSTR_POP =>
                        REG_WE <= '1';
                        STACK_AE <= '1';
                        STACK_CE <= PCE1;
                        RAM_RDi <= '1';
                        RG_IN <= RAMQ;
                        DIS_IRQ  <= '1';

            when INSTR_JS =>
                        JSorJMP <= '1';
                        JS_i    <= '1';
                        RAM_WE  <= '1';
                        STACK_AE <= '1';
                        STACK_CE <= '1';
                        --DIS_IRQ  <= '1';

            when INSTR_JMP =>
                        JSorJMP <= '1';
                        --DIS_IRQ  <= '1';

            when INSTR_RTS =>
                        -- return from subroutine is memory read
                        RAM_RDi <= '1';
                        RTSorRTI_i   <= '1';
                        RTI_i   <= OPINFO(0);
                        --DIS_IRQ  <= '1';
                        STACK_AE <= '1';
                        STACK_CE <= PCE1;

            when INSTR_JC  =>
                        CJMP <=     COUT;
                        --DIS_IRQ  <= COUT;

            when INSTR_JNC =>
                        CJMP <= not COUT;
                        --DIS_IRQ  <= not COUT;

            when INSTR_JZ  =>
                        CJMP <=     ZERO;
                        --DIS_IRQ  <= ZERO;

            when INSTR_JNZ =>
                        CJMP <= not ZERO;
                        --DIS_IRQ  <= not ZERO;
            when INSTR_HLT =>
                        HLT <= '1';
                        --DIS_IRQ  <= '1';

            when others => NULL;

            end case;

            if J_IRQ_i='1' then
                JS_i   <= '1';
                RAM_WE <= '1';
                STACK_AE <= '1';
                STACK_CE <= PCE1;
            end if;

        end process;

        JUMP  <= CJMP or JSorJMP; -- jump to a new address (all cases)

        SEL_M <= OPC(0); -- select MSWord

        -- don't decode completely! Used only when STACK_AE/CE='1'
        PUSH  <= JS_i or (not OPC(0));

        -- IRQ
        process(CLK)
        begin
            if CLK'event and CLK='1' then
                if RESET='1' then
                    IRQ1      <= '0';
                    IRQ2      <= '0';
                    INT_REQ   <= '0';
                    IRQ_PROC  <= '0';
                    DIS_IRQ_F <= '1';
                else

                    if LD_IRQF='1' then DIS_IRQ_F <= not PDAT(OP_IMMW_LSB); end if; -- enable irq flag

                    if PCE1='1' then
                            IRQ1 <= IRQ;
                            IRQ2 <= IRQ1;

                            if    IRQ_PROC='1' or DIS_IRQ_F='1' then INT_REQ <='0';
                            elsif (IRQ1='1') and (IRQ2='0')     then INT_REQ <='1'; end if;

                            if    J_IRQ_i='1' then IRQ_PROC <= '1';
                            elsif RTI_i  ='1' then IRQ_PROC <= '0';
                            end if;
                    end if;
                end if;
            end if;
        end process;

        PCE1 <= not (RAM_RDi or IO_WEi or IO_RDi) when pce_sm=idle else not IO_wait when pce_sm=pce_wait2 else '0';

        process(clk)
        begin
            if rising_edge(clk) then
                if reset='1' then
                    pce_sm <= idle;
                else
                    case pce_sm is
                    when idle =>
                        if RAM_RDi='1' then
                            if PDAT(OP_CODE_WAIT)='0' then
                                pce_sm <= pce_wait2;
                            else
                                pce_sm <= pce_wait1;
                            end if;
                        end if;
                        if IO_WEi='1' or IO_RDi='1' then
                            pce_sm <= pce_wait2;
                        end if;

                    when pce_wait1 =>
                        pce_sm <= pce_wait2;
                    when pce_wait2 =>
                        if IO_wait='0' then
                            pce_sm <= idle;
                        end if;
                    end case;
                end if;
            end if;
        end process;

        IO_wait <= (IO_RDi or IO_WEi) and not IO_rdy;
        J_IRQ_i <= INT_REQ and not DIS_IRQ;

        -- assign outputs
        J_IRQ   <= J_IRQ_i;
        PCE     <= PCE1 and not HLT;
        RAM_RD  <= RAM_RDi;
        JS      <= JS_i;
        RTI     <= RTI_i;
        RTSorRTI <= RTSorRTI_i and PCE1; -- wait state because of pop operation

        IO_RD <= IO_RDi;
        IO_WE <= IO_WEi;
end;
