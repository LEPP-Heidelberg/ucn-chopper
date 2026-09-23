-- $Id: aluv.vhd 1149 2025-03-07 13:29:45Z angelov $:
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.all;
USE IEEE.STD_LOGIC_UNSIGNED.all;

use work.sw32_pack.all;

-- OpCode       Opinfo         Result
-- 00000        00000          not opA
-- 00000        00001          swap hi-low part of opA
-- 00000        00010          sign extend opA from 16->32
-- 00000        00011          move: opA

-- 00001          -            opA xor opB
-- 00010          -            opA  or opB
-- 00011          -            opA and opB

-- 10000        bbbbb          opA &  (1 << b)
-- 10001        bbbbb          opA ^  (1 << b)
-- 10010        bbbbb          opA |  (1 << b)
-- 10011        bbbbb          opA & !(1 << b)

-- compile generic without/with barrel shifter with distance 4 or 8, nn=00 means 4, nnn=000 means 8!
-- 00100        00nnn          opA shl n
-- 00101        a0nnn          opA shr n when a=0 (logical) or opA sar n when a=1 (arithmetic)
-- 10100        00nnn          opA rol n  rotate left through carry
-- 10101        00nnn          opA ror n  rotate right through carry
-- 00110          -            opA - opB
-- 00111          -            opA + opB
-- 10110          -            opA - opB - C
-- 10111          -            opA + opB + C

-- -- last modified: 17:49 / 17-Aug-2013 / V.Angelov
-- barrel shifter, swap operation

ENTITY aluv IS
GENERIC (Nwidth : Integer := 32;
         Nf     : Integer :=  2;
         barrel : Integer :=  1); -- max distance: 1, 4 or 8
PORT(
    A           : IN  STD_LOGIC_VECTOR(Nwidth-1 downto 0);
    B           : IN  STD_LOGIC_VECTOR(Nwidth-1 downto 0);
    OPC         : IN  STD_LOGIC_VECTOR(4 downto 0);
    CLK         : IN  STD_LOGIC;
    RST         : IN  STD_LOGIC;
    OPINFO      : IN  STD_LOGIC_VECTOR(OP_INFO_WIDTH-1 downto 0);
    CZ_back     : IN  STD_LOGIC_VECTOR(Nf-1 downto 0); -- C & Z flags back from stack
    RTI         : IN  STD_LOGIC; -- return from interrupt
    CZ_stored   : OUT STD_LOGIC_VECTOR(Nf-1 downto 0);
    CZ_new      : OUT STD_LOGIC_VECTOR(Nf-1 downto 0);
    F           : OUT STD_LOGIC_VECTOR(Nwidth-1 downto 0)
        );
END aluv;

architecture a of aluv is

component my_addsub is
    generic (width : Integer := 16);
    port (
      A       : in  std_logic_vector(width-1 downto 0);
      B       : in  std_logic_vector(width-1 downto 0);
      CI      : in  std_logic;
      ADD_SUB : in  std_logic;  -- 1 for add
      SUM     : out std_logic_vector(width-1 downto 0);
      CO      : out std_logic);
    end component;


-- results
signal resI, resAI, resL, resO, resA, resB, resLG, MREG : std_logic_vector(Nwidth-1 downto 0);
-- carry
signal CMSK, CROT, CADDSUB_out, CADDSUB_in, CSXT : std_logic;
-- flags
signal NewFlag, OldFlag, EnFlag, NewFVal : std_logic_vector(Nf-1 downto 0);

begin
    -- mask for the bit operations
