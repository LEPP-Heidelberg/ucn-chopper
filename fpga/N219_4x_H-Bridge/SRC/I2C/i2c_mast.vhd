-- $Id: i2c_mast.vhd 1065 2024-03-16 06:40:18Z angelov $:

LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
-- temporary!
USE IEEE.std_logic_arith.ALL;
USE IEEE.std_logic_unsigned.ALL;

library work;
use work.i2c_pack.all;


entity i2c_master is
generic (waittime : Positive := 2; timeoutmax : Positive := 2; Nfil : Positive := 3; DEL_READY : Positive := 1);
port(
        clk     : in    std_logic;
        srst    : in    std_logic;
        cmd     : in    std_logic_vector(2 downto 0);
        din     : in    std_logic_vector(7 downto 0);
        status  : out   std_logic_vector(3 downto 0);
        start   : in    std_logic;
        ready   : out   std_logic;
        timeout : out   std_logic;
        dout    : out   std_logic_vector(7 downto 0);
        scl     : out   std_logic;  -- 1 means Z, 0 means 0
        sda_i   : in    std_logic;
        sda_o   : out   std_logic); -- 1 means Z, 0 means 0
end i2c_master;

architecture a of i2c_master is

--    SDA(1);
--    SCL(0);

--    for (i=0; i<4; i++) // 4 times i2c stop
--    {
--        SDA(0);
--        SCL(1);
--        SDA(1);
--    }


type i2c_states_type is (idle, stop1,
                        rstart1, start1, start2, start3,
                        getack1, getack2, getack3, getack4,
                        giveack1, giveack2,
                        putbyte1, putbyte2, putbyte3,
                        getbyte1, getbyte2, getbyte3, putgetend );

attribute syn_enum_encoding : string;
attribute syn_enum_encoding of i2c_states_type : type is "gray";

component filt_long is
generic (N     : Positive := 3);
port(
     clk        : in  std_logic;
     d          : in  std_logic;
     inv_q      : in  std_logic;
     ena_edge   : in  std_logic;
     pos_edge   : out std_logic;
     neg_edge   : out std_logic;
     q          : out std_logic);
end component;


signal sm     : i2c_states_type;

signal stepen : std_logic;
signal waitc  : Integer range 0 to waittime-1;
signal cnt    : Integer range 0 to timeoutmax-1;
signal bcnt   : Integer range 0 to 7;

signal dreg   : std_logic_vector(7 downto 0);


signal sda_i_s : std_logic;
signal scl_o   : std_logic;
signal start_latched : std_logic;

signal cready : Integer range 0 to DEL_READY-1;

begin
    with sm select
    status <= X"0" when idle,
              X"1" when stop1,
              X"2" when rstart1,
              X"2" when start1,
              X"3" when start2,
              X"4" when start3,
              X"5" when getack1,
              X"6" when getack2,
              X"7" when getack3 | getack4,
              X"8" when giveack1,
              X"9" when giveack2,
              X"A" when putbyte1,
              X"A" when putbyte2,
              X"B" when putbyte3,
              X"C" when getbyte1,
              X"D" when getbyte2,
              X"E" when getbyte3,
              X"F" when putgetend;

    process(clk)
    begin
        if rising_edge(clk) then
            stepen <= '0';
            if waitc = 0 then
                waitc <= waittime-1;
                stepen <= '1';
            else
                waitc <= waitc - 1;
            end if;

            if srst='1' then
                waitc <= waittime-1;
                stepen <= '1';
            end if;

        end if;
    end process;


sdi_fil: filt_long
generic map(N => Nfil)
port map(
     clk      => clk,
     d        => sda_i,
     inv_q    => '0',
     ena_edge => '0',
     pos_edge => open,
     neg_edge => open,
     q        => sda_i_s);


    process(clk)
    begin
        if rising_edge(clk) then
            ready <= '0';
