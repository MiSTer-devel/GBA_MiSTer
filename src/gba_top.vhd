library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

use work.pProc_bus_gba.all;

entity gba_top is
   generic
   (
      Softmap_GBA_Gamerom_ADDR : integer := 13631488; -- count: 8388608  -- 32 Mbyte Data for GameRom
      Softmap_GBA_WRam_ADDR    : integer := 55574528; -- count:   65536  -- 256 Kbyte Data for GBA WRam Large
      Softmap_GBA_FLASH_ADDR   : integer := 56623104; -- count:  131072  -- 128/512 Kbyte Data for GBA Flash
      Softmap_GBA_EEPROM_ADDR  : integer := 57671680; -- count:    8192  -- 8/32 Kbyte Data for GBA EEProm
      is_simu                  : std_logic := '0'
   );
   port 
   (
      clk100             : in     std_logic;  
      -- settings                 
      GBA_on             : in     std_logic;  -- switching from off to on = reset
      GBA_lockspeed      : in     std_logic;  -- 1 = 100% speed, 0 = max speed
      GBA_flash_1m       : in     std_logic;  -- 1 when string "FLASH1M_V" is anywhere in gamepak
      CyclePrecalc       : in     std_logic_vector(15 downto 0); -- 100 seems to be ok to keep fullspeed for all games
      MaxPakAddr         : in     std_logic_vector(24 downto 0); -- max byte address that will contain data, required for buggy games that read behind their own memory, e.g. zelda minish cap
      CyclesMissing      : buffer std_logic_vector(31 downto 0); -- debug only for speed measurement, keep open
      -- sdram interface
      sdram_read_ena     : out    std_logic;                     -- triggered once for read request 
      sdram_read_done    : in     std_logic := '0';              -- must be triggered once when sdram_read_data is valid after last read
      sdram_read_addr    : out    std_logic_vector(24 downto 0); -- all addresses are DWORD addresses!
      sdram_read_data    : in     std_logic_vector(31 downto 0); -- data from last request, valid when done = 1
      sdram_second_dword : in     std_logic_vector(31 downto 0); -- second dword to be read for buffering/prefetch. Must be valid 1 cycle after done = 1
      -- other Memories           
      bus_out_Din        : out    std_logic_vector(31 downto 0); -- data read from WRam Large, SRAM/Flash/EEPROM
      bus_out_Dout       : in     std_logic_vector(31 downto 0); -- data written to WRam Large, SRAM/Flash/EEPROM
      bus_out_Adr        : out    std_logic_vector(25 downto 0); -- all addresses are DWORD addresses!
      bus_out_rnw        : out    std_logic;                     -- read = 1, write = 0
      bus_out_ena        : out    std_logic;                     -- one cycle high for each action
      bus_out_done       : in     std_logic;                     -- should be one cycle high when write is done or read value is valid
      -- Write to BIOS
      bios_wraddr        : in     std_logic_vector(11 downto 0) := (others => '0');
      bios_wrdata        : in     std_logic_vector(31 downto 0) := (others => '0');
      bios_wr            : in     std_logic := '0';
      -- Bus for MiTM
      cpu_addr           : out    std_logic_vector(31 downto 0);
      cpu_din            : in     std_logic_vector(31 downto 0); -- cpu_din => cpu_frombus if no MiTM used.
      cpu_frombus        : out    std_logic_vector(31 downto 0);
      -- save memory used
      save_eeprom        : out    std_logic;
      save_sram          : out    std_logic;
      save_flash         : out    std_logic;
      -- Keys - all active high   
      KeyA               : in     std_logic; 
      KeyB               : in     std_logic;
      KeySelect          : in     std_logic;
      KeyStart           : in     std_logic;
      KeyRight           : in     std_logic;
      KeyLeft            : in     std_logic;
      KeyUp              : in     std_logic;
      KeyDown            : in     std_logic;
      KeyR               : in     std_logic;
      KeyL               : in     std_logic;
      -- debug interface          
      GBA_BusAddr        : in     std_logic_vector(27 downto 0);
      GBA_BusRnW         : in     std_logic;
      GBA_BusACC         : in     std_logic_vector(1 downto 0);
      GBA_BusWriteData   : in     std_logic_vector(31 downto 0);
      GBA_BusReadData    : out    std_logic_vector(31 downto 0);
      GBA_Bus_written    : in     std_logic;
      -- display data
      pixel_out_addr     : out   integer range 0 to 38399;       -- address for framebuffer 
      pixel_out_data     : out   std_logic_vector(14 downto 0);  -- RGB data for framebuffer 
      pixel_out_we       : out   std_logic;                      -- new pixel for framebuffer 
      -- sound                            
      sound_out_left     : out   std_logic_vector(15 downto 0) := (others => '0');
      sound_out_right    : out   std_logic_vector(15 downto 0) := (others => '0')
   );
