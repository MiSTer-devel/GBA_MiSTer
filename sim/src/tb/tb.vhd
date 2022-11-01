library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

library tb;
library top;
library gba;

library procbus;
use procbus.pProc_bus.all;
use procbus.pRegmap.all;

library reg_map;
use reg_map.pReg_gameboy.all;

entity etb  is
end entity;

architecture arch of etb is

   constant clk_speed : integer := 100000000;
   constant baud      : integer := 25000000;
 
   signal clk100      : std_logic := '1';
   
   signal command_in  : std_logic;
   signal command_out : std_logic;
   signal command_out_filter : std_logic;
   
   signal proc_bus_in : proc_bus_type;
   
   -- settings
   signal GBA_on            : std_logic_vector(Reg_GBA_on.upper             downto Reg_GBA_on.lower)             := (others => '0');
   signal GBA_lockspeed     : std_logic_vector(Reg_GBA_lockspeed.upper      downto Reg_GBA_lockspeed.lower)      := (others => '0');
   signal GBA_cputurbo      : std_logic_vector(Reg_GBA_cputurbo.upper       downto Reg_GBA_cputurbo.lower)       := (others => '0');
   signal GBA_SramFlashEna  : std_logic_vector(Reg_GBA_SramFlashEna.upper   downto Reg_GBA_SramFlashEna.lower)   := (others => '0');
   signal GBA_MemoryRemap   : std_logic_vector(Reg_GBA_MemoryRemap.upper    downto Reg_GBA_MemoryRemap.lower)    := (others => '0');
   signal GBA_SaveState     : std_logic_vector(Reg_GBA_SaveState.upper      downto Reg_GBA_SaveState.lower)      := (others => '0');
   signal GBA_LoadState     : std_logic_vector(Reg_GBA_LoadState.upper      downto Reg_GBA_LoadState.lower)      := (others => '0');
   signal GBA_FrameBlend    : std_logic_vector(Reg_GBA_FrameBlend.upper     downto Reg_GBA_FrameBlend.lower)     := (others => '0');
   signal GBA_Pixelshade    : std_logic_vector(Reg_GBA_Pixelshade.upper     downto Reg_GBA_Pixelshade.lower)     := (others => '0');
   signal GBA_SaveStateAddr : std_logic_vector(Reg_GBA_SaveStateAddr.upper  downto Reg_GBA_SaveStateAddr.lower)  := (others => '0');
   signal GBA_Rewind_on     : std_logic_vector(Reg_GBA_Rewind_on    .upper  downto Reg_GBA_Rewind_on    .lower)  := (others => '0');
   signal GBA_Rewind_active : std_logic_vector(Reg_GBA_Rewind_active.upper  downto Reg_GBA_Rewind_active.lower)  := (others => '0');
                            
   signal GBA_flash_1m      : std_logic_vector(Reg_GBA_flash_1m.upper       downto Reg_GBA_flash_1m.lower)       := (others => '0');
   signal CyclePrecalc      : std_logic_vector(Reg_GBA_CyclePrecalc.upper   downto Reg_GBA_CyclePrecalc.lower);
   signal CyclesMissing     : std_logic_vector(Reg_GBA_CyclesMissing.upper  downto Reg_GBA_CyclesMissing.lower)  := (others => '0');
   signal CyclesVsyncSpeed  : std_logic_vector(Reg_GBA_VsyncSpeed.upper     downto Reg_GBA_VsyncSpeed.lower);
                            
   signal MaxPakAddr        : std_logic_vector(Reg_GBA_MaxPakAddr.upper     downto Reg_GBA_MaxPakAddr.lower)     := (others => '0');
                            
   signal GBA_BusAddr       : std_logic_vector(Reg_GBA_BusAddr     .upper downto Reg_GBA_BusAddr     .lower) := (others => '0');
   signal GBA_BusRnW        : std_logic_vector(Reg_GBA_BusRnW      .upper downto Reg_GBA_BusRnW      .lower) := (others => '0');
   signal GBA_BusACC        : std_logic_vector(Reg_GBA_BusACC      .upper downto Reg_GBA_BusACC      .lower) := (others => '0');
   signal GBA_BusWriteData  : std_logic_vector(Reg_GBA_BusWriteData.upper downto Reg_GBA_BusWriteData.lower) := (others => '0');
   signal GBA_BusReadData   : std_logic_vector(Reg_GBA_BusReadData .upper downto Reg_GBA_BusReadData .lower) := (others => '0');
   signal GBA_Bus_written   : std_logic;   
   
   signal GBA_KeyUp     : std_logic_vector(Reg_GBA_KeyUp    .upper downto Reg_GBA_KeyUp    .lower) := (others => '0');
   signal GBA_KeyDown   : std_logic_vector(Reg_GBA_KeyDown  .upper downto Reg_GBA_KeyDown  .lower) := (others => '0');
   signal GBA_KeyLeft   : std_logic_vector(Reg_GBA_KeyLeft  .upper downto Reg_GBA_KeyLeft  .lower) := (others => '0');
   signal GBA_KeyRight  : std_logic_vector(Reg_GBA_KeyRight .upper downto Reg_GBA_KeyRight .lower) := (others => '0');
   signal GBA_KeyA      : std_logic_vector(Reg_GBA_KeyA     .upper downto Reg_GBA_KeyA     .lower) := (others => '0');
   signal GBA_KeyB      : std_logic_vector(Reg_GBA_KeyB     .upper downto Reg_GBA_KeyB     .lower) := (others => '0');
   signal GBA_KeyL      : std_logic_vector(Reg_GBA_KeyL     .upper downto Reg_GBA_KeyL     .lower) := (others => '0');
   signal GBA_KeyR      : std_logic_vector(Reg_GBA_KeyR     .upper downto Reg_GBA_KeyR     .lower) := (others => '0');
   signal GBA_KeyStart  : std_logic_vector(Reg_GBA_KeyStart .upper downto Reg_GBA_KeyStart .lower) := (others => '0');
   signal GBA_KeySelect : std_logic_vector(Reg_GBA_KeySelect.upper downto Reg_GBA_KeySelect.lower) := (others => '0');
   
   signal GBA_DEBUG_CPU_PC  : std_logic_vector(Reg_GBA_DEBUG_CPU_PC .upper downto Reg_GBA_DEBUG_CPU_PC .lower) := (others => '0');
   signal GBA_DEBUG_CPU_MIX : std_logic_vector(Reg_GBA_DEBUG_CPU_MIX.upper downto Reg_GBA_DEBUG_CPU_MIX.lower) := (others => '0');
   signal GBA_DEBUG_IRQ     : std_logic_vector(Reg_GBA_DEBUG_IRQ    .upper downto Reg_GBA_DEBUG_IRQ    .lower) := (others => '0');
   signal GBA_DEBUG_DMA     : std_logic_vector(Reg_GBA_DEBUG_DMA    .upper downto Reg_GBA_DEBUG_DMA    .lower) := (others => '0');
   signal GBA_DEBUG_MEM     : std_logic_vector(Reg_GBA_DEBUG_MEM    .upper downto Reg_GBA_DEBUG_MEM    .lower) := (others => '0');
   
   signal GBA_CHEAT_FLAGS   : std_logic_vector(Reg_GBA_CHEAT_FLAGS  .upper downto Reg_GBA_CHEAT_FLAGS  .lower) := (others => '0');
   signal GBA_CHEAT_ADDRESS : std_logic_vector(Reg_GBA_CHEAT_ADDRESS.upper downto Reg_GBA_CHEAT_ADDRESS.lower) := (others => '0');
   signal GBA_CHEAT_COMPARE : std_logic_vector(Reg_GBA_CHEAT_COMPARE.upper downto Reg_GBA_CHEAT_COMPARE.lower) := (others => '0');
   signal GBA_CHEAT_REPLACE : std_logic_vector(Reg_GBA_CHEAT_REPLACE.upper downto Reg_GBA_CHEAT_REPLACE.lower) := (others => '0');
   signal GBA_CHEAT_RESET   : std_logic_vector(Reg_GBA_CHEAT_RESET  .upper downto Reg_GBA_CHEAT_RESET  .lower) := (others => '0');
   
   signal bus_out_Din      : std_logic_vector(31 downto 0);
   signal bus_out_Dout     : std_logic_vector(31 downto 0);
   signal bus_out_Adr      : std_logic_vector(25 downto 0);
   signal bus_out_rnw      : std_logic;
   signal bus_out_ena      : std_logic;
   signal bus_out_done     : std_logic;
   
   signal SAVE_out_Din     : std_logic_vector(63 downto 0);
   signal SAVE_out_Dout    : std_logic_vector(63 downto 0);
   signal SAVE_out_Adr     : std_logic_vector(25 downto 0);
   signal SAVE_out_be      : std_logic_vector(7 downto 0);
   signal SAVE_out_rnw     : std_logic;                    
   signal SAVE_out_ena     : std_logic;                    
   signal SAVE_out_active  : std_logic;                    
   signal SAVE_out_done    : std_logic;                    
   
   signal cpu_loopback     : std_logic_vector(31 downto 0);
   
   signal Cheat_written    : std_logic;
   signal cheats_vector    : std_logic_vector(127 downto 0);
   
   -- gba signals
   signal sdram_read_ena     : std_logic;
   signal sdram_read_done    : std_logic;
   signal sdram_read_addr    : std_logic_vector(24 downto 0);
   signal sdram_read_data    : std_logic_vector(31 downto 0);
   signal sdram_second_dword : std_logic_vector(31 downto 0);
    
   signal Copy_request_start : std_logic;
   signal Copy_request_src   : std_logic_vector(24 downto 0);
   signal Copy_request_dst   : std_logic_vector(24 downto 0);
   signal Copy_request_len   : std_logic_vector(24 downto 0);
   signal Copy_request_done  : std_logic;
    
   signal pixel_out_x        : integer range 0 to 239;
   signal pixel_out_y        : integer range 0 to 159;
   signal pixel_out_data     : std_logic_vector(17 downto 0);  
   signal pixel_out_we       : std_logic;
   
   signal largeimg_out_addr  : std_logic_vector(25 downto 0);
   signal largeimg_out_data  : std_logic_vector(63 downto 0);
   signal largeimg_out_req   : std_logic;
   signal largeimg_out_done  : std_logic;
   signal largeimg_newframe  : std_logic;
                         
   signal sound_out_left     : std_logic_vector(15 downto 0);
   signal sound_out_right    : std_logic_vector(15 downto 0);
   
   signal RTC_saveLoaded     : std_logic := '0';
   
   -- ddrram
   signal DDRAM_CLK        : std_logic;
   signal DDRAM_BUSY       : std_logic;
   signal DDRAM_BURSTCNT   : std_logic_vector(7 downto 0);
   signal DDRAM_ADDR       : std_logic_vector(28 downto 0);
   signal DDRAM_DOUT       : std_logic_vector(63 downto 0);
   signal DDRAM_DOUT_READY : std_logic;
   signal DDRAM_RD         : std_logic;
   signal DDRAM_DIN        : std_logic_vector(63 downto 0);
   signal DDRAM_BE         : std_logic_vector(7 downto 0);
   signal DDRAM_WE         : std_logic;
                   
   signal ch1_addr         : std_logic_vector(27 downto 1);
   signal ch1_dout         : std_logic_vector(63 downto 0);
   signal ch1_din          : std_logic_vector(15 downto 0);
   signal ch1_req          : std_logic;
   signal ch1_rnw          : std_logic;
   signal ch1_ready        : std_logic;
                          
   signal ch2_addr         : std_logic_vector(27 downto 1);
   signal ch2_dout         : std_logic_vector(31 downto 0);
   signal ch2_din          : std_logic_vector(31 downto 0);
   signal ch2_req          : std_logic;
   signal ch2_rnw          : std_logic;
   signal ch2_ready        : std_logic;
                       
   signal ch3_addr         : std_logic_vector(25 downto 1);
   signal ch3_dout         : std_logic_vector(15 downto 0);
   signal ch3_din          : std_logic_vector(15 downto 0);
   signal ch3_req          : std_logic;
   signal ch3_rnw          : std_logic;
   signal ch3_ready        : std_logic;
                     
   signal ch4_addr         : std_logic_vector(27 downto 1);
   signal ch4_dout         : std_logic_vector(63 downto 0);
   signal ch4_din          : std_logic_vector(63 downto 0);
   signal ch4_be           : std_logic_vector(7 downto 0);
   signal ch4_req          : std_logic;
   signal ch4_rnw          : std_logic;
   signal ch4_ready        : std_logic;
   
   
