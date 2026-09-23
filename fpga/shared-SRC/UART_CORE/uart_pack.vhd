library ieee;
use ieee.std_logic_1164.all;

package uart_pack is

-- $Id: uart_pack.vhd 1 2016-03-15 14:35:42Z angelov $:

constant byte_size : Positive :=  8;
constant addr_size : Positive := 16;
constant ID_size   : Positive :=  4;

subtype ID_vector is std_logic_vector(ID_size-1 downto 0);
subtype data_vector is std_logic_vector(byte_size-1 downto 0);
subtype addr_vector is std_logic_vector(addr_size-1 downto 0);

-- slave ID for broadcast
constant IDbrcst : ID_vector := (others => '1');

-- number of bits for the packet size
constant psize_size  : Positive := byte_size - ID_size - 1;
-- max size of the byte counter
constant pfsize_size : Positive := 11; -- up to 2048 bytes in a packet

function log2(n : natural) return natural;

end uart_pack;

package body uart_pack is

function log2 (n : natural) return natural is
    variable n_bit : natural := 0;
    variable n_cpy : natural;
  begin  -- log2ceil
    n_cpy := n;
    while (n_cpy > 0) loop
        n_bit := n_bit + 1;
        n_cpy := n_cpy / 2;
    end loop;
    return n_bit;
  end log2;


end uart_pack;
