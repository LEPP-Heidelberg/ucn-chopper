-- $Id: config_pkg.vhd 1216 2026-09-02 16:57:27Z  $:

library ieee;
use ieee.std_logic_1164.all;

package config_pkg is

constant NA_RAM_HBR_GEN : Integer := 10;

-- Type declarations
subtype addr_type  is std_logic_vector(15 downto 0); -- address type for the whole bus
subtype caddr_type is std_logic_vector( 4 downto 0); -- subaddress type for the config.vhd only

-- Constant declarations of all basis addresses
--                                          FEDCBA9876543210
-- in all designs
constant ADDR_WB            : addr_type := "00000000--------";  -- 0x0000..0x00FF
constant ADDR_CONF          : addr_type := "00000001--------";  -- 0x0100..0x01FF
constant ADDR_SMALL_MEM     : addr_type := "0000001---------";  -- 0x0200..0x03FF
constant ADDR_ADS           : addr_type := "0000010000------";  -- 0x0400..0x043F
constant ADDR_I2C           : addr_type := "000001001000----";  -- 0x0480..0x048F
constant ADDR_DTEMP         : addr_type := "000001001001----";  -- 0x0490..0x049F
constant ADDR_TX_CPU        : addr_type := "0000010011000---";  -- 0x04C0..0x04C7
constant ADDR_HBR           : addr_type := "0001------------";  -- 0x1000..0x1FFF
constant ADDR_PSRG_TST      : addr_type := "001-------------";  -- 0x2000..0x3FFF

-- single configuration registers starting at ADDR_CONF
constant ADDR_UART_SEL      : caddr_type := 5x"00";

constant ADDR_COMMAND       : caddr_type := 5x"01";
constant BIT_CMD_CPU_RST    : Integer := 0;  -- as status: CPU_OFF
constant BIT_CMD_CPU_OFF    : Integer := 1;  -- as status: CPU OFF
constant BIT_CMD_SFT_RST    : Integer := 2;

constant ADDR_LED           : caddr_type := 5x"02";

constant ADDR_LED_BLINK     : caddr_type := 5x"03";

constant ADDR_TIMER         : caddr_type := 5x"04";
constant BIT_TIMER_CLR      : Integer := 0;
constant BIT_TIMER_RUN      : Integer := 1;
constant BIT_TIMER_LAT0     : Integer := 2;
constant BIT_TIMER_LAT1     : Integer := 3;
constant BIT_TIMER_LAT2     : Integer := 4;
constant ADDR_TIMER_LAT0    : caddr_type := 5x"05";
constant ADDR_TIMER_LAT1    : caddr_type := 5x"06";
constant ADDR_TIMER_LAT2    : caddr_type := 5x"07";

-- in all designs!
constant ADDR_STATUS        : caddr_type := 5x"10"; -- not used now

constant ADDR_CHIP_CRC      : caddr_type := 5x"11";
constant BIT_CRC_ENA        : Integer := 0;
constant BIT_CRC_START      : Integer := 1;
constant BIT_CRC_FRERR      : Integer := 2;
constant BIT_CRC_DONE       : Integer := 4;
constant BIT_CRC_RUN        : Integer := 5;
constant BIT_CRC_ERR        : Integer := 6;

constant ADDR_CRC_CNT0      : caddr_type := 5x"12";
constant ADDR_CRC_CNT1      : caddr_type := 5x"13";
constant ADDR_CRC_CNT2      : caddr_type := 5x"14";

constant ADDR_SED_TIME0     : caddr_type := 5x"15";
constant ADDR_SED_TIME1     : caddr_type := 5x"16";
constant ADDR_SED_TIME2     : caddr_type := 5x"17";

constant ADDR_SVN0          : caddr_type := 5x"19";
constant ADDR_SVN1          : caddr_type := 5x"1A";
constant ADDR_SVN2          : caddr_type := 5x"1B";
constant ADDR_CMP0          : caddr_type := 5x"1C";
constant ADDR_CMP1          : caddr_type := 5x"1D";
constant ADDR_CMP2          : caddr_type := 5x"1E";

constant ADDR_VERSION       : caddr_type := 5x"1F";
constant BIT_BOOT_IMG       : Integer := 0;
constant BIT_VER_HW         : Integer := 1;
constant BIT_VER_AS         : Integer := 4;

subtype COLOUR_CODE is std_logic_vector(7 downto 0);
    -- typically the codes below are constants, eventually programmable, but static
    -- code to be sent when intensity is 1
constant CODE_1_G           : COLOUR_CODE := x"08";
constant CODE_1_R           : COLOUR_CODE := x"08";
constant CODE_1_B           : COLOUR_CODE := x"08";

    -- code to be sent when intensity is 2
constant CODE_2_G           : COLOUR_CODE := x"0F";
constant CODE_2_R           : COLOUR_CODE := x"00";
constant CODE_2_B           : COLOUR_CODE := x"00";

    -- code to be sent when intensity is 3
constant CODE_3_G           : COLOUR_CODE := x"00";
constant CODE_3_R           : COLOUR_CODE := x"04";
constant CODE_3_B           : COLOUR_CODE := x"02";

end config_pkg;

package body config_pkg is

end config_pkg;
