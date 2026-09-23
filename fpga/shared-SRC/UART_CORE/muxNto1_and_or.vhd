LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

-- $Id: muxNto1_and_or.vhd 65 2016-08-30 13:15:36Z angelov $:

entity muxNto1_and_or is
generic (Nbus : Positive := 8;
         Ninp : Positive := 4);
port (
    DIN     : in  std_logic_vector(Ninp*Nbus-1 downto 0);
    SMASK   : in  std_logic_vector(Ninp-1      downto 0);
    Y       : out std_logic_vector(Nbus-1      downto 0));
end muxNto1_and_or;

architecture a of muxNto1_and_or is

signal cleared_bus : std_logic_vector(Nbus-1 downto 0);

begin
    cleared_bus <= (others => '0');

    process(DIN, SMASK, cleared_bus)
    variable DIN_MASKED : std_logic_vector(DIN'range);
    variable dout       : std_logic_vector(  Y'range);
    begin
        DIN_MASKED := DIN;
        dout := cleared_bus;
        for i in Ninp-1 downto 0 loop
            if SMASK(i)='0' then
                DIN_MASKED((i+1)*Nbus-1 downto i*Nbus) := cleared_bus;
            end if;
            dout := dout or DIN_MASKED((i+1)*Nbus-1 downto i*Nbus);
        end loop;
        Y <= dout;
    end process;

end;
