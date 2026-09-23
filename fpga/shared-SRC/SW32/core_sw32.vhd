-- $Id: core_sw32.vhd 1136 2025-01-27 18:19:13Z angelov $:
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

use work.sw32_pack.all;

entity core_sw32 is
GENERIC (Nramt  : Integer := 8;  -- total width of the RAM address bus
         Nstack : Integer := 4;  -- the part controlled by the stack pointer
         Nreg   : Integer := 16; -- number of registers, possible values are 8 (smallest), 12 and 16 (max)
         Nflag  : Integer := 2;  -- number of flags
         Nrom   : Integer := 8;  -- the width of the ROM address bus
         barrel : Integer := 1;  -- 1, 4 or 8 for max shift 1, 4, 8
         IRQ_ADR : Integer :=  1); -- address of the IRQ routine
port
        (
          CLK              : IN  STD_LOGIC;
          RESET            : IN  STD_LOGIC;
          IRQ              : IN  STD_LOGIC;

          -- IO space
          IO_IN            : IN  STD_LOGIC_VECTOR(31 downto 0);
          IO_ADR           : OUT STD_LOGIC_VECTOR(31 downto 0);  -- QB
          IO_OUT           : OUT STD_LOGIC_VECTOR(31 downto 0);  -- QC
          IO_RD, IO_WE     : OUT STD_LOGIC;
          IO_rdy           : IN  STD_LOGIC;

          -- Data memory and Stack
          RAM_WE           : OUT STD_LOGIC;
          RAM_A            : OUT STD_LOGIC_VECTOR(Nramt-1 downto 0);
          RAM_D            : OUT STD_LOGIC_VECTOR(31 downto 0);
          RAM_Q            : IN  STD_LOGIC_VECTOR(31 downto 0);  -- make input for external RAM

          -- Instruction Memory
          ROM_A            : OUT STD_LOGIC_VECTOR(Nrom-1 downto 0);-- QB
          ROM_D            : IN  STD_LOGIC_VECTOR(23 downto 0)   -- QB
        );
end core_sw32;

architecture a of core_sw32 is

COMPONENT pcount is
GENERIC (Np : Integer := 8; IRQ_ADR : Integer := 1);
port
    (
    RTSA, JMPA      : IN  STD_LOGIC_VECTOR(Np-1 downto 0);
    JUMP, RTSorRTI  : IN  STD_LOGIC;
    CLK, PCE, RST   : IN  STD_LOGIC;
    J_IRQ           : IN  STD_LOGIC; -- jump to interrupt handler
    PC_next, PC     : OUT STD_LOGIC_VECTOR(Np-1 downto 0)
    );
end component;

component regreg16 is
generic (Nwidth : Integer := 32;   -- data path width
         Nr1mod : Integer :=  3;   -- up to Nwidth-1, number of bits in r1 that can be modified
         Nreg   : Integer := 16);  -- number of registers, possible values are 8 (smallest), 12 and 16 (max)
PORT (
        D          : IN  STD_LOGIC_VECTOR(Nwidth-1 downto 0);
        CLK        : IN  STD_LOGIC;
        WE         : IN  STD_LOGIC;
        DWORD      : IN  STD_LOGIC; -- WORD operation
        SEL_M      : IN  STD_LOGIC; -- selects the Byte
        WADDR      : IN  STD_LOGIC_VECTOR(3 downto 0);
        RADDR_A    : IN  STD_LOGIC_VECTOR(3 downto 0);
        RADDR_B    : IN  STD_LOGIC_VECTOR(3 downto 0);
        R1_MODIF   : IN  STD_LOGIC_VECTOR(Nr1mod-1 downto 0);
        RESET      : IN  STD_LOGIC; -- global reset
        QA         : OUT STD_LOGIC_VECTOR(Nwidth-1 downto 0);
        QB         : OUT STD_LOGIC_VECTOR(Nwidth-1 downto 0)
        );
end component;

component controlv is
GENERIC( Nd : Integer := 32; -- data path width
         Nf : Integer := 2); -- number of flags