end entity;

architecture arch of gba_top is

   constant SPEEDDIV : integer := 6; 

   -- debug
   signal debug_bus_active : std_logic := '0';
   
   signal debug_bus_Adr        : std_logic_vector(27 downto 0);
   signal debug_bus_rnw        : std_logic;
   signal debug_bus_ena        : std_logic;
   signal debug_bus_acc        : std_logic_vector(1 downto 0);
   signal debug_bus_dout       : std_logic_vector(31 downto 0);
   
   -- wiring  
   signal cpu_bus_Adr          : std_logic_vector(31 downto 0);
   signal cpu_bus_rnw          : std_logic;
   signal cpu_bus_ena          : std_logic;
   signal cpu_bus_acc          : std_logic_vector(1 downto 0);
   signal cpu_bus_dout         : std_logic_vector(31 downto 0);
   signal cpu_bus_din          : std_logic_vector(31 downto 0);
   signal cpu_bus_done         : std_logic;
   
   signal dma_bus_Adr          : std_logic_vector(27 downto 0);
   signal dma_bus_rnw          : std_logic;
   signal dma_bus_ena          : std_logic;
   signal dma_bus_acc          : std_logic_vector(1 downto 0);
   signal dma_bus_dout         : std_logic_vector(31 downto 0);
   signal dma_bus_din          : std_logic_vector(31 downto 0);
   signal dma_bus_done         : std_logic;
   
   signal mem_bus_Adr          : std_logic_vector(31 downto 0);
   signal mem_bus_rnw          : std_logic;
   signal mem_bus_ena          : std_logic;
   signal mem_bus_acc          : std_logic_vector(1 downto 0);
   signal mem_bus_dout         : std_logic_vector(31 downto 0);
   signal mem_bus_din          : std_logic_vector(31 downto 0);
   signal mem_bus_done         : std_logic;
   
   signal bus_lowbits          : std_logic_vector(1 downto 0); -- only required for sram access
                               
   signal VRAM_Lo_addr         : integer range 0 to 16383;
   signal VRAM_Lo_datain       : std_logic_vector(31 downto 0);
   signal VRAM_Lo_dataout      : std_logic_vector(31 downto 0);
   signal VRAM_Lo_we           : std_logic;
   signal VRAM_Lo_be           : std_logic_vector(3 downto 0);
   signal VRAM_Hi_addr         : integer range 0 to 8191;
   signal VRAM_Hi_datain       : std_logic_vector(31 downto 0);
   signal VRAM_Hi_dataout      : std_logic_vector(31 downto 0);
   signal VRAM_Hi_we           : std_logic;
   signal VRAM_Hi_be           : std_logic_vector(3 downto 0);
                               
   signal OAMRAM_PROC_addr     : integer range 0 to 255;
   signal OAMRAM_PROC_datain   : std_logic_vector(31 downto 0);
   signal OAMRAM_PROC_dataout  : std_logic_vector(31 downto 0);
   signal OAMRAM_PROC_we       : std_logic_vector(3 downto 0);
   
   signal PALETTE_BG_addr      : integer range 0 to 128;
   signal PALETTE_BG_datain    : std_logic_vector(31 downto 0);
   signal PALETTE_BG_dataout   : std_logic_vector(31 downto 0);
   signal PALETTE_BG_we        : std_logic_vector(3 downto 0);
   signal PALETTE_OAM_addr     : integer range 0 to 128;
   signal PALETTE_OAM_datain   : std_logic_vector(31 downto 0);
   signal PALETTE_OAM_dataout  : std_logic_vector(31 downto 0);
   signal PALETTE_OAM_we       : std_logic_vector(3 downto 0);
   
   signal gbaon                : std_logic := '0';
   signal gpu_out_active       : std_logic;
   
   signal Linetimerdebug : unsigned(8 downto 0);
   signal LineCountdebug : unsigned(7 downto 0);
   
   signal dma_on         : std_logic;
   signal CPU_bus_idle   : std_logic;
   
   signal dma_new_cycles   : std_logic; 
   signal dma_first_cycles : std_logic;
   signal dma_dword_cycles : std_logic;
   signal dma_cycles_adrup : std_logic_vector(3 downto 0); 
   
   signal gba_step : std_logic := '0';
   signal cpu_done : std_logic;
   signal cpu_stepsleft : unsigned(7 downto 0) := (others => '0');
   signal cpu_IRP  : std_logic := '0';
   signal new_halt : std_logic := '0';
   
   signal PC_in_BIOS : std_logic;
   signal lastread   : std_logic_vector(31 downto 0);
   
   signal new_cycles       : unsigned(7 downto 0);
   signal new_cycles_valid : std_logic;
   
   signal hblank_trigger : std_logic;
   signal vblank_trigger : std_logic;
   
   signal timer0_tick    : std_logic;
   signal timer1_tick    : std_logic;
   signal sound_dma_req  : std_logic_vector(1 downto 0);
   
   signal dma_eepromcount : unsigned(16 downto 0);
   
   -- debug wires
   signal DISPSTAT_debug  : std_logic_vector(31 downto 0);     
   signal debug_fifocount : integer;
   signal timerdebug0     : std_logic_vector(31 downto 0);
   signal timerdebug1     : std_logic_vector(31 downto 0);
   signal timerdebug2     : std_logic_vector(31 downto 0);
   signal timerdebug3     : std_logic_vector(31 downto 0);
   signal cyclenr         : integer;
   
   -- gb registers
   signal gb_bus      : proc_bus_gb_type;
   
   signal REG_IRP_IE  : std_logic_vector(work.pReg_gba_system.IRP_IE .upper downto work.pReg_gba_system.IRP_IE .lower) := (others => '0');
   signal REG_IRP_IF  : std_logic_vector(work.pReg_gba_system.IRP_IF .upper downto work.pReg_gba_system.IRP_IF .lower) := (others => '0');                                                                                                 
   signal REG_WAITCNT : std_logic_vector(work.pReg_gba_system.WAITCNT.upper downto work.pReg_gba_system.WAITCNT.lower) := (others => '0');                                                                                                  
   signal REG_IME     : std_logic_vector(work.pReg_gba_system.IME    .upper downto work.pReg_gba_system.IME    .lower) := (others => '0');                                                                                                   
   signal REG_POSTFLG : std_logic_vector(work.pReg_gba_system.POSTFLG.upper downto work.pReg_gba_system.POSTFLG.lower) := (others => '0');
   signal REG_HALTCNT : std_logic_vector(work.pReg_gba_system.HALTCNT.upper downto work.pReg_gba_system.HALTCNT.lower) := (others => '0');
   
   signal REG_HALTCNT_written : std_logic;
   signal WAITCNT_written     : std_logic;
   
   -- IRP
   signal IRPFLags    : std_logic_vector(15 downto 0) := (others => '0');
   signal IF_written  : std_logic;
   
   signal IRP_HBlank  : std_logic;
   signal IRP_VBlank  : std_logic;
   signal IRP_LCDStat : std_logic;
   signal IRP_Timer   : std_logic_vector(3 downto 0);
   signal IRP_DMA     : std_logic_vector(3 downto 0);
   signal IRP_Serial  : std_logic;
   signal IRP_Joypad  : std_logic;
   signal IRP_Gamepak : std_logic;
   
   -- timing/speedmult
   --signal oCoord_Y_100_1 : integer range -1023 to 2047;
   --signal oCoord_Y_100_2 : integer range -1023 to 2047;
   --signal new_image_req  : unsigned(3 downto 0) := (others => '0');
   
   signal cycles_ahead  : integer range 0 to 131071 := 0;
   signal cycles_16_100 : integer range 0 to (SPEEDDIV - 1) := 0;
   signal new_missing   : std_logic := '0';
   
   
