-- altera vhdl_input_version vhdl_2008

library ieee;
use ieee.std_logic_1164.all;

package ads131m04_pack is
-- for 1..4 ADS131M04 chips

-- $Id: ads131m04_pack.vhd 1216 2026-09-02 16:57:27Z angelov $:


subtype ADS131_cmd_type  is std_logic_vector(15 downto 0);
subtype ADS131_reg_type  is std_logic_vector(15 downto 0);
subtype ADS131_cfgd_type is std_logic_vector( 7 downto 0);
subtype ADS131_adcd_type is std_logic_vector(23 downto 0);

constant CHS_PER_ADC_CHIP       : Integer := 4;

-- Commands
constant ADS131_NULL           : ADS131_cmd_type := x"0000";   -- responce with STATUS, CRC, ADC0..3
constant ADS131_RESET          : ADS131_cmd_type := x"0011";   -- reset
    constant ADS131_RESET_RESP     : ADS131_cmd_type := x"FF24";   -- responce
constant ADS131_STANDBY        : ADS131_cmd_type := x"0022";   -- standby
constant ADS131_WAKEUP         : ADS131_cmd_type := x"0033";
constant ADS131_LOCK           : ADS131_cmd_type := x"0555";
constant ADS131_UNLOCK         : ADS131_cmd_type := x"0655";
constant ADS131_RREG           : ADS131_cmd_type := x"A000";   -- in bits 12..7 is the reg address
constant ADS131_WREG           : ADS131_cmd_type := x"6000";   -- in bits 12..7 is the reg address
constant ADS131_RREG_C         : ADS131_cmd_type := "101------0000000";
constant ADS131_WREG_C         : ADS131_cmd_type := "011------0000000";

-- 32-bit data words configuration addresses in FPGA
constant ADDR_CMD_WR            : Integer := 0;  -- always necessary - only 16-bits used, 24-bit sent (MSB aligned)
    constant BIT_CMD_WMASK_ENA  : Integer := 18; -- is this bit is set, write bits 23..20 to the chip mask
    constant BIT_CMD_WMASK      : Integer := 20;
constant ADDR_WREG              : Integer := 1;  -- if applicable    /
    -- here writing to the chip mask, start and reset bit possible
constant ADDR_CRC_WR            : Integer := 2;  -- normally not used
    -- here writing to the chip mask, start and reset bit possible
constant ADDR_AUTO_READ         : Integer := 3;  -- set/clear the auto read flag
    constant BIT_AUTO_RD        : Integer := 0;
    constant BIT_AUTO_CRC       : Integer := 1;
constant ADDR_ADC_MSK           : Integer := 4;  -- which ADC chips are enabled, which ADC chip is selected for Period & Freq measurement
    constant BIT_MASK           : Integer := 0;
    constant BIT_SEL            : Integer := 4;
constant ADDR_CMD_SM            : Integer := 5;  -- commands like reset the SPI SMs, send SYNC/RESET
    constant BIT_RESET          : Integer := 0;
    constant BIT_START          : Integer := 1;
    constant BIT_RESET_SYNC     : Integer := 2;
    constant BIT_SYNC           : Integer := 3;
    constant BIT_CLR_NEW_SAMPLE : Integer := 4;
    constant BIT_NULL           : Integer := 7;