port(
        CLK             : IN  STD_LOGIC;                       -- global clk
        RESET           : IN  STD_LOGIC;                       -- global reset
        PDAT            : IN  STD_LOGIC_VECTOR(23 downto 0);   -- program data
        ARES            : IN  STD_LOGIC_VECTOR(Nd-1 downto 0); -- result in ALU
        RAMQ            : IN  STD_LOGIC_VECTOR(Nd-1 downto 0); -- output from RAM
        IO_Q            : IN  STD_LOGIC_VECTOR(Nd-1 downto 0); -- output from I/O dev
        CZ_stored       : IN  STD_LOGIC_VECTOR(Nf-1 downto 0); -- carry from ALU
        IRQ             : IN  STD_LOGIC;                       -- IRQ, positive edge sensitive
        REG_WE          : OUT STD_LOGIC;                       -- register write enable
        RAM_WE          : OUT STD_LOGIC;                       -- RAM write enable
        RAM_RD          : OUT STD_LOGIC;
        IO_WE           : OUT STD_LOGIC;                       -- I/O write enable
        IO_RD           : OUT STD_LOGIC;                       -- 1 for external dev read
        IO_rdy          : IN  STD_LOGIC;
        WA              : OUT STD_LOGIC_VECTOR(3 downto 0);    -- write register #
        RB              : OUT STD_LOGIC_VECTOR(3 downto 0);    -- read register B #
        RC              : OUT STD_LOGIC_VECTOR(3 downto 0);    -- read register C #
        R1_MODIF        : OUT STD_LOGIC_VECTOR(R1MD_WIDTH-1 downto 0);    -- modify r1 to another constant
        OPCODE          : OUT STD_LOGIC_VECTOR(4 downto 0);    -- operation code to ALU
        OPINFO          : OUT STD_LOGIC_VECTOR(OP_INFO_WIDTH-1 downto 0);
        RG_IN           : OUT STD_LOGIC_VECTOR(Nd-1 downto 0); -- output to register file
        JUMP            : OUT STD_LOGIC;                       -- jump
        RTSorRTI        : OUT STD_LOGIC;                       -- return from subroutine
        RTI             : OUT STD_LOGIC;                       -- return from interrupt
        JS              : OUT STD_LOGIC;                       -- jump to subroutine
        PCE             : OUT STD_LOGIC;                       -- program counter enable
        DWORD           : OUT STD_LOGIC;                       -- WORD write
        SEL_M           : OUT STD_LOGIC;                       -- select MSByte
        STACK_AE        : OUT STD_LOGIC;                       -- stack addr enable
        STACK_CE        : OUT STD_LOGIC;                       -- stack count enable
        PUSH            : OUT STD_LOGIC;                       -- push in stack
        J_IRQ           : OUT STD_LOGIC                        -- jump to interrupt handler
        );
end component;

component aluv IS
GENERIC (Nwidth : Integer := 32;
         Nf     : Integer :=  2;  -- number of flags
         barrel : Integer :=  1); -- 1, 4 or 8 for max shift 1, 4, 8
PORT(
        A, B         : IN  STD_LOGIC_VECTOR(Nwidth-1 downto 0);
        OPC          : IN  STD_LOGIC_VECTOR(4 downto 0);
        CLK, RST     : IN  STD_LOGIC;
        OPINFO       : IN  STD_LOGIC_VECTOR(OP_INFO_WIDTH-1 downto 0);
        CZ_back      : IN  STD_LOGIC_VECTOR(Nf-1 downto 0); -- C & Z flags back from stack
        RTI          : IN  STD_LOGIC; -- return from interrupt
        CZ_stored    : OUT STD_LOGIC_VECTOR(Nf-1 downto 0);
        CZ_new       : OUT STD_LOGIC_VECTOR(Nf-1 downto 0);
        F            : OUT STD_LOGIC_VECTOR(Nwidth-1 downto 0)
    );
END component;

component stack_cntrl is
GENERIC (Nramt  : Integer :=32;  -- total width of the RAM address bus
         Nstack : Integer := 4;  -- the part controlled by the stack pointer
         Nflag  : Integer := 2;  -- number of flags
         Nrom   : Integer := 8); -- the width of the ROM address bus
PORT(
        clk, reset    : IN  STD_LOGIC;
        AE, CE, PUSH  : IN  STD_LOGIC;
        CZ_new        : IN  STD_LOGIC_VECTOR(Nflag-1 downto 0);
        Adr_in        : IN  STD_LOGIC_VECTOR(Nramt-1 downto 0);
--        Adr_in        : IN  STD_LOGIC_VECTOR(15 downto 0);
        JS            : IN  STD_LOGIC;
        NxPC          : IN  STD_LOGIC_VECTOR(Nrom-1 downto 0);
        DataFromReg   : IN  STD_LOGIC_VECTOR(31 downto 0);
        RAMD          : OUT STD_LOGIC_VECTOR(31 downto 0);
        SPO           : OUT STD_LOGIC_VECTOR(Nstack-1 downto 0);
        Adr_out       : OUT STD_LOGIC_VECTOR(Nramt-1 downto 0)
        );
end component;


