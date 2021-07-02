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
   
   signal bus1_out_Din      : std_logic_vector(31 downto 0);
   signal bus1_out_Dout     : std_logic_vector(31 downto 0);
   signal bus1_out_Adr      : std_logic_vector(25 downto 0);
   signal bus1_out_rnw      : std_logic;
   signal bus1_out_ena      : std_logic;
   signal bus1_out_done     : std_logic;
   
   signal bus2_out_Din      : std_logic_vector(31 downto 0);
   signal bus2_out_Dout     : std_logic_vector(31 downto 0);
   signal bus2_out_Adr      : std_logic_vector(25 downto 0);
   signal bus2_out_rnw      : std_logic;
   signal bus2_out_ena      : std_logic;
   signal bus2_out_done     : std_logic;
   
   signal SAVE1_out_Din     : std_logic_vector(63 downto 0);
   signal SAVE1_out_Dout    : std_logic_vector(63 downto 0);
   signal SAVE1_out_Adr     : std_logic_vector(25 downto 0);
   signal SAVE1_out_be      : std_logic_vector(7 downto 0);
   signal SAVE1_out_rnw     : std_logic;                    
   signal SAVE1_out_ena     : std_logic;                    
   signal SAVE1_out_active  : std_logic;                    
   signal SAVE1_out_done    : std_logic;   

   signal SAVE2_out_Din     : std_logic_vector(63 downto 0);
   signal SAVE2_out_Dout    : std_logic_vector(63 downto 0);
   signal SAVE2_out_Adr     : std_logic_vector(25 downto 0);
   signal SAVE2_out_be      : std_logic_vector(7 downto 0);
   signal SAVE2_out_rnw     : std_logic;                    
   signal SAVE2_out_ena     : std_logic;                    
   signal SAVE2_out_active  : std_logic;                    
   signal SAVE2_out_done    : std_logic;   
   
   -- gba signals
   signal sdram1_read_ena     : std_logic;
   signal sdram1_read_done    : std_logic;
   signal sdram1_read_addr    : std_logic_vector(24 downto 0);
   signal sdram1_read_data    : std_logic_vector(31 downto 0);
   signal sdram1_second_dword : std_logic_vector(31 downto 0);   
   
   signal sdram2_read_ena     : std_logic;
   signal sdram2_read_done    : std_logic;
   signal sdram2_read_addr    : std_logic_vector(24 downto 0);
   signal sdram2_read_data    : std_logic_vector(31 downto 0);
   signal sdram2_second_dword : std_logic_vector(31 downto 0);

   signal largeimg_out_addr  : std_logic_vector(25 downto 0);
   signal largeimg_out_data  : std_logic_vector(63 downto 0);
   signal largeimg_out_req   : std_logic;
   signal largeimg_out_done  : std_logic;
   signal largeimg_newframe  : std_logic;
   
   signal largeimg_out2_addr : std_logic_vector(25 downto 0);
   signal largeimg_out2_data : std_logic_vector(63 downto 0);
   signal largeimg_out2_req  : std_logic;
   signal largeimg_out2_done : std_logic;
                         
   signal sound_out_left     : std_logic_vector(15 downto 0);
   signal sound_out_right    : std_logic_vector(15 downto 0);
   
   signal RTC_saveLoaded     : std_logic := '0';
   
   signal serial1_clockout   : std_logic;
   signal serial2_clockout   : std_logic;
   signal serial1_dataout    : std_logic;
   signal serial2_dataout    : std_logic;
   
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
   
   -- ddrram2
   signal DDRAM2_CLK        : std_logic;
   signal DDRAM2_BUSY       : std_logic;
   signal DDRAM2_BURSTCNT   : std_logic_vector(7 downto 0);
   signal DDRAM2_ADDR       : std_logic_vector(28 downto 0);
   signal DDRAM2_DOUT       : std_logic_vector(63 downto 0);
   signal DDRAM2_DOUT_READY : std_logic;
   signal DDRAM2_RD         : std_logic;
   signal DDRAM2_DIN        : std_logic_vector(63 downto 0);
   signal DDRAM2_BE         : std_logic_vector(7 downto 0);
   signal DDRAM2_WE         : std_logic;
                   
   signal c2h1_addr         : std_logic_vector(27 downto 1);
   signal c2h1_dout         : std_logic_vector(63 downto 0);
   signal c2h1_din          : std_logic_vector(15 downto 0);
   signal c2h1_req          : std_logic;
   signal c2h1_rnw          : std_logic;
   signal c2h1_ready        : std_logic;
                          
   signal c2h2_addr         : std_logic_vector(27 downto 1);
   signal c2h2_dout         : std_logic_vector(31 downto 0);
   signal c2h2_din          : std_logic_vector(31 downto 0);
   signal c2h2_req          : std_logic;
   signal c2h2_rnw          : std_logic;
   signal c2h2_ready        : std_logic;
                       
   signal c2h3_addr         : std_logic_vector(25 downto 1);
   signal c2h3_dout         : std_logic_vector(15 downto 0);
   signal c2h3_din          : std_logic_vector(15 downto 0);
   signal c2h3_req          : std_logic;
   signal c2h3_rnw          : std_logic;
   signal c2h3_ready        : std_logic;
                     
   signal c2h4_addr         : std_logic_vector(27 downto 1);
   signal c2h4_dout         : std_logic_vector(63 downto 0);
   signal c2h4_din          : std_logic_vector(63 downto 0);
   signal c2h4_be           : std_logic_vector(7 downto 0);
   signal c2h4_req          : std_logic;
   signal c2h4_rnw          : std_logic;
   signal c2h4_ready        : std_logic;
   
   
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
   iReg_GBA_CHEAT_REPLACE : entity procbus.eProcReg generic map (Reg_GBA_CHEAT_REPLACE) port map  (clk100, proc_bus_in, GBA_CHEAT_REPLACE, GBA_CHEAT_REPLACE); 
   iReg_GBA_CHEAT_RESET   : entity procbus.eProcReg generic map (Reg_GBA_CHEAT_RESET  ) port map  (clk100, proc_bus_in, GBA_CHEAT_RESET  , GBA_CHEAT_RESET  ); 
     
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
      specialmodule      => '0',
      rewind_on          => GBA_Rewind_on(GBA_Rewind_on'left),
      rewind_active      => GBA_Rewind_active(GBA_Rewind_active'left),
      savestate_number   => 0,
      -- sdram interface 
      sdram_read_ena     => sdram1_read_ena,    
      sdram_read_done    => sdram1_read_done,   
      sdram_read_addr    => sdram1_read_addr,   
      sdram_read_data    => sdram1_read_data,   
      sdram_second_dword => sdram1_second_dword,
      -- other Memories
      bus_out_Din        => bus1_out_Din, 
      bus_out_Dout       => bus1_out_Dout,
      bus_out_Adr        => bus1_out_Adr, 
      bus_out_rnw        => bus1_out_rnw,
      bus_out_ena        => bus1_out_ena, 
      bus_out_done       => bus1_out_done,
      -- savestate
      SAVE_out_Din       => SAVE1_out_Din,   
      SAVE_out_Dout      => SAVE1_out_Dout,  
      SAVE_out_Adr       => SAVE1_out_Adr,   
      SAVE_out_rnw       => SAVE1_out_rnw,   
      SAVE_out_ena       => SAVE1_out_ena,   
      SAVE_out_active    => SAVE1_out_active,
      SAVE_out_be        => SAVE1_out_be,
      SAVE_out_done      => SAVE1_out_done, 
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
      -- debug interface 
      GBA_BusAddr        => GBA_BusAddr,     
      GBA_BusRnW         => GBA_BusRnW(GBA_BusRnW'left),      
      GBA_BusACC         => GBA_BusACC,      
      GBA_BusWriteData   => GBA_BusWriteData,
      GBA_BusReadData    => GBA_BusReadData, 
      GBA_Bus_written    => GBA_Bus_written,

      fb_hoffset         => 0,
      fb_voffset         => 0,
      fb_linesize        => 256,
      largeimg_out_addr  => largeimg_out_addr,
      largeimg_out_data  => largeimg_out_data,
      largeimg_out_req   => largeimg_out_req, 
      largeimg_out_done  => largeimg_out_done,
      largeimg_newframe  => largeimg_newframe,
      largeimg_singlebuf => '0',
      -- sound          
      sound_out_left     => sound_out_left,
      sound_out_right    => sound_out_right,
      -- serial
      serial_clockout    => serial1_clockout,
      serial_clockin     => serial2_clockout,
      serial_dataout     => serial1_dataout,
      serial_datain      => serial2_dataout,    
      si_terminal        => '0',
      sd_terminal        => '1'
   );
   
   igba_top2 : entity gba.gba_top
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
      specialmodule      => '0',
      rewind_on          => GBA_Rewind_on(GBA_Rewind_on'left),
      rewind_active      => GBA_Rewind_active(GBA_Rewind_active'left),
      savestate_number   => 0,
      -- sdram interface 
      sdram_read_ena     => sdram2_read_ena,    
      sdram_read_done    => sdram2_read_done,   
      sdram_read_addr    => sdram2_read_addr,   
      sdram_read_data    => sdram2_read_data,   
      sdram_second_dword => sdram2_second_dword,
      -- other Memories
      bus_out_Din        => bus2_out_Din, 
      bus_out_Dout       => bus2_out_Dout,
      bus_out_Adr        => bus2_out_Adr, 
      bus_out_rnw        => bus2_out_rnw,
      bus_out_ena        => bus2_out_ena, 
      bus_out_done       => bus2_out_done,
      -- savestate
      SAVE_out_Din       => SAVE2_out_Din,   
      SAVE_out_Dout      => SAVE2_out_Dout,  
      SAVE_out_Adr       => SAVE2_out_Adr,   
      SAVE_out_rnw       => SAVE2_out_rnw,   
      SAVE_out_ena       => SAVE2_out_ena,   
      SAVE_out_active    => SAVE2_out_active,
      SAVE_out_be        => SAVE2_out_be,
      SAVE_out_done      => SAVE2_out_done, 
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
      -- debug interface 
      GBA_BusAddr        => GBA_BusAddr,     
      GBA_BusRnW         => GBA_BusRnW(GBA_BusRnW'left),      
      GBA_BusACC         => GBA_BusACC,      
      GBA_BusWriteData   => GBA_BusWriteData,
      GBA_BusReadData    => GBA_BusReadData, 
      GBA_Bus_written    => GBA_Bus_written,

      fb_hoffset         => 0,
      fb_voffset         => 1,
      fb_linesize        => 256,
      largeimg_out_addr  => largeimg_out2_addr,
      largeimg_out_data  => largeimg_out2_data,
      largeimg_out_req   => largeimg_out2_req, 
      largeimg_out_done  => largeimg_out2_done,
      largeimg_newframe  => largeimg_newframe,
      largeimg_singlebuf => '0',
      -- serial
      serial_clockout    => serial2_clockout,
      serial_clockin     => serial1_clockout,
      serial_dataout     => serial2_dataout,
      serial_datain      => serial1_dataout,
      si_terminal        => '1',
      sd_terminal        => '1'      
   );
   
   largeimg_newframe <= '1' when unsigned(largeimg_out_addr(19 downto 0)) = 0 else '0';
   
   -- ddrram1
   ch1_addr <= '0' & sdram1_read_addr & "0";
   ch1_req  <= sdram1_read_ena;
   ch1_rnw  <= '1';
   sdram1_second_dword <= ch1_dout(63 downto 32);
   sdram1_read_data    <= ch1_dout(31 downto 0);
   sdram1_read_done    <= ch1_ready; 
   
   ch2_addr <= bus1_out_Adr & "0";
   ch2_din  <= bus1_out_Din;
   ch2_req  <= bus1_out_ena;
   ch2_rnw  <= bus1_out_rnw;
   bus1_out_Dout <= ch2_dout;
   bus1_out_done <= ch2_ready;
   
   ch4_addr <= SAVE1_out_Adr(25 downto 0) & "0";
   ch4_din  <= SAVE1_out_Din;
   ch4_req  <= SAVE1_out_ena;
   ch4_rnw  <= SAVE1_out_rnw;
   ch4_be   <= SAVE1_out_be;
   SAVE1_out_Dout <= ch4_dout;
   SAVE1_out_done <= ch4_ready;
   
   iddrram : entity top.ddram
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
      ch5_ready        => largeimg_out_done,
      
      ch6_addr         => (27 downto 1 => '0'),        
      ch6_din          => (63 downto 0 => '0'),               
      ch6_req          => '0',                
      ch6_ready        => open  
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
   
   -- ddrram2
   c2h1_addr <= '0' & sdram2_read_addr & "0";
   c2h1_req  <= sdram2_read_ena;
   c2h1_rnw  <= '1';
   sdram2_second_dword <= c2h1_dout(63 downto 32);
   sdram2_read_data    <= c2h1_dout(31 downto 0);
   sdram2_read_done    <= c2h1_ready; 
   
   c2h2_addr <= bus2_out_Adr & "0";
   c2h2_din  <= bus2_out_Din;
   c2h2_req  <= bus2_out_ena;
   c2h2_rnw  <= bus2_out_rnw;
   bus2_out_Dout <= c2h2_dout;
   bus2_out_done <= c2h2_ready;
   
   c2h4_addr <= SAVE2_out_Adr(25 downto 0) & "0";
   c2h4_din  <= SAVE2_out_Din;
   c2h4_req  <= SAVE2_out_ena;
   c2h4_rnw  <= SAVE2_out_rnw;
   c2h4_be   <= SAVE2_out_be;
   SAVE2_out_Dout <= c2h4_dout;
   SAVE2_out_done <= c2h4_ready;
   
   iddrram2 : entity top.ddram
   port map (
      DDRAM_CLK        => clk100,      
      DDRAM_BUSY       => DDRAM2_BUSY,      
      DDRAM_BURSTCNT   => DDRAM2_BURSTCNT,  
      DDRAM_ADDR       => DDRAM2_ADDR,      
      DDRAM_DOUT       => DDRAM2_DOUT,      
      DDRAM_DOUT_READY => DDRAM2_DOUT_READY,
      DDRAM_RD         => DDRAM2_RD,        
      DDRAM_DIN        => DDRAM2_DIN,       
      DDRAM_BE         => DDRAM2_BE,        
      DDRAM_WE         => DDRAM2_WE,        
                                 
      ch1_addr         => c2h1_addr,        
      ch1_dout         => c2h1_dout,        
      ch1_din          => c2h1_din,         
      ch1_req          => c2h1_req,         
      ch1_rnw          => c2h1_rnw,         
      ch1_ready        => c2h1_ready,       
                                        
      ch2_addr         => c2h2_addr,       
      ch2_dout         => c2h2_dout,        
      ch2_din          => c2h2_din,         
      ch2_req          => c2h2_req,         
      ch2_rnw          => c2h2_rnw,         
      ch2_ready        => c2h2_ready,       
                                     
      ch3_addr         => c2h3_addr,        
      ch3_dout         => c2h3_dout,        
      ch3_din          => c2h3_din,         
      ch3_req          => c2h3_req,         
      ch3_rnw          => c2h3_rnw,         
      ch3_ready        => c2h3_ready,       
                                   
      ch4_addr         => c2h4_addr,        
      ch4_dout         => c2h4_dout,        
      ch4_din          => c2h4_din,         
      ch4_req          => c2h4_req,         
      ch4_rnw          => c2h4_rnw,         
      ch4_be           => c2h4_be,       
      ch4_ready        => c2h4_ready,       
      
      ch5_addr         => (27 downto 1 => '0'),        
      ch5_din          => (63 downto 0 => '0'),               
      ch5_req          => largeimg_out2_req,                
      ch5_ready        => largeimg_out2_done,
      
      ch6_addr         => (27 downto 1 => '0'),        
      ch6_din          => (63 downto 0 => '0'),               
      ch6_req          => '0',                
      ch6_ready        => open  
   );
   
   iddrram_model2 : entity tb.ddrram_model
   port map
   (
      DDRAM_CLK        => clk100,      
      DDRAM_BUSY       => DDRAM2_BUSY,      
      DDRAM_BURSTCNT   => DDRAM2_BURSTCNT,  
      DDRAM_ADDR       => DDRAM2_ADDR,      
      DDRAM_DOUT       => DDRAM2_DOUT,      
      DDRAM_DOUT_READY => DDRAM2_DOUT_READY,
      DDRAM_RD         => DDRAM2_RD,        
      DDRAM_DIN        => DDRAM2_DIN,       
      DDRAM_BE         => DDRAM2_BE,        
      DDRAM_WE         => DDRAM2_WE        
   );
   
   iframebuffer_large : entity work.framebuffer_large
   generic map
   (
      FRAMESIZE_X => 240,
      FRAMESIZE_Y => 320
   )
   port map
   (
      clk100             => clk100,
                          
      pixel_in_addr      => largeimg_out_addr,
      pixel_in_data      => largeimg_out_data,
      pixel_in_we        => largeimg_out_req,
      pixel_in_done      => open,
      
      pixel2_in_addr     => largeimg_out2_addr,
      pixel2_in_data     => largeimg_out2_data,
      pixel2_in_we       => largeimg_out2_req,
      pixel2_in_done     => open
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


