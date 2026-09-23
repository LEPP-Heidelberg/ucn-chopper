-- $Id: top_sw32.vhd 1136 2025-01-27 18:19:13Z angelov $:

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

--use work.uart_pack.all;

entity top_sw32 is
GENERIC (Nrom    : Integer := 12;  -- address bits (Program ROM 1024x16, imem), max 11!
         BOOT_ROM : Boolean := false;
         Nram    : Integer :=  8;  -- address bits (DATA RAM 256x16, dmem)
         Nreg    : Integer := 16;  -- number of registers, possible values are 8 (smallest), 12 and 16 (max)
         barrel  : Integer :=  1;  -- max distance: 1, 4 or 8
         SRAM_SyncOut : Boolean := true ; -- for DMEM, must be true to use EBR and false to use distributed RAM
         Nstack  : Integer :=  5;  -- address bits (Stack inside the DMEM)
         Nflag   : Integer :=  2;  -- number of flags
         IRQ_ADR : Integer :=  1;  -- address of the IRQ routine
         Bittime : Natural := 10;  -- UART
         Ntx_fifo: Natural :=  0;  -- UART tx fifo, > 0 - set the size of the fifo to 2**Ntx_fifo, 0 - no fifo but CRC
         Nfilt   : Positive := 3); -- filter depth of the UART input signal
port
        (
          CLK              : IN  STD_LOGIC;
          RESET            : IN  STD_LOGIC; -- reset, used to stop the CPU and write/read the IMEM
          pup_rst          : IN  STD_LOGIC; -- power up reset
          imem_page        : IN  STD_LOGIC := '1';

            -- serial interface
          tx_pause         : in  std_logic := '0'; -- UART input
          rx               : in  std_logic; -- UART input
          tx               : out std_logic; -- UART output
          debug            : out std_logic_vector(7 downto 0);

          -- IO bus master access to the IMEM
          IM_BADDR         : IN  STD_LOGIC_VECTOR(Nrom-1 downto 0);
          IM_WDATA         : IN  STD_LOGIC_VECTOR(  23 downto 0);
          IM_RDATA         : OUT STD_LOGIC_VECTOR(  23 downto 0);
          IM_WE            : IN  STD_LOGIC;

          -- CPU to IO bus
          IO_IN            : IN  STD_LOGIC_VECTOR(31 downto 0);
          IO_ADR           : OUT STD_LOGIC_VECTOR(31 downto 0);  -- QB
          IO_OUT           : OUT STD_LOGIC_VECTOR(31 downto 0);  -- QC
          IO_rdy           : IN  STD_LOGIC;
          IO_RD, IO_WE     : OUT STD_LOGIC);

end top_sw32;

architecture a of top_sw32 is

component core_sw32 is
GENERIC (Nramt   : Integer := 8;  -- total width of the RAM address bus
         Nstack  : Integer := 4;  -- the part controlled by the stack pointer
         Nflag   : Integer := 2;  -- number of flags
         Nreg    : Integer := 16;  -- number of registers, possible values are 8 (smallest), 12 and 16 (max)
         Nrom    : Integer := 8; -- the width of the ROM address bus
         barrel  : Integer := 1;  -- 1, 4 or 8
         IRQ_ADR : Integer :=  1); -- address of the IRQ routine
port
        (
          CLK              : IN  STD_LOGIC;
          RESET            : IN  STD_LOGIC;
          IRQ              : IN  STD_LOGIC;
          IO_IN            : IN  STD_LOGIC_VECTOR(31 downto 0);
          IO_ADR           : OUT STD_LOGIC_VECTOR(31 downto 0);  -- QB
          IO_OUT           : OUT STD_LOGIC_VECTOR(31 downto 0);  -- QC
          IO_RD, IO_WE     : OUT STD_LOGIC;
          IO_rdy           : IN  STD_LOGIC;

          RAM_WE           : OUT STD_LOGIC;
          RAM_A            : OUT STD_LOGIC_VECTOR(Nramt-1 downto 0);
          RAM_D            : OUT STD_LOGIC_VECTOR(31 downto 0);
          RAM_Q            : IN  STD_LOGIC_VECTOR(31 downto 0);  -- make input for external RAM
          ROM_A            : OUT STD_LOGIC_VECTOR(Nrom-1 downto 0);-- QB
          ROM_D            : IN  STD_LOGIC_VECTOR(23 downto 0)   -- QB
        );
