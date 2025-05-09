library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;    
use STD.textio.all; 

library MEM;

use work.pProc_bus_gba.all;
use work.pReg_savestates.all;

entity gba_memorymux is
   generic
   (
      is_simu                  : std_logic;
      Softmap_GBA_Gamerom_ADDR : integer; -- count: 8388608  -- 32 Mbyte Data for GameRom   
      Softmap_GBA_FLASH_ADDR   : integer; -- count:  131072  -- 128/512 Kbyte Data for GBA Flash
      Softmap_GBA_EEPROM_ADDR  : integer  -- count:    8192  -- 8/32 Kbyte Data for GBA EEProm
   );
   port 
   (
      clk                  : in     std_logic; 
      reset                : in     std_logic;
      ce                   : in     std_logic;
      
      sleep_savestate      : in     std_logic;
      loading_savestate    : in     std_logic;
      saving_savestate     : in     std_logic;
      register_reset       : in     std_logic;
      
      cart_ena             : out    std_logic := '0';
      cart_32              : out    std_logic := '0';
      cart_rnw             : out    std_logic := '0';
      cart_addr            : out    std_logic_vector(27 downto 0) := (others => '0');
      cart_writedata       : out    std_logic_vector(7 downto 0) := (others => '0');
      cart_done            : in     std_logic := '0';
      cart_readdata        : in     std_logic_vector(31 downto 0);
      
      cart_waitcnt         : in     std_logic_vector(14 downto 0);
                                    
-- synthesis translate_off
      debug_PF_count       : out    unsigned(3 downto 0) := (others => '0');
      debug_PF_countdown   : out    unsigned(3 downto 0) := (others => '0');
-- synthesis translate_on 
                                    
      gb_bus_out           : out    proc_bus_gb_type := ((others => '0'), (others => '0'), '0', '0', "00", "0000", '0');      
      wired_out            : in     std_logic_vector(proc_buswidth-1 downto 0) := (others => '0');
      wired_done           : in     std_logic;      
                                    
      mem_bus_Adr          : in     std_logic_vector(31 downto 0);
      mem_bus_rnw          : in     std_logic;
      mem_bus_ena          : in     std_logic;
      mem_bus_seq          : in     std_logic;
      mem_bus_code         : in     std_logic;
      mem_bus_acc          : in     std_logic_vector(1 downto 0);
      mem_bus_dout         : in     std_logic_vector(31 downto 0);
      mem_bus_din          : out    std_logic_vector(31 downto 0) := (others => '0');
      mem_bus_done_out     : out    std_logic;
      mem_bus_unread       : out    std_logic;
      
      bios_wraddr          : in     std_logic_vector(11 downto 0) := (others => '0');
      bios_wrdata          : in     std_logic_vector(31 downto 0) := (others => '0');
      bios_wr              : in     std_logic := '0';
      
      bus_lowbits          : in     std_logic_vector(1 downto 0);
      
      dma_on               : in     std_logic;
                                    
      PC_in_BIOS           : in     std_logic;
      lastread             : in     std_logic_vector(31 downto 0);
      lastread_dma         : in     std_logic_vector(31 downto 0);
      last_access_dma      : in     std_logic;
      
      bitmapdrawmode       : in     std_logic;
                                    
      VRAM_Lo_addr         : out    integer range 0 to 16383;
      VRAM_Lo_datain       : out    std_logic_vector(31 downto 0);
      VRAM_Lo_dataout      : in     std_logic_vector(31 downto 0);
      VRAM_Lo_ce           : out    std_logic;
      VRAM_Lo_we           : out    std_logic;
      VRAM_Lo_be           : out    std_logic_vector(3 downto 0);
      VRAM_Hi_addr         : out    integer range 0 to 8191;
      VRAM_Hi_datain       : out    std_logic_vector(31 downto 0);
      VRAM_Hi_dataout      : in     std_logic_vector(31 downto 0);
      VRAM_Hi_ce           : out    std_logic;
      VRAM_Hi_we           : out    std_logic;
      VRAM_Hi_be           : out    std_logic_vector(3 downto 0);
      vram_blocked         : in     std_logic;      
      vram_cycle           : out    std_logic := '0';
                                    
      OAMRAM_PROC_addr     : out    integer range 0 to 255;
      OAMRAM_PROC_datain   : out    std_logic_vector(31 downto 0);
      OAMRAM_PROC_dataout  : in     std_logic_vector(31 downto 0);
      OAMRAM_PROC_we       : out    std_logic_vector(3 downto 0);
                                    
      PALETTE_BG_addr      : out    integer range 0 to 128;
      PALETTE_BG_datain    : out    std_logic_vector(31 downto 0);
      PALETTE_BG_dataout   : in     std_logic_vector(31 downto 0);
      PALETTE_BG_we        : out    std_logic_vector(3 downto 0);
      PALETTE_BG_re        : out    std_logic_vector(3 downto 0);
      PALETTE_OAM_addr     : out    integer range 0 to 128;
      PALETTE_OAM_datain   : out    std_logic_vector(31 downto 0);
      PALETTE_OAM_dataout  : in     std_logic_vector(31 downto 0);
      PALETTE_OAM_we       : out    std_logic_vector(3 downto 0);
      PALETTE_OAM_re       : out    std_logic_vector(3 downto 0)
   );
end entity;

