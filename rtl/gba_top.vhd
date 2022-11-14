library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

library MEM;

use work.pProc_bus_gba.all;
use work.pReg_savestates.all;

entity gba_top is
   generic
   (
      Softmap_GBA_Gamerom_ADDR : integer; -- count: 8388608    -- 32 Mbyte Data for GameRom
      Softmap_GBA_WRam_ADDR    : integer; -- count:   65536    -- 256 Kbyte Data for GBA WRam Large
      Softmap_GBA_FLASH_ADDR   : integer; -- count:  131072    -- 128/512 Kbyte Data for GBA Flash
      Softmap_GBA_EEPROM_ADDR  : integer; -- count:    8192    -- 8/32 Kbyte Data for GBA EEProm
      Softmap_SaveState_ADDR   : integer; -- count:  524288    -- 512 Kbyte Data for Savestate 
      Softmap_Rewind_ADDR      : integer; -- count:  524288*64 -- 64*512 Kbyte Data for Savestates
      is_simu                  : std_logic := '0';
      turbosound               : std_logic  -- sound buffer to play sound in turbo mode without sound pitched up
   );
   port 
   (
      clk100                : in     std_logic;  
      -- settings                 
      GBA_on                : in     std_logic;  -- switching from off to on = reset
      GBA_lockspeed         : in     std_logic;  -- 1 = 100% speed, 0 = max speed
      GBA_cputurbo          : in     std_logic;  -- 1 = cpu free running, all other 16 mhz
      GBA_flash_1m          : in     std_logic;  -- 1 when string "FLASH1M_V" is anywhere in gamepak
      CyclePrecalc          : in     std_logic_vector(15 downto 0); -- 100 seems to be ok to keep fullspeed for all games
      Underclock            : in     std_logic_vector(1 downto 0);
      MaxPakAddr            : in     std_logic_vector(24 downto 0); -- max byte address that will contain data, required for buggy games that read behind their own memory, e.g. zelda minish cap
      CyclesMissing         : buffer std_logic_vector(31 downto 0); -- debug only for speed measurement, keep open
      CyclesVsyncSpeed      : out    std_logic_vector(31 downto 0); -- debug only for speed measurement, keep open
      SramFlashEnable       : in     std_logic;
      memory_remap          : in     std_logic;
      increaseSSHeaderCount : in     std_logic;
      save_state            : in     std_logic;
      load_state            : in     std_logic;
      interframe_blend      : in     std_logic_vector(1 downto 0); -- 0 = off, 1 = blend, 2 = 30hz
      maxpixels             : in     std_logic;                    -- limit pixels per line
      shade_mode            : in     std_logic_vector(2 downto 0); -- 0 = off, 1..4 modes
      hdmode2x_bg           : in     std_logic;
      hdmode2x_obj          : in     std_logic;
      specialmodule         : in     std_logic;                    -- 0 = off, 1 = use gamepak GPIO Port at address 0x080000C4..0x080000C8
      solar_in              : in     std_logic_vector(2 downto 0);
      tilt                  : in     std_logic;                    -- 0 = off, 1 = use tilt at address 0x0E008200, 0x0E008300, 0x0E008400, 0x0E008500
      rewind_on             : in     std_logic;
      rewind_active         : in     std_logic;
      savestate_number      : in     integer;
      -- RTC
      RTC_timestampNew      : in     std_logic;                     -- new current timestamp from system
      RTC_timestampIn       : in     std_logic_vector(31 downto 0); -- timestamp in seconds, current time
      RTC_timestampSaved    : in     std_logic_vector(31 downto 0); -- timestamp in seconds, saved time
      RTC_savedtimeIn       : in     std_logic_vector(41 downto 0); -- time structure, loaded
      RTC_saveLoaded        : in     std_logic;                     -- must be 0 when loading new game, should go and stay 1 when RTC was loaded and values are valid
      RTC_timestampOut      : out    std_logic_vector(31 downto 0); -- timestamp to be saved
      RTC_savedtimeOut      : out    std_logic_vector(41 downto 0); -- time structure to be saved
      RTC_inuse             : out    std_logic := '0';              -- will indicate that RTC is in use and should be saved on next saving
      -- cheats
      cheat_clear           : in     std_logic;
      cheats_enabled        : in     std_logic;
      cheat_on              : in     std_logic;
      cheat_in              : in     std_logic_vector(127 downto 0);
      cheats_active         : out    std_logic := '0';
      -- sdram interface
      sdram_read_ena        : out    std_logic;                     -- triggered once for read request 
      sdram_read_done       : in     std_logic := '0';              -- must be triggered once when sdram_read_data is valid after last read
      sdram_read_addr       : out    std_logic_vector(24 downto 0); -- all addresses are DWORD addresses!
      sdram_read_data       : in     std_logic_vector(31 downto 0); -- data from last request, valid when done = 1
      sdram_second_dword    : in     std_logic_vector(31 downto 0); -- second dword to be read for buffering/prefetch. Must be valid 1 cycle after done = 1
      -- other Memories           
      bus_out_Din           : out    std_logic_vector(31 downto 0); -- data read from WRam Large, SRAM/Flash/EEPROM
      bus_out_Dout          : in     std_logic_vector(31 downto 0); -- data written to WRam Large, SRAM/Flash/EEPROM
      bus_out_Adr           : out    std_logic_vector(25 downto 0); -- all addresses are DWORD addresses!
      bus_out_rnw           : out    std_logic;                     -- read = 1, write = 0
      bus_out_ena           : out    std_logic;                     -- one cycle high for each action
      bus_out_done          : in     std_logic;                     -- should be one cycle high when write is done or read value is valid
      -- savestate           
      SAVE_out_Din          : out    std_logic_vector(63 downto 0); -- data read from savestate
      SAVE_out_Dout         : in     std_logic_vector(63 downto 0); -- data written to savestate
      SAVE_out_Adr          : out    std_logic_vector(25 downto 0); -- all addresses are DWORD addresses!
      SAVE_out_rnw          : out    std_logic;                     -- read = 1, write = 0
      SAVE_out_ena          : out    std_logic;                     -- one cycle high for each action
      SAVE_out_active       : out    std_logic;                     -- is high when access goes to savestate
      SAVE_out_be           : out    std_logic_vector(7 downto 0);
      SAVE_out_done         : in     std_logic;                     -- should be one cycle high when write is done or read value is valid
      -- Write to BIOS
      bios_wraddr           : in     std_logic_vector(11 downto 0) := (others => '0');
      bios_wrdata           : in     std_logic_vector(31 downto 0) := (others => '0');
      bios_wr               : in     std_logic := '0';
      -- save memory used
      save_eeprom           : out    std_logic;
      save_sram             : out    std_logic;
      save_flash            : out    std_logic;
      load_done             : out    std_logic;                     -- savestate successfully loaded
      -- Keys - all active high   
      KeyA                  : in     std_logic; 
      KeyB                  : in     std_logic;
      KeySelect             : in     std_logic;
      KeyStart              : in     std_logic;
      KeyRight              : in     std_logic;
      KeyLeft               : in     std_logic;
      KeyUp                 : in     std_logic;
      KeyDown               : in     std_logic;
      KeyR                  : in     std_logic;
      KeyL                  : in     std_logic;
      AnalogTiltX           : in     signed(7 downto 0);
      AnalogTiltY           : in     signed(7 downto 0);
      Rumble                : out    std_logic;
      -- debug interface          
      GBA_BusAddr           : in     std_logic_vector(27 downto 0);
      GBA_BusRnW            : in     std_logic;
      GBA_BusACC            : in     std_logic_vector(1 downto 0);
      GBA_BusWriteData      : in     std_logic_vector(31 downto 0);
      GBA_BusReadData       : out    std_logic_vector(31 downto 0);
      GBA_Bus_written       : in     std_logic;
      -- display data
      pixel_out_x           : buffer integer range 0 to 239;
      pixel_out_y           : buffer integer range 0 to 159;
      pixel_out_addr        : buffer integer range 0 to 38399;       -- address for framebuffer 
      pixel_out_data        : buffer std_logic_vector(17 downto 0);  -- RGB data for framebuffer 
      pixel_out_we          : buffer std_logic;                      -- new pixel for framebuffer 
                                  
      largeimg_out_base     : out    std_logic_vector(31 downto 0) := x"38000000";            
      largeimg_out_addr     : buffer std_logic_vector(25 downto 0) := (others => '0');
      largeimg_out_data     : out    std_logic_vector(63 downto 0);
      largeimg_out_req      : out    std_logic := '0';
      largeimg_out_done     : in     std_logic;
      largeimg_newframe     : in     std_logic;
      largeimg_singlebuf    : in     std_logic;
      -- sound                             
      sound_out_left        : out    std_logic_vector(15 downto 0) := (others => '0');
      sound_out_right       : out    std_logic_vector(15 downto 0) := (others => '0');
      -- debug                    
      debug_cpu_pc          : out    std_logic_vector(31 downto 0);
      debug_cpu_mixed       : out    std_logic_vector(31 downto 0);
      debug_irq             : out    std_logic_vector(31 downto 0);
      debug_dma             : out    std_logic_vector(31 downto 0);
      debug_mem             : out    std_logic_vector(31 downto 0)  
   );