SIGNAL RG_D, QB, QC, ARES, RAMD_i : STD_LOGIC_VECTOR(31 downto 0);
SIGNAL PDAT         : STD_LOGIC_VECTOR(23 downto 0);
SIGNAL RAMQ_i       : STD_LOGIC_VECTOR(31 downto 0);
SIGNAL WA, RB, RC   : STD_LOGIC_VECTOR( 3 downto 0);
SIGNAL R1_MODIF     : STD_LOGIC_VECTOR(R1MD_WIDTH-1 downto 0);
SIGNAL PC_next, PC  : STD_LOGIC_VECTOR(Nrom-1 downto 0);
SIGNAL JUMP, RTSorRTI, JS, PCE, REG_WE, RAM_WE_i, DWORD, SEL_M, STACK_AE, STACK_CE, PUSH, J_IRQ : STD_LOGIC;
SIGNAL OPCODE       : opcode_type;      -- operation code to ALU
SIGNAL OPINFO       : STD_LOGIC_VECTOR(OP_INFO_WIDTH-1 downto 0);      -- additional information to the operation code
--SIGNAL SP           : STD_LOGIC_VECTOR(Nstack-1 downto 0); -- stack pointer
SIGNAL RAM_A_i      : STD_LOGIC_VECTOR(RAM_A'range); -- RAM address
SIGNAL CZ_new, CZ_stored : STD_LOGIC_VECTOR(Nflag-1 downto 0);
signal RTI          : std_logic;

begin

    IO_ADR <= QB;
    IO_OUT <= QC;

pcnt: pcount
generic map(
    Np => Nrom,
    IRQ_ADR => IRQ_ADR)
port map(
         RTSA       => RAMQ_i(Nrom-1 downto 0),
         JMPA       => PDAT(Nrom-1 downto 0),
         JUMP       => JUMP,
         RTSorRTI   => RTSorRTI,
         CLK        => CLK,
         PCE        => PCE,
         RST        => RESET,
         J_IRQ      => J_IRQ,
         PC_next    => PC_next, -- before the register
         PC         => PC);

reg16x16: regreg16
generic map(
    Nwidth => 32,
    Nr1mod => R1MD_WIDTH,
    Nreg   => Nreg)
port map(
        D          => RG_D,
        CLK        => CLK,
        WE         => REG_WE,
        DWORD      => DWORD,
        SEL_M      => SEL_M,
        WADDR      => WA,
        RADDR_A    => RB,
        RADDR_B    => RC,
        R1_MODIF   => R1_MODIF,
        RESET      => RESET,
        QA         => QB,
        QB         => QC);

ctrl: controlv
GENERIC MAP( Nd => 32, Nf => Nflag) -- data path width
port map(
            CLK         => CLK,
            RESET       => RESET,
            PDAT        => PDAT,
            ARES        => ARES,
            RAMQ        => RAMQ_i,
            IO_Q        => IO_IN,
            CZ_stored   => CZ_stored,
            IRQ         => IRQ,
            REG_WE      => REG_WE,
            RAM_WE      => RAM_WE_i,
            RAM_RD      => open, --RAM_RD,
            IO_WE       => IO_WE,
            IO_RD       => IO_RD,
            IO_rdy      => IO_rdy,
            WA          => WA,
            RB          => RB,
            RC          => RC,
            R1_MODIF    => R1_MODIF,
            OPCODE      => OPCODE,
            OPINFO      => OPINFO,
            RG_IN       => RG_D,
            JUMP        => JUMP,
            RTSorRTI    => RTSorRTI,
            RTI         => RTI,
            JS          => JS,
            PCE         => PCE,
            DWORD       => DWORD,
            SEL_M       => SEL_M,
            STACK_AE    => STACK_AE,
            STACK_CE    => STACK_CE,
            PUSH        => PUSH,
            J_IRQ       => J_IRQ);

alu_i: aluv
generic map (
    Nwidth => 32,
    Nf     => Nflag,
    barrel => barrel)
port map(
        A           => QB,
        B           => QC,
        OPC         => OPCode,
        CLK         => CLK,
        RST         => RESET,
        OPINFO      => OPINFO,
        CZ_back     => RAMQ_i(RAMQ_i'high downto RAMQ_i'high-1),
        RTI         => RTI,
        CZ_stored   => CZ_stored,
        CZ_new      => CZ_new,
        F           => ARES);


stack_i: stack_cntrl
GENERIC map(
         Nramt  => Nramt,
         Nstack => Nstack,
         Nflag  => Nflag,
         Nrom   => Nrom)
PORT MAP(
        clk         => clk,
        reset       => reset,
        AE          => STACK_AE,
        CE          => STACK_CE,
        PUSH        => PUSH,
        CZ_new      => CZ_new,
        Adr_in      => QB(Nramt-1 downto 0),
        JS          => JS,
        NxPC        => PC_next,
        DataFromReg => QC,
        RAMD        => RAMD_i,
        SPO         => open,
        Adr_out     => RAM_A_i);

     RAMQ_i <= RAM_Q;
     RAM_D  <= RAMD_i;
     RAM_WE <= RAM_WE_i;
     RAM_A  <= RAM_A_i;

     ROM_A <= PC;
     PDAT  <= ROM_D;
end;