architecture arch of gba_memorymux is

   constant busadr_bits   : integer := 26;
   constant gbbusadr_bits : integer := work.pProc_bus_gba.proc_busadr;
   
   type tState is
   (
      IDLE,
      ALLWAIT,
      ALLWAIT_CE,
      WAIT_CART
   );
   signal state : tState := IDLE;
   
   type treadState is
   (
      READSTATE_BIOS,
      READSTATE_EWRAM,
      READSTATE_IRAM,
      READSTATE_GBBUS,
      READSTATE_PALBG,
      READSTATE_PALOAM,
      READSTATE_VRAMHI,
      READSTATE_VRAMLO,
      READSTATE_OAM,
      READSTATE_ROM,
      READSTATE_UNREADABLE
   );
   signal readState : treadState := READSTATE_BIOS;
   
   signal mem_bus_din_unrot       : std_logic_vector(31 downto 0);
          
   signal mem_bus_din_dummy       : std_logic_vector(31 downto 0);
   
   signal ce_latched_done         : std_logic := '0';
   signal ce_latched_data         : std_logic_vector(31 downto 0) := (others => '0');
   signal ce_wait                 : unsigned(3 downto 0) := (others => '0');
   signal ce_block_prefetch       : std_logic := '0';
   signal ce_done_hold            : std_logic := '0';
          
   signal adr_save                : std_logic_vector(gbbusadr_bits-1 downto 0);
   signal acc_save                : std_logic_vector(1 downto 0);
   signal rnw_save                : std_logic := '0';
                        
   signal mem_bus_done            : std_logic := '0';
   signal return_rotate           : std_logic_vector(1 downto 0);
   signal rotate_data             : std_logic_vector(31 downto 0) := (others => '0');
             
   signal bios_readEna            : std_logic;
   signal bios_data               : std_logic_vector(31 downto 0);
                                  
   signal smallram_addr           : integer range 0 to 8191 := 0;
   signal smallram_DataOut        : std_logic_vector(31 downto 0);
   signal smallram_be             : std_logic_vector(0 to 3);
   signal smallram_we             : std_logic;
   signal smallram_ce             : std_logic;
                                  
   signal largeram_addr           : integer range 0 to 65535 := 0;
   signal largeram_DataOut        : std_logic_vector(31 downto 0);
   signal largeram_we             : std_logic;
   signal largeram_ce             : std_logic;
                 
   signal gb_bus_out_ena          : std_logic := '0';
                 
   signal cart_readback           : std_logic_vector(31 downto 0) := (others => '0');
   signal cart_readback_muxed     : std_logic_vector(31 downto 0) := (others => '0');
                               
   signal cart_nowait             : std_logic := '0';
                               
   signal rotate_writedata        : std_logic_vector(31 downto 0);
   signal rotate_BE               : std_logic_vector(3 downto 0);   
   signal rotate_writedata_save   : std_logic_vector(31 downto 0) := (others => '0');
   signal rotate_BE_save          : std_logic_vector(3 downto 0) := (others => '0');

   signal wait_timer              : integer range 0 to 31 := 0;
   signal wait_timer_ce           : integer range 0 to 31 := 0;
                                  
   signal vramwait                : std_logic := '0';
   
   -- ROM timing
   signal wait_sram               : integer range 2 to 8;
   signal wait_0_first            : integer range 2 to 8;
   signal wait_0_second           : integer range 1 to 2;
   signal wait_1_first            : integer range 2 to 8;
   signal wait_1_second           : integer range 1 to 4;
   signal wait_2_first            : integer range 2 to 8;
   signal wait_2_second           : integer range 1 to 8;
            
   signal is_sequential           : std_logic;
   signal wait_cartnext           : integer range 0 to 31;
   
   -- prefetch
   signal prefetch_active         : std_logic := '0';
   signal prefetch_headAddr       : std_logic_vector(27 downto 0);
   signal prefetch_lastAddr       : std_logic_vector(27 downto 0);
   signal prefetch_count          : integer range 0 to 8 := 0;
   signal prefetch_countDown      : integer range 0 to 63 := 0;
   signal prefetch_timing         : integer range 0 to 31 := 0;
   signal prefetch_timingNext     : integer range 0 to 31 := 0;
   signal prefetch_capacity       : integer range 4 to 8 := 4;
   signal prefetch_width          : integer range 2 to 4 := 2;
   signal prefetch_stopDelay      : integer range 0 to 1;
   
   -- savestate
   signal SAVESTATE_EEPROM  : std_logic_vector(31 downto 0);
   signal SAVESTATE_FLASH   : std_logic_vector(16 downto 0);
   
   signal SAVESTATE_EEPROM_BACK : std_logic_vector(31 downto 0);
   signal SAVESTATE_FLASH_BACK  : std_logic_vector(16 downto 0);
   
   type t_ss_wired_or is array(0 to 1) of std_logic_vector(31 downto 0);
   signal save_wired_or        : t_ss_wired_or;   
   signal save_wired_done      : unsigned(0 to 1);
   
   -- synthesis translate_off
   signal next_PF_count        : unsigned(3 downto 0) := (others => '0');
   signal next_PF_countdown    : unsigned(3 downto 0) := (others => '0');
-- synthesis translate_on 
   