end entity;

architecture arch of gba_top is

   constant SPEEDDIV    : integer := 6;
   constant DEBUG_NOCPU : std_logic := '0';  

   -- debug
   signal debug_bus_active : std_logic := '0';
   
   signal debug_bus_Adr        : std_logic_vector(27 downto 0);
   signal debug_bus_rnw        : std_logic;
   signal debug_bus_ena        : std_logic;
   signal debug_bus_acc        : std_logic_vector(1 downto 0);
   signal debug_bus_dout       : std_logic_vector(31 downto 0);
   
   -- save states
   signal SAVE_BusAddr         : std_logic_vector(27 downto 0);
   signal SAVE_BusRnW          : std_logic;
   signal SAVE_BusACC          : std_logic_vector(1 downto 0);
   signal SAVE_BusWriteData    : std_logic_vector(31 downto 0);
   signal SAVE_Bus_ena         : std_logic;
   
   signal savestate_bus        : proc_bus_gb_type;
   signal reset                : std_logic;
   signal loading_savestate    : std_logic;
   signal sleep_savestate      : std_logic;
   
   signal cpu_jump             : std_logic;
   
   signal savestate_savestate  : std_logic := '0';
   signal savestate_loadstate  : std_logic := '0';
   signal savestate_address    : integer;
   signal savestate_busy       : std_logic;
   
   signal sleep_rewind         : std_logic;
   
   -- cheats
   signal Cheats_BusAddr       : std_logic_vector(27 downto 0);
   signal Cheats_BusRnW        : std_logic;
   signal Cheats_BusACC        : std_logic_vector(1 downto 0);
   signal Cheats_BusWriteData  : std_logic_vector(31 downto 0);
   signal Cheats_Bus_ena       : std_logic := '0';
   
   signal sleep_cheats         : std_logic;
   
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
   signal dma_bus_unread       : std_logic;
   
   signal mem_bus_Adr          : std_logic_vector(31 downto 0);
   signal mem_bus_rnw          : std_logic;
   signal mem_bus_ena          : std_logic;
   signal mem_bus_acc          : std_logic_vector(1 downto 0);
   signal mem_bus_dout         : std_logic_vector(31 downto 0);
   signal mem_bus_din          : std_logic_vector(31 downto 0);
   signal mem_bus_done         : std_logic;
   signal mem_bus_unread       : std_logic;
   
   signal bus_lowbits          : std_logic_vector(1 downto 0); -- only required for sram access
                                          
   signal settle               : std_logic;
   
   signal bitmapdrawmode       : std_logic;
                               
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
   signal vram_blocked         : std_logic;
   signal vram_cycle           : std_logic;
                               
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
   
   signal GPIO_done            : std_logic;
   signal GPIO_readEna         : std_logic;
   signal GPIO_Din             : std_logic_vector(3 downto 0);
   signal GPIO_Dout            : std_logic_vector(3 downto 0);
   signal GPIO_writeEna        : std_logic;
   signal GPIO_addr            : std_logic_vector(1 downto 0);
   
   signal gbaon                : std_logic := '0';
   signal gpu_out_active       : std_logic;
   
   signal Linetimerdebug : unsigned(8 downto 0);
   signal LineCountdebug : unsigned(7 downto 0);
   
   signal dma_on         : std_logic;
   signal CPU_bus_idle   : std_logic;
   signal dma_soon       : std_logic;
   
   signal dma_new_cycles   : std_logic; 
   signal dma_first_cycles : std_logic;
   signal dma_dword_cycles : std_logic;
   signal dma_toROM        : std_logic;
   signal dma_init_cycles  : std_logic;
   signal dma_cycles_adrup : std_logic_vector(3 downto 0); 
   
   signal gba_step : std_logic := '0';
   signal cpu_done : std_logic;
   signal cpu_stepsleft : unsigned(7 downto 0) := (others => '0');
   signal cpu_IRP  : std_logic := '0';
   signal new_halt : std_logic := '0';
   
   signal PC_in_BIOS      : std_logic;
   signal lastread        : std_logic_vector(31 downto 0);
   signal lastread_dma    : std_logic_vector(31 downto 0);
   signal last_access_dma : std_logic := '0';
   
   signal new_cycles           : unsigned(7 downto 0);
   signal new_cycles_valid     : std_logic;      
   signal new_cycles_cpu       : unsigned(7 downto 0);
   signal new_cycles_valid_cpu : std_logic;   
   
   signal hblank_trigger : std_logic;
   signal vblank_trigger : std_logic;
   signal videodma_start : std_logic;
   signal videodma_stop  : std_logic;
   
   signal timer0_tick    : std_logic;
   signal timer1_tick    : std_logic;
   signal sound_dma_req  : std_logic_vector(1 downto 0);
   
   signal dma_eepromcount : unsigned(16 downto 0);
   
   signal MaxPakAddr_modified  : std_logic_vector(24 downto 0);
   
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
   signal SAVESTATE_IRP : std_logic_vector(15 downto 0) := (others => '0');
   signal IRPFLags      : std_logic_vector(15 downto 0) := (others => '0');
   signal IF_written    : std_logic;
   
   signal IRP_HBlank  : std_logic;
   signal IRP_VBlank  : std_logic;
   signal IRP_LCDStat : std_logic;
   signal IRP_Timer   : std_logic_vector(3 downto 0);
   signal IRP_DMA     : std_logic_vector(3 downto 0);
   signal IRP_Serial  : std_logic;
   signal IRP_Joypad  : std_logic;
   -- signal IRP_Gamepak : std_logic; -- not implemented
   
   signal cycles_ahead    : integer range 0 to 131071 := 0;
   signal cycles_16_100   : integer range 0 to (SPEEDDIV - 1) := 0;
   signal new_missing     : std_logic := '0';
   signal new_exact_cycle : std_logic := '0';
   signal CyclesVsync     : unsigned(31 downto 0) := (others => '0');
   signal bench_slow      : integer range 0 to 1685375 := 0;
   
   -- large image out
   signal pixel_out_2x       : integer range 0 to 479; 
   signal pixel_out_data2x   : std_logic_vector(17 downto 0);  
   signal pixel_out_we2x     : std_logic := '0';   
   signal pixel2_out_x       : integer range 0 to 479;
   signal pixel2_out_data    : std_logic_vector(17 downto 0);  
   signal pixel2_out_we      : std_logic;
   
   signal pixel_write_addr   : integer range 0 to 239;
   signal pixel_write_data   : std_logic_vector(35 downto 0);
   signal pixel_write_ena    : std_logic := '0';
      
   signal pixel2_write_addr  : integer range 0 to 239;
   signal pixel2_write_data  : std_logic_vector(35 downto 0);
   signal pixel2_write_ena   : std_logic := '0';
   
   type tstate is
   (
      IDLE,
      READPIXEL,
      WRITEPIXEL
   );
   signal state           : tstate := IDLE;
                          
   signal pixel_out_y_1    : integer range 0 to 159 := 0;
   signal pixelpos         : integer range 0 to 240 := 0;
   signal pixelpos2        : integer range 0 to 240 := 0;
   signal pixelcnt         : integer range 0 to 3 := 0;
   signal firstpixel       : std_logic := '0';
   signal linebuffer_data  : std_logic_vector(35 downto 0);
   signal linebuffer2_data : std_logic_vector(35 downto 0);
   signal pixeladdress     : integer range 0 to 262143;
   
   signal newframe_sreg    : std_logic_vector(2 downto 0) := (others => '0');
   signal current_frame    : integer range 0 to 2 := 0;
   signal frameoffset      : integer range 0 to 2 := 0;
   