constant ADDR_STA_SM            : Integer := ADDR_CMD_SM;
    constant BIT_STA_BUSY           : Integer := 1;
    constant BIT_STA_SYNC           : Integer := 2;  -- sync/reset process is active
    constant BIT_STA_SYNC2          : Integer := 3;  -- /
    constant BIT_STA_NEW_SAMPLE     : Integer := 4;  -- there is a new sample
    constant BIT_STA_NO_NEW_SAMPLE  : Integer := 5;  -- same as above, inverted
    constant BIT_STA_RECV_AD        : Integer := 6;  --  8..6
    constant BIT_STA_SEND_AD        : Integer := 9;  -- 10..9
    constant BIT_STA_DRDY           : Integer :=12;  -- data ready, inverted, of all channels (15..12)
    constant BIT_STA_DRDY_RE        : Integer :=16;  -- was a rising edge of DRDY after SYNC was activ
    constant BIT_STA_PMET_BUSY      : Integer :=20;  -- the period measurement is not ready, after changing ADDR_ADC_MSK
    constant BIT_STA_FMET_BUSY      : Integer :=21;  -- the frequency measurement is not ready, after changing ADDR_ADC_MSK
    constant BIT_STA_CRC_0_INP      : Integer :=24;  -- up to 4 bits, CRC on the SPI input data is 0

constant ADDR_P_METER           : Integer := 6;  -- the last period of the DRDY pulses in system ADC clocks (8.192 MHz), about 16 ms max => 18 bits
constant ADDR_F_METER           : Integer := 7;  -- the frequency of the DRDY pulses, 16-bit 32 kHz max
-- the MSBit in both _METER is 1 when the measurement is still in progress

-- non-ADC data from the ADCs
constant ADDR_RD_RESP0          : Integer := 8;  -- responce
constant ADDR_RD_RESP1          : Integer := 9;  -- responce
constant ADDR_RD_RESP2          : Integer :=10;  -- responce
constant ADDR_RD_RESP3          : Integer :=11;  -- responce
constant ADDR_TMR_32KHZ         : Integer :=14;  -- timer running at 32 kHz, synchronous to the system clock
                                                 -- clear by sync/reset command
constant ADDR_TMR_32KHZ_L       : Integer :=15;  -- the timer above latched with new data
--constant ADDR_RD_CRC0           : Integer :=12;
--constant ADDR_RD_CRC1           : Integer :=13;
--constant ADDR_RD_CRC2           : Integer :=14;
--constant ADDR_RD_CRC3           : Integer :=15;

-- ADC data from the first ADC chip
constant ADDR_RD_ADC0           : Integer :=16;
constant ADDR_RD_ADC1           : Integer :=17;
constant ADDR_RD_ADC2           : Integer :=18;
constant ADDR_RD_ADC3           : Integer :=19;

-- ADC data from the second ADC chip
constant ADDR_RD_ADC4           : Integer :=20;
constant ADDR_RD_ADC5           : Integer :=21;
constant ADDR_RD_ADC6           : Integer :=22;
constant ADDR_RD_ADC7           : Integer :=23;

-- ADC data from the third ADC chip
constant ADDR_RD_ADC8           : Integer :=24;
constant ADDR_RD_ADC9           : Integer :=25;
constant ADDR_RD_ADCA           : Integer :=26;
constant ADDR_RD_ADCB           : Integer :=27;

-- ADC data from the fourth (if installed) ADC chip
constant ADDR_RD_ADCC           : Integer :=28;
constant ADDR_RD_ADCD           : Integer :=29;
constant ADDR_RD_ADCE           : Integer :=30;
constant ADDR_RD_ADCF           : Integer :=31;

-- only for VHDL code

constant SYNC_PULSE_LEN         : Integer := 1000*4;  -- 1 .. 2047, x4 as the counter runs with the 4x clock rate of the MCLK
constant REST_PULSE_LEN         : Integer := 3000*4;  --  > 2047

function se( src : std_logic_vector;
            ndst : Integer; sign : Boolean) return std_logic_vector;

end ads131m04_pack;

package body ads131m04_pack is

function se( src : std_logic_vector;
            ndst : Integer; sign : Boolean) return std_logic_vector is

variable tmp : std_logic_vector(ndst-1 downto 0);

begin
    if sign then
        tmp := (others => src(src'high) );
    else
        tmp := (others => '0');
    end if;
    if ndst >= src'length then
        tmp(src'range) := src;
    else
        tmp := src(tmp'range);
    end if;

return tmp;

end se;


end ads131m04_pack;