begin 

   -- dummy modules
   igba_reservedregs : entity work.gba_reservedregs port map ( clk100, gb_bus);
   igba_serial       : entity work.gba_serial       port map ( clk100, gb_bus);
   
   -- real modules
   igba_joypad : entity work.gba_joypad
   port map
   (
      clk100     => clk100,
      gb_bus     => gb_bus,
      IRP_Joypad => IRP_Joypad,
      
      KeyA       => KeyA,
      KeyB       => KeyB,
      KeySelect  => KeySelect,
      KeyStart   => KeyStart,
      KeyRight   => KeyRight,
      KeyLeft    => KeyLeft,
      KeyUp      => KeyUp,
      KeyDown    => KeyDown,
      KeyR       => KeyR,
      KeyL       => KeyL     
   );
   
   mem_bus_Adr  <=  x"0" & debug_bus_Adr  when debug_bus_active = '1' else cpu_bus_Adr  when cpu_bus_ena = '1' else x"0" & dma_bus_Adr;
   mem_bus_rnw  <=  debug_bus_rnw         when debug_bus_active = '1' else cpu_bus_rnw  when cpu_bus_ena = '1' else dma_bus_rnw;
   mem_bus_ena  <=  debug_bus_ena         when debug_bus_active = '1' else cpu_bus_ena  when cpu_bus_ena = '1' else dma_bus_ena; 
   mem_bus_acc  <=  debug_bus_acc         when debug_bus_active = '1' else cpu_bus_acc  when cpu_bus_ena = '1' else dma_bus_acc;
   mem_bus_dout <=  debug_bus_dout        when debug_bus_active = '1' else cpu_bus_dout when cpu_bus_ena = '1' else dma_bus_dout;
   
   ------------- debug bus
   process (clk100)
   begin
      if rising_edge(clk100) then
   
         debug_bus_ena    <= '0';
         if (GBA_Bus_written = '1') then
            debug_bus_active <= '1';
            debug_bus_Adr    <= GBA_BusAddr;
            debug_bus_rnw    <= GBA_BusRnW;
            debug_bus_ena    <= '1';
            debug_bus_acc    <= GBA_BusACC;
            debug_bus_dout   <= GBA_BusWriteData;
         end if;
         
         if (debug_bus_active = '1' and mem_bus_done = '1') then
            GBA_BusReadData  <= mem_bus_din;
            debug_bus_active <= '0';
         end if;
         
      end if;
   end process;
   
   dma_bus_din  <= mem_bus_din;
   dma_bus_done <= mem_bus_done;
   
   cpu_addr     <= cpu_bus_Adr;
   cpu_bus_din  <= cpu_din;
   cpu_frombus  <= mem_bus_din;
   cpu_bus_done <= mem_bus_done;
   
   igba_memorymux : entity work.gba_memorymux
   generic map
   (
      is_simu                  => is_simu,
      Softmap_GBA_Gamerom_ADDR => Softmap_GBA_Gamerom_ADDR,
      Softmap_GBA_WRam_ADDR    => Softmap_GBA_WRam_ADDR,
      Softmap_GBA_FLASH_ADDR   => Softmap_GBA_FLASH_ADDR,
      Softmap_GBA_EEPROM_ADDR  => Softmap_GBA_EEPROM_ADDR
   )
   port map
   (
      clk100               => clk100,
      gb_on                => gbaon,
      
      sdram_read_ena       => sdram_read_ena,    
      sdram_read_done      => sdram_read_done,    
      sdram_read_addr      => sdram_read_addr,   
      sdram_read_data      => sdram_read_data,   
      sdram_second_dword   => sdram_second_dword,
      
      bus_out_Din          => bus_out_Din, 
      bus_out_Dout         => bus_out_Dout,
      bus_out_Adr          => bus_out_Adr, 
      bus_out_rnw          => bus_out_rnw,
      bus_out_ena          => bus_out_ena, 
      bus_out_done         => bus_out_done,
      
      gb_bus_out           => gb_bus,
      
      bios_wraddr          => bios_wraddr,
      bios_wrdata          => bios_wrdata,
      bios_wr              => bios_wr,

      mem_bus_Adr          => mem_bus_Adr, 
      mem_bus_rnw          => mem_bus_rnw, 
      mem_bus_ena          => mem_bus_ena, 
      mem_bus_acc          => mem_bus_acc, 
      mem_bus_dout         => mem_bus_dout,
      mem_bus_din          => mem_bus_din, 
      mem_bus_done         => mem_bus_done,
      
      bus_lowbits          => bus_lowbits,
      
      save_eeprom          => save_eeprom,
      save_sram            => save_sram,  
      save_flash           => save_flash, 
      
      new_cycles           => new_cycles,      
      new_cycles_valid     => new_cycles_valid,
      
      PC_in_BIOS           => PC_in_BIOS,
      lastread             => lastread,
      
      dma_eepromcount      => dma_eepromcount,
      flash_1m             => GBA_flash_1m,
      MaxPakAddr           => MaxPakAddr,
      
      VRAM_Lo_addr         => VRAM_Lo_addr,   
      VRAM_Lo_datain       => VRAM_Lo_datain, 
      VRAM_Lo_dataout      => VRAM_Lo_dataout,
      VRAM_Lo_we           => VRAM_Lo_we,     
      VRAM_Lo_be           => VRAM_Lo_be,     
      VRAM_Hi_addr         => VRAM_Hi_addr,   
      VRAM_Hi_datain       => VRAM_Hi_datain, 
      VRAM_Hi_dataout      => VRAM_Hi_dataout,
      VRAM_Hi_we           => VRAM_Hi_we,     
      VRAM_Hi_be           => VRAM_Hi_be,     

      OAMRAM_PROC_addr     => OAMRAM_PROC_addr,   
      OAMRAM_PROC_datain   => OAMRAM_PROC_datain, 
      OAMRAM_PROC_dataout  => OAMRAM_PROC_dataout,
      OAMRAM_PROC_we       => OAMRAM_PROC_we,
      
      PALETTE_BG_addr      => PALETTE_BG_addr,    
      PALETTE_BG_datain    => PALETTE_BG_datain,  
      PALETTE_BG_dataout   => PALETTE_BG_dataout, 
      PALETTE_BG_we        => PALETTE_BG_we,      
      PALETTE_OAM_addr     => PALETTE_OAM_addr,   
      PALETTE_OAM_datain   => PALETTE_OAM_datain, 
      PALETTE_OAM_dataout  => PALETTE_OAM_dataout,
      PALETTE_OAM_we       => PALETTE_OAM_we      
   );
   
   igba_dma : entity work.gba_dma
   port map
   (
      clk100              => clk100,
      gb_bus              => gb_bus,
      
      IRP_DMA             => IRP_DMA,
      
      dma_on              => dma_on,
      CPU_bus_idle        => CPU_bus_idle,
      do_step             => gba_step,
      
      sound_dma_req       => sound_dma_req,
      hblank_trigger      => hblank_trigger,
      vblank_trigger      => vblank_trigger,
      
      dma_new_cycles      => dma_new_cycles,  
      dma_first_cycles    => dma_first_cycles,
      dma_dword_cycles    => dma_dword_cycles,
      dma_cycles_adrup    => dma_cycles_adrup,
      
      dma_eepromcount     => dma_eepromcount,
      
      dma_bus_Adr         => dma_bus_Adr, 
      dma_bus_rnw         => dma_bus_rnw, 
      dma_bus_ena         => dma_bus_ena, 
      dma_bus_acc         => dma_bus_acc, 
      dma_bus_dout        => dma_bus_dout,
      dma_bus_din         => dma_bus_din, 
      dma_bus_done        => dma_bus_done
   );
   
   igba_sound : entity work.gba_sound        
   port map 
   ( 
      clk100               => clk100,
      gb_on                => gbaon,
      gb_bus               => gb_bus,
      
      lockspeed            => GBA_lockspeed,
      bus_cycles           => new_cycles,
      bus_cycles_valid     => new_cycles_valid,
      
      timer0_tick          => timer0_tick,
      timer1_tick          => timer1_tick,
      sound_dma_req        => sound_dma_req,
      
      sound_out_left       => sound_out_left,
      sound_out_right      => sound_out_right,
      
      debug_fifocount      => debug_fifocount
   );
   
   igba_gpu : entity work.gba_gpu
   generic map
   (
      is_simu => is_simu
   )
   port map
   (
      clk100               => clk100,
      gb_on                => gbaon,

      gb_bus               => gb_bus,

      pixel_out_addr       => pixel_out_addr,
      pixel_out_data       => pixel_out_data,
      pixel_out_we         => pixel_out_we,  
      
      new_cycles           => new_cycles,      
      new_cycles_valid     => new_cycles_valid,
              
      IRP_HBlank           => IRP_HBlank,
      IRP_VBlank           => IRP_VBlank,      
      IRP_LCDStat          => IRP_LCDStat,  

      hblank_trigger       => hblank_trigger,
      vblank_trigger       => vblank_trigger,
                        
      VRAM_Lo_addr         => VRAM_Lo_addr,   
      VRAM_Lo_datain       => VRAM_Lo_datain, 
      VRAM_Lo_dataout      => VRAM_Lo_dataout,
      VRAM_Lo_we           => VRAM_Lo_we,     
      VRAM_Lo_be           => VRAM_Lo_be,     
      VRAM_Hi_addr         => VRAM_Hi_addr,   
      VRAM_Hi_datain       => VRAM_Hi_datain, 
      VRAM_Hi_dataout      => VRAM_Hi_dataout,
      VRAM_Hi_we           => VRAM_Hi_we,        
      VRAM_Hi_be           => VRAM_Hi_be,        
                         
      OAMRAM_PROC_addr     => OAMRAM_PROC_addr,   
      OAMRAM_PROC_datain   => OAMRAM_PROC_datain, 
      OAMRAM_PROC_dataout  => OAMRAM_PROC_dataout,
      OAMRAM_PROC_we       => OAMRAM_PROC_we,  

      PALETTE_BG_addr      => PALETTE_BG_addr,    
      PALETTE_BG_datain    => PALETTE_BG_datain,  
      PALETTE_BG_dataout   => PALETTE_BG_dataout, 
      PALETTE_BG_we        => PALETTE_BG_we,      
      PALETTE_OAM_addr     => PALETTE_OAM_addr,   
      PALETTE_OAM_datain   => PALETTE_OAM_datain, 
      PALETTE_OAM_dataout  => PALETTE_OAM_dataout,
      PALETTE_OAM_we       => PALETTE_OAM_we,            
   
      DISPSTAT_debug       => DISPSTAT_debug       
   );
   
   igba_timer : entity work.gba_timer
   generic map
   (
      is_simu => is_simu
   )
   port map
   (
      clk100           => clk100,
      gb_on            => gbaon,
      gb_bus           => gb_bus,
      new_cycles       => new_cycles,      
      new_cycles_valid => new_cycles_valid,
      IRP_Timer        => IRP_Timer,
      
      timer0_tick      => timer0_tick,
      timer1_tick      => timer1_tick,
      
      debugout0        => timerdebug0,
      debugout1        => timerdebug1,
      debugout2        => timerdebug2,
      debugout3        => timerdebug3
   );
   
   igba_cpu : entity work.gba_cpu
   generic map
   (
      is_simu => is_simu
   )
   port map
   (
      clk100           => clk100, 
      gb_on            => gbaon,
      
      gb_bus_Adr       => cpu_bus_Adr, 
      gb_bus_rnw       => cpu_bus_rnw, 
      gb_bus_ena       => cpu_bus_ena, 
      gb_bus_acc       => cpu_bus_acc, 
      gb_bus_dout      => cpu_bus_dout,
      gb_bus_din       => cpu_bus_din, 
      gb_bus_done      => cpu_bus_done,
      
      bus_lowbits      => bus_lowbits,
      
      wait_cnt_value   => unsigned(REG_WAITCNT),
      wait_cnt_update  => WAITCNT_written,
      
      dma_on           => dma_on,
      do_step          => gba_step,
      done             => open,--cpu_done,
      CPU_bus_idle     => CPU_bus_idle,
      PC_in_BIOS       => PC_in_BIOS,
      lastread         => lastread,
      
      new_cycles_out   => new_cycles,
      new_cycles_valid => new_cycles_valid,
      
      dma_new_cycles   => dma_new_cycles,  
      dma_first_cycles => dma_first_cycles,
      dma_dword_cycles => dma_dword_cycles,
      dma_cycles_adrup => dma_cycles_adrup,
      
      IRP_in           => IRPFLags,
      cpu_IRP          => cpu_IRP,
      new_halt         => new_halt,
      
      DISPSTAT_debug   => DISPSTAT_debug,
      debug_fifocount  => debug_fifocount,
      timerdebug0      => timerdebug0,
      timerdebug1      => timerdebug1,
      timerdebug2      => timerdebug2,
      timerdebug3      => timerdebug3,
      
      cyclenr          => open --cyclenr
   );
   
   iREG_IRP_IE  : entity work.eProcReg_gba generic map (work.pReg_gba_system.IRP_IE ) port map  (clk100, gb_bus, REG_IRP_IE , REG_IRP_IE );
   iREG_IRP_IF  : entity work.eProcReg_gba generic map (work.pReg_gba_system.IRP_IF ) port map  (clk100, gb_bus, IRPFLags   , REG_IRP_IF , IF_written);                                                                                                                   
   iREG_WAITCNT : entity work.eProcReg_gba generic map (work.pReg_gba_system.WAITCNT) port map  (clk100, gb_bus, REG_WAITCNT, REG_WAITCNT, WAITCNT_written);                                                                                                                     
   iREG_IME     : entity work.eProcReg_gba generic map (work.pReg_gba_system.IME    ) port map  (clk100, gb_bus, REG_IME    , REG_IME    );                                                                                                                       
   iREG_POSTFLG : entity work.eProcReg_gba generic map (work.pReg_gba_system.POSTFLG) port map  (clk100, gb_bus, REG_POSTFLG, REG_POSTFLG);
   iREG_HALTCNT : entity work.eProcReg_gba generic map (work.pReg_gba_system.HALTCNT) port map  (clk100, gb_bus, (REG_HALTCNT'range => '0'), REG_HALTCNT, REG_HALTCNT_written);

   ------------- interrupt
   process (clk100)
   begin
      if rising_edge(clk100) then
   
         gbaon <= GBA_on;
   
         if (gbaon = '0') then -- reset
   
            IRPFLags <= (others => '0');
   
         else
         
            if (IF_written = '1') then
               IRPFLags <= IRPFLags and not REG_IRP_IF;
            end if;
      
            if (IRP_VBlank = '1')   then IRPFLags( 0) <= '1'; end if;
            if (IRP_HBlank = '1')   then IRPFLags( 1) <= '1'; end if;
            if (IRP_LCDStat = '1')  then IRPFLags( 2) <= '1'; end if;
            if (IRP_Timer(0) = '1') then IRPFLags( 3) <= '1'; end if;
            if (IRP_Timer(1) = '1') then IRPFLags( 4) <= '1'; end if;
            if (IRP_Timer(2) = '1') then IRPFLags( 5) <= '1'; end if;
            if (IRP_Timer(3) = '1') then IRPFLags( 6) <= '1'; end if;
            if (IRP_Serial = '1')   then IRPFLags( 7) <= '1'; end if;
            if (IRP_DMA(0) = '1')   then IRPFLags( 8) <= '1'; end if;
            if (IRP_DMA(1) = '1')   then IRPFLags( 9) <= '1'; end if;
            if (IRP_DMA(2) = '1')   then IRPFLags(10) <= '1'; end if;
            if (IRP_DMA(3) = '1')   then IRPFLags(11) <= '1'; end if;
            if (IRP_Joypad = '1')   then IRPFLags(12) <= '1'; end if;
            if (IRP_Gamepak = '1')  then IRPFLags(13) <= '1'; end if;
            
            cpu_IRP <= '0';
            if ((IRPFLags and REG_IRP_IE) /= x"0000" and REG_IME(0) = '1') then
               cpu_IRP <= '1';
            end if;
            
            new_halt <= '0';
            if (REG_HALTCNT_written = '1') then
               if (REG_HALTCNT(15) = '0') then
                  new_halt <= '1';
               end if;
            end if;
            
         end if;

      end if;
   end process;
   
   ------------- cycling
   process (clk100)
      variable new_cycles_ahead : integer range 0 to 1023;
   begin
      if rising_edge(clk100) then
         
         new_missing <= '0';
         
         new_cycles_ahead := cycles_ahead;
         if (new_cycles_valid = '1') then
            new_cycles_ahead := new_cycles_ahead + to_integer(new_cycles);
         end if;
         
         if (cycles_16_100 < (SPEEDDIV - 1)) then
            cycles_16_100 <= cycles_16_100 + 1;
         else
            cycles_16_100 <= 0;
            if (new_cycles_ahead > 0) then
               new_cycles_ahead := new_cycles_ahead - 1;
            else
               new_missing <= '1';
            end if;
         end if;
         if (GBA_lockspeed = '1') then
            cycles_ahead <= new_cycles_ahead;
         else
            cycles_ahead <= 0;
         end if;
         
         gba_step <= '0';
         if (GBA_lockspeed = '0' or cycles_ahead < unsigned(CyclePrecalc)) then
            gba_step <= '1';
         end if;
      
         if (GBA_lockspeed = '0' or gbaon = '0') then
            CyclesMissing <= (others => '0');
         elsif (new_missing = '1') then
            CyclesMissing <= std_logic_vector(unsigned(CyclesMissing) + 1);
         end if;
   
      end if;
   end process;
   

end architecture;