begin

   clk100 <= not clk100 after 5 ns;
   
   -- registers
   iReg_GBA_on            : entity procbus.eProcReg generic map (Reg_GBA_on      )       port map (clk100, proc_bus_in, GBA_on, GBA_on);      
   iReg_GBA_lockspeed     : entity procbus.eProcReg generic map (Reg_GBA_lockspeed)      port map (clk100, proc_bus_in, GBA_lockspeed, GBA_lockspeed);   
   iReg_GBA_cputurbo      : entity procbus.eProcReg generic map (Reg_GBA_cputurbo)       port map (clk100, proc_bus_in, GBA_cputurbo, GBA_cputurbo);   
   iReg_GBA_SramFlashEna  : entity procbus.eProcReg generic map (Reg_GBA_SramFlashEna)   port map (clk100, proc_bus_in, GBA_SramFlashEna, GBA_SramFlashEna);   
   iReg_GBA_MemoryRemap   : entity procbus.eProcReg generic map (Reg_GBA_MemoryRemap )   port map (clk100, proc_bus_in, GBA_MemoryRemap , GBA_MemoryRemap );   
   iReg_GBA_SaveState     : entity procbus.eProcReg generic map (Reg_GBA_SaveState )     port map (clk100, proc_bus_in, GBA_SaveState , GBA_SaveState );   
   iReg_GBA_LoadState     : entity procbus.eProcReg generic map (Reg_GBA_LoadState )     port map (clk100, proc_bus_in, GBA_LoadState , GBA_LoadState );   
   iReg_GBA_FrameBlend    : entity procbus.eProcReg generic map (Reg_GBA_FrameBlend)     port map (clk100, proc_bus_in, GBA_FrameBlend , GBA_FrameBlend );   
   iReg_GBA_Pixelshade    : entity procbus.eProcReg generic map (Reg_GBA_Pixelshade)     port map (clk100, proc_bus_in, GBA_Pixelshade , GBA_Pixelshade );   
   iReg_GBA_SaveStateAddr : entity procbus.eProcReg generic map (Reg_GBA_SaveStateAddr)  port map (clk100, proc_bus_in, GBA_SaveStateAddr , GBA_SaveStateAddr );   
   iReg_GBA_Rewind_on     : entity procbus.eProcReg generic map (Reg_GBA_Rewind_on    )  port map (clk100, proc_bus_in, GBA_Rewind_on     , GBA_Rewind_on     );   
   iReg_GBA_Rewind_active : entity procbus.eProcReg generic map (Reg_GBA_Rewind_active)  port map (clk100, proc_bus_in, GBA_Rewind_active , GBA_Rewind_active );   
                          
   iReg_GBA_flash_1m      : entity procbus.eProcReg generic map (Reg_GBA_flash_1m)       port map (clk100, proc_bus_in, GBA_flash_1m, GBA_flash_1m);  
   iReg_CyclesMissing     : entity procbus.eProcReg generic map (Reg_GBA_CyclesMissing)  port map (clk100, proc_bus_in, CyclesMissing);  
   iReg_CyclePrecalc      : entity procbus.eProcReg generic map (Reg_GBA_CyclePrecalc)   port map (clk100, proc_bus_in, CyclePrecalc, CyclePrecalc);  
   iReg_GBA_VsyncSpeed    : entity procbus.eProcReg generic map (Reg_GBA_VsyncSpeed)     port map (clk100, proc_bus_in, CyclesVsyncSpeed);  
                          
   iReg_MaxPakAddr        : entity procbus.eProcReg generic map (Reg_GBA_MaxPakAddr)     port map (clk100, proc_bus_in, MaxPakAddr, MaxPakAddr);  
                          
   iReg_GBA_BusAddr       : entity procbus.eProcReg generic map (Reg_GBA_BusAddr     ) port map (clk100, proc_bus_in, GBA_BusAddr     , GBA_BusAddr     , GBA_Bus_written);  
   iReg_GBA_BusRnW        : entity procbus.eProcReg generic map (Reg_GBA_BusRnW      ) port map (clk100, proc_bus_in, GBA_BusRnW      , GBA_BusRnW      );  
   iReg_GBA_BusACC        : entity procbus.eProcReg generic map (Reg_GBA_BusACC      ) port map (clk100, proc_bus_in, GBA_BusACC      , GBA_BusACC      );  
   iReg_GBA_BusWriteData  : entity procbus.eProcReg generic map (Reg_GBA_BusWriteData) port map (clk100, proc_bus_in, GBA_BusWriteData, GBA_BusWriteData);  
   iReg_GBA_BusReadData   : entity procbus.eProcReg generic map (Reg_GBA_BusReadData ) port map (clk100, proc_bus_in, GBA_BusReadData);  

   iReg_Gameboy_KeyUp     : entity procbus.eProcReg generic map (Reg_GBA_KeyUp    ) port map  (clk100, proc_bus_in, GBA_KeyUp    , GBA_KeyUp    );  
   iReg_Gameboy_KeyDown   : entity procbus.eProcReg generic map (Reg_GBA_KeyDown  ) port map  (clk100, proc_bus_in, GBA_KeyDown  , GBA_KeyDown  );  
   iReg_Gameboy_KeyLeft   : entity procbus.eProcReg generic map (Reg_GBA_KeyLeft  ) port map  (clk100, proc_bus_in, GBA_KeyLeft  , GBA_KeyLeft  );  
   iReg_Gameboy_KeyRight  : entity procbus.eProcReg generic map (Reg_GBA_KeyRight ) port map  (clk100, proc_bus_in, GBA_KeyRight , GBA_KeyRight );  
   iReg_Gameboy_KeyA      : entity procbus.eProcReg generic map (Reg_GBA_KeyA     ) port map  (clk100, proc_bus_in, GBA_KeyA     , GBA_KeyA     );  
   iReg_Gameboy_KeyB      : entity procbus.eProcReg generic map (Reg_GBA_KeyB     ) port map  (clk100, proc_bus_in, GBA_KeyB     , GBA_KeyB     );  
   iReg_Gameboy_KeyL      : entity procbus.eProcReg generic map (Reg_GBA_KeyL     ) port map  (clk100, proc_bus_in, GBA_KeyL     , GBA_KeyL     );  
   iReg_Gameboy_KeyR      : entity procbus.eProcReg generic map (Reg_GBA_KeyR     ) port map  (clk100, proc_bus_in, GBA_KeyR     , GBA_KeyR     );  
   iReg_Gameboy_KeyStart  : entity procbus.eProcReg generic map (Reg_GBA_KeyStart ) port map  (clk100, proc_bus_in, GBA_KeyStart , GBA_KeyStart );  
   iReg_Gameboy_KeySelect : entity procbus.eProcReg generic map (Reg_GBA_KeySelect) port map  (clk100, proc_bus_in, GBA_KeySelect, GBA_KeySelect); 
   
   --iReg_GBA_DEBUG_CPU_PC  : entity procbus.eProcReg generic map (Reg_GBA_DEBUG_CPU_PC ) port map  (clk100, proc_bus_in, GBA_DEBUG_CPU_PC ); 
   --iReg_GBA_DEBUG_CPU_MIX : entity procbus.eProcReg generic map (Reg_GBA_DEBUG_CPU_MIX) port map  (clk100, proc_bus_in, GBA_DEBUG_CPU_MIX); 
   --iReg_GBA_DEBUG_IRQ     : entity procbus.eProcReg generic map (Reg_GBA_DEBUG_IRQ    ) port map  (clk100, proc_bus_in, GBA_DEBUG_IRQ    ); 
   --iReg_GBA_DEBUG_DMA     : entity procbus.eProcReg generic map (Reg_GBA_DEBUG_DMA    ) port map  (clk100, proc_bus_in, GBA_DEBUG_DMA    ); 
   --iReg_GBA_DEBUG_MEM     : entity procbus.eProcReg generic map (Reg_GBA_DEBUG_MEM    ) port map  (clk100, proc_bus_in, GBA_DEBUG_MEM    ); 
   
   iReg_GBA_CHEAT_FLAGS   : entity procbus.eProcReg generic map (Reg_GBA_CHEAT_FLAGS  ) port map  (clk100, proc_bus_in, GBA_CHEAT_FLAGS  , GBA_CHEAT_FLAGS  ); 
   iReg_GBA_CHEAT_ADDRESS : entity procbus.eProcReg generic map (Reg_GBA_CHEAT_ADDRESS) port map  (clk100, proc_bus_in, GBA_CHEAT_ADDRESS, GBA_CHEAT_ADDRESS); 
   iReg_GBA_CHEAT_COMPARE : entity procbus.eProcReg generic map (Reg_GBA_CHEAT_COMPARE) port map  (clk100, proc_bus_in, GBA_CHEAT_COMPARE, GBA_CHEAT_COMPARE); 
   iReg_GBA_CHEAT_REPLACE : entity procbus.eProcReg generic map (Reg_GBA_CHEAT_REPLACE) port map  (clk100, proc_bus_in, GBA_CHEAT_REPLACE, GBA_CHEAT_REPLACE, Cheat_written); 
   iReg_GBA_CHEAT_RESET   : entity procbus.eProcReg generic map (Reg_GBA_CHEAT_RESET  ) port map  (clk100, proc_bus_in, GBA_CHEAT_RESET  , GBA_CHEAT_RESET  ); 
     
   cheats_vector <= GBA_CHEAT_FLAGS & GBA_CHEAT_ADDRESS & GBA_CHEAT_COMPARE & GBA_CHEAT_REPLACE; 
   
   RTC_saveLoaded <= '1' after 500 ns;
   
   igba_top : entity gba.gba_top
   generic map
   (
      is_simu                  => '1',
      Softmap_GBA_Gamerom_ADDR => 65536+131072,
      Softmap_GBA_WRam_ADDR    => 131072,
      Softmap_GBA_FLASH_ADDR   => 0,
      Softmap_GBA_EEPROM_ADDR  => 0,
      Softmap_SaveState_ADDR   => 16#3800000#,
      Softmap_Rewind_ADDR      => 16#2000000#,
      turbosound               => '1'
   )
   port map
   (
      clk100             => clk100,
      -- settings        
      GBA_on             => GBA_on(0),        
      GBA_lockspeed      => GBA_lockspeed(0), 
      GBA_cputurbo       => GBA_cputurbo(GBA_cputurbo'left), 
      GBA_flash_1m       => GBA_flash_1m(0),  
      CyclePrecalc       => CyclePrecalc, 
      MaxPakAddr         => MaxPakAddr,    
      CyclesMissing      => CyclesMissing,
      CyclesVsyncSpeed   => CyclesVsyncSpeed,
      SramFlashEnable    => GBA_SramFlashEna(GBA_SramFlashEna'left),
      memory_remap       => GBA_MemoryRemap(GBA_MemoryRemap'left),
      increaseSSHeaderCount => '0',
      save_state         => GBA_SaveState(GBA_SaveState'left),
      load_state         => GBA_LoadState(GBA_LoadState'left),
      interframe_blend   => "00",
      maxpixels          => '0',
      shade_mode         => "000",
      hdmode2x_bg        => '0',
      hdmode2x_obj       => '0',
      specialmodule      => '1',
      solar_in           => "000",
      tilt               => '0',
      rewind_on          => GBA_Rewind_on(GBA_Rewind_on'left),
      rewind_active      => GBA_Rewind_active(GBA_Rewind_active'left),
      savestate_number   => 0,
      -- RTC
      RTC_timestampNew   => '0',
      RTC_timestampIn    => x"00001E10", -- one hour
      RTC_timestampSaved => x"00001000",
      RTC_savedtimeIn    => x"19" & "10010" & "110001" & "110" & "100011" & "1011001" & "1011001",
      RTC_saveLoaded     => RTC_saveLoaded,
      RTC_timestampOut   => open,
      RTC_savedtimeOut   => open,
      RTC_inuse          => open, 
      -- cheats
      cheat_clear        => GBA_CHEAT_RESET(GBA_CHEAT_RESET'left),
      cheats_enabled     => '1',
      cheat_on           => Cheat_written,
      cheat_in           => cheats_vector,
      -- sdram interface 
      sdram_read_ena     => sdram_read_ena,    
      sdram_read_done    => sdram_read_done,   
      sdram_read_addr    => sdram_read_addr,   
      sdram_read_data    => sdram_read_data,   
      sdram_second_dword => sdram_second_dword,
      -- other Memories
      bus_out_Din        => bus_out_Din, 
      bus_out_Dout       => bus_out_Dout,
      bus_out_Adr        => bus_out_Adr, 
      bus_out_rnw        => bus_out_rnw,
      bus_out_ena        => bus_out_ena, 
      bus_out_done       => bus_out_done,
      -- savestate
      SAVE_out_Din       => SAVE_out_Din,   
      SAVE_out_Dout      => SAVE_out_Dout,  
      SAVE_out_Adr       => SAVE_out_Adr,   
      SAVE_out_rnw       => SAVE_out_rnw,   
      SAVE_out_ena       => SAVE_out_ena,   
      SAVE_out_active    => SAVE_out_active,
      SAVE_out_be        => SAVE_out_be,
      SAVE_out_done      => SAVE_out_done, 
      -- copy
      --Copy_request_start  => Copy_request_start,
      --Copy_request_src    => Copy_request_src,  
      --Copy_request_dst    => Copy_request_dst,  
      --Copy_request_len    => Copy_request_len,  
      --Copy_request_done   => Copy_request_done,  
      -- Write to BIOS
      bios_wraddr        => (11 downto 0 => '0'),
      bios_wrdata        => (31 downto 0 => '0'),
      bios_wr            => '0',
      -- save memory used
      save_eeprom        => open,
      save_sram          => open,
      save_flash         => open,
      -- Keys
      KeyA               => GBA_KeyA(GBA_KeyA'left),
      KeyB               => GBA_KeyB(GBA_KeyB'left),
      KeySelect          => GBA_KeySelect(GBA_KeySelect'left),
      KeyStart           => GBA_KeyStart(GBA_KeyStart'left),
      KeyRight           => GBA_KeyRight(GBA_KeyRight'left),
      KeyLeft            => GBA_KeyLeft(GBA_KeyLeft'left),
      KeyUp              => GBA_KeyUp(GBA_KeyUp'left),
      KeyDown            => GBA_KeyDown(GBA_KeyDown'left),
      KeyR               => GBA_KeyR(GBA_KeyR'left),
      KeyL               => GBA_KeyL(GBA_KeyL'left),
      AnalogTiltX        => x"00",
      AnalogTiltY        => x"00",
      -- debug interface 
      GBA_BusAddr        => GBA_BusAddr,     
      GBA_BusRnW         => GBA_BusRnW(GBA_BusRnW'left),      
      GBA_BusACC         => GBA_BusACC,      
      GBA_BusWriteData   => GBA_BusWriteData,
      GBA_BusReadData    => GBA_BusReadData, 
      GBA_Bus_written    => GBA_Bus_written,
      -- display data      
      pixel_out_x        => pixel_out_x,
      pixel_out_y        => pixel_out_y,
      pixel_out_addr     => open,
      pixel_out_data     => pixel_out_data,
      pixel_out_we       => pixel_out_we, 

      largeimg_out_addr  => largeimg_out_addr,
      largeimg_out_data  => largeimg_out_data,
      largeimg_out_req   => largeimg_out_req, 
      largeimg_out_done  => largeimg_out_done,
      largeimg_newframe  => largeimg_newframe,
      largeimg_singlebuf => '0',
      -- sound          
      sound_out_left     => sound_out_left,
      sound_out_right    => sound_out_right,
      -- debug
      debug_cpu_pc       => open, --GBA_DEBUG_CPU_PC, 
      debug_cpu_mixed    => open, --GBA_DEBUG_CPU_MIX,
      debug_irq          => open, --GBA_DEBUG_IRQ,    
      debug_dma          => open, --GBA_DEBUG_DMA,
      debug_mem          => open  --GBA_DEBUG_MEM      
   );
   
   largeimg_newframe <= '1' when unsigned(largeimg_out_addr(19 downto 0)) = 0 else '0';
   
   ch1_addr <= '0' & sdram_read_addr & "0";
   ch1_req  <= sdram_read_ena;
   ch1_rnw  <= '1';
   sdram_second_dword <= ch1_dout(63 downto 32);
   sdram_read_data    <= ch1_dout(31 downto 0);
   sdram_read_done    <= ch1_ready; 
   
   ch2_addr <= bus_out_Adr & "0";
   ch2_din  <= bus_out_Din;
   ch2_req  <= bus_out_ena;
   ch2_rnw  <= bus_out_rnw;
   bus_out_Dout <= ch2_dout;
   bus_out_done <= ch2_ready;
   
   ch4_addr <= SAVE_out_Adr(25 downto 0) & "0";
   ch4_din  <= SAVE_out_Din;
   ch4_req  <= SAVE_out_ena;
   ch4_rnw  <= SAVE_out_rnw;
   ch4_be   <= SAVE_out_be;
   SAVE_out_Dout <= ch4_dout;
   SAVE_out_done <= ch4_ready;
   
   iddrram : entity tb.ddram
   port map (
      DDRAM_CLK        => clk100,      
      DDRAM_BUSY       => DDRAM_BUSY,      
      DDRAM_BURSTCNT   => DDRAM_BURSTCNT,  
      DDRAM_ADDR       => DDRAM_ADDR,      
      DDRAM_DOUT       => DDRAM_DOUT,      
      DDRAM_DOUT_READY => DDRAM_DOUT_READY,
      DDRAM_RD         => DDRAM_RD,        
      DDRAM_DIN        => DDRAM_DIN,       
      DDRAM_BE         => DDRAM_BE,        
      DDRAM_WE         => DDRAM_WE,        
                                 
      ch1_addr         => ch1_addr,        
      ch1_dout         => ch1_dout,        
      ch1_din          => ch1_din,         
      ch1_req          => ch1_req,         
      ch1_rnw          => ch1_rnw,         
      ch1_ready        => ch1_ready,       
                                        
      ch2_addr         => ch2_addr,       
      ch2_dout         => ch2_dout,        
      ch2_din          => ch2_din,         
      ch2_req          => ch2_req,         
      ch2_rnw          => ch2_rnw,         
      ch2_ready        => ch2_ready,       
                                     
      ch3_addr         => ch3_addr,        
      ch3_dout         => ch3_dout,        
      ch3_din          => ch3_din,         
      ch3_req          => ch3_req,         
      ch3_rnw          => ch3_rnw,         
      ch3_ready        => ch3_ready,       
                                   
      ch4_addr         => ch4_addr,        
      ch4_dout         => ch4_dout,        
      ch4_din          => ch4_din,         
      ch4_req          => ch4_req,         
      ch4_rnw          => ch4_rnw,         
      ch4_be           => ch4_be,       
      ch4_ready        => ch4_ready,       
      
      ch5_addr         => (27 downto 1 => '0'),        
      ch5_din          => (63 downto 0 => '0'),               
      ch5_req          => largeimg_out_req,                
      ch5_ready        => largeimg_out_done  
   );
   
   iddrram_model : entity tb.ddrram_model
   port map
   (
      DDRAM_CLK        => clk100,      
      DDRAM_BUSY       => DDRAM_BUSY,      
      DDRAM_BURSTCNT   => DDRAM_BURSTCNT,  
      DDRAM_ADDR       => DDRAM_ADDR,      
      DDRAM_DOUT       => DDRAM_DOUT,      
      DDRAM_DOUT_READY => DDRAM_DOUT_READY,
      DDRAM_RD         => DDRAM_RD,        
      DDRAM_DIN        => DDRAM_DIN,       
      DDRAM_BE         => DDRAM_BE,        
      DDRAM_WE         => DDRAM_WE        
   );
   
   iframebuffer : entity work.framebuffer
   generic map
   (
      FRAMESIZE_X => 240,
      FRAMESIZE_Y => 160
   )
   port map
   (
      clk100             => clk100,
                          
      pixel_in_x         => pixel_out_x,
      pixel_in_y         => pixel_out_y,
      pixel_in_data      => pixel_out_data,
      pixel_in_we        => pixel_out_we
   );
   
   iframebuffer_large : entity work.framebuffer_large
   generic map
   (
      FRAMESIZE_X => 480,
      FRAMESIZE_Y => 320
   )
   port map
   (
      clk100             => clk100,
                          
      pixel_in_addr      => largeimg_out_addr,
      pixel_in_data      => largeimg_out_data,
      pixel_in_we        => largeimg_out_req,
      pixel_in_done      => open
   );
   
   iTestprocessor : entity procbus.eTestprocessor
   generic map
   (
      clk_speed => clk_speed,
      baud      => baud,
      is_simu   => '1'
   )
   port map 
   (
      clk               => clk100,
      bootloader        => '0',
      debugaccess       => '1',
      command_in        => command_in,
      command_out       => command_out,
            
      proc_bus          => proc_bus_in,
      
      fifo_full_error   => open,
      timeout_error     => open
   );
   
   command_out_filter <= '0' when command_out = 'Z' else command_out;
   
   itb_interpreter : entity tb.etb_interpreter
   generic map
   (
      clk_speed => clk_speed,
      baud      => baud
   )
   port map
   (
      clk         => clk100,
      command_in  => command_in, 
      command_out => command_out_filter
   );
   
end architecture;


