library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

library MEM;
use work.pProc_bus_gba.all;
use work.pReg_savestates.all;
use work.pDDR3.all;

entity gba_wrap is
   generic
   (
      Softmap_GBA_Gamerom_ADDR : integer; -- count: 8388608    -- 32 Mbyte Data for GameRom
      Softmap_GBA_FLASH_ADDR   : integer; -- count:  131072    -- 128/512 Kbyte Data for GBA Flash
      Softmap_GBA_EEPROM_ADDR  : integer; -- count:    8192    -- 8/32 Kbyte Data for GBA EEProm
      Softmap_SaveState_ADDR   : integer; -- count:  524288    -- 512 Kbyte Data for Savestate 
      Softmap_Rewind_ADDR      : integer; -- count:  524288*64 -- 64*512 Kbyte Data for Savestates
      is_simu                  : std_logic := '0';
      turbosound               : std_logic  -- sound buffer to play sound in turbo mode without sound pitched up
   );
   port 
   (
      clk1x                 : in     std_logic;  
      clk3x                 : in     std_logic;  
      clk6x                 : in     std_logic;  
      -- settings                 
      GBA_on                : in     std_logic;  -- switching from off to on = reset
      pause                 : in     std_logic;
      inPause               : out    std_logic;
      GBA_lockspeed         : in     std_logic;  -- 1 = 100% speed, 0 = max speed
      GBA_cputurbo          : in     std_logic;  -- 1 = cpu free running, all other 16 mhz
      GBA_flash_1m          : in     std_logic;  -- 1 when string "FLASH1M_V" is anywhere in gamepak
      Underclock            : in     std_logic_vector(1 downto 0);
      MaxPakAddr            : in     std_logic_vector(24 downto 0); -- max byte address that will contain data, required for buggy games that read behind their own memory, e.g. zelda minish cap
      CyclesMissing         : out    std_logic_vector(31 downto 0); -- debug only for speed measurement, keep open
      CyclesVsyncSpeed      : out    std_logic_vector(31 downto 0); -- debug only for speed measurement, keep open
      SramFlashEnable       : in     std_logic;
      memory_remap          : in     std_logic;
      increaseSSHeaderCount : in     std_logic;
      save_state            : in     std_logic;
      load_state            : in     std_logic;
      interframe_blend      : in     std_logic_vector(1 downto 0); -- 0 = off, 1 = blend, 2 = 30hz
      shade_mode            : in     std_logic_vector(2 downto 0);
      borderOn              : in     std_logic;     
      videoHshift           : in     signed(3 downto 0);      
      videoVshift           : in     signed(2 downto 0);      
      specialmodule         : in     std_logic;                    -- 0 = off, 1 = use gamepak GPIO Port at address 0x080000C4..0x080000C8
      solar_in              : in     std_logic_vector(2 downto 0);
      tilt                  : in     std_logic;                    -- 0 = off, 1 = use tilt at address 0x0E008200, 0x0E008300, 0x0E008400, 0x0E008500
      overlay_error_on      : in     std_logic;  
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
      -- SDRAM           
      sdram_Din             : out    std_logic_vector(31 downto 0);  
      sdram_Adr             : out    std_logic_vector(26 downto 0); 
      sdram_rnw             : out    std_logic;                     
      sdram_ena             : out    std_logic;              
      sdram_cancel          : out    std_logic;              
      sdram_refresh         : out    std_logic;              
      sdram_Dout            : in     std_logic_vector(31 downto 0);      
      sdram_done16          : in     std_logic;                     
      sdram_done32          : in     std_logic;  
      -- DDR3 
      ddr3_BUSY             : in     std_logic;                    
      ddr3_DOUT             : in     std_logic_vector(63 downto 0);
      ddr3_DOUT_READY       : in     std_logic;
      ddr3_BURSTCNT         : out    std_logic_vector(7 downto 0) := (others => '0'); 
      ddr3_ADDR             : out    std_logic_vector(28 downto 0) := (others => '0');                       
      ddr3_DIN              : out    std_logic_vector(63 downto 0) := (others => '0');
      ddr3_BE               : out    std_logic_vector(7 downto 0) := (others => '0'); 
      ddr3_WE               : out    std_logic := '0';
      ddr3_RD               : out    std_logic := '0';   
      -- romcopy                     
      romcopy_start         : in     std_logic;
      romcopy_size          : in     unsigned(26 downto 0);
      rom_addr              : out    std_logic_vector(26 downto 0);
      rom_dout              : out    std_logic_vector(15 downto 0);
      rom_wr                : out    std_logic := '0';
      rom_copy              : out    std_logic := '0';
      romcopy_req           : out    std_logic := '0';
      romcopy_data          : out    std_logic_vector(31 downto 0);
      romcopy_writepos      : out    std_logic_vector(26 downto 0);
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
      KeyPause              : in     std_logic;
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
      pixel_out_data        : buffer std_logic_vector(14 downto 0);  -- RGB data for framebuffer 
      pixel_out_we          : buffer std_logic;                      -- new pixel for framebuffer 
      
      videoout_hsync        : out    std_logic := '0';
      videoout_vsync        : out    std_logic := '0';
      videoout_hblank       : out    std_logic := '0';
      videoout_vblank       : out    std_logic := '0';
      videoout_ce           : out    std_logic;
      videoout_interlace    : out    std_logic;
      videoout_r            : out    std_logic_vector(7 downto 0);
      videoout_g            : out    std_logic_vector(7 downto 0);
      videoout_b            : out    std_logic_vector(7 downto 0);
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

architecture arch of gba_wrap is

   signal clk1xToggle       : std_logic := '0';

   signal clk1xToggle6X     : std_logic := '0';
   signal clk1xToggle6X_1   : std_logic := '0';
   signal clk6xIndex        : unsigned(2 downto 0) := (others => '0');
   
   signal vblank_trigger    : std_logic;
   signal inPauseCore       : std_logic;
   signal requestPause      : std_logic;
   signal allowUnpause      : std_logic;
   
   signal cart_ena          : std_logic;
   signal cart_idle         : std_logic;
   signal cart_32           : std_logic;
   signal cart_rnw          : std_logic;
   signal cart_addr         : std_logic_vector(27 downto 0);
   signal cart_writedata    : std_logic_vector(7 downto 0);
   signal cart_done         : std_logic;
   signal cart_readdata     : std_logic_vector(31 downto 0);
   signal cart_waitcnt      : std_logic_vector(15 downto 0);
   signal dma_eepromcount   : unsigned(16 downto 0);
   signal cart_reset        : std_logic; 
   
   signal MaxPakAddr_modified  : std_logic_vector(24 downto 0);
   
   signal SAVE_out_Din      : std_logic_vector(63 downto 0);
   signal SAVE_out_Dout     : std_logic_vector(63 downto 0);
   signal SAVE_out_Adr      : std_logic_vector(25 downto 0);
   signal SAVE_out_rnw      : std_logic;                    
   signal SAVE_out_ena      : std_logic;                                
   signal SAVE_out_be       : std_logic_vector(7 downto 0);
   signal SAVE_out_done     : std_logic;                    
   
   signal GPIO_done         : std_logic;
   signal GPIO_readEna      : std_logic;
   signal GPIO_Din          : std_logic_vector(3 downto 0);
   signal GPIO_Dout         : std_logic_vector(3 downto 0);
   signal GPIO_writeEna     : std_logic;
   signal GPIO_addr         : std_logic_vector(1 downto 0);
   
   signal savestate_bus_ext : proc_bus_gb_type;
   signal ss_wired_out_ext  : std_logic_vector(proc_buswidth-1 downto 0) := (others => '0');
   signal ss_wired_done_ext : std_logic;
   
   type t_ss_wired_or is array(0 to 1) of std_logic_vector(31 downto 0);
   signal save_wired_or        : t_ss_wired_or;   
   signal save_wired_done      : unsigned(0 to 1);

   signal rdram_request    : tDDDR3Single;
   signal rdram_rnw        : tDDDR3Single;    
   signal rdram_address    : tDDDR3ReqAddr;
   signal rdram_burstcount : tDDDR3Burstcount;  
   signal rdram_writeMask  : tDDDR3BwriteMask;  
   signal rdram_dataWrite  : tDDDR3BwriteData;
   signal rdram_granted    : tDDDR3Single;
   signal rdram_done       : tDDDR3Single;
   signal rdram_ready      : tDDDR3Single;
   signal rdram_dataRead   : std_logic_vector(63 downto 0);
   
   signal gpufifo_reset    : std_logic; 
   signal gpufifo_Din      : std_logic_vector(33 downto 0); -- 16bit data + 18 bit address
   signal gpufifo_Wr       : std_logic;  
   signal gpufifo_nearfull : std_logic;  
   signal gpufifo_empty    : std_logic;
   signal gpufifo_Frame    : std_logic_vector(1 downto 0);
   
   signal pixel_core_x           : integer range 0 to 239;
   signal pixel_core_y           : integer range 0 to 159;
   signal pixel_core_data        : std_logic_vector(14 downto 0);  
   signal pixel_core_we          : std_logic := '0';   
   
   signal shader_mode            : std_logic_vector(2 downto 0);
   signal pixel_shade_x          : integer range 0 to 239;
   signal pixel_shade_y          : integer range 0 to 159;
   signal pixel_shade_data       : std_logic_vector(17 downto 0);  
   signal pixel_shade_we         : std_logic := '0';
   
   signal colorR                 : unsigned(7 downto 0);
   signal colorG                 : unsigned(7 downto 0);
   signal colorB                 : unsigned(7 downto 0);
   signal luma                   : unsigned(7 downto 0);
   signal colorRdesat            : unsigned(7 downto 0);
   signal colorGdesat            : unsigned(7 downto 0);
   signal colorBdesat            : unsigned(7 downto 0);
   
   signal pixel_data             : std_logic_vector(14 downto 0);
   signal errortext              : unsigned(31 downto 0);
   signal overlay_error_data     : std_logic_vector(14 downto 0);
   signal overlay_error_ena      : std_logic;   
      
   signal errorEna               : std_logic;
   signal errorCode              : unsigned(15 downto 0) := (others => '0');
   signal error_cpu              : std_logic;
   signal error_memRequ_timeout  : std_logic;
   signal error_memResp_timeout  : std_logic;
   signal error_refresh          : std_logic;
   
   signal flash_busy             : std_logic;
  
   -- romcopy
   type tROMCOPYSTATE is
   (
      ROMCOPY_IDLE,
      ROMCOPY_CLEANSAVERAM,
      ROMCOPY_READDDR3,
      ROMCOPY_WRITESDRAM1,
      ROMCOPY_WRITESDRAM2,
      ROMCOPY_WRITESDRAM3,
      ROMCOPY_WRITESDRAM4,
      ROMCOPY_NEXT
   );
   signal ROMCOPYSTATE : tROMCOPYSTATE := ROMCOPY_IDLE;
   
   signal romcopy_writedata : std_logic_vector(63 downto 0);
   
   signal GBA_on1X : std_logic := '0';

begin 

   igba_top : entity work.gba_top
   generic map
   (
      Softmap_GBA_Gamerom_ADDR => Softmap_GBA_Gamerom_ADDR,
      Softmap_GBA_FLASH_ADDR   => Softmap_GBA_FLASH_ADDR  ,
      Softmap_GBA_EEPROM_ADDR  => Softmap_GBA_EEPROM_ADDR ,
      Softmap_SaveState_ADDR   => Softmap_SaveState_ADDR  ,
      Softmap_Rewind_ADDR      => Softmap_Rewind_ADDR     ,
      is_simu                  => is_simu                 ,
      turbosound               => turbosound              
   )
   port map
   (
      clk1x                 => clk1x                ,       
      -- settings                                   
      GBA_on                => GBA_on1X             ,
      pause                 => pause or (requestPause and (not is_simu)),
      allowUnpause          => allowUnpause         ,
      inPause               => inPauseCore          ,
      GBA_lockspeed         => GBA_lockspeed        ,
      GBA_cputurbo          => GBA_cputurbo         ,
      GBA_flash_1m          => GBA_flash_1m         ,
      Underclock            => Underclock           ,
      CyclesMissing         => CyclesMissing        ,
      CyclesVsyncSpeed      => CyclesVsyncSpeed     ,
      increaseSSHeaderCount => increaseSSHeaderCount,
      save_state            => save_state           ,
      load_state            => load_state           ,
      interframe_blend      => interframe_blend     ,
      shade_mode            => shade_mode           ,
      rewind_on             => rewind_on            ,
      rewind_active         => rewind_active        ,
      savestate_number      => savestate_number     ,
      -- errors
      error_cpu             => error_cpu,
      error_memRequ_timeout => error_memRequ_timeout,
      error_memResp_timeout => error_memResp_timeout,
      flash_busy            => flash_busy,
      -- cheats                                     
      cheat_clear           => cheat_clear          ,
      cheats_enabled        => cheats_enabled       ,
      cheat_on              => cheat_on             ,
      cheat_in              => cheat_in             ,
      cheats_active         => cheats_active        ,
      -- cart interface                            
      cart_ena              => cart_ena,      
      cart_idle             => cart_idle,      
      cart_32               => cart_32,      
      cart_rnw              => cart_rnw,      
      cart_addr             => cart_addr,     
      cart_writedata        => cart_writedata,
      cart_done             => cart_done,     
      cart_readdata         => cart_readdata, 
      cart_waitcnt          => cart_waitcnt,
      dma_eepromcount       => dma_eepromcount, 
      cart_reset            => cart_reset,
      -- savestate                                  
      SAVE_out_Din          => SAVE_out_Din         ,
      SAVE_out_Dout         => SAVE_out_Dout        ,
      SAVE_out_Adr          => SAVE_out_Adr         ,
      SAVE_out_rnw          => SAVE_out_rnw         ,
      SAVE_out_ena          => SAVE_out_ena         ,
      SAVE_out_active       => open      ,
      SAVE_out_be           => SAVE_out_be          ,
      SAVE_out_done         => SAVE_out_done        ,
      
      savestate_bus_ext     => savestate_bus_ext    ,
      ss_wired_out_ext      => ss_wired_out_ext     , 
      ss_wired_done_ext     => ss_wired_done_ext    ,
      -- Write to BIOS                              
      bios_wraddr           => bios_wraddr          ,
      bios_wrdata           => bios_wrdata          ,
      bios_wr               => bios_wr              ,
      -- save memory used                           
      load_done             => load_done            ,
      -- Keys                                       
      KeyA                  => KeyA                 ,
      KeyB                  => KeyB                 ,
      KeySelect             => KeySelect            ,
      KeyStart              => KeyStart             ,
      KeyRight              => KeyRight             ,
      KeyLeft               => KeyLeft              ,
      KeyUp                 => KeyUp                ,
      KeyDown               => KeyDown              ,
      KeyR                  => KeyR                 ,
      KeyL                  => KeyL                 ,
      KeyPause              => KeyPause             ,
      -- debug interface                            
      GBA_BusAddr           => GBA_BusAddr          ,
      GBA_BusRnW            => GBA_BusRnW           ,
      GBA_BusACC            => GBA_BusACC           ,
      GBA_BusWriteData      => GBA_BusWriteData     ,
      GBA_BusReadData       => GBA_BusReadData      ,
      GBA_Bus_written       => GBA_Bus_written      ,
      -- display data                               
      pixel_out_x           => pixel_core_x         ,
      pixel_out_y           => pixel_core_y         ,
      pixel_out_data        => pixel_core_data      ,
      pixel_out_we          => pixel_core_we        ,
      vblank_trigger        => vblank_trigger       ,
      -- sound                                      
      sound_out_left        => sound_out_left       ,
      sound_out_right       => sound_out_right      ,
      -- debug                                      
      debug_cpu_pc          => debug_cpu_pc         ,
      debug_cpu_mixed       => debug_cpu_mixed      ,
      debug_irq             => debug_irq            ,
      debug_dma             => debug_dma            ,
      debug_mem             => debug_mem            
   );

   process (save_wired_or)
      variable wired_or : std_logic_vector(31 downto 0);
   begin
      wired_or := save_wired_or(0);
      for i in 1 to (save_wired_or'length - 1) loop
         wired_or := wired_or or save_wired_or(i);
      end loop;
      ss_wired_out_ext <= wired_or;
   end process;
   ss_wired_done_ext <= '0' when (save_wired_done = 0) else '1';

   -- clock index
   process (clk1x)
   begin
      if rising_edge(clk1x) then
         clk1xToggle <= not clk1xToggle;
      end if;
   end process;
   
   process (clk6x)
   begin
      if rising_edge(clk6x) then
         clk1xToggle6x   <= clk1xToggle;
         clk1xToggle6X_1 <= clk1xToggle6X;
         
         if (clk1xToggle6x = '1' and clk1xToggle6X_1 = '0') then
            clk6xIndex <= "010";
         elsif (clk6xIndex = 5) then
            clk6xIndex <= (others => '0');
         else
            clk6xIndex <= clk6xIndex + 1;
         end if;
      end if;
   end process;
   
   process (clk6x)
   begin
      if rising_edge(clk6x) then
   
         if (memory_remap = '1') then
            MaxPakAddr_modified <= (others => '1');
         else
            MaxPakAddr_modified <= MaxPakAddr;
         end if;
         
      end if;
   end process;

   imemorymux_extern : entity work.memorymux_extern
   generic map
   (
      is_simu                  => is_simu,                 
      Softmap_GBA_Gamerom_ADDR => Softmap_GBA_Gamerom_ADDR,
      Softmap_GBA_FLASH_ADDR   => Softmap_GBA_FLASH_ADDR,  
      Softmap_GBA_EEPROM_ADDR  => Softmap_GBA_EEPROM_ADDR 
   )
   port map
   (
      clk1x                => clk1x,          
      clk6x                => clk6x,          
      clk6xIndex           => clk6xIndex,     
      reset                => cart_reset,     

      SramFlashEnable      => SramFlashEnable,

      error_refresh        => error_refresh,
      flash_busy           => flash_busy,
                                               
      savestate_bus        => savestate_bus_ext,  
      ss_wired_out         => save_wired_or(0),   
      ss_wired_done        => save_wired_done(0),  
                    
      cart_ena             => cart_ena,      
      cart_idle            => cart_idle,      
      cart_32              => cart_32,          
      cart_rnw             => cart_rnw,      
      cart_addr            => cart_addr,     
      cart_writedata       => cart_writedata,
      cart_done            => cart_done,     
      cart_readdata        => cart_readdata, 
      
      cart_waitcnt         => cart_waitcnt,
                    
      sdram_Din            => sdram_Din,      
      sdram_Adr            => sdram_Adr,    
      sdram_rnw            => sdram_rnw,    
      sdram_ena            => sdram_ena,    
      sdram_cancel         => sdram_cancel,    
      sdram_refresh        => sdram_refresh,
      sdram_Dout           => sdram_Dout,   
      sdram_done16         => sdram_done16, 
      sdram_done32         => sdram_done32, 
                                             
      specialmodule        => specialmodule,  
      GPIO_readEna         => GPIO_readEna,   
      GPIO_done            => GPIO_done,      
      GPIO_Din             => GPIO_Din,       
      GPIO_Dout            => GPIO_Dout,      
      GPIO_writeEna        => GPIO_writeEna,  
      GPIO_addr            => GPIO_addr,      
                                             
      dma_eepromcount      => dma_eepromcount,
      flash_1m             => GBA_flash_1m,       
      MaxPakAddr           => MaxPakAddr_modified,     
      memory_remap         => memory_remap,   
                          
      save_eeprom          => save_eeprom,    
      save_sram            => save_sram,      
      save_flash           => save_flash,     
                                             
      tilt                 => tilt,           
      AnalogTiltX          => AnalogTiltX,    
      AnalogTiltY          => AnalogTiltY    
   );
   
   igba_gpioRTCSolarGyro : entity work.gba_gpioRTCSolarGyro
   port map
   (
      clk1x                => clk1x, 
      reset                => cart_reset,
      GBA_on               => GBA_on,
                                         
      savestate_bus        => savestate_bus_ext,
      ss_wired_out         => save_wired_or(1),
      ss_wired_done        => save_wired_done(1),
                                         
      GPIO_readEna         => GPIO_readEna, 
      GPIO_done            => GPIO_done,   
      GPIO_Din             => GPIO_Din,     
      GPIO_Dout            => GPIO_Dout,    
      GPIO_writeEna        => GPIO_writeEna,
      GPIO_addr            => GPIO_addr,
      
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
   
   shader_mode <= shade_mode when (unsigned(shade_mode) < 5) else "000";
   igba_gpu_colorshade : entity work.gba_gpu_colorshade
   port map
   (
      clk                  => clk1x,
                           
      shade_mode           => shader_mode,
                           
      pixel_in_x           => pixel_core_x,   
      pixel_in_y           => pixel_core_y,   
      pixel_in_data        => pixel_core_data,
      pixel_in_we          => pixel_core_we,
                  
      pixel_out_x          => pixel_shade_x,     
      pixel_out_y          => pixel_shade_y,  
      pixel_out_data       => pixel_shade_data,
      pixel_out_we         => pixel_shade_we  
   );   
   
   inPause <= inPauseCore;
   
   ivideoout160 : entity work.videoout160
   port map
   (
      clk1x                   => clk1x,
      clk3x                   => clk3x,
      
      blend                   => interframe_blend(0),
      borderOn                => borderOn,
      videoHshift             => videoHshift,
      videoVshift             => videoVshift,
      
      pixel_x                 => pixel_shade_x,   
      pixel_y                 => pixel_shade_y,   
      pixel_we                => pixel_shade_we, 
      vblank_trigger          => vblank_trigger, 

      nextFrame_out           => gpufifo_Frame,
      
      inPause                 => inPauseCore,
      requestPause            => requestPause,
      allowUnpause            => allowUnpause,

      ddr3_request            => rdram_request(DDR3MUX_VIDEOOUT),
      ddr3_address            => rdram_address(DDR3MUX_VIDEOOUT),
      ddr3_burstcnt           => rdram_burstcount(DDR3MUX_VIDEOOUT),
      ddr3_ready              => rdram_ready(DDR3MUX_VIDEOOUT),
      ddr3_done               => rdram_done(DDR3MUX_VIDEOOUT),
      ddr3_data               => ddr3_DOUT,
      
      videoout_hsync          => videoout_hsync,    
      videoout_vsync          => videoout_vsync,    
      videoout_hblank         => videoout_hblank,   
      videoout_vblank         => videoout_vblank,   
      videoout_ce             => videoout_ce,       
      videoout_interlace      => videoout_interlace,
      videoout_r              => colorR,        
      videoout_g              => colorG,        
      videoout_b              => colorB        
   );

   luma   <= "00" & colorR(7 downto 2) + colorG(7 downto 1) + colorG(7 downto 3) + colorB(7 downto 3);
   
   colorRdesat <= '0' & colorR(7 downto 1) + colorR(7 downto 2) +   luma(7 downto 2) when (shade_mode = "101") else 
                  '0' & colorR(7 downto 1) +   luma(7 downto 1)                      when (shade_mode = "110") else 
                  '0' &   luma(7 downto 1) +   luma(7 downto 2) + colorR(7 downto 2) when (shade_mode = "111") else 
                  colorR;
  
   colorGdesat <= '0' & colorG(7 downto 1) + colorG(7 downto 2) +   luma(7 downto 2) when (shade_mode = "101") else 
                  '0' & colorG(7 downto 1) +   luma(7 downto 1)                      when (shade_mode = "110") else 
                  '0' &   luma(7 downto 1) +   luma(7 downto 2) + colorG(7 downto 2) when (shade_mode = "111") else 
                  colorG;

   colorBdesat <= '0' & colorB(7 downto 1) + colorB(7 downto 2) +   luma(7 downto 2) when (shade_mode = "101") else 
                  '0' & colorB(7 downto 1) +   luma(7 downto 1)                      when (shade_mode = "110") else 
                  '0' &   luma(7 downto 1) +   luma(7 downto 2) + colorB(7 downto 2) when (shade_mode = "111") else 
                  colorB;                 
   
   videoout_r <= std_logic_vector(colorRdesat);
   videoout_g <= std_logic_vector(colorGdesat);
   videoout_b <= std_logic_vector(colorBdesat);
   
   
   process (clk1x)
   begin
      if rising_edge(clk1x) then
         if (cart_reset = '1') then
            errorCode <= (others => '0');
         else
            if (error_cpu = '1')             then errorCode(0) <= '1'; end if;
            if (error_memRequ_timeout = '1') then errorCode(1) <= '1'; end if;
            if (error_memResp_timeout = '1') then errorCode(2) <= '1'; end if;
            if (error_refresh = '1')         then errorCode(3) <= '1'; end if;
         end if;
      end if;
   end process;
   
   errortext( 7 downto  0) <= resize(errorCode( 3 downto  0), 8) + 16#30# when (errorCode( 3 downto  0) < 10) else resize(errorCode( 3 downto  0), 8) + 16#37#;
   errortext(15 downto  8) <= resize(errorCode( 7 downto  4), 8) + 16#30# when (errorCode( 7 downto  4) < 10) else resize(errorCode( 7 downto  4), 8) + 16#37#;
   errortext(23 downto 16) <= resize(errorCode(11 downto  8), 8) + 16#30# when (errorCode(11 downto  8) < 10) else resize(errorCode(11 downto  8), 8) + 16#37#;
   errortext(31 downto 24) <= resize(errorCode(15 downto 12), 8) + 16#30# when (errorCode(15 downto 12) < 10) else resize(errorCode(15 downto 12), 8) + 16#37#;
   
   errorEna <= '1' when (errorCode /= x"0000" and overlay_error_on = '1') else '0';
   
   ioverlayError : entity work.overlay generic map (5, 2, 2, 15x"7C00", 15x"7FFF")
   port map
   (
      clk                    => clk1x,
      ce                     => '1',
      ena                    => errorEna,                    
      i_pixel_out_x          => pixel_out_x,
      i_pixel_out_y          => pixel_out_y,
      o_pixel_out_data       => overlay_error_data,
      o_pixel_out_ena        => overlay_error_ena,
      textstring             => x"45" & errortext
   ); 
   
   pixel_out_x    <= pixel_shade_x; 
   pixel_out_y    <= pixel_shade_y; 
   pixel_out_we   <= pixel_shade_we;
   pixel_out_data <= overlay_error_data when (overlay_error_ena = '1') else pixel_shade_data(17 downto 13) & pixel_shade_data(11 downto 7) & pixel_shade_data(5 downto 1);
   
   rdram_rnw(DDR3MUX_VIDEOOUT)        <= '1';
   rdram_writeMask(DDR3MUX_VIDEOOUT)  <= x"FF";
   rdram_dataWrite(DDR3MUX_VIDEOOUT)  <= 64x"0";
   
   rdram_request(DDR3MUX_SS)    <= SAVE_out_ena;
   rdram_rnw(DDR3MUX_SS)        <= SAVE_out_rnw;
   rdram_address(DDR3MUX_SS)    <= unsigned(SAVE_out_Adr) & "00";
   rdram_burstcount(DDR3MUX_SS) <= 10x"01";
   rdram_writeMask(DDR3MUX_SS)  <= SAVE_out_be;
   rdram_dataWrite(DDR3MUX_SS)  <= SAVE_out_Din;
   SAVE_out_done                <= rdram_ready(DDR3MUX_SS) when (SAVE_out_rnw = '1') else rdram_done(DDR3MUX_SS);
   SAVE_out_Dout                <= ddr3_DOUT;
   
   gpufifo_reset  <= '0';
   gpufifo_Din    <= gpufifo_Frame & std_logic_vector(to_unsigned(pixel_out_y,8)) & std_logic_vector(to_unsigned(pixel_out_x,8)) & '0' & pixel_out_data;
   gpufifo_Wr     <= pixel_out_we;
   
   iDDR3Mux : entity work.DDR3Mux
   port map
   (
      clk1x            => clk1x,
      
      error            => open,
      error_fifo       => open,

      ddr3_BUSY        => ddr3_BUSY,       
      ddr3_DOUT        => ddr3_DOUT,       
      ddr3_DOUT_READY  => ddr3_DOUT_READY, 
      ddr3_BURSTCNT    => ddr3_BURSTCNT,   
      ddr3_ADDR        => ddr3_ADDR,       
      ddr3_DIN         => ddr3_DIN,        
      ddr3_BE          => ddr3_BE,         
      ddr3_WE          => ddr3_WE,         
      ddr3_RD          => ddr3_RD,         
                       
      rdram_request    => rdram_request,   
      rdram_rnw        => rdram_rnw,       
      rdram_address    => rdram_address,   
      rdram_burstcount => rdram_burstcount,
      rdram_writeMask  => rdram_writeMask, 
      rdram_dataWrite  => rdram_dataWrite, 
      rdram_granted    => rdram_granted,   
      rdram_done       => rdram_done,      
      rdram_ready      => rdram_ready,      
      rdram_dataRead   => rdram_dataRead,  
                       
      gpufifo_reset    => gpufifo_reset,   
      gpufifo_Din      => gpufifo_Din,     
      gpufifo_Wr       => gpufifo_Wr,      
      gpufifo_nearfull => gpufifo_nearfull,
      gpufifo_empty    => gpufifo_empty   
   );
   
   rdram_rnw(DDR3MUX_ROMCOPY)        <= '1';
   rdram_burstcount(DDR3MUX_ROMCOPY) <= 10x"01";
   rdram_writeMask(DDR3MUX_ROMCOPY)  <= x"FF";
   rdram_dataWrite(DDR3MUX_ROMCOPY)  <= 64x"0";

   process (clk1x)
   begin
      if (rising_edge(clk1x)) then
   
         GBA_on1X <= '0';
         if (GBA_on = '1' and ROMCOPYSTATE = ROMCOPY_IDLE) then
            GBA_on1X <= '1';
         end if;
         
      end if;
   end process;

   process (clk6x)
   begin
      if (rising_edge(clk6x)) then
      
         if (clk6xIndex = 5) then
            rdram_request(DDR3MUX_ROMCOPY) <= '0'; 
         end if;
         rom_wr      <= '0';
         romcopy_req <= '0';
         
         case (ROMCOPYSTATE) is
         
            when ROMCOPY_IDLE =>
               rom_copy <= '0';
               rdram_address(DDR3MUX_ROMCOPY) <= x"0080000";
               rom_addr                       <= (others => '0');
               romcopy_writepos               <= 27x"0000000";
               if (romcopy_start = '1') then
                  ROMCOPYSTATE <= ROMCOPY_CLEANSAVERAM;
                  rom_copy     <= '1';
                  romcopy_req  <= '1';
                  romcopy_data <= (others => '1');
               end if;
               
            when ROMCOPY_CLEANSAVERAM =>
               if (sdram_done16 = '1') then
                  romcopy_writepos <= std_logic_vector(unsigned(romcopy_writepos) + 4);
                  if (romcopy_writepos = 27x"007FFFC") then
                     ROMCOPYSTATE                   <= ROMCOPY_READDDR3;
                     rdram_request(DDR3MUX_ROMCOPY) <= '1';
                  else
                     romcopy_req      <= '1';
                  end if;
               end if;

            when ROMCOPY_READDDR3 => 
               if (rdram_done(DDR3MUX_ROMCOPY) = '1') then
                  ROMCOPYSTATE      <= ROMCOPY_WRITESDRAM1;
                  romcopy_writedata <= rdram_dataRead;
                  rdram_address(DDR3MUX_ROMCOPY) <= rdram_address(DDR3MUX_ROMCOPY) + 8;
               end if;
               
            when ROMCOPY_WRITESDRAM1 => 
               ROMCOPYSTATE <= ROMCOPY_WRITESDRAM2; 
               rom_wr       <= '1';
               rom_dout     <= romcopy_writedata(15 downto 0); 
               romcopy_writedata(47 downto 0) <= romcopy_writedata(63 downto 16);
               romcopy_req  <= '1';
               romcopy_data <= romcopy_writedata(31 downto 0); 
            
            when ROMCOPY_WRITESDRAM2 =>   
               if (sdram_done16 = '1') then
                  ROMCOPYSTATE     <= ROMCOPY_WRITESDRAM3; 
                  rom_wr           <= '1';
                  rom_dout         <= romcopy_writedata(15 downto 0);
                  rom_addr         <= std_logic_vector(unsigned(rom_addr) + 2);      
                  romcopy_writepos <= std_logic_vector(unsigned(romcopy_writepos) + 4);      
                  romcopy_writedata(47 downto 0) <= romcopy_writedata(63 downto 16);
               end if;
               
            when ROMCOPY_WRITESDRAM3 =>   
               ROMCOPYSTATE <= ROMCOPY_WRITESDRAM4; 
               rom_wr       <= '1';
               rom_dout     <= romcopy_writedata(15 downto 0);
               rom_addr     <= std_logic_vector(unsigned(rom_addr) + 2);      
               romcopy_writedata(47 downto 0) <= romcopy_writedata(63 downto 16);
               romcopy_req  <= '1';
               romcopy_data <= romcopy_writedata(31 downto 0);
               
            when ROMCOPY_WRITESDRAM4 =>   
               if (sdram_done16 = '1') then
                  ROMCOPYSTATE <= ROMCOPY_NEXT; 
                  rom_wr       <= '1';
                  rom_dout     <= romcopy_writedata(15 downto 0);
                  rom_addr     <= std_logic_vector(unsigned(rom_addr) + 2); 
                                
               end if;
            
            when ROMCOPY_NEXT => 
               rom_addr         <= std_logic_vector(unsigned(rom_addr) + 2); 
               romcopy_writepos <= std_logic_vector(unsigned(romcopy_writepos) + 4);       
               if (unsigned(rom_addr) + 2 < unsigned(romcopy_size)) then
                  ROMCOPYSTATE <= ROMCOPY_READDDR3; 
                  rdram_request(DDR3MUX_ROMCOPY) <= '1';   
               else
                  ROMCOPYSTATE <= ROMCOPY_IDLE;
               end if;
               
         end case;
      
      end if;
   end process;

end architecture;





