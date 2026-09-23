-- $Id: imem_dp_par.vhd 584 2019-02-01 15:12:43Z angelov $:

library ieee;
USE IEEE.std_logic_1164.ALL;
USE IEEE.std_logic_unsigned.ALL;

entity imem_dp_par is
generic (
    Hamm     : Boolean  := false;
    Nrom     : Positive := 11);
port(
     WrAddress      : in  std_logic_vector(Nrom-1 downto 0);
     RdAddress      : in  std_logic_vector(Nrom-1 downto 0);
     Data           : in  std_logic_vector(  15 downto 0);
     ByteEn         : in  std_logic_vector(   1 downto 0);
     WE             : in  std_logic;
     RdClock        : in  std_logic;
     RdClockEn      : in  std_logic;
     Reset          : in  std_logic;
     WrClock        : in  std_logic;
     WrClockEn      : in  std_logic;
     status         : out std_logic_vector(   7 downto 0);
     Q              : out std_logic_vector(  15 downto 0) );
end imem_dp_par;

architecture a of imem_dp_par is

component dec IS
    PORT
    (
       data          : IN  STD_LOGIC_VECTOR (12 DOWNTO 0);
       err_corrected : OUT STD_LOGIC ;
       err_detected  : OUT STD_LOGIC ;
       err_fatal     : OUT STD_LOGIC ;
       q             : OUT STD_LOGIC_VECTOR ( 7 DOWNTO 0)
    );
END component;

component ecc IS
    PORT
    (
       data          : IN  STD_LOGIC_VECTOR ( 7 DOWNTO 0);
       q             : OUT STD_LOGIC_VECTOR (12 DOWNTO 0)
    );
END component;

function number_of_bits(with_hamm : Boolean) return integer is
begin
    if with_hamm then return 13;
                 else return  8;
    end if;
end;

component dpram is
generic (Na     : Positive := 4;
         Nd     : positive := 8;
       async_rd : Boolean := true);
port(
    clk_r   : in  std_logic;
    clk_w   : in  std_logic;
    we      : in  std_logic;
    raddr   : in  std_logic_vector(Na-1 downto 0);
    waddr   : in  std_logic_vector(Na-1 downto 0);
    din     : in  std_logic_vector(Nd-1 downto 0);
    dout    : out std_logic_vector(Nd-1 downto 0) );
end component;

signal we_gated     : std_logic_vector(1 downto 0);

constant Nd             : integer := 8;
constant Ndh            : integer := number_of_bits(Hamm);

signal wdata_l          : std_logic_vector(Ndh-1 downto 0);
signal wdata_h          : std_logic_vector(Ndh-1 downto 0);

signal rdata_l          : std_logic_vector(Ndh-1 downto 0);
signal rdata_h          : std_logic_vector(Ndh-1 downto 0);
signal err_corrected_l  : std_logic;
signal err_detected_l   : std_logic;
signal err_fatal_l      : std_logic;
signal err_corrected_h  : std_logic;
signal err_detected_h   : std_logic;
signal err_fatal_h      : std_logic;

begin
    we_gated(0) <= we and WrClockEn and ByteEn(0);
    we_gated(1) <= we and WrClockEn and ByteEn(1);

with_hamm_enc_i: if Hamm generate

hamm_enc_L_i: ecc
    PORT map
    (
        data  => data( 7 downto 0),
        q     => wdata_l
    );

hamm_enc_H_i: ecc
    PORT map
    (
        data  => data(15 downto 8),
        q     => wdata_h
    );

else generate -- bypass
       wdata_l <= data( 7 downto 0);
       wdata_h <= data(15 downto 8);
end generate;

ram_b0: dpram
generic map(Na => Nrom,
            Nd => Ndh,
            async_rd => false)
port map(
    clk_r   => RdClock,
    clk_w   => WrClock,
    we      => we_gated(0),
    raddr   => RdAddress,
    waddr   => WrAddress,
    din     => wdata_l,
    dout    => rdata_l);

ram_b1: dpram
generic map(Na => Nrom,
            Nd => Ndh,
            async_rd => false)
port map(
    clk_r   => RdClock,
    clk_w   => WrClock,
    we      => we_gated(1),
    raddr   => RdAddress,
    waddr   => WrAddress,
    din     => wdata_h,
    dout    => rdata_h);

with_hamm_dec_i: if Hamm generate

hamm_dec_L_i: dec
    PORT map
    (
        data            => rdata_l,
        err_corrected   => err_corrected_l,
        err_detected    => err_detected_l,
        err_fatal       => err_fatal_l,
        q               => q( 7 downto 0)
    );

hamm_dec_H_i: dec
    PORT map
    (
        data            => rdata_h,
        err_corrected   => err_corrected_h,
        err_detected    => err_detected_h,
        err_fatal       => err_fatal_h,
        q               => q(15 downto 8)
    );

    process(RdClock)
    begin
        if rising_edge(RdClock) then
            status <= '1' & err_corrected_h & err_detected_h & err_fatal_h & '1' & err_corrected_l & err_detected_l & err_fatal_l;
        end if;
    end process;

else generate -- bypass
    q <= rdata_h & rdata_l;
    status <= (others => '0');
end generate;

end;