end component;

component ucontr_uart is -- no TX fifo, with CRC!
generic(Bittime  : Positive := 10;
        LSBfirst : Boolean  := true;
        Nfilt    : Positive := 3);
port (
    clk          : in  std_logic;
    reset        : in  std_logic;
    -- serial interface
    rx           : in  std_logic;
    tx           : out std_logic;
    -- CPU interface
    we           : in  std_logic;
    addr         : in  std_logic_vector(1 downto 0);
    data_out     : in  std_logic_vector(7 downto 0);
    data_in      : out std_logic_vector(7 downto 0));
end component;

component uc_uart is   -- with TX fifo, no CRC!
generic(Bittime  : Positive := 10;
        Ntx_fifo : Natural  :=  8; -- number of address bits in the tx FIFO, 0 for no FIFO
        LSBfirst : Boolean  := true;
        Nfilt    : Positive := 3);
port (
    clk          : in  std_logic;
    reset        : in  std_logic;
    -- serial interface
    tx_pause     : in  std_logic := '0'; -- UART input
    rx           : in  std_logic;
    tx           : out std_logic;
    -- CPU interface
    we           : in  std_logic;
    addr         : in  std_logic_vector(1 downto 0);
    data_out     : in  std_logic_vector(7 downto 0);
    data_in      : out std_logic_vector(7 downto 0));
end component;

component imem_dp is -- is created in the Makefile (for Lattice):

-- assem -p$(IMEM_DEPTH) -i $(assem_prog) $(asm_define) -ot ../SRC/$(imem_ahx) -ol assem.log
-- scuba -w -n imem_dp -lang vhdl -synth synplify -bus_exp 7 -bb -arch xo2c00 -type bram -wp 10 -rp 0011 -rdata_width 16 -data_width 16 -num_rows $(IMEM_DEPTH) -byte 8 -cascade 11 -memfile ../$(imem_ahx) -memformat orca

generic (Nrom : Integer := 9);
    port (
        WrAddress   : in  std_logic_vector(Nrom-1 downto 0);
        RdAddress   : in  std_logic_vector(Nrom-1 downto 0);
        Data        : in  std_logic_vector(23 downto 0);
        WE          : in  std_logic;
        RdClock     : in  std_logic;
        RdClockEn   : in  std_logic;
        Reset       : in  std_logic;
        WrClock     : in  std_logic;
        WrClockEn   : in  std_logic;
        Q           : out std_logic_vector(23 downto 0));
end component;

component dmem is
generic (Nsram   : Integer := 5;
         Ndata   : Integer := 16;
         SyncOut : Boolean := false);
port(
    clk         : in  std_logic;
    addr        : in  std_logic_vector(Nsram-1 downto 0);
    we          : in  std_logic;
    data_in     : in  std_logic_vector(Ndata-1 downto 0);
    data_out    : out std_logic_vector(Ndata-1 downto 0));
end component;

component rom is
generic(Np : Integer := 9);
port(
    clk         : in  std_logic;
    rom_addr    : in  std_logic_vector(Np-1 downto 0);
    rom_data    : out std_logic_vector(23 downto 0));
end component;

signal RAM_D            : std_logic_vector(31 downto 0);
signal RAM_Q            : std_logic_vector(31 downto 0);
signal ROM_D            : std_logic_vector(23 downto 0);
signal IMEM_Q           : std_logic_vector(23 downto 0);

signal ROM_A            : std_logic_vector(Nrom- 1 downto 0);
signal IMEM_RADDR       : std_logic_vector(Nrom- 1 downto 0);
signal RAM_A            : std_logic_vector(Nram- 1 downto 0);