--            sda_i_s <= sda_i;
            if sm = idle then
                start_latched <= start_latched or start;
            else
                start_latched <= '0';
            end if;
            if srst='1' then
                sm    <= idle;
                sda_o <= '1';
                scl_o <= '1';
                start_latched <= '0';
                timeout <= '0';
            elsif stepen='1' then
                cnt   <= 0;
                case sm is
                    when idle =>
                        cready <= DEL_READY-1;
                        bcnt <= 7;
                        if start_latched = '1' then
                            timeout <= '0';
                            case cmd is
                                when CMD_STOP  => sm <= stop1;    sda_o <= '0';
                                when CMD_START => sm <= start1;   scl_o <= '1';
                                when CMD_RSTRT => sm <= rstart1;  sda_o <= '1';
                                when CMD_GETA  => sm <= getack1;  sda_o <= '1';
                                when CMD_GIVA  => sm <= giveack1; sda_o <= '0';
                                when CMD_PUTB  => sm <= putbyte1; scl_o <= '0'; dreg <= din;
                                when CMD_GETB  => sm <= getbyte1; sda_o <= '1';
                                when others    => ready <= '1';
                            end case;
                            start_latched <= '0';
                        end if;
                    when stop1      => sm <= putgetend; scl_o <= '1';

                    when rstart1    => sm <= start2;    scl_o <= '1';

                    when start1     => sm <= start2;    sda_o <= '1';

                    when start2     => sm <= start3;    sda_o <= '0';
                    when start3     => sm <= putgetend; scl_o <= '0';

                    when giveack1   => sm <= giveack2;  scl_o <= '1';
                    when giveack2   => sm <= putgetend; scl_o <= '0';

                    when getack1    => sm <= getack2; sda_o <= '1';
                    when getack2    => sm <= getack3; scl_o <= '1';
                    when getack3    => if cnt=timeoutmax-1 or sda_i_s='0' then
                                            sm    <= getack4;
                                            scl_o <= '0';
                                         --   ready <= '1';
                                            if cnt=timeoutmax-1 then timeout <= '1'; end if;
                                       else
                                            cnt <= cnt + 1;
                                       end if;
                    when getack4    =>
                                      if cready = 0 then
                                          sm <= idle; ready <= '1';
                                      else
                                          cready <= cready - 1;
                                      end if;
--                                    sm <= idle;
--                                    ready <= '1';

                    when putbyte1 => sm <= putbyte2; sda_o <= dreg(7);
                    when putbyte2 => sm <= putbyte3; scl_o <= '1';
                    when putbyte3 => scl_o <= '0';
                                     dreg <= dreg(6 downto 0) & sda_i_s; -- shift
                                     if bcnt = 0 then
                                            sm <= putgetend;
                                        else
                                            sm <= putbyte1;
                                            bcnt <= bcnt - 1;
                                        end if;

                    when getbyte1 => scl_o <= '0'; sm <= getbyte2;
                    when getbyte2 => scl_o <= '1'; sm <= getbyte3;
                    when getbyte3 => scl_o <= '0';
                                     dreg <= dreg(6 downto 0) & sda_i_s;
                                     if bcnt = 0 then
                                            sm <= putgetend;
                                        else
                                            bcnt <= bcnt - 1;
                                            sm <= getbyte1; end if;
                    when putgetend => sda_o <= '1';
                                      if cready = 0 then
                                            sm <= idle; ready <= '1';
                                      else
                                            cready <= cready - 1;
                                      end if;

                end case;
            end if;
        end if;
    end process;

    dout <= dreg;
    scl  <= scl_o;

end;

-- i2c_stop is
-- SDA <= '0'
-- SCL <= '1'
-- SDA <= '1'

-- ic2_start is
-- SCL <= '1';
-- SDA <= '1';
-- SDA <= '0';
-- SCL <= '0';
-- SDA <= '1';

-- ic2 repeated start is
-- (initial position is 0, 0)
-- SDA <= '1';
-- SCL <= '1';
-- SDA <= '0';
-- SCL <= '0';
-- SDA <= '1';

-- i2c_giveack
-- SDA <= '0';
-- SCL <= '1';
-- SCL <= '0';
-- SDA <= '1';

-- i2c_getack
-- SDA <= '1';
-- SCL <= '1';
    -- wait until SDA is 1 but check for timeout
-- SCL <= '0';

-- putbyte data
-- SCL <= '0';
--    for (i=7; i>=0; i--)
--    {
--  SDA <= MSB(data) to send
--  SCL <= '1';
--  SCL <= '0';
--  data <= data << 1 - shift left
--    }
-- SDA <= '1';



-- i2c_getbyte
-- SDA <= '1';
--{
-- SCL <= '0';
--    for (i=0; i<=7; i++)
--    {
--  SCL <= '1';
-- recv_data <= (recv_data << 1) or SDA_in
--  SCL <= '0';
--    }
-- SDA <= '1';


--uint16_t i2c_j2c::i2c_readbyte(uint16_t device_addr_7bit, uint16_t offset)
--{
--    uint16_t data;
--    i2c_start();
--    i2c_putbyte(device_addr_7bit << 1);
--    i2c_getack();
--    i2c_putbyte(offset);
--    i2c_getack();
--    i2c_start();
--    i2c_putbyte((device_addr_7bit << 1) | 0x01);
--    i2c_getack();
--    data = i2c_getbyte();
--    i2c_stop();
--    return data;
--}
--
--
--void i2c_j2c::i2c_writebyte(uint16_t device_addr_7bit, uint16_t offset, uint16_t data)
--{
--    i2c_start();
--    i2c_putbyte(device_addr_7bit << 1);
--    i2c_getack();
--    i2c_putbyte(offset);
--    i2c_getack();
--    i2c_putbyte(data & 0xff);
--    i2c_getack();
--    i2c_stop();
--}