begin 

   -- dummy modules
   igba_reservedregs : entity work.gba_reservedregs port map ( clk100, gb_bus);
   
   igba_serial       : entity work.gba_serial       
   port map 
   ( 
      clk100            => clk100,
      gb_bus            => gb_bus,
      
      new_cycles        => new_cycles,      
      new_cycles_valid  => new_cycles_valid,
                         
      IRP_Serial        => IRP_Serial
   );
   
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
      KeyL       => KeyL,

      cpu_done   => cpu_done  
   );
   
   mem_bus_Adr  <=  x"0" & debug_bus_Adr  when debug_bus_active = '1' else cpu_bus_Adr  when cpu_bus_ena = '1' else x"0" & dma_bus_Adr;
   mem_bus_rnw  <=  debug_bus_rnw         when debug_bus_active = '1' else cpu_bus_rnw  when cpu_bus_ena = '1' else dma_bus_rnw;
   mem_bus_ena  <=  debug_bus_ena         when debug_bus_active = '1' else cpu_bus_ena  when cpu_bus_ena = '1' else dma_bus_ena; 
   mem_bus_acc  <=  debug_bus_acc         when debug_bus_active = '1' else cpu_bus_acc  when cpu_bus_ena = '1' else dma_bus_acc;
   mem_bus_dout <=  debug_bus_dout        when debug_bus_active = '1' else cpu_bus_dout when cpu_bus_ena = '1' else dma_bus_dout;
       
   process (clk100)
   begin       
      if rising_edge(clk100) then
      
         if (cpu_done = '1') then
            last_access_dma <= '0';
         elsif (dma_bus_ena = '1') then
            last_access_dma <= '1';
         end if;

      end if;
   end process;
                      
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
         elsif (SAVE_Bus_ena = '1') then
            debug_bus_active <= '1';
            debug_bus_Adr    <= SAVE_BusAddr;
            debug_bus_rnw    <= SAVE_BusRnW;
            debug_bus_ena    <= '1';
            debug_bus_acc    <= SAVE_BusACC;
            debug_bus_dout   <= SAVE_BusWriteData;
         elsif (Cheats_Bus_ena = '1') then
            debug_bus_active <= '1';
            debug_bus_Adr    <= Cheats_BusAddr;
            debug_bus_rnw    <= Cheats_BusRnW;
            debug_bus_ena    <= '1';
            debug_bus_acc    <= Cheats_BusACC;
            debug_bus_dout   <= Cheats_BusWriteData;
         end if;
         
         if (debug_bus_active = '1' and mem_bus_done = '1') then
            GBA_BusReadData  <= mem_bus_din;
            debug_bus_active <= '0';
         end if;
         
      end if;
   end process;
   
   dma_bus_din    <= mem_bus_din;
   dma_bus_done   <= mem_bus_done;
   dma_bus_unread <= mem_bus_unread;
   
   cpu_bus_din  <= mem_bus_din;
   cpu_bus_done <= mem_bus_done;
   
   igba_savestates : entity work.gba_savestates
   generic map
   (
      Softmap_GBA_WRam_ADDR    => Softmap_GBA_WRam_ADDR,  
      Softmap_GBA_FLASH_ADDR   => Softmap_GBA_FLASH_ADDR, 
      Softmap_GBA_EEPROM_ADDR  => Softmap_GBA_EEPROM_ADDR,
      is_simu                  => is_simu                
   )
   port map
   (
      clk100                => clk100,
      gb_on                 => gbaon,
      reset                 => reset,
  
      load_done             => load_done,
                        
      increaseSSHeaderCount => increaseSSHeaderCount,
      save                  => savestate_savestate,
      load                  => savestate_loadstate,
      savestate_address     => savestate_address,
      savestate_busy        => savestate_busy,      

      cpu_jump              => cpu_jump,

      internal_bus_out      => savestate_bus,
      loading_savestate     => loading_savestate,
      --saving_savestate      => saving_savestate,
      sleep_savestate       => sleep_savestate,
      bus_ena_in            => mem_bus_ena,

      gb_bus                => gb_bus,

      SAVE_BusAddr          => SAVE_BusAddr,     
      SAVE_BusRnW           => SAVE_BusRnW,      
      SAVE_BusACC           => SAVE_BusACC,      
      SAVE_BusWriteData     => SAVE_BusWriteData,
      SAVE_Bus_ena          => SAVE_Bus_ena,     
                                             
      SAVE_BusReadData      => mem_bus_din, 
      SAVE_BusReadDone      => mem_bus_done, 
                                            
      bus_out_Din           => SAVE_out_Din,   
      bus_out_Dout          => SAVE_out_Dout,  
      bus_out_Adr           => SAVE_out_Adr,   
      bus_out_rnw           => SAVE_out_rnw,   
      bus_out_ena           => SAVE_out_ena,   
      bus_out_active        => SAVE_out_active,
      bus_out_be            => SAVE_out_be,
      bus_out_done          => SAVE_out_done  
   );
   
   igba_statemanager : entity work.gba_statemanager
   generic map
   (
      Softmap_SaveState_ADDR   => Softmap_SaveState_ADDR,
      Softmap_Rewind_ADDR      => Softmap_Rewind_ADDR   
   )
   port map
   (
      clk100              => clk100,
      gb_on               => gbaon,

      rewind_on           => rewind_on,    
      rewind_active       => rewind_active,
      
      savestate_number    => savestate_number,
      save                => save_state,
      load                => load_state,
      
      sleep_rewind        => sleep_rewind,
      vsync               => vblank_trigger,       
      
      request_savestate   => savestate_savestate,
      request_loadstate   => savestate_loadstate,
      request_address     => savestate_address,  
      request_busy        => savestate_busy     
   );
   
   igba_cheats : entity work.gba_cheats
   port map
   (
      clk100         => clk100,
      gb_on          => GBA_on,
                      
      cheat_clear    => cheat_clear,
      cheats_enabled => cheats_enabled,
      cheat_on       => cheat_on,
      cheat_in       => cheat_in,
      cheats_active  => cheats_active,
                     
      vsync          => vblank_trigger,
                     
      bus_ena_in     => mem_bus_ena,
      sleep_cheats   => sleep_cheats,
                    
      BusAddr        => Cheats_BusAddr,     
      BusRnW         => Cheats_BusRnW,      
      BusACC         => Cheats_BusACC,      
      BusWriteData   => Cheats_BusWriteData,
      Bus_ena        => Cheats_Bus_ena,     
      BusReadData    => mem_bus_din, 
      BusDone        => mem_bus_done
   );
   
   igba_gpioRTCSolarGyro : entity work.gba_gpioRTCSolarGyro
   port map
   (
      clk100               => clk100, 
      reset                => reset,
      GBA_on               => GBA_on,
                                         
      savestate_bus        => savestate_bus,
                                         
      GPIO_readEna         => GPIO_readEna, 
      GPIO_done            => GPIO_done,   
      GPIO_Din             => GPIO_Din,     
      GPIO_Dout            => GPIO_Dout,    
      GPIO_writeEna        => GPIO_writeEna,
      GPIO_addr            => GPIO_addr,
      
      vblank_trigger       => vblank_trigger,
      RTC_timestampNew     => RTC_timestampNew,
      RTC_timestampIn      => RTC_timestampIn,   
      RTC_timestampSaved   => RTC_timestampSaved,
      RTC_savedtimeIn      => RTC_savedtimeIn,   
      RTC_saveLoaded       => RTC_saveLoaded,    
      RTC_timestampOut     => RTC_timestampOut,  
      RTC_savedtimeOut     => RTC_savedtimeOut,  
      RTC_inuse            => RTC_inuse,         

      rumble               => Rumble,
      AnalogX              => AnalogTiltX,
      solar_in             => solar_in
   );
   
   process (clk100)
   begin
      if rising_edge(clk100) then
   
         if (memory_remap = '1') then
            MaxPakAddr_modified <= (others => '1');
         else
            MaxPakAddr_modified <= MaxPakAddr;
         end if;
         
      end if;
   end process;
   
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
      reset                => reset,
                           
      savestate_bus        => savestate_bus,
      
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
      mem_bus_unread       => mem_bus_unread,
      
      bus_lowbits          => bus_lowbits,
      
      dma_soon             => dma_soon,
      settle               => settle,
      
      save_eeprom          => save_eeprom,
      save_sram            => save_sram,  
      save_flash           => save_flash, 
      
      new_cycles           => new_cycles,      
      new_cycles_valid     => new_cycles_valid,
      
      PC_in_BIOS           => PC_in_BIOS,
      lastread             => lastread,
      lastread_dma         => lastread_dma,
      last_access_dma      => last_access_dma,
      
      dma_eepromcount      => dma_eepromcount,
      flash_1m             => GBA_flash_1m,
      MaxPakAddr           => MaxPakAddr_modified,
      SramFlashEnable      => SramFlashEnable,
      memory_remap         => memory_remap,
      
      bitmapdrawmode       => bitmapdrawmode,
      
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
      vram_blocked         => vram_blocked,    
      vram_cycle           => vram_cycle,

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

      specialmodule        => specialmodule,
      GPIO_readEna         => GPIO_readEna,
      GPIO_done            => GPIO_done,    
      GPIO_Din             => GPIO_Din,     
      GPIO_Dout            => GPIO_Dout,    
      GPIO_writeEna        => GPIO_writeEna,
      GPIO_addr            => GPIO_addr,    
      
      tilt                 => tilt,       
      AnalogTiltX          => AnalogTiltX,
      AnalogTiltY          => AnalogTiltY,

      debug_mem            => debug_mem      
   );
   
   igba_dma : entity work.gba_dma
   port map
   (
      clk100              => clk100,
      reset               => reset,
                           
      savestate_bus       => savestate_bus,
      loading_savestate   => loading_savestate,
      
      gb_bus              => gb_bus,
      
      new_cycles          => new_cycles,      
      new_cycles_valid    => new_cycles_valid,
      
      IRP_DMA             => IRP_DMA,
      lastread_dma        => lastread_dma,
      
      dma_on              => dma_on,
      CPU_bus_idle        => CPU_bus_idle,
      do_step             => gba_step,
      dma_soon            => dma_soon,
      
      sound_dma_req       => sound_dma_req,
      hblank_trigger      => hblank_trigger,
      vblank_trigger      => vblank_trigger,
      videodma_start      => videodma_start,
      videodma_stop       => videodma_stop ,   
      
      dma_new_cycles      => dma_new_cycles,  
      dma_first_cycles    => dma_first_cycles,
      dma_dword_cycles    => dma_dword_cycles,
      dma_toROM           => dma_toROM,
      dma_init_cycles     => dma_init_cycles,
      dma_cycles_adrup    => dma_cycles_adrup,
      
      dma_eepromcount     => dma_eepromcount,
      
      dma_bus_Adr         => dma_bus_Adr, 
      dma_bus_rnw         => dma_bus_rnw, 
      dma_bus_ena         => dma_bus_ena, 
      dma_bus_acc         => dma_bus_acc, 
      dma_bus_dout        => dma_bus_dout,
      dma_bus_din         => dma_bus_din, 
      dma_bus_done        => dma_bus_done,
      dma_bus_unread      => dma_bus_unread,
      
      debug_dma           => debug_dma
   );
   
   igba_sound : entity work.gba_sound        
   generic map
   (
      turbosound => turbosound
   )   
   port map 
   ( 
      clk100               => clk100,
      gb_on                => gbaon,
      reset                => reset,
      
      savestate_bus        => savestate_bus,
      loading_savestate    => loading_savestate,
      
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
      reset                => reset,
      
      savestate_bus        => savestate_bus,

      gb_bus               => gb_bus,

      lockspeed            => GBA_lockspeed,
      interframe_blend     => interframe_blend,
      maxpixels            => maxpixels,
      shade_mode           => shade_mode,
      hdmode2x_bg          => hdmode2x_bg,
      hdmode2x_obj         => hdmode2x_obj,
      
      bitmapdrawmode       => bitmapdrawmode,

      pixel_out_x          => pixel_out_x,
      pixel_out_2x         => pixel_out_2x, 
      pixel_out_y          => pixel_out_y,
      pixel_out_addr       => pixel_out_addr,
      pixel_out_data       => pixel_out_data,
      pixel_out_we         => pixel_out_we,  
       
      pixel2_out_x         => pixel2_out_x,   
      pixel2_out_data      => pixel2_out_data,
      pixel2_out_we        => pixel2_out_we,  
      
      new_cycles           => new_cycles,      
      new_cycles_valid     => new_cycles_valid,
              
      IRP_HBlank           => IRP_HBlank,
      IRP_VBlank           => IRP_VBlank,      
      IRP_LCDStat          => IRP_LCDStat,  

      hblank_trigger       => hblank_trigger,
      vblank_trigger       => vblank_trigger,
      videodma_start       => videodma_start,
      videodma_stop        => videodma_stop ,   
                        
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
      vram_blocked         => vram_blocked,        
                         
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
      clk100            => clk100,
      gb_on             => gbaon,
      reset             => reset,
                            
      savestate_bus     => savestate_bus,
      loading_savestate => loading_savestate,
      
      gb_bus            => gb_bus,
      new_cycles        => new_cycles,      
      new_cycles_valid  => new_cycles_valid,
      IRP_Timer         => IRP_Timer,
                        
      timer0_tick       => timer0_tick,
      timer1_tick       => timer1_tick,
                        
      debugout0         => timerdebug0,
      debugout1         => timerdebug1,
      debugout2         => timerdebug2,
      debugout3         => timerdebug3
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
      reset            => reset,
      
      savestate_bus    => savestate_bus,
      
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
      
      Underclock       => Underclock,
      
      settle           => settle,
      dma_on           => dma_on,
      do_step          => gba_step,
      done             => cpu_done,
      CPU_bus_idle     => CPU_bus_idle,
      PC_in_BIOS       => PC_in_BIOS,
      lastread         => lastread,
      jump_out         => cpu_jump,
      
      new_cycles_out   => new_cycles_cpu,
      new_cycles_valid => new_cycles_valid_cpu,
      
      dma_new_cycles   => dma_new_cycles,  
      dma_first_cycles => dma_first_cycles,
      dma_dword_cycles => dma_dword_cycles,
      dma_toROM        => dma_toROM,
      dma_init_cycles  => dma_init_cycles,
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
      
      debug_cpu_pc     => debug_cpu_pc,   
      debug_cpu_mixed  => debug_cpu_mixed
   );
   
   new_cycles       <= x"01"           when GBA_cputurbo = '1' or DEBUG_NOCPU = '1' or vram_cycle = '1' else new_cycles_cpu      ;
   new_cycles_valid <= new_exact_cycle when GBA_cputurbo = '1' or DEBUG_NOCPU = '1' or vram_cycle = '1' else new_cycles_valid_cpu;
   
   iREG_IRP_IE  : entity work.eProcReg_gba generic map (work.pReg_gba_system.IRP_IE ) port map  (clk100, gb_bus, REG_IRP_IE , REG_IRP_IE );
   iREG_IRP_IF  : entity work.eProcReg_gba generic map (work.pReg_gba_system.IRP_IF ) port map  (clk100, gb_bus, IRPFLags   , REG_IRP_IF , IF_written);                                                                                                                   
   iREG_WAITCNT : entity work.eProcReg_gba generic map (work.pReg_gba_system.WAITCNT) port map  (clk100, gb_bus, REG_WAITCNT, REG_WAITCNT, WAITCNT_written);                                                                                                                     
   iREG_ISCGB   : entity work.eProcReg_gba generic map (work.pReg_gba_system.ISCGB  ) port map  (clk100, gb_bus, "0");                                                                                                                     
   iREG_IME     : entity work.eProcReg_gba generic map (work.pReg_gba_system.IME    ) port map  (clk100, gb_bus, REG_IME    , REG_IME    );                                                                                                                       
   iREG_POSTFLG : entity work.eProcReg_gba generic map (work.pReg_gba_system.POSTFLG) port map  (clk100, gb_bus, REG_POSTFLG, REG_POSTFLG);
   iREG_HALTCNT : entity work.eProcReg_gba generic map (work.pReg_gba_system.HALTCNT) port map  (clk100, gb_bus, (REG_HALTCNT'range => '0'), REG_HALTCNT, REG_HALTCNT_written);

   iSAVESTATE_IRP   : entity work.eProcReg_gba generic map (REG_SAVESTATE_IRP  ) port map (clk100, savestate_bus, IRPFLags , SAVESTATE_IRP);

   debug_irq(15 downto 0) <= IRPFLags;
   debug_irq(16) <= REG_IME(0);
   debug_irq(31 downto 17) <= (others => '0');

   ------------- interrupt
   process (clk100)
   begin
      if rising_edge(clk100) then
   
         gbaon <= GBA_on;
   
         if (reset = '1') then -- reset
   
            IRPFLags <= SAVESTATE_IRP;
   
         elsif (gbaon = '1') then
         
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
            --if (IRP_Gamepak = '1')  then IRPFLags(13) <= '1'; end if; -- not implemented
            
            cpu_IRP <= '0';
            if ((IRPFLags and REG_IRP_IE) /= x"0000" and REG_IME(0) = '1') then
               cpu_IRP <= '1';
            end if;
            
            new_halt <= '0';
            if (REG_HALTCNT_written = '1' and loading_savestate = '0') then
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
         
         new_missing     <= '0';
         new_exact_cycle <= '0';
         
         new_cycles_ahead := cycles_ahead;
         if (new_cycles_valid = '1') then
            new_cycles_ahead := new_cycles_ahead + to_integer(new_cycles);
         end if;
         
         if (cycles_16_100 < (SPEEDDIV - 1)) then
            cycles_16_100 <= cycles_16_100 + 1;
         else
            cycles_16_100   <= 0;
            new_exact_cycle <= '1';
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
         if (DEBUG_NOCPU = '0' and sleep_savestate = '0' and sleep_cheats = '0' and sleep_rewind = '0' and 
            (GBA_lockspeed = '0' or GBA_cputurbo = '1' or cycles_ahead < unsigned(CyclePrecalc))) then
            gba_step <= '1';
         end if;
      
         if (GBA_lockspeed = '0' or gbaon = '0') then
            CyclesMissing <= (others => '0');
         elsif (new_missing = '1') then
            CyclesMissing <= std_logic_vector(unsigned(CyclesMissing) + 1);
         end if;
         
         
         if (bench_slow < 1685375) then -- vsync time
            bench_slow <= bench_slow + 1;
         end if;
         if (bench_slow = 1685375) then
            CyclesVsyncSpeed <= std_logic_vector(CyclesVsync);
            CyclesVsync      <= (others => '0');
            bench_slow       <= 0;
         elsif (new_cycles_valid = '1') then
            CyclesVsync <= CyclesVsync + new_cycles;
         end if;
   
      end if;
   end process;
   
   -- large pixel out
   process (clk100)
   begin
      if rising_edge(clk100) then
         
         pixel_write_ena <= '0';
         if (pixel_out_we = '1') then
            pixel_write_addr <= pixel_out_2x / 2;
            if (pixel_out_2x mod 2 = 0) then
               pixel_write_data(17 downto 0) <= pixel_out_data;
            else
               pixel_write_data(35 downto 18) <= pixel_out_data;
               pixel_write_ena <= '1';
            end if;
         end if;
         
         pixel2_write_ena <= '0';
         if (pixel2_out_we = '1') then
            pixel2_write_addr <= pixel2_out_x / 2;
            if (pixel2_out_x mod 2 = 0) then
               pixel2_write_data(17 downto 0) <= pixel2_out_data;
            else
               pixel2_write_data(35 downto 18) <= pixel2_out_data;
               pixel2_write_ena <= '1';
            end if;
         end if;
   
      end if;
   end process;
   
   
   ilinebuffer_hd0: entity MEM.SyncRamDual
   generic map
   (
      DATA_WIDTH => 36,
      ADDR_WIDTH => 8
   )
   port map
   (
      clk        => clk100,
      
      addr_a     => pixel_write_addr,
      datain_a   => pixel_write_data,
      dataout_a  => open,
      we_a       => pixel_write_ena,
      re_a       => '0',
               
      addr_b     => pixelpos,
      datain_b   => (35 downto 0 => '0'),
      dataout_b  => linebuffer_data,
      we_b       => '0',
      re_b       => '1'
   );
   
   ilinebuffer_hd1: entity MEM.SyncRamDual
   generic map
   (
      DATA_WIDTH => 36,
      ADDR_WIDTH => 8
   )
   port map
   (
      clk        => clk100,
      
      addr_a     => pixel2_write_addr,
      datain_a   => pixel2_write_data,
      dataout_a  => open,
      we_a       => pixel2_write_ena,
      re_a       => '0',
               
      addr_b     => pixelpos2,
      datain_b   => (35 downto 0 => '0'),
      dataout_b  => linebuffer2_data,
      we_b       => '0',
      re_b       => '1'
   );
   
   process (clk100)
   begin
      if rising_edge(clk100) then
         
         largeimg_out_req <= '0';
         
         newframe_sreg <= newframe_sreg(1 downto 0) & largeimg_newframe;
         if (newframe_sreg(2 downto 1) = "01") then
            largeimg_out_base <= (std_logic_vector(to_unsigned(16#38000000# + frameoffset * 16#400000#, 32)));
         end if;
         
         case (state) is
         
            when IDLE =>
               if (pixel_out_y_1 /= pixel_out_y and pixel_write_ena = '1' and (hdmode2x_bg = '1' or hdmode2x_obj = '1')) then
                  pixel_out_y_1     <= pixel_out_y;
                  state             <= READPIXEL;
                  pixelpos          <= 0;
                  pixelpos2         <= 0;
                  pixeladdress      <= pixel_out_y * 1024;
                  if (pixel_out_y = 0) then
                     frameoffset <= current_frame;
                     --if (largeimg_singlebuf = '0') then
                        if (current_frame < 2) then
                           current_frame <= current_frame + 1;
                        else
                           current_frame <= 0;
                        end if;
                     --end if;
                  end if;
               end if;
               
            when READPIXEL => 
               state      <= WRITEPIXEL;
               firstpixel <= '1';
         
            when WRITEPIXEL =>
               firstpixel <= '0';
               if (largeimg_out_done = '1' or firstpixel = '1') then
                  
                  if (pixelcnt = 0) then
                     pixelcnt <= 1;
                     pixelpos <= pixelpos + 1;
                  else
                     pixelcnt  <= 0;
                     pixelpos2 <= pixelpos2 + 1;
                     if (pixelpos2 < 239) then
                        pixeladdress <= pixeladdress + 2;
                     else
                        state <= IDLE;
                     end if;
                  end if;

                  largeimg_out_req  <= '1';
                  case (pixelcnt) is
                     when 0 => 
                        largeimg_out_addr <= "1" & std_logic_vector(to_unsigned(pixeladdress + current_frame * 16#100000#, 25));
                        largeimg_out_data(31 downto  0) <= x"00" & linebuffer_data( 5 downto  0) & linebuffer_data( 5 downto  4) & linebuffer_data(11 downto  6) & linebuffer_data(11 downto 10) & linebuffer_data(17 downto 12) & linebuffer_data(17 downto 16);
                        largeimg_out_data(63 downto 32) <= x"00" & linebuffer_data(23 downto 18) & linebuffer_data(23 downto 22) & linebuffer_data(29 downto 24) & linebuffer_data(29 downto 28) & linebuffer_data(35 downto 30) & linebuffer_data(35 downto 34);
                     when 1 => 
                        largeimg_out_addr <= "1" & std_logic_vector(to_unsigned(pixeladdress + 512 + current_frame * 16#100000#, 25));
                        largeimg_out_data(31 downto  0) <= x"00" & linebuffer2_data( 5 downto  0) & linebuffer2_data( 5 downto  4) & linebuffer2_data(11 downto  6) & linebuffer2_data(11 downto 10) & linebuffer2_data(17 downto 12) & linebuffer2_data(17 downto 16);
                        largeimg_out_data(63 downto 32) <= x"00" & linebuffer2_data(23 downto 18) & linebuffer2_data(23 downto 22) & linebuffer2_data(29 downto 24) & linebuffer2_data(29 downto 28) & linebuffer2_data(35 downto 30) & linebuffer2_data(35 downto 34);
                     when others => null;
                  end case;
                  
               end if;
         
         end case;
         
         
   
      end if;
   end process;
   

end architecture;