signal RAM_WE           : std_logic;

signal IRQ              : std_logic;

signal IO_IN_i          : std_logic_vector(31 downto 0);
signal IO_ADR_i         : std_logic_vector(31 downto 0);  -- QB
signal IO_OUT_i         : std_logic_vector(31 downto 0);  -- QC
signal IO_RD_i, IO_WE_i : std_logic;
signal IO_rdy_i         : std_logic;

signal rom_addr         : std_logic_vector(Nrom- 1 downto 0);
signal rom_data         : std_logic_vector(23 downto 0);

signal io_we_uart       : std_logic;
signal uart_sel         : std_logic;
signal uart_rdy         : std_logic;
signal uart_dout        : std_logic_vector( 7 downto 0);

signal Log1             : std_logic;

signal rst_late         : std_logic;
signal rst_long         : std_logic;

begin
    IRQ  <= '0';
    Log1 <= '1';

------------------------------------------------------------------------------------------

sw16: core_sw32
GENERIC map(Nrom    => Nrom,    -- address bits (Program ROM 512x16, imem)
            Nramt   => Nram,    -- address bits RAM total
            Nreg    => Nreg,
            Nstack  => Nstack,  -- address bits Stack inside SRAM
            Nflag   => Nflag,   -- number of flags, must be 2
            barrel  => barrel,  -- 1, 4 or 8 for max shift 1, 4, 8
            IRQ_ADR => IRQ_ADR) -- address of the IRQ routine
port map
        (
          CLK              => CLK,
          RESET            => rst_long,
          IRQ              => IRQ,
          IO_IN            => IO_IN_i,
          IO_ADR           => IO_ADR_i,
          IO_OUT           => IO_OUT_i,
          IO_RD            => IO_RD_i,
          IO_WE            => IO_WE_i,
          IO_rdy           => IO_rdy_i,

          RAM_WE           => RAM_WE,
          RAM_A            => RAM_A,
          RAM_D            => RAM_D,
          RAM_Q            => RAM_Q,
          ROM_A            => ROM_A,
          ROM_D            => ROM_D
        );

------------------------------------------------------------------------------------------

    -- dual port RAM as IMEM