g1: for i in 0 to Nwidth-1 generate
        MREG(i) <= '1' when OPINFO(4 downto 0)=i else '0';
    end generate;

    -- mask, set, clear single bits
    process(A, MREG, OPC(1 downto 0))
    begin
        CASE OPC(1 downto 0) IS
        WHEN INSTR_MKB(1 downto 0) => resB <= A and     MREG; -- mask all other bits
        WHEN INSTR_INB(1 downto 0) => resB <= A xor     MREG; -- invert the selected bit
        WHEN INSTR_SEB(1 downto 0) => resB <= A  or     MREG; -- set the selected bit
        WHEN INSTR_CLB(1 downto 0) => resB <= A and not MREG; -- clear the selected bit
        WHEN others                => resB <= (others => '-');
        end case;
    end process;

    process(A, B, OPC(1 downto 0), opinfo)
    begin
        CASE OPC(1 downto 0) IS
        WHEN INSTR_NOT(1 downto 0) =>
                    case opinfo(1 downto 0) is
                        -- NOT
                        WHEN INS_MOD_NOT  =>  resL <= not A;
                        -- swap hi-lo byte
                        WHEN INS_MOD_SWP  =>  resL <= A(A'length/2-1 downto 0) & A(A'high downto A'length/2);
                        -- sign extension 16->32 bit
                        WHEN INS_MOD_SXT  =>  resL <= (others => A( A'length/2-1) );
                                              resL(A'length/2-1 downto 0) <= A(A'length/2-1 downto 0);
                        -- move, not used now, may be implement something more useful
                        -- MOV is now realized as OR Rtarget, R0, Rsource
                        WHEN INS_MOD_MOV  =>  resL <= A;
                        when others       =>  resL <= (others => '-');
                    end case;

        WHEN INSTR_XOR(1 downto 0) =>  resL <= A xor B;
        WHEN INSTR_OR( 1 downto 0) =>  resL <= A  or B;
        WHEN INSTR_AND(1 downto 0) =>  resL <= A and B;
        WHEN others                =>  resL <= (others => '-');
        end case;
    end process;

    -- mask the carry-in when ADD and SUB
    CMSK <= OldFlag(CARRY_FLAG_BIT) and OPC(4);     -- Left:  1-rotate / 0-shift coded in bit 4
    CSXT <= A(A'high) when opinfo(5)='1' else CMSK; -- Right: 1-arithmetic / 0-logical, used in SAR, SHR, ROR

b8: if barrel >= 8 generate
    process(A, OPC(0), CMSK, CSXT, opinfo) --  shift/rotate left/right
    begin
            CASE OPC(0) IS    -- left/right coded in bit 0
            -- left
            WHEN '0'    => -- left
                case opinfo(2 downto 0) is
--                when "000" => resI <= A; Crot <= CMSK; -- no change
                when "001" => resI <= A(A'high-1 downto 0) & CMSK;
                              Crot <= A(A'high);
                when "010" => resI <= A(A'high-2 downto 0) & CMSK & CMSK;
                              Crot <= A(A'high-1);
                when "011" => resI <= A(A'high-3 downto 0) & CMSK & CMSK & CMSK;
                              Crot <= A(A'high-2);
                when "100" => resI <= A(A'high-4 downto 0) & CMSK & CMSK & CMSK & CMSK;
                              Crot <= A(A'high-3);
                when "101" => resI <= A(A'high-5 downto 0) & CMSK & CMSK & CMSK & CMSK & CMSK;
                              Crot <= A(A'high-4);
                when "110" => resI <= A(A'high-6 downto 0) & CMSK & CMSK & CMSK & CMSK & CMSK & CMSK;
                              Crot <= A(A'high-5);
                when "111" => resI <= A(A'high-7 downto 0) & CMSK & CMSK & CMSK & CMSK & CMSK & CMSK & CMSK;
                              Crot <= A(A'high-6);
                when "000" => resI <= A(A'high-8 downto 0) & CMSK & CMSK & CMSK & CMSK & CMSK & CMSK & CMSK & CMSK;
                              Crot <= A(A'high-7);
                when others => resI <= (others => '-'); Crot <= '-';
                end case;

            WHEN '1'    => -- right
                case opinfo(2 downto 0) is
  --              when "000" => resI <= A; Crot <= CSXT; -- no change
                when "001" => resI <= CSXT & A(A'high downto 1);
                              Crot <= A(0);
                when "010" => resI <= CSXT & CSXT & A(A'high downto 2);
                              Crot <= A(1);
                when "011" => resI <= CSXT & CSXT & CSXT & A(A'high downto 3);
                              Crot <= A(2);
                when "100" => resI <= CSXT & CSXT & CSXT & CSXT & A(A'high downto 4);
                              Crot <= A(3);
                when "101" => resI <= CSXT & CSXT & CSXT & CSXT & CSXT & A(A'high downto 5);
                              Crot <= A(4);
                when "110" => resI <= CSXT & CSXT & CSXT & CSXT & CSXT & CSXT & A(A'high downto 6);
                              Crot <= A(5);
                when "111" => resI <= CSXT & CSXT & CSXT & CSXT & CSXT & CSXT & CSXT & A(A'high downto 7);
                              Crot <= A(6);
                when "000" => resI <= CSXT & CSXT & CSXT & CSXT & CSXT & CSXT & CSXT & CSXT & A(A'high downto 8);
                              Crot <= A(7);
                when others => resI <= (others => '-'); Crot <= '-';
                end case;

            when others => resI <= (others => '-'); Crot <= '-';

            end case;
    end process;
    end generate;

b4: if (barrel >=4) and (barrel < 8) generate   -- 4
    process(A, OPC(0), CMSK, opinfo) --  shift/rotate left/right
    begin
            CASE OPC(0) IS
            -- left
            WHEN '0'    => -- left
                case opinfo(1 downto 0) is
                when  "01" => resI <= A(A'high-1 downto 0) & CMSK;
                              Crot <= A(A'high);
                when  "10" => resI <= A(A'high-2 downto 0) & CMSK & CMSK;
                              Crot <= A(A'high-1);
                when  "11" => resI <= A(A'high-3 downto 0) & CMSK & CMSK & CMSK;
                              Crot <= A(A'high-2);
                when  "00" => resI <= A(A'high-4 downto 0) & CMSK & CMSK & CMSK & CMSK;
                              Crot <= A(A'high-3);
                when others => resI <= (others => '-'); Crot <= '-';
                end case;

            WHEN '1'    => -- right
                case opinfo(1 downto 0) is
                when  "01" => resI <= CSXT & A(A'high downto 1);
                              Crot <= A(0);
                when  "10" => resI <= CSXT & CSXT & A(A'high downto 2);
                              Crot <= A(1);
                when  "11" => resI <= CSXT & CSXT & CSXT & A(A'high downto 3);
                              Crot <= A(2);
                when  "00" => resI <= CSXT & CSXT & CSXT & CSXT & A(A'high downto 4);
                              Crot <= A(3);
                when others => resI <= (others => '-'); Crot <= '-';
                end case;

            when others => resI <= (others => '-'); Crot <= '-';

            end case;
    end process;
    end generate;

b1: if (barrel < 4) generate    -- 1
      resI <= A(Nwidth-2 downto 0) & CMSK when OPC(0)='0' else CSXT & A(Nwidth-1 downto 1);
      CROT <= A(Nwidth-1)                 when OPC(0)='0' else A(0);
    end generate;


--      resA <= opA +/- opB;
    CADDSUB_in <= CMSK xor not OPC(0);

u1: my_addsub
    generic map (
      width => Nwidth)
    port map (
      A       => A,
      B       => B,
      CI      => CADDSUB_in,
      ADD_SUB => OPC(0),
      SUM     => resA,
      CO      => CADDSUB_out);

        -- enable for the carry flag
    EnFlag(CARRY_FLAG_BIT) <= ((not OPC(3)) and OPC(2) );   -- arithmetic (add/sub or rotate/shift)
        -- new value for the carry flag
    NewFVal(CARRY_FLAG_BIT) <= (CADDSUB_out xor not OPC(0)) when OPC(1)='1' -- add/subtract -- LPM or my_addsub
             else CROT;                                        -- rotate/shift
        -- enable for the zero flag
    EnFlag(ZERO_FLAG_BIT) <= (not OPC(3));
        -- new value for the zero flag
    NewFVal(ZERO_FLAG_BIT) <= '1' when resO=0 else '0';

f1: for i in 0 to Nf-1 generate
f2:     NewFlag(i) <= OldFlag(i) when EnFlag(i)='0' -- the old value from the DFF
                 else NewFVal(i);
    end generate;

    process(CLK, RST)
    begin
        if RST='1' then OldFlag <= (others => '0');
        elsif rising_edge(CLK) then
            if RTI='1' then OldFlag <= CZ_back;
                       else OldFlag <= NewFlag; end if;
        end if;
    end process;

    CZ_stored <= OldFlag;
    CZ_new    <= NewFlag;

    with OPC(1) select
    resAI <= resI when '0',     -- shift/rotate
             resA when others;  -- add/sub

    with OPC(4) select
    resLG <= resL when '0',     -- logical
             resB  when others; -- bit

    with OPC(2) select
    resO <= resLG when '0',     -- logical & bit
            resAI when others;  -- arithmetical

    F <= resO;

end;