begin 

   wait_sram     <= 4 when (cart_waitcnt(1 downto 0) = "00") else
                    3 when (cart_waitcnt(1 downto 0) = "01") else
                    2 when (cart_waitcnt(1 downto 0) = "10") else
                    8;
                 
   wait_0_first  <= 4 when (cart_waitcnt(3 downto 2) = "00") else
                    3 when (cart_waitcnt(3 downto 2) = "01") else
                    2 when (cart_waitcnt(3 downto 2) = "10") else
                    8;

   wait_0_second <= 2 when (cart_waitcnt(4) = '0') else
                    1;

   wait_1_first  <= 4 when (cart_waitcnt(6 downto 5) = "00") else
                    3 when (cart_waitcnt(6 downto 5) = "01") else
                    2 when (cart_waitcnt(6 downto 5) = "10") else
                    8;
                   
   wait_1_second <= 4 when (cart_waitcnt(7) = '0') else
                    1;
   
   wait_2_first  <= 4 when (cart_waitcnt(9 downto 8) = "00") else
                    3 when (cart_waitcnt(9 downto 8) = "01") else
                    2 when (cart_waitcnt(9 downto 8) = "10") else
                    8;
   
   wait_2_second <= 8 when (cart_waitcnt(10) = '0') else
                    1;
        
   is_sequential <= '1' when (mem_bus_seq = '1' and unsigned(mem_bus_Adr(20 downto 1)) /= 0) else '0'; -- special case for first address of bank
   
   wait_cartnext <= wait_sram                         when (                                                        mem_bus_Adr(27 downto 24) = x"E" or mem_bus_Adr(27 downto 24) = x"F") else
                    wait_0_first + wait_0_second + 1  when (mem_bus_acc = ACCESS_32BIT and is_sequential = '0' and (mem_bus_Adr(27 downto 24) = x"8" or mem_bus_Adr(27 downto 24) = x"9")) else
                    wait_0_second + wait_0_second + 1 when (mem_bus_acc = ACCESS_32BIT and is_sequential = '1' and (mem_bus_Adr(27 downto 24) = x"8" or mem_bus_Adr(27 downto 24) = x"9")) else
                    wait_1_first + wait_1_second + 1  when (mem_bus_acc = ACCESS_32BIT and is_sequential = '0' and (mem_bus_Adr(27 downto 24) = x"A" or mem_bus_Adr(27 downto 24) = x"B")) else
                    wait_1_second + wait_1_second + 1 when (mem_bus_acc = ACCESS_32BIT and is_sequential = '1' and (mem_bus_Adr(27 downto 24) = x"A" or mem_bus_Adr(27 downto 24) = x"B")) else
                    wait_2_first + wait_2_second + 1  when (mem_bus_acc = ACCESS_32BIT and is_sequential = '0' and (mem_bus_Adr(27 downto 24) = x"C" or mem_bus_Adr(27 downto 24) = x"D")) else
                    wait_2_second + wait_2_second + 1 when (mem_bus_acc = ACCESS_32BIT and is_sequential = '1' and (mem_bus_Adr(27 downto 24) = x"C" or mem_bus_Adr(27 downto 24) = x"D")) else
                    wait_0_first                      when (                               is_sequential = '0' and (mem_bus_Adr(27 downto 24) = x"8" or mem_bus_Adr(27 downto 24) = x"9")) else
                    wait_0_second                     when (                               is_sequential = '1' and (mem_bus_Adr(27 downto 24) = x"8" or mem_bus_Adr(27 downto 24) = x"9")) else
                    wait_1_first                      when (                               is_sequential = '0' and (mem_bus_Adr(27 downto 24) = x"A" or mem_bus_Adr(27 downto 24) = x"B")) else
                    wait_1_second                     when (                               is_sequential = '1' and (mem_bus_Adr(27 downto 24) = x"A" or mem_bus_Adr(27 downto 24) = x"B")) else
                    wait_2_first                      when (                               is_sequential = '0' and (mem_bus_Adr(27 downto 24) = x"C" or mem_bus_Adr(27 downto 24) = x"D")) else
                    wait_2_second                     when (                               is_sequential = '1' and (mem_bus_Adr(27 downto 24) = x"C" or mem_bus_Adr(27 downto 24) = x"D")) else
                    1;

   prefetch_timing <= wait_0_second + wait_0_second + 1 when (mem_bus_acc = ACCESS_32BIT and (mem_bus_Adr(27 downto 24) = x"8" or mem_bus_Adr(27 downto 24) = x"9")) else
                      wait_1_second + wait_1_second + 1 when (mem_bus_acc = ACCESS_32BIT and (mem_bus_Adr(27 downto 24) = x"A" or mem_bus_Adr(27 downto 24) = x"B")) else
                      wait_2_second + wait_2_second + 1 when (mem_bus_acc = ACCESS_32BIT and (mem_bus_Adr(27 downto 24) = x"C" or mem_bus_Adr(27 downto 24) = x"D")) else
                      wait_0_second                     when (                                mem_bus_Adr(27 downto 24) = x"8" or mem_bus_Adr(27 downto 24) = x"9") else
                      wait_1_second                     when (                                mem_bus_Adr(27 downto 24) = x"A" or mem_bus_Adr(27 downto 24) = x"B") else
                      wait_2_second                     when (                                mem_bus_Adr(27 downto 24) = x"C" or mem_bus_Adr(27 downto 24) = x"D") else
                      1;

   igba_bios : entity work.gba_bios
   port map
   (
      clk       => clk,
      address   => mem_bus_Adr(13 downto 2),
      readEna   => bios_readEna,
      data      => bios_data,
      
      wraddress => bios_wraddr,
      wrdata    => bios_wrdata,
      wren      => bios_wr    
   );
   
   ismallram: entity MEM.SyncRamDualByteEnable
   generic map
   (
      is_simu    => is_simu,
      is_cyclone5=> '1',
      BYTE_WIDTH => 8,
      BYTES      => 4,
      ADDR_WIDTH => 13
   )
   port map
   (
      clk        => clk,
      
      ce_a       => '1',
      addr_a     => smallram_addr,
      datain_a0  => rotate_writedata(7 downto 0),
      datain_a1  => rotate_writedata(15 downto 8),
      datain_a2  => rotate_writedata(23 downto 16),
      datain_a3  => rotate_writedata(31 downto 24),
      dataout_a  => open,
      we_a       => smallram_we,
      be_a       => rotate_BE,
         
      ce_b       => smallram_ce,
      addr_b     => smallram_addr,
      datain_b0  => x"00",
      datain_b1  => x"00",
      datain_b2  => x"00",
      datain_b3  => x"00",
      dataout_b  => smallram_DataOut,
      we_b       => '0',
      be_b       => "0000"
   );   
   
   smallram_addr <= to_integer(unsigned(mem_bus_Adr(14 downto 2)));

   ilargeram: entity MEM.SyncRamDualByteEnable
   generic map
   (
      is_simu    => is_simu,
      is_cyclone5=> '1',
      BYTE_WIDTH => 8,
      BYTES      => 4,
      ADDR_WIDTH => 16
   )
   port map
   (
      clk        => clk,
      
      ce_a       => '1',
      addr_a     => largeram_addr,
      datain_a0  => rotate_writedata(7 downto 0),
      datain_a1  => rotate_writedata(15 downto 8),
      datain_a2  => rotate_writedata(23 downto 16),
      datain_a3  => rotate_writedata(31 downto 24),
      dataout_a  => open,
      we_a       => largeram_we,
      be_a       => rotate_BE,
        
      ce_b       => largeram_ce,
      addr_b     => largeram_addr,
      datain_b0  => x"00",
      datain_b1  => x"00",
      datain_b2  => x"00",
      datain_b3  => x"00",
      dataout_b  => largeram_DataOut,
      we_b       => '0',
      be_b       => "0000"
   );   

   largeram_addr <= to_integer(unsigned(mem_bus_Adr(17 downto 2)));
   
   -- input rotate
   process (all)
   begin
      
      rotate_writedata <= mem_bus_dout; -- default, full dword
      if (mem_bus_acc = ACCESS_8BIT) then
         case(mem_bus_Adr(1 downto 0)) is
            when "00" => rotate_writedata( 7 downto  0) <= mem_bus_dout(7 downto 0);
            when "01" => rotate_writedata(15 downto  8) <= mem_bus_dout(7 downto 0);
            when "10" => rotate_writedata(23 downto 16) <= mem_bus_dout(7 downto 0);
            when "11" => rotate_writedata(31 downto 24) <= mem_bus_dout(7 downto 0);
            when others => null;
         end case;
      elsif (mem_bus_acc = ACCESS_16BIT and mem_bus_Adr(1) = '1') then
         rotate_writedata(31 downto 16) <= mem_bus_dout(15 downto 0);
      end if;
   
      rotate_BE <= "1111";
      case (mem_bus_acc) is
         when ACCESS_8BIT  => 
            case (mem_bus_Adr(1 downto 0)) is
               when "00" => rotate_BE <= "0001";
               when "01" => rotate_BE <= "0010";
               when "10" => rotate_BE <= "0100";
               when "11" => rotate_BE <= "1000";
               when others => null;
            end case;
         when ACCESS_16BIT => 
            if (mem_bus_Adr(1) = '1') then
               rotate_BE <= "1100";
            else
               rotate_BE <= "0011";
            end if;
         when ACCESS_32BIT => rotate_BE <= "1111";
         when others => null;
      end case;
      
   end process;
   
   -- request
   gb_bus_out.rst   <= register_reset;

   process (all)
      variable palette_we : std_logic_vector(3 downto 0);
      variable VRAM_be    : std_logic_vector(3 downto 0);
   begin
   
      bios_readEna     <= '0';
   
      largeram_ce      <= '0';
      largeram_we      <= '0';

      smallram_ce      <= '0';
      smallram_we      <= '0';
   
      gb_bus_out.adr  <= 16x"0000" & adr_save(11 downto 2) & "00";
      gb_bus_out.acc  <= acc_save;
      gb_bus_out.rnw  <= rnw_save;
      gb_bus_out.Din  <= rotate_writedata_save;
      gb_bus_out.BEna <= rotate_BE_save;
      gb_bus_out.ena  <= gb_bus_out_ena;
      
      PALETTE_BG_addr     <= to_integer(unsigned(mem_bus_Adr(8 downto 2)));
      PALETTE_OAM_addr    <= to_integer(unsigned(mem_bus_Adr(8 downto 2)));
      PALETTE_BG_datain   <= rotate_writedata;
      PALETTE_OAM_datain  <= rotate_writedata;
      if (mem_bus_acc = ACCESS_8BIT) then
         PALETTE_BG_datain(15 downto 8)  <= rotate_writedata(7 downto 0);
         PALETTE_OAM_datain(15 downto 8) <= rotate_writedata(7 downto 0);
      end if;
      PALETTE_OAM_we <= (others => '0');
      PALETTE_OAM_re <= (others => '0');
      PALETTE_BG_we <= (others => '0');
      PALETTE_BG_re <= (others => '0');
      
      palette_we := "0000";
      if (mem_bus_acc = ACCESS_8BIT) then
         case(mem_bus_Adr(1 downto 0)) is
            when "00" => palette_we(0) := '1'; palette_we(1) := '1';
            when "01" => palette_we(1) := '1'; palette_we(0) := '1';
            when "10" => palette_we(2) := '1'; palette_we(3) := '1';
            when "11" => palette_we(3) := '1'; palette_we(2) := '1';
            when others => null;
         end case;
      elsif (mem_bus_acc = ACCESS_16BIT) then
         if (mem_bus_Adr(1) = '1') then
            palette_we(2) := '1';
            palette_we(3) := '1';
         else                                                               
            palette_we(0) := '1';
            palette_we(1) := '1';
         end if;
      else
         palette_we := (others => '1');
      end if;
      
      VRAM_Hi_addr   <= to_integer(unsigned(mem_bus_Adr(14 downto 2)));
      VRAM_Lo_addr   <= to_integer(unsigned(mem_bus_Adr(15 downto 2)));
      VRAM_Hi_datain <= rotate_writedata;
      VRAM_Lo_datain <= rotate_writedata;
      
      if (mem_bus_acc = ACCESS_8BIT) then
         case (to_integer(unsigned(mem_bus_Adr(1 downto 0)))) is
            when 0 => VRAM_Hi_datain(15 downto  8) <= rotate_writedata( 7 downto  0); VRAM_Lo_datain(15 downto  8) <= rotate_writedata( 7 downto  0);
            when 1 => VRAM_Hi_datain( 7 downto  0) <= rotate_writedata(15 downto  8); VRAM_Lo_datain( 7 downto  0) <= rotate_writedata(15 downto  8);
            when 2 => VRAM_Hi_datain(31 downto 24) <= rotate_writedata(23 downto 16); VRAM_Lo_datain(31 downto 24) <= rotate_writedata(23 downto 16);
            when 3 => VRAM_Hi_datain(23 downto 16) <= rotate_writedata(31 downto 24); VRAM_Lo_datain(23 downto 16) <= rotate_writedata(31 downto 24);
            when others => null;
         end case;
      end if;

      VRAM_be := (others => '0');
      if (mem_bus_acc = ACCESS_8BIT) then
         -- maybe also just check like 16/32 bit?
         if ((bitmapdrawmode = '0' and unsigned(mem_bus_Adr(16 downto 0)) <= 16#FFFF#) or (bitmapdrawmode = '1' and unsigned(mem_bus_Adr(16 downto 0)) <= 16#13FFF#)) then
            case(mem_bus_Adr(1 downto 0)) is
               when "00" => VRAM_be(0) := '1'; VRAM_be(1) := '1';
               when "01" => VRAM_be(1) := '1'; VRAM_be(0) := '1';
               when "10" => VRAM_be(2) := '1'; VRAM_be(3) := '1';
               when "11" => VRAM_be(3) := '1'; VRAM_be(2) := '1';
               when others => null;
            end case;
         end if;
      elsif (mem_bus_acc = ACCESS_16BIT) then
         if ((bitmapdrawmode = '0' or unsigned(mem_bus_Adr(16 downto 14)) /= "110")) then
            if (mem_bus_Adr(1) = '1') then
               VRAM_be(2) := '1';
               VRAM_be(3) := '1';
            else                                                               
               VRAM_be(0) := '1';
               VRAM_be(1) := '1';
            end if;
         end if;
      else
         if ((bitmapdrawmode = '0' or unsigned(mem_bus_Adr(16 downto 14)) /= "110")) then
            VRAM_be := (others => '1');
         end if;
      end if;
      VRAM_Hi_be <= VRAM_be;
      VRAM_Lo_be <= VRAM_be;
      VRAM_Hi_ce <= '0';
      VRAM_Lo_ce <= '0';      
      VRAM_Hi_we <= '0';
      VRAM_Lo_we <= '0';
      
      OAMRAM_PROC_addr   <= to_integer(unsigned(mem_bus_Adr(9 downto 2)));
      OAMRAM_PROC_datain <= rotate_writedata;
      OAMRAM_PROC_we     <= (others => '0');

      cart_ena       <= '0';
      cart_32        <= '0';
      cart_rnw       <= mem_bus_rnw;
      cart_writedata <= rotate_writedata(7 downto 0);
      cart_addr      <= mem_bus_Adr(27 downto 0);
      if (mem_bus_Adr(27 downto 24) = x"E" or mem_bus_Adr(27 downto 24) = x"F") then
         cart_addr(1 downto 0) <= mem_bus_Adr(1 downto 0) or bus_lowbits;
      elsif (mem_bus_acc = ACCESS_32BIT) then
         cart_addr(1) <= '0';
         cart_32      <= '1';
      end if;

      if (mem_bus_ena = '1' and mem_bus_Adr(31 downto 28) = x"0") then
      
         case (mem_bus_Adr(27 downto 24)) is
             
            when x"0" =>
               if (PC_in_BIOS = '1') then
                  bios_readEna <= mem_bus_rnw;
               end if;
             
            when x"2" => 
               largeram_ce <= '1'; 
               largeram_we <= not mem_bus_rnw; 
             
            when x"3" => 
               smallram_ce <= '1';
               smallram_we <= not mem_bus_rnw;
               
            when x"5" =>
               if (mem_bus_rnw = '1') then
                  if (mem_bus_Adr(9) = '1') then
                     PALETTE_OAM_re <= "1111";
                  else
                     PALETTE_BG_re <= "1111";
                  end if;
               else
                  if (mem_bus_Adr(9) = '1') then
                     PALETTE_OAM_we <= palette_we;
                  else
                     PALETTE_BG_we <= palette_we;
                  end if;
               end if;
               
            when x"6" =>
               VRAM_Hi_ce <= '1';
               VRAM_Lo_ce <= '1';
            
               if (mem_bus_rnw = '0') then
                  if (mem_bus_Adr(16) = '1') then
                     VRAM_Hi_we <= '1';
                  else
                     VRAM_Lo_we <= '1';
                  end if;
               end if;
               
            when x"7" =>
               if (mem_bus_rnw = '0') then
                  if (mem_bus_acc = ACCESS_8BIT) then
                     OAMRAM_PROC_we <= (others => '0'); -- dont write bytes
                  elsif (mem_bus_acc = ACCESS_16BIT) then
                     if (mem_bus_Adr(1) = '1') then
                        OAMRAM_PROC_we(2) <= '1';
                        OAMRAM_PROC_we(3) <= '1';
                     else                                                               
                        OAMRAM_PROC_we(0) <= '1';
                        OAMRAM_PROC_we(1) <= '1';
                     end if;
                  else
                     OAMRAM_PROC_we <= (others => '1');
                  end if;
               end if;
               
             when x"8" | x"9" | x"A" | x"B" | x"C" | x"D" | x"E" | x"F" =>
                cart_ena <= '1';
               
            when others => null;
         
         end case;
         
      end if;

   end process;
   
   -- response
   mem_bus_done_out <= mem_bus_done or (cart_done and cart_nowait);
   
   cart_readback_muxed <= cart_readback when (mem_bus_done = '1') else
                          cart_readdata;
   
   process (all)
   begin

      mem_bus_unread <= '0';

      case (readState) is
      
         when READSTATE_BIOS       => mem_bus_din_unrot <= bios_data;
         when READSTATE_EWRAM      => mem_bus_din_unrot <= largeram_DataOut;
         when READSTATE_IRAM       => mem_bus_din_unrot <= smallram_DataOut;
         when READSTATE_GBBUS      => 
            mem_bus_din_unrot <= wired_out;
            if (wired_done = '0') then
               if (dma_on = '1') then
                  mem_bus_din_unrot <= lastread_dma;
               else
                  mem_bus_din_unrot <= lastread;
               end if;
            end if;
         when READSTATE_PALBG      => mem_bus_din_unrot <= PALETTE_BG_dataout;
         when READSTATE_PALOAM     => mem_bus_din_unrot <= PALETTE_OAM_dataout;
         when READSTATE_VRAMHI     => mem_bus_din_unrot <= VRAM_Hi_dataout;
         when READSTATE_VRAMLO     => mem_bus_din_unrot <= VRAM_Lo_dataout; 
         when READSTATE_OAM        => mem_bus_din_unrot <= OAMRAM_PROC_dataout;
         when READSTATE_ROM        => mem_bus_din_unrot <= cart_readback_muxed;
         when READSTATE_UNREADABLE => 
            mem_bus_unread <= '1';
            if (dma_on = '1') then
               mem_bus_din_unrot <= lastread_dma;
            else
               mem_bus_din_unrot <= lastread;
            end if;
      
      end case;
      
      mem_bus_din <= (others => '0');
      
      if (acc_save = ACCESS_8BIT) then
         case (return_rotate) is
            when "00" => mem_bus_din <= x"000000" & mem_bus_din_unrot(7 downto 0);
            when "01" => mem_bus_din <= x"000000" & mem_bus_din_unrot(15 downto 8);
            when "10" => mem_bus_din <= x"000000" & mem_bus_din_unrot(23 downto 16);
            when "11" => mem_bus_din <= x"000000" & mem_bus_din_unrot(31 downto 24);
            when others => null;
         end case;
      elsif (acc_save = ACCESS_16BIT) then
         case (return_rotate) is
            when "00" => mem_bus_din <= x"0000" & mem_bus_din_unrot(15 downto 0);
            when "01" => mem_bus_din <= mem_bus_din_unrot(7 downto 0) & x"0000" & mem_bus_din_unrot(15 downto 8);
            when "10" => mem_bus_din <= x"0000" & mem_bus_din_unrot(31 downto 16);
            when "11" => mem_bus_din <= mem_bus_din_unrot(23 downto 16) & x"0000" & mem_bus_din_unrot(31 downto 24);
            when others => null;
         end case;
      else
         case (return_rotate) is
            when "00" => mem_bus_din <= mem_bus_din_unrot;
            when "01" => mem_bus_din <= mem_bus_din_unrot(7 downto 0) & mem_bus_din_unrot(31 downto 8);
            when "10" => mem_bus_din <= mem_bus_din_unrot(15 downto 0) & mem_bus_din_unrot(31 downto 16);
            when "11" => mem_bus_din <= mem_bus_din_unrot(23 downto 0) & mem_bus_din_unrot(31 downto 24);
            when others => null;
         end case;
      end if;
      
      if (ce_latched_done = '1' and saving_savestate = '0') then
         mem_bus_din <= ce_latched_data;
      end if;
      
   end process;
   
   
   prefetch_stopDelay <= 1 when (prefetch_active = '1' and (prefetch_countDown = 1 or (prefetch_width = 4 and prefetch_countDown = ((prefetch_timingNext / 2) + 1)))) else 0; 
   
   
   process (clk)
      variable prefetch_hit       : std_logic;
      variable prefetch_countNext : integer range 0 to 8;
   begin
      if rising_edge(clk) then
      
         prefetch_countNext := prefetch_count;
      
         if (reset = '1') then  
            state               <= IDLE;
            prefetch_active     <= '0';
            ce_latched_done     <= '0';
            ce_block_prefetch   <= '0';
            prefetch_countNext  := 0;
            prefetch_countDown  <= 0;
         end if;
         
         -- synthesis translate_off
         if (prefetch_active = '1') then
            next_PF_count        <= to_unsigned(prefetch_count, 4);
            next_PF_countdown    <= to_unsigned(prefetch_countDown, 4);
         else
            next_PF_count        <= (others => '0');
            next_PF_countdown    <= (others => '0');
         end if;
         debug_PF_count       <= next_PF_count;    
         debug_PF_countdown   <= next_PF_countdown;
         -- synthesis translate_on 

         -- default pulse regs
         mem_bus_done    <= '0';
         gb_bus_out_ena  <= '0';
         
         vram_cycle      <= '0';

         -- ce stopped handling
         if ((ce = '1' and mem_bus_done_out = '1') or reset = '1' or loading_savestate = '1') then
            ce_latched_done   <= '0';
            ce_wait           <= (others => '0');
            ce_done_hold      <= '0';
            ce_block_prefetch <= '0';
            if (loading_savestate = '1') then
               state          <= IDLE;
            end if;
         elsif (ce = '0' and saving_savestate = '0') then
            ce_wait <= ce_wait + 1;
            if (ce_done_hold = '1') then
               mem_bus_done <= '1';
            end if;
            if (mem_bus_done_out = '1') then
               ce_latched_done <= '1';
               if (ce_latched_done = '0') then
                  ce_latched_data   <= mem_bus_din;
                  wait_timer_ce     <= to_integer(ce_wait);
                  if (ce_wait > 0) then
                     state             <= ALLWAIT_CE;
                     ce_block_prefetch <= '1';
                     ce_done_hold      <= '0';
                  else
                     ce_done_hold      <= '1'; 
                  end if;
               end if;
            end if;
         end if;
         
         if (ce_block_prefetch = '1' and saving_savestate = '0') then
            state <= ALLWAIT_CE;
         end if;
         
         -- prefetch
         if (ce = '1' and prefetch_active = '1') then
            if (prefetch_countdown > 0) then
               prefetch_countdown <= prefetch_countdown - 1;
            end if;
            if (prefetch_countdown < 2) then
               if (cart_waitcnt(14) = '1' and prefetch_count < prefetch_capacity) then
                  prefetch_countNext := prefetch_count + 1;
                  prefetch_lastAddr  <= std_logic_vector(unsigned(prefetch_lastAddr) + prefetch_width);
                  prefetch_countdown <= prefetch_timingNext;
               end if;
            end if;
         end if;

         case state is
         
            when IDLE =>
            
               wait_timer  <= 0;
            
               if (mem_bus_ena = '1') then
               
                  adr_save  <= mem_bus_Adr(27 downto 0);
                  acc_save  <= mem_bus_acc;
                  rnw_save  <= mem_bus_rnw;
                  
                  rotate_writedata_save <= rotate_writedata;
                  rotate_BE_save        <= rotate_BE;
               
                  cart_nowait <= '0';
               
                  if (mem_bus_rnw = '1') then  -- read
                  
                     return_rotate <= mem_bus_Adr(1 downto 0);
                     
                     if (mem_bus_Adr(31 downto 28) /= x"0") then

                        mem_bus_done   <= '1';
                        readState      <= READSTATE_UNREADABLE;
                        
                     else
                     
                        case (mem_bus_Adr(27 downto 24)) is
                        
                           when x"0" => 
                              if (PC_in_BIOS = '0') then
                                 if (unsigned(mem_bus_Adr) < 16#4000#) then
                                    --rotate_data <= x"E3A02004"; -- only applies for one situation! -> after irq
                                    --rotate_data <= x"E55EC002"; -- only applies for one situation! -> after swi
                                    --rotate_data <= x"E129F000"; -- only applies for one situation! -> after startup
                                    --rotate_data <= x"E25EF004"; -- only applies for one situation! -> while irq
                                    readState    <= READSTATE_BIOS;
                                    mem_bus_done <= '1';
                                 else
                                    mem_bus_done <= '1';
                                    readState    <= READSTATE_UNREADABLE;
                                 end if;
                              else
                                 readState    <= READSTATE_BIOS;
                                 mem_bus_done <= '1';
                              end if;
                           
                           when x"2" =>
                              readState    <= READSTATE_EWRAM;
                              if (sleep_savestate = '1') then
                                 mem_bus_done <= '1';
                              else
                                 state        <= ALLWAIT;
                                 if (mem_bus_acc = ACCESS_32BIT) then
                                    wait_timer <= 4;
                                 else
                                    wait_timer <= 1;
                                 end if;  
                              end if;
                              
                           when x"3" =>
                              readState    <= READSTATE_IRAM;
                              mem_bus_done <= '1';
                           
                           when x"4" =>
                              mem_bus_done   <= '1';
                              if (unsigned(mem_bus_Adr) < x"4000400") then
                                 readState      <= READSTATE_GBBUS;
                                 gb_bus_out_ena <= '1';
                              else
                                 readState      <= READSTATE_UNREADABLE;
                              end if;
                              
                           when x"5" =>
                              if (mem_bus_acc = ACCESS_32BIT) then
                                 state      <= ALLWAIT;
                                 wait_timer <= 0;
                              else
                                 mem_bus_done <= '1';
                              end if; 
                              if (mem_bus_Adr(9) = '1') then
                                 readState <= READSTATE_PALOAM;
                              else
                                 readState <= READSTATE_PALBG;
                              end if;
                              
                           when x"6" =>
                              if (mem_bus_acc = ACCESS_32BIT and sleep_savestate = '0') then
                                 state      <= ALLWAIT;
                                 wait_timer <= 0;
                              else
                                 mem_bus_done <= '1';
                              end if; 
                              if (mem_bus_Adr(16) = '1') then
                                 readState <= READSTATE_VRAMHI;
                              else
                                 readState <= READSTATE_VRAMLO;
                              end if;
                           
                           when x"7" =>
                              readState      <= READSTATE_OAM;
                              mem_bus_done   <= '1';
                           
                           when x"8" | x"9" | x"A" | x"B" | x"C" | x"D" | x"E" | x"F" =>
                              readState  <= READSTATE_ROM;
                              wait_timer <= wait_cartnext - 1 + prefetch_stopDelay; 
                              
                              if (dma_on = '1') then
                                 prefetch_active <= '0';
                              end if;
                              state         <= WAIT_CART; 
                              
                              prefetch_hit := '0';
                              if (prefetch_active = '1' and mem_bus_code = '1') then
                              	if (prefetch_count > 0 and mem_bus_Adr(27 downto 0) = prefetch_HeadAddr) then
                                    prefetch_hit       := '1';
                                    state              <= IDLE;
                                    cart_nowait        <= '1';
                                    prefetch_countNext := prefetch_countNext - 1;
                                    if (mem_bus_acc = ACCESS_32BIT) then
                                       prefetch_headAddr <= std_logic_vector(unsigned(prefetch_headAddr) + 4);
                                    else
                                       prefetch_headAddr <= std_logic_vector(unsigned(prefetch_headAddr) + 2);
                                    end if;
                                    if (prefetch_countdown < 2 and cart_waitcnt(14) = '1' and prefetch_count = prefetch_capacity) then -- special case of fetch when buffer is full
                                       prefetch_countNext := prefetch_count;
                                       prefetch_lastAddr  <= std_logic_vector(unsigned(prefetch_lastAddr) + prefetch_width);
                                       prefetch_countdown <= prefetch_timingNext;
                                    end if;
                                 elsif (mem_bus_Adr(27 downto 0) = prefetch_lastAddr) then
                                    prefetch_hit := '1';
                                    if (prefetch_countdown <= 1) then
                                       state        <= IDLE;
                                       cart_nowait  <= '1';
                                    else
                                       wait_timer         <= prefetch_countdown - 2;
                                       prefetch_countdown <= prefetch_countdown + prefetch_timingNext - 1;
                                    end if;
                                    if (mem_bus_acc = ACCESS_32BIT) then
                                       prefetch_headAddr  <= std_logic_vector(unsigned(mem_bus_Adr(27 downto 0)) + 4);
                                       prefetch_lastAddr  <= std_logic_vector(unsigned(mem_bus_Adr(27 downto 0)) + 4);
                                    else
                                       prefetch_headAddr  <= std_logic_vector(unsigned(mem_bus_Adr(27 downto 0)) + 2);
                                       prefetch_lastAddr  <= std_logic_vector(unsigned(mem_bus_Adr(27 downto 0)) + 2);
                                    end if;
                                    prefetch_countNext := 0;
                                 end if;
                              end if;
                                    
                              if (prefetch_hit = '0') then
                              
                                 prefetch_active <= '0';
                              
                                 if (mem_bus_code = '1' and cart_waitcnt(14) = '1' and dma_on = '0') then
                                    prefetch_active     <= '1';
                                    prefetch_countNext  := 0;
                                    prefetch_countdown  <= wait_cartnext + prefetch_timing + 1 + prefetch_stopDelay;
                                    prefetch_timingNext <= prefetch_timing + 1;
                                    if (mem_bus_acc = ACCESS_32BIT) then
                                       prefetch_width     <= 4;
                                       prefetch_capacity  <= 4;
                                       prefetch_headAddr  <= std_logic_vector(unsigned(mem_bus_Adr(27 downto 0)) + 4);
                                       prefetch_lastAddr  <= std_logic_vector(unsigned(mem_bus_Adr(27 downto 0)) + 4);
                                    else
                                       prefetch_width     <= 2;
                                       prefetch_capacity  <= 8;
                                       prefetch_headAddr  <= std_logic_vector(unsigned(mem_bus_Adr(27 downto 0)) + 2);
                                       prefetch_lastAddr  <= std_logic_vector(unsigned(mem_bus_Adr(27 downto 0)) + 2);
                                    end if;
                                 end if;
                              end if;

                              if (mem_bus_acc = ACCESS_32BIT) then
                                 adr_save(1) <= '0';
                              end if;
                           
                           when others =>
                              mem_bus_done   <= '1';
                              readState      <= READSTATE_UNREADABLE;

                        end case;
                        
                     end if;
                     
                  else -- write
                  
                     if (mem_bus_Adr(31 downto 28) /= x"0") then

                        mem_bus_done <= '1';
                        
                     else
                     
                        case (mem_bus_Adr(27 downto 24)) is
                           when x"2" => 
                              if (sleep_savestate = '1') then
                                 mem_bus_done <= '1';
                              else
                                 state <= ALLWAIT;
                                 if (mem_bus_acc = ACCESS_32BIT) then
                                    wait_timer <= 4;
                                 else
                                    wait_timer <= 1;
                                 end if; 
                              end if;
                               
                           when x"3" =>
                              mem_bus_done <= '1'; 
                           
                           when x"4" => 
                              mem_bus_done   <= '1';
                              gb_bus_out_ena <= '1';
                           
                           when x"5" => 
                              if (mem_bus_acc = ACCESS_32BIT) then
                                 state      <= ALLWAIT;
                                 wait_timer <= 0;
                              else
                                 mem_bus_done <= '1';
                              end if; 
                              
                           when x"6" => 
                              if (mem_bus_acc = ACCESS_32BIT and sleep_savestate = '0') then
                                 state      <= ALLWAIT;
                                 wait_timer <= 0;
                              else
                                 mem_bus_done <= '1';
                              end if;   
                              --mem_bus_done <= not vram_blocked or mem_bus_Adr(16); vramwait <= vram_blocked;
                              
                           when x"7" => 
                              mem_bus_done <= '1';
                           
                           when x"8" | x"9" | x"A" | x"B" | x"C" | x"D" | x"E" | x"F" =>
                              state           <= WAIT_CART; 
                              prefetch_active <= '0';
                              wait_timer      <= wait_cartnext - 1 + prefetch_stopDelay; 
                              
                           when others => mem_bus_done <= '1'; --report "writing here not implemented!" severity failure;
                        end case;
                     
                     end if;
               
                  end if;
               
               end if;

            -- wait
             when ALLWAIT =>
               if (wait_timer > 0) then
                  wait_timer <= wait_timer - 1;
               else
                  mem_bus_done <= '1'; 
                  state <= IDLE;
               end if;             
               
            when ALLWAIT_CE =>
               if (loading_savestate = '1') then
                  state <= IDLE;
               end if;
               if (saving_savestate = '1') then
                  state <= IDLE;
               end if;
               if (ce = '1') then
                  if (wait_timer_ce < 2) then
                     ce_block_prefetch <= '0';
                  end if;
                  if (wait_timer_ce > 0) then
                     wait_timer_ce <= wait_timer_ce - 1;
                  else
                     mem_bus_done <= '1'; 
                     state <= IDLE;
                  end if;
               end if;
               
            -- reading
            when WAIT_CART =>
               if (wait_timer > 0) then
                  wait_timer <= wait_timer - 1;
               end if;
               if (wait_timer = 0 and adr_save(27 downto 24) < x"E") then
                  cart_nowait <= '1';
                  state       <= IDLE;
               end if;
               
               if (cart_done = '1') then
                  if (adr_save(27 downto 24) = x"E" or adr_save(27 downto 24) = x"F") then
                     cart_readback <= cart_readdata(7 downto 0) & cart_readdata(7 downto 0) & cart_readdata(7 downto 0) & cart_readdata(7 downto 0); 
                     if (wait_timer > 0) then
                        state      <= ALLWAIT;
                     else
                        mem_bus_done  <= '1'; 
                        state         <= IDLE;
                     end if;
                  else
                     cart_readback <= cart_readdata;
                     
                     if (wait_timer > 0) then
                        state      <= ALLWAIT;
                     else
                        mem_bus_done    <= '1'; 
                        state           <= IDLE;
                     end if;
                  end if;
               end if;

         end case;
         
         prefetch_count <= prefetch_countNext;
      
      end if;
   end process;
   
   
   
--##############################################################
--############################### export
--##############################################################
   
   -- synthesis translate_off
   goutput : if 1 = 1 generate
      signal out_count        : unsigned(31 downto 0) := (others => '0');
      
      function to_lower(c: character) return character is
         variable l: character;
      begin
         case c is
            when 'A' => l := 'a';
            when 'B' => l := 'b';
            when 'C' => l := 'c';
            when 'D' => l := 'd';
            when 'E' => l := 'e';
            when 'F' => l := 'f';
            when 'G' => l := 'g';
            when 'H' => l := 'h';
            when 'I' => l := 'i';
            when 'J' => l := 'j';
            when 'K' => l := 'k';
            when 'L' => l := 'l';
            when 'M' => l := 'm';
            when 'N' => l := 'n';
            when 'O' => l := 'o';
            when 'P' => l := 'p';
            when 'Q' => l := 'q';
            when 'R' => l := 'r';
            when 'S' => l := 's';
            when 'T' => l := 't';
            when 'U' => l := 'u';
            when 'V' => l := 'v';
            when 'W' => l := 'w';
            when 'X' => l := 'x';
            when 'Y' => l := 'y';
            when 'Z' => l := 'z';
            when others => l := c;
         end case;
         return l;
      end to_lower;
      
      function to_lower(s: string) return string is
         variable lowercase: string (s'range);
         begin
         for i in s'range loop
            lowercase(i):= to_lower(s(i));
         end loop;
         return lowercase;
      end to_lower;
      
   begin
   
      process
         file outfile          : text;
         variable f_status     : FILE_OPEN_STATUS;
         variable line_out     : line;
         variable stringbuffer : string(1 to 31);
      begin
   
         file_open(f_status, outfile, "R:\\mem_gba_sim.txt", write_mode);
         file_close(outfile);
         file_open(f_status, outfile, "R:\\mem_gba_sim.txt", append_mode);
         
         while (true) loop
         
            if (reset = '1') then
               file_close(outfile);
               file_open(f_status, outfile, "R:\\mem_gba_sim.txt", write_mode);
               file_close(outfile);
               file_open(f_status, outfile, "R:\\mem_gba_sim.txt", append_mode);
               out_count <= (others => '0');
            end if;
            
            wait until rising_edge(clk);

            if (mem_bus_ena = '1' and mem_bus_rnw = '0') then
               write(line_out, string'("WRITE: "));
               
               if (mem_bus_acc = "00") then write(line_out, string'("8B "));
               elsif (mem_bus_acc = "01") then write(line_out, string'("16B "));
               elsif (mem_bus_acc = "10") then write(line_out, string'("32B "));
               end if;
               
               write(line_out, string'("A "));
               write(line_out, to_lower(to_hstring(unsigned(mem_bus_adr))) & " ");
            
               write(line_out, string'("D "));
               if (mem_bus_acc = "00") then 
                  write(line_out, string'("000000"));
                  write(line_out, to_lower(to_hstring(unsigned(mem_bus_dout(7 downto 0)))));
               elsif (mem_bus_acc = "01") then 
                  write(line_out, string'("0000"));
                  write(line_out, to_lower(to_hstring(unsigned(mem_bus_dout(15 downto 0)))));
               elsif (mem_bus_acc = "10") then 
                  write(line_out, to_lower(to_hstring(unsigned(mem_bus_dout))));
               end if;
               
               
               writeline(outfile, line_out);
               out_count <= out_count + 1;
            end if;
            
            --if (mem_bus_done = '1' and rnw_save = '1') then
            --   write(line_out, string'("READ: "));
            --   
            --   if (acc_save = "00") then write(line_out, string'("8B "));
            --   elsif (acc_save = "01") then write(line_out, string'("16B "));
            --   elsif (acc_save = "10") then write(line_out, string'("32B "));
            --   end if;
            --   
            --   write(line_out, string'("A "));
            --   write(line_out, to_lower(to_hstring(unsigned(adr_save))) & " ");
            --
            --   write(line_out, string'("D "));
            --   if (acc_save = "00") then 
            --      write(line_out, string'("000000"));
            --      write(line_out, to_lower(to_hstring(unsigned(mem_bus_din(7 downto 0)))));
            --   elsif (acc_save = "01") then 
            --      write(line_out, string'("0000"));
            --      write(line_out, to_lower(to_hstring(unsigned(mem_bus_din(15 downto 0)))));
            --   elsif (acc_save = "10") then 
            --      write(line_out, to_lower(to_hstring(unsigned(mem_bus_din))));
            --   end if;
            --   
            --   
            --   writeline(outfile, line_out);
            --   out_count <= out_count + 1;
            --end if;
            
         end loop;
         
      end process;
   
   end generate goutput;

   -- synthesis translate_on 
   

end architecture;