--im: entity work.imem_dp  -- instruction memory, wrapper to different implementations depending on the FPGA family
im: imem_dp  -- instruction memory, wrapper to different implementations depending on the FPGA family
generic map(Nrom => IMEM_RADDR'length)
    port map(
        WrAddress   => IM_BADDR,
        RdAddress   => IMEM_RADDR,
        Data        => IM_WData,
        WE          => IM_WE,
        RdClock     => clk,
        RdClockEn   => Log1,
        Reset       => pup_rst,
        WrClock     => clk,
        WrClockEn   => Log1,
        Q           => IMEM_Q);

with_boot_rom: if BOOT_ROM generate
boot_rom_i: rom
generic map(Np => Nrom)
port map(
    clk         => clk,
    rom_addr    => rom_addr,
    rom_data    => rom_data);

    -- send 0x0000 to the processor (NOP) while and after reset, else the output from the IMEM
    ROM_D <= (others => '0') when rst_late='1' else IMEM_Q when imem_page='1' else rom_data;

    -- read address is the write address (from external bus) when RESET, else program counter (ROM_A)
    IMEM_RADDR <= IM_BADDR(IM_BADDR'high downto 0) when Reset='1' or imem_page='0' else ROM_A;
    rom_addr   <= IM_BADDR(IM_BADDR'high downto 0) when Reset='1' or imem_page='1' else ROM_A;

    process(IMEM_Q, Reset, imem_page, IM_BADDR, rom_data)
    variable my_sel   : std_logic_vector( 1 downto 0);
    variable rd_dat   : std_logic_vector(23 downto 0);
    begin
        my_sel := Reset & imem_page;
        case my_sel is
            when "10" | "01" => IM_RDATA <= rom_data; -- boot rom
            when "11" | "00" => IM_RDATA <= IMEM_Q;   -- SRAM IMEM
            when others => NULL;
        end case;
    end process;

    -- the window to write into IMEM from UART is here used to access the own UART

    uart_sel   <= '1' when IO_ADR_i(14 downto 12) = "001" and imem_page='1' else '0';

else generate

    -- send 0x0000 to the processor (NOP) while and after reset, else the output from the IMEM
    ROM_D <= (others => '0') when rst_late='1' else IMEM_Q;

    -- read address is the write address (from external bus) when RESET, else program counter (ROM_A)
    IMEM_RADDR <= IM_BADDR(IM_BADDR'high downto 0) when Reset='1' else ROM_A;

    -- 8-bit read data for external bus, Addr0 selects bits 7..0 or 15..8
    IM_RDATA  <= (others => '-') when Reset='0' else           -- when CPU running not possible to read the IMEM
                 IMEM_Q;

    uart_sel   <= '1' when IO_ADR_i(15 downto 12) = "001" else '0';

end generate;
------------------------------------------------------------------------------------------

dm: dmem     -- Data memory, Stack
generic map(
    Nsram   => Nram,
    Ndata   => 32,
    SyncOut => SRAM_SyncOut)
port map(
    clk         => clk,
    addr        => RAM_A,
    we          => RAM_WE,
    data_in     => RAM_D,
    data_out    => RAM_Q);

------------------------------------------------------------------------------------------

    -- write enable for the UART
    io_we_uart <= IO_WE_i when uart_sel='1' else '0';

    -- mux for the read data from IO to the CPU
    IO_IN_i <= x"000000" & uart_dout when uart_sel='1' else IO_IN;

    -- WE and RD to the IO bus only when the UART was not selected
    IO_WE   <= IO_WE_i when uart_sel='0' else '0';
    IO_RD   <= IO_RD_i when uart_sel='0' else '0';
    -- output data and address not changed
    IO_OUT  <= IO_OUT_i;
    IO_ADR  <= IO_ADR_i;

    -- read from the IO bus, or from outside and UART
    IO_rdy_i <= IO_rdy when uart_sel='0' else uart_rdy;

    process(clk)
    begin
        if rising_edge(clk) then
            -- auto generate RDY from UART
            uart_rdy <= uart_sel and (IO_RD_i or IO_WE_i);
            -- one clock delayed reset for the IMEM data
            rst_late <= reset;
            -- longer reset for the CPU
            rst_long <= reset or rst_late;

            debug <= IO_WE_i & IO_RD_i & uart_sel & ROM_A(Nrom-1 downto Nrom-4) & ROM_A(0);

        end if;
    end process;


with_uart: if Bittime > 0 generate

  no_fifo: if Ntx_fifo = 0 generate
                -- UART without FIFO, but with CRC generator
    uart: ucontr_uart
    generic map(
            Bittime  => Bittime,
            Nfilt    => Nfilt)
    port map(
        clk          => clk,
        reset        => pup_rst,
        -- serial interface
        rx           => rx,
        tx           => tx,
        -- CPU interface
        we           => io_we_uart,
        addr         => IO_ADR_i(1 downto 0),
        data_out     => IO_OUT_i(7 downto 0),
        data_in      => uart_dout);

  else generate -- UART with FIFO

    uart_fifo: uc_uart
    generic map(
            Bittime  => Bittime,
            Ntx_fifo => Ntx_fifo,
            Nfilt    => Nfilt)
    port map(
        clk          => clk,
        reset        => pup_rst,
        -- serial interface
        tx_pause     => tx_pause,
        rx           => rx,
        tx           => tx,
        -- CPU interface
        we           => io_we_uart,
        addr         => IO_ADR_i(1 downto 0),
        data_out     => IO_OUT_i(7 downto 0),
        data_in      => uart_dout);

  end generate;

else generate   -- no UART

      uart_dout <= (others => '0');
      tx <= '1';

end generate;

end;
