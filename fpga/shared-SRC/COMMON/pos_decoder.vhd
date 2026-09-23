-- $Id: pos_decoder.vhd 1208 2026-08-08 16:11:40Z  $:

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.all;
USE IEEE.STD_LOGIC_UNSIGNED.all;

entity pos_decoder is
generic(Nbits : Integer := 32;
        Nfilt : Integer :=  3);
port (
    clk   : in  std_logic;
    clr   : in  std_logic;
    P1    : in  std_logic;
    P2    : in  std_logic;
    posit : out std_logic_vector(Nbits-1 downto 0) );
end pos_decoder;

architecture a of pos_decoder is

component state_2ph is
port (
    clk   : in  std_logic;
    rst   : in  std_logic;
    P1    : in  std_logic;
    P2    : in  std_logic;
    EN    : out std_logic;
    UP    : out std_logic);
end component;

component filt_long is
generic (N     : Natural := 3);
port(
     clk        : in  std_logic;
     d          : in  std_logic;
     inv_q      : in  std_logic;
     ena_edge   : in  std_logic;
     pos_edge   : out std_logic;
     neg_edge   : out std_logic;
     q          : out std_logic);
end component;

signal Log0     : std_logic;
signal p1filt   : std_logic;
signal p2filt   : std_logic;
signal cnt_ena  : std_logic;
signal cnt_up   : std_logic;
signal cnt_pos  : std_logic_vector(Nbits-1 downto 0);

begin
    Log0 <= '0';

fil_p1: filt_long
generic map(
    N => Nfilt)
port map(
     clk        => clk,
     d          => P1,
     inv_q      => Log0,
     ena_edge   => Log0,
     pos_edge   => open,
     neg_edge   => open,
     q          => p1filt);

fil_p2: filt_long
generic map(
    N => Nfilt)
port map(
     clk        => clk,
     d          => P2,
     inv_q      => Log0,
     ena_edge   => Log0,
     pos_edge   => open,
     neg_edge   => open,
     q          => p2filt);


sm: state_2ph
port map(
    clk   => clk,
    rst   => clr,
    P1    => p1filt,
    P2    => p2filt,
    EN    => cnt_ena,
    UP    => cnt_up);

    process(clk)
    begin
        if rising_edge(clk) then
            if clr='1' then
                cnt_pos <= (others => '0');
            elsif cnt_ena='1' then
                if cnt_up='1' then
                    cnt_pos <= cnt_pos + 1;
                else
                    cnt_pos <= cnt_pos - 1;
                end if;
            end if;
        end if;
    end process;

    posit <= cnt_pos;

end;
