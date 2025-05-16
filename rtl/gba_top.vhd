library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

library MEM;
use work.pexport.all;
use work.pProc_bus_gba.all;
use work.pReg_savestates.all;

entity gba_top is
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
      clk1x                : in     std_logic;  
      -- settings                 
      GBA_on                : in     std_logic;  -- switching from off to on = reset
      pause                 : in     std_logic;
      allowUnpause          : in     std_logic;
      inPause               : out    std_logic;
      GBA_lockspeed         : in     std_logic;  -- 1 = 100% speed, 0 = max speed
      GBA_cputurbo          : in     std_logic;  -- 1 = cpu free running, all other 16 mhz
      GBA_flash_1m          : in     std_logic;  -- 1 when string "FLASH1M_V" is anywhere in gamepak
      Underclock            : in     std_logic_vector(1 downto 0);
      CyclesMissing         : buffer std_logic_vector(31 downto 0); -- debug only for speed measurement, keep open
      CyclesVsyncSpeed      : out    std_logic_vector(31 downto 0); -- debug only for speed measurement, keep open
      increaseSSHeaderCount : in     std_logic;
      save_state            : in     std_logic;
      load_state            : in     std_logic;
      interframe_blend      : in     std_logic_vector(1 downto 0); -- 0 = off, 1 = blend, 2 = 30hz
      shade_mode            : in     std_logic_vector(2 downto 0); -- 0 = off, 1..4 modes
      rewind_on             : in     std_logic;
      rewind_active         : in     std_logic;
      savestate_number      : in     integer;
      -- errors
      error_cpu             : out    std_logic;
      error_memRequ_timeout : out    std_logic := '0';
      error_memResp_timeout : out    std_logic := '0';
      flash_busy            : in     std_logic;
      -- cheats
      cheat_clear           : in     std_logic;
      cheats_enabled        : in     std_logic;
      cheat_on              : in     std_logic;
      cheat_in              : in     std_logic_vector(127 downto 0);
      cheats_active         : out    std_logic := '0';
      -- cart interface
      cart_ena              : out    std_logic := '0';
      cart_idle             : out    std_logic := '0';
      cart_32               : out    std_logic := '0';
      cart_rnw              : out    std_logic := '0';
      cart_addr             : out    std_logic_vector(27 downto 0) := (others => '0');
      cart_writedata        : out    std_logic_vector(7 downto 0) := (others => '0');
      cart_done             : in     std_logic := '0';
      cart_readdata         : in     std_logic_vector(31 downto 0);
      cart_waitcnt          : out    std_logic_vector(15 downto 0);
      dma_eepromcount       : out    unsigned(16 downto 0);
      cart_reset            : out    std_logic;
      -- savestate           
      SAVE_out_Din          : out    std_logic_vector(63 downto 0); -- data read from savestate
      SAVE_out_Dout         : in     std_logic_vector(63 downto 0); -- data written to savestate
      SAVE_out_Adr          : out    std_logic_vector(25 downto 0); -- all addresses are DWORD addresses!
      SAVE_out_rnw          : out    std_logic;                     -- read = 1, write = 0
      SAVE_out_ena          : out    std_logic;                     -- one cycle high for each action
      SAVE_out_active       : out    std_logic;                     -- is high when access goes to savestate
      SAVE_out_be           : out    std_logic_vector(7 downto 0);
      SAVE_out_done         : in     std_logic;                     -- should be one cycle high when write is done or read value is valid
      savestate_bus_ext     : out    proc_bus_gb_type;
      ss_wired_out_ext      : in     std_logic_vector(proc_buswidth-1 downto 0) := (others => '0');
      ss_wired_done_ext     : in     std_logic;
      -- Write to BIOS
      bios_wraddr           : in     std_logic_vector(11 downto 0) := (others => '0');
      bios_wrdata           : in     std_logic_vector(31 downto 0) := (others => '0');
      bios_wr               : in     std_logic := '0';
      -- save memory used
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
      pixel_out_addr        : buffer integer range 0 to 38399;       -- address for framebuffer 
      pixel_out_data        : buffer std_logic_vector(14 downto 0);  -- RGB data for framebuffer 
      pixel_out_we          : buffer std_logic;                      -- new pixel for framebuffer 
      vblank_trigger        : buffer std_logic;                     
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

   constant DEBUG_NOCPU : std_logic := '0'; 

   type tState is
   (
      PAUSING,
      RUNNING,
      WAITPAUSE,
      WAITUNPAUSE
   );
   signal state : tState := PAUSING;
   
   signal ce              : std_logic := '0';   
   signal pauseCnt        : unsigned(8 downto 0);
   signal pause_active    : std_logic;

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
   signal ss_wired_out         : std_logic_vector(proc_buswidth-1 downto 0) := (others => '0');
   signal ss_wired_done        : std_logic;
   type t_ss_wired_or is array(0 to 6) of std_logic_vector(31 downto 0);
   signal save_wired_or        : t_ss_wired_or;   
   signal save_wired_done      : unsigned(0 to 6);
   
   
   signal reset                : std_logic;
   signal loading_savestate    : std_logic;
   signal saving_savestate     : std_logic;
   signal sleep_savestate      : std_logic;
   signal register_reset       : std_logic;
   
   signal cpu_jump             : std_logic;
   
   signal savestate_savestate  : std_logic := '0';
   signal savestate_loadstate  : std_logic := '0';
   signal savestate_address    : integer;
   signal savestate_busy       : std_logic;
   
   signal sleep_rewind         : std_logic;
   
   -- cheats
   --signal Cheats_BusAddr       : std_logic_vector(27 downto 0);
   --signal Cheats_BusRnW        : std_logic;
   --signal Cheats_BusACC        : std_logic_vector(1 downto 0);
   --signal Cheats_BusWriteData  : std_logic_vector(31 downto 0);
   --signal Cheats_Bus_ena       : std_logic := '0';
   --
   --signal sleep_cheats         : std_logic;
   
   -- wiring  
   signal cpu_bus_Adr          : std_logic_vector(31 downto 0);
   signal cpu_bus_rnw          : std_logic;
   signal cpu_bus_ena          : std_logic;
   signal cpu_bus_seq          : std_logic;
   signal CPU_bus_code         : std_logic;
   signal cpu_bus_acc          : std_logic_vector(1 downto 0);
   signal cpu_bus_dout         : std_logic_vector(31 downto 0);
   signal cpu_bus_din          : std_logic_vector(31 downto 0);
   signal cpu_bus_done         : std_logic;
   
   signal dma_bus_Adr          : std_logic_vector(27 downto 0);
   signal dma_bus_rnw          : std_logic;
   signal dma_bus_ena          : std_logic;
   signal dma_bus_seq          : std_logic;
   signal dma_bus_norom        : std_logic;
   signal dma_bus_acc          : std_logic_vector(1 downto 0);
   signal dma_bus_dout         : std_logic_vector(31 downto 0);
   signal dma_bus_din          : std_logic_vector(31 downto 0);
   signal dma_bus_done         : std_logic;
   signal dma_bus_unread       : std_logic;
   
   signal mem_bus_Adr          : std_logic_vector(31 downto 0);
   signal mem_bus_rnw          : std_logic;
   signal mem_bus_ena          : std_logic;
   signal mem_bus_seq          : std_logic;
   signal mem_bus_code         : std_logic;
   signal mem_bus_acc          : std_logic_vector(1 downto 0);
   signal mem_bus_dout         : std_logic_vector(31 downto 0);
   signal mem_bus_din          : std_logic_vector(31 downto 0);
   signal mem_bus_done         : std_logic;
   signal mem_bus_unread       : std_logic;
   signal mem_bus_isCPU        : std_logic := '0';        
   signal mem_bus_isDMA        : std_logic := '0';        
   
   signal bus_lowbits          : std_logic_vector(1 downto 0); -- only required for sram access
   
   signal bitmapdrawmode       : std_logic;
                               
   signal VRAM_Lo_addr         : integer range 0 to 16383;
   signal VRAM_Lo_datain       : std_logic_vector(31 downto 0);
   signal VRAM_Lo_dataout      : std_logic_vector(31 downto 0);
   signal VRAM_Lo_ce           : std_logic;
   signal VRAM_Lo_we           : std_logic;
   signal VRAM_Lo_be           : std_logic_vector(3 downto 0);
   signal VRAM_Hi_addr         : integer range 0 to 8191;
   signal VRAM_Hi_datain       : std_logic_vector(31 downto 0);
   signal VRAM_Hi_dataout      : std_logic_vector(31 downto 0);
   signal VRAM_Hi_ce           : std_logic;
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
   signal PALETTE_BG_re        : std_logic_vector(3 downto 0);
   signal PALETTE_OAM_addr     : integer range 0 to 128;
   signal PALETTE_OAM_datain   : std_logic_vector(31 downto 0);
   signal PALETTE_OAM_dataout  : std_logic_vector(31 downto 0);
   signal PALETTE_OAM_we       : std_logic_vector(3 downto 0);
   signal PALETTE_OAM_re       : std_logic_vector(3 downto 0);
   
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
   
   signal dma_on           : std_logic;
   signal dma_on_next      : std_logic;
   signal CPU_bus_idle     : std_logic;
   signal CPU_bus_idleDone : std_logic;
   
   signal gba_step         : std_logic := '0';
   signal cpu_done         : std_logic;
   signal cpu_stepsleft    : unsigned(7 downto 0) := (others => '0');
   signal cpu_unhalt       : std_logic := '0';
   signal cpu_irq          : std_logic := '0';
   signal cpu_irq_next     : std_logic := '0';
   signal new_halt         : std_logic := '0';
   
   signal PC_in_BIOS       : std_logic;
   signal cpu_halt         : std_logic;
   signal lastread         : std_logic_vector(31 downto 0);
   signal lastread_dma     : std_logic_vector(31 downto 0);
   signal last_access_dma  : std_logic := '0';    
   
   signal hblank_trigger   : std_logic;
   signal videodma_start   : std_logic;
   signal videodma_stop    : std_logic;
                           
   signal timer0_tick      : std_logic;
   signal timer1_tick      : std_logic;
   signal sound_dma_req    : std_logic_vector(1 downto 0);
   
   -- debug wires
   signal DISPSTAT_debug  : std_logic_vector(31 downto 0);     
   signal sound_fifocount : unsigned(15 downto 0);
   signal timerdebug0     : unsigned(15 downto 0);
   signal timerdebug1     : unsigned(15 downto 0);
   signal timerdebug2     : unsigned(15 downto 0);
   signal timerdebug3     : unsigned(15 downto 0);
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
   
   signal wired_out       : std_logic_vector(proc_buswidth-1 downto 0) := (others => '0');
   signal wired_done      : std_logic;
   
   type t_reg_wired_or is array(0 to 13) of std_logic_vector(31 downto 0);
   signal reg_wired_or    : t_reg_wired_or;   
   signal reg_wired_done  : unsigned(0 to 13);
   
   -- IRP
   signal SAVESTATE_IRP : std_logic_vector(15 downto 0) := (others => '0');
   signal IRPFLags      : std_logic_vector(15 downto 0) := (others => '0');
   signal IRPFLags_next : std_logic_vector(15 downto 0) := (others => '0');
   
   signal REG_IRP_IF_writeValue  : std_logic_vector(work.pReg_gba_system.IRP_IF .upper downto work.pReg_gba_system.IRP_IF .lower) := (others => '0');
   signal REG_IRP_IF_writeTo     : std_logic;
   
   signal IRP_HBlank  : std_logic;
   signal IRP_VBlank  : std_logic;
   signal IRP_LCDStat : std_logic;
   signal IRP_Timer   : std_logic_vector(3 downto 0);
   signal IRP_DMA     : std_logic_vector(3 downto 0);
   signal IRP_Serial  : std_logic;
   signal IRP_Joypad  : std_logic;
   -- signal IRP_Gamepak : std_logic; -- not implemented
   
   signal memRequ_cnt : unsigned(6 downto 0) := (others => '0');
   signal memResp_cnt : unsigned(6 downto 0) := (others => '0');
   
-- synthesis translate_off
   -- export
   signal cpu_export_done      : std_logic; 
   signal new_export           : std_logic; 
   signal cpu_export           : cpu_export_type;
   signal debug_PF_count       : unsigned(3 downto 0);
   signal debug_PF_countdown   : unsigned(3 downto 0);
-- synthesis translate_on
   
   signal lfsr          : unsigned(22 downto 0) := (others => '0');
   
begin 

   ------------- cycling
   inPause <= pause_active;
   
   process (clk1x)
   begin
      if rising_edge(clk1x) then
         
         ce            <= '0';
         pause_active  <= '0';
         
         lfsr(22 downto 1) <= lfsr(21 downto 0);
         lfsr(0) <= not(lfsr(22) xor lfsr(18));
         
         if (gbaon = '0' or savestate_loadstate = '1') then
            state    <= PAUSING;
            pauseCnt <= (others => '0');
         else
     
            case (state) is
            
               when PAUSING =>
                  if (pauseCnt(8) = '0') then
                     pauseCnt <= pauseCnt + 1;
                  else
                     pause_active <= '1';
                  end if;
                  if (pauseCnt(8 downto 7) > 0 and pause = '0' and sleep_savestate = '0' and sleep_rewind = '0') then
                     state <= WAITUNPAUSE;
                  end if;
                  if (dma_on_next = '1') then -- should never happen here, save exit
                     state <= RUNNING;
                  end if;
                  
               when RUNNING =>
                  ce    <= '1';
                  if (pause = '1' or sleep_savestate = '1' or sleep_rewind = '1' or (KeyPause = '1' and lfsr(5 downto 0) = 0)) then
                     state <= WAITPAUSE;
                  end if;
                  
               when WAITPAUSE =>
                  ce    <= '1';
                  if (dma_on_next = '0' and cpu_jump = '1') then
                     state    <= PAUSING;
                     ce       <= '0'; 
                     pauseCnt <= (others => '0');
                  end if;

               when WAITUNPAUSE =>
                  if (allowUnpause = '1' or is_simu = '1') then
                     state <= RUNNING;
                  end if;
            
            end case;
            
         end if;
      
      end if;
   end process;
   

   -- dummy modules
   igba_reservedregs : entity work.gba_reservedregs port map ( clk1x, gb_bus, reg_wired_or(7), reg_wired_done(7));
   
   igba_serial       : entity work.gba_serial       
   port map 
   ( 
      clk100            => clk1x,
      ce                => ce,
      gb_bus            => gb_bus,           
      wired_out         => reg_wired_or(8),
      wired_done        => reg_wired_done(8),
                         
      IRP_Serial        => IRP_Serial
   );
   
   -- real modules
   igba_joypad : entity work.gba_joypad
   port map
   (
      clk100     => clk1x,
      gb_bus     => gb_bus,           
      wired_out  => reg_wired_or(9),
      wired_done => reg_wired_done(9),
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
   mem_bus_seq  <=  '0'                   when debug_bus_active = '1' else cpu_bus_seq  when cpu_bus_ena = '1' else dma_bus_seq; 
   mem_bus_code <=  '0'                   when debug_bus_active = '1' else CPU_bus_code when cpu_bus_ena = '1' else '0'; 
   mem_bus_acc  <=  debug_bus_acc         when debug_bus_active = '1' else cpu_bus_acc  when cpu_bus_ena = '1' else dma_bus_acc;
   mem_bus_dout <=  debug_bus_dout        when debug_bus_active = '1' else cpu_bus_dout when cpu_bus_ena = '1' else dma_bus_dout;
       
   process (clk1x)
   begin       
      if rising_edge(clk1x) then
      
         if (cpu_done = '1') then
            last_access_dma <= '0';
         elsif (dma_bus_ena = '1') then
            last_access_dma <= '1';
         end if;

      end if;
   end process;
                      
   ------------- debug bus
   process (clk1x)
   begin
      if rising_edge(clk1x) then
   
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
         --elsif (Cheats_Bus_ena = '1') then
         --   debug_bus_active <= '1';
         --   debug_bus_Adr    <= Cheats_BusAddr;
         --   debug_bus_rnw    <= Cheats_BusRnW;
         --   debug_bus_ena    <= '1';
         --   debug_bus_acc    <= Cheats_BusACC;
         --   debug_bus_dout   <= Cheats_BusWriteData;
         end if;
         
         if (debug_bus_active = '1' and mem_bus_done = '1') then
            GBA_BusReadData  <= mem_bus_din;
            debug_bus_active <= '0';
            mem_bus_isCPU    <= '1';
         end if;
         
         if (debug_bus_ena = '1') then
            mem_bus_isCPU <= '0';
            mem_bus_isDMA <= '0';
         elsif (cpu_bus_ena = '1') then
            mem_bus_isCPU <= '1';
            mem_bus_isDMA <= '0';
         elsif (dma_bus_ena = '1') then
            mem_bus_isCPU <= '0';
            mem_bus_isDMA <= '1';
         end if;
         
         error_memRequ_timeout <= '0';
         if (reset = '1' or mem_bus_ena = '1' or flash_busy = '1') then
            memRequ_cnt <= (others => '0');
         elsif (memRequ_cnt(6) = '0') then
            if (ce = '1' and cpu_halt = '0') then
               memRequ_cnt <= memRequ_cnt + 1;
            end if;
         else
            error_memRequ_timeout <= '1';
         end if;
         
         error_memResp_timeout <= '0';
         if (reset = '1' or mem_bus_done = '1' or flash_busy = '1') then
            memResp_cnt <= (others => '0');
         elsif (memResp_cnt(6) = '0') then
            if (ce = '1' and cpu_halt = '0') then
               memResp_cnt <= memResp_cnt + 1;
            end if;
         else
            error_memResp_timeout <= '1';
         end if;
              
      end if;
   end process;
   
   dma_bus_din    <= mem_bus_din;
   dma_bus_done   <= mem_bus_done and mem_bus_isDMA;
   dma_bus_unread <= mem_bus_unread;
   
   cpu_bus_din  <= mem_bus_din;
   cpu_bus_done <= mem_bus_done and mem_bus_isCPU;
   
   cart_reset <= reset;
   
   igba_savestates : entity work.gba_savestates
   generic map
   (
      Softmap_GBA_FLASH_ADDR   => Softmap_GBA_FLASH_ADDR, 
      Softmap_GBA_EEPROM_ADDR  => Softmap_GBA_EEPROM_ADDR,
      is_simu                  => is_simu                
   )
   port map
   (
      clk                   => clk1x,
      gb_on                 => gbaon,
      reset                 => reset,
      register_reset        => register_reset,
  
      load_done             => load_done,
                        
      increaseSSHeaderCount => increaseSSHeaderCount,
      save                  => savestate_savestate,
      load                  => savestate_loadstate,
      savestate_address     => savestate_address,
      savestate_busy        => savestate_busy,      

      internal_bus_out      => savestate_bus,
      wired_out             => ss_wired_out,
      wired_done            => ss_wired_done,
      
      loading_savestate     => loading_savestate,
      saving_savestate      => saving_savestate,
      sleep_savestate       => sleep_savestate,
      pause_active          => pause_active,

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
     
   process (save_wired_or)
      variable wired_or : std_logic_vector(31 downto 0);
   begin
      wired_or := save_wired_or(0);
      for i in 1 to (save_wired_or'length - 1) loop
         wired_or := wired_or or save_wired_or(i);
      end loop;
      ss_wired_out <= wired_or;
   end process;
   ss_wired_done <= '0' when (save_wired_done = 0) else '1';
   
   igba_statemanager : entity work.gba_statemanager
   generic map
   (
      Softmap_SaveState_ADDR   => Softmap_SaveState_ADDR,
      Softmap_Rewind_ADDR      => Softmap_Rewind_ADDR   
   )
   port map
   (
      clk100              => clk1x,
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
   
   --igba_cheats : entity work.gba_cheats
   --port map
   --(
   --   clk100         => clk1x,
   --   gb_on          => GBA_on,
   --                   
   --   cheat_clear    => cheat_clear,
   --   cheats_enabled => cheats_enabled,
   --   cheat_on       => cheat_on,
   --   cheat_in       => cheat_in,
   --   cheats_active  => cheats_active,
   --                  
   --   vsync          => vblank_trigger,
   --                  
   --   bus_ena_in     => mem_bus_ena,
   --   sleep_cheats   => sleep_cheats,
   --                 
   --   BusAddr        => Cheats_BusAddr,     
   --   BusRnW         => Cheats_BusRnW,      
   --   BusACC         => Cheats_BusACC,      
   --   BusWriteData   => Cheats_BusWriteData,
   --   Bus_ena        => Cheats_Bus_ena,     
   --   BusReadData    => mem_bus_din, 
   --   BusDone        => mem_bus_done
   --);
   
   savestate_bus_ext  <= savestate_bus;
   save_wired_or(1)   <= ss_wired_out_ext;
   save_wired_done(1) <= ss_wired_done_ext;
   
   cart_idle <= '1' when (reset = '1') else
                '1' when (cpu_halt = '1') else
                '1' when (ce = '0' and (is_simu = '0' or sleep_savestate = '0')) else
                '1' when (cpu_bus_ena = '1' and mem_bus_Adr(27) = '0') else
                '1' when (dma_bus_ena = '1' and dma_bus_norom = '1') else
                '0';
   
   igba_memorymux : entity work.gba_memorymux
   generic map
   (
      is_simu                  => is_simu,     
      Softmap_GBA_Gamerom_ADDR => Softmap_GBA_Gamerom_ADDR,
      Softmap_GBA_FLASH_ADDR   => Softmap_GBA_FLASH_ADDR,
      Softmap_GBA_EEPROM_ADDR  => Softmap_GBA_EEPROM_ADDR
   )
   port map
   (
      clk                  => clk1x,
      reset                => reset,
      ce                   => ce,
                           
      sleep_savestate      => sleep_savestate,
      loading_savestate    => loading_savestate,
      saving_savestate     => saving_savestate,
      register_reset       => register_reset,
      
      cart_ena             => cart_ena,      
      cart_32              => cart_32,          
      cart_rnw             => cart_rnw,      
      cart_addr            => cart_addr,     
      cart_writedata       => cart_writedata,
      cart_done            => cart_done,     
      cart_readdata        => cart_readdata, 
      
      cart_waitcnt         => REG_WAITCNT,
      
-- synthesis translate_off
      debug_PF_count       => debug_PF_count,    
      debug_PF_countdown   => debug_PF_countdown,
-- synthesis translate_on 
      
      gb_bus_out           => gb_bus,           
      wired_out            => wired_out, 
      wired_done           => wired_done,
      
      bios_wraddr          => bios_wraddr,
      bios_wrdata          => bios_wrdata,
      bios_wr              => bios_wr,

      mem_bus_Adr          => mem_bus_Adr, 
      mem_bus_rnw          => mem_bus_rnw, 
      mem_bus_ena          => mem_bus_ena, 
      mem_bus_seq          => mem_bus_seq, 
      mem_bus_code         => mem_bus_code, 
      mem_bus_acc          => mem_bus_acc, 
      mem_bus_dout         => mem_bus_dout,
      mem_bus_din          => mem_bus_din, 
      mem_bus_done_out     => mem_bus_done,
      mem_bus_unread       => mem_bus_unread,
      
      bus_lowbits          => bus_lowbits,
      
      dma_on               => dma_on,
      
      PC_in_BIOS           => PC_in_BIOS,
      lastread             => lastread,
      lastread_dma         => lastread_dma,
      last_access_dma      => last_access_dma,
      
      bitmapdrawmode       => bitmapdrawmode,
      
      VRAM_Lo_addr         => VRAM_Lo_addr,   
      VRAM_Lo_datain       => VRAM_Lo_datain, 
      VRAM_Lo_dataout      => VRAM_Lo_dataout,
      VRAM_Lo_ce           => VRAM_Lo_ce,     
      VRAM_Lo_we           => VRAM_Lo_we,     
      VRAM_Lo_be           => VRAM_Lo_be,     
      VRAM_Hi_addr         => VRAM_Hi_addr,   
      VRAM_Hi_datain       => VRAM_Hi_datain, 
      VRAM_Hi_dataout      => VRAM_Hi_dataout,
      VRAM_Hi_ce           => VRAM_Hi_ce,     
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
      PALETTE_BG_re        => PALETTE_BG_re,      
      PALETTE_OAM_addr     => PALETTE_OAM_addr,   
      PALETTE_OAM_datain   => PALETTE_OAM_datain, 
      PALETTE_OAM_dataout  => PALETTE_OAM_dataout,
      PALETTE_OAM_we       => PALETTE_OAM_we,
      PALETTE_OAM_re       => PALETTE_OAM_re
   );
   
   CPU_bus_idleDone <= CPU_bus_idle or cpu_bus_done;
   
   igba_dma : entity work.gba_dma
   port map
   (
      clk                 => clk1x,
      reset               => reset,
                           
      savestate_bus       => savestate_bus,
      ss_wired_out        => save_wired_or(2),
      ss_wired_done       => save_wired_done(2),
      loading_savestate   => loading_savestate,
      
      gb_bus              => gb_bus,           
      wired_out           => reg_wired_or(10),
      wired_done          => reg_wired_done(10),
      
      IRP_DMA             => IRP_DMA,
      lastread_dma        => lastread_dma,
      
      dma_on              => dma_on,
      dma_on_next         => dma_on_next,
      CPU_bus_idle        => CPU_bus_idleDone,
      
      sound_dma_req       => sound_dma_req,
      hblank_trigger      => hblank_trigger,
      vblank_trigger      => vblank_trigger,
      videodma_start      => videodma_start,
      videodma_stop       => videodma_stop ,   
      
      dma_eepromcount     => dma_eepromcount,
      
      dma_bus_Adr         => dma_bus_Adr, 
      dma_bus_rnw         => dma_bus_rnw, 
      dma_bus_ena         => dma_bus_ena, 
      dma_bus_seq         => dma_bus_seq, 
      dma_bus_norom       => dma_bus_norom, 
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
      clk1x                => clk1x,
      ce                   => ce,
      reset                => reset,
      
      savestate_bus        => savestate_bus,
      ss_wired_out         => save_wired_or(3),
      ss_wired_done        => save_wired_done(3),
      loading_savestate    => loading_savestate,
      
      gb_bus               => gb_bus,           
      wired_out            => reg_wired_or(11),
      wired_done           => reg_wired_done(11),
      
      lockspeed            => GBA_lockspeed,
      
      timer0_tick          => timer0_tick,
      timer1_tick          => timer1_tick,
      sound_dma_req        => sound_dma_req,
      
      sound_out_left       => sound_out_left,
      sound_out_right      => sound_out_right,
      
      debug_fifocount      => sound_fifocount
   );
   
   igba_gpu : entity work.gba_gpu
   generic map
   (
      is_simu => is_simu
   )
   port map
   (
      clk                  => clk1x,
      ce                   => ce,
      reset                => reset,
      
      savestate_bus        => savestate_bus,
      ss_wired_out         => save_wired_or(4),
      ss_wired_done        => save_wired_done(4),

      gb_bus               => gb_bus,           
      wired_out            => reg_wired_or(12),
      wired_done           => reg_wired_done(12),

      lockspeed            => GBA_lockspeed,
      interframe_blend     => interframe_blend,
      shade_mode           => shade_mode,
      
      bitmapdrawmode       => bitmapdrawmode,

      pixel_out_x          => pixel_out_x,
      pixel_out_y          => pixel_out_y,
      pixel_out_addr       => pixel_out_addr,
      pixel_out_data       => pixel_out_data,
      pixel_out_we         => pixel_out_we,  
              
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
      VRAM_Lo_ce           => VRAM_Lo_ce,     
      VRAM_Lo_we           => VRAM_Lo_we,     
      VRAM_Lo_be           => VRAM_Lo_be,     
      VRAM_Hi_addr         => VRAM_Hi_addr,   
      VRAM_Hi_datain       => VRAM_Hi_datain, 
      VRAM_Hi_dataout      => VRAM_Hi_dataout,
      VRAM_Hi_ce           => VRAM_Hi_ce,        
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
      PALETTE_BG_re        => PALETTE_BG_re,      
      PALETTE_OAM_addr     => PALETTE_OAM_addr,   
      PALETTE_OAM_datain   => PALETTE_OAM_datain, 
      PALETTE_OAM_dataout  => PALETTE_OAM_dataout,
      PALETTE_OAM_we       => PALETTE_OAM_we,            
      PALETTE_OAM_re       => PALETTE_OAM_re,            
   
      DISPSTAT_debug       => DISPSTAT_debug       
   );
   
   igba_timer : entity work.gba_timer
   generic map
   (
      is_simu => is_simu
   )
   port map
   (
      clk               => clk1x,
      ce                => ce,
      reset             => reset,
                            
      savestate_bus     => savestate_bus,
      ss_wired_out      => save_wired_or(5),
      ss_wired_done     => save_wired_done(5),
      loading_savestate => loading_savestate,
      
      gb_bus            => gb_bus,           
      wired_out         => reg_wired_or(13),
      wired_done        => reg_wired_done(13),
      
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
      clk              => clk1x, 
      ce               => ce,
      reset            => reset,
      
-- synthesis translate_off
      cpu_export_done  => cpu_export_done,  
      cpu_export       => cpu_export,
-- synthesis translate_on

      error_cpu        => error_cpu,
      
      savestate_bus    => savestate_bus,
      ss_wired_out     => save_wired_or(6),
      ss_wired_done    => save_wired_done(6),
      
      gb_bus_Adr       => cpu_bus_Adr, 
      gb_bus_rnw       => cpu_bus_rnw, 
      gb_bus_ena       => cpu_bus_ena, 
      gb_bus_seq       => cpu_bus_seq, 
      gb_bus_code      => CPU_bus_code, 
      gb_bus_acc       => cpu_bus_acc, 
      gb_bus_dout      => cpu_bus_dout,
      gb_bus_din       => cpu_bus_din, 
      gb_bus_done      => cpu_bus_done,
      
      bus_lowbits      => bus_lowbits,
      
      dma_on           => dma_on,
      done             => cpu_done,
      CPU_bus_idle     => CPU_bus_idle,
      PC_in_BIOS       => PC_in_BIOS,
      cpu_halt         => cpu_halt,
      lastread         => lastread,
      jump_out         => cpu_jump,
      
      IRQ_in           => cpu_irq,
      unhalt           => cpu_unhalt,
      new_halt         => new_halt
   );
   
   iREG_IRP_IE  : entity work.eProcReg_gba generic map (work.pReg_gba_system.IRP_IE ) port map  (clk1x, gb_bus, reg_wired_or(0), reg_wired_done(0), REG_IRP_IE , REG_IRP_IE );
   iREG_IRP_IF  : entity work.eProcReg_gba generic map (work.pReg_gba_system.IRP_IF ) port map  (clk1x, gb_bus, reg_wired_or(1), reg_wired_done(1), IRPFLags   , REG_IRP_IF , open, REG_IRP_IF_writeValue, REG_IRP_IF_writeTo);                                                                                                                   
   iREG_WAITCNT : entity work.eProcReg_gba generic map (work.pReg_gba_system.WAITCNT) port map  (clk1x, gb_bus, reg_wired_or(2), reg_wired_done(2), REG_WAITCNT, REG_WAITCNT, WAITCNT_written);                                                                                                                     
   iREG_ISCGB   : entity work.eProcReg_gba generic map (work.pReg_gba_system.ISCGB  ) port map  (clk1x, gb_bus, reg_wired_or(3), reg_wired_done(3), "0");                                                                                                                     
   iREG_IME     : entity work.eProcReg_gba generic map (work.pReg_gba_system.IME    ) port map  (clk1x, gb_bus, reg_wired_or(4), reg_wired_done(4), REG_IME    , REG_IME    );                                                                                                                       
   iREG_POSTFLG : entity work.eProcReg_gba generic map (work.pReg_gba_system.POSTFLG) port map  (clk1x, gb_bus, reg_wired_or(5), reg_wired_done(5), REG_POSTFLG, REG_POSTFLG);
   iREG_HALTCNT : entity work.eProcReg_gba generic map (work.pReg_gba_system.HALTCNT) port map  (clk1x, gb_bus, reg_wired_or(6), reg_wired_done(6), (REG_HALTCNT'range => '0'), REG_HALTCNT, REG_HALTCNT_written);

   process (reg_wired_or)
      variable wired_or : std_logic_vector(31 downto 0);
   begin
      wired_or := reg_wired_or(0);
      for i in 1 to (reg_wired_or'length - 1) loop
         wired_or := wired_or or reg_wired_or(i);
      end loop;
      wired_out <= wired_or;
   end process;
   wired_done <= '0' when (reg_wired_done = 0) else '1';

   iSAVESTATE_IRP   : entity work.eProcReg_gba generic map (REG_SAVESTATE_IRP  ) port map (clk1x, savestate_bus, save_wired_or(0), save_wired_done(0), IRPFLags , SAVESTATE_IRP);

   cart_waitcnt <= '0' & REG_WAITCNT;

   debug_irq(15 downto 0) <= IRPFLags;
   debug_irq(16) <= REG_IME(0);
   debug_irq(31 downto 17) <= (others => '0');

   ------------- interrupt
   process (clk1x)
   begin
      if rising_edge(clk1x) then
   
         gbaon <= GBA_on;
         

         if (reset = '1') then -- reset
   
            IRPFLags      <= SAVESTATE_IRP;
            IRPFLags_next <= (others => '0');
      
         elsif (ce = '1') then

            IRPFLags <= IRPFLags or IRPFLags_next;
            
            if (REG_IRP_IF_writeTo = '1') then
               IRPFLags <= (IRPFLags or IRPFLags_next) and not REG_IRP_IF_writeValue;
            end if;
         
            IRPFLags_next <= (others => '0');
            if (IRP_VBlank = '1')   then IRPFLags_next( 0) <= '1'; end if;
            if (IRP_HBlank = '1')   then IRPFLags_next( 1) <= '1'; end if;
            if (IRP_LCDStat = '1')  then IRPFLags_next( 2) <= '1'; end if;
            if (IRP_Timer(0) = '1') then IRPFLags_next( 3) <= '1'; end if;
            if (IRP_Timer(1) = '1') then IRPFLags_next( 4) <= '1'; end if;
            if (IRP_Timer(2) = '1') then IRPFLags_next( 5) <= '1'; end if;
            if (IRP_Timer(3) = '1') then IRPFLags_next( 6) <= '1'; end if;
            if (IRP_Serial = '1')   then IRPFLags_next( 7) <= '1'; end if;
            if (IRP_DMA(0) = '1')   then IRPFLags_next( 8) <= '1'; end if;
            if (IRP_DMA(1) = '1')   then IRPFLags_next( 9) <= '1'; end if;
            if (IRP_DMA(2) = '1')   then IRPFLags_next(10) <= '1'; end if;
            if (IRP_DMA(3) = '1')   then IRPFLags_next(11) <= '1'; end if;
            if (IRP_Joypad = '1')   then IRPFLags_next(12) <= '1'; end if;
            --if (IRP_Gamepak = '1')  then IRPFLags_next(13) <= '1'; end if; -- not implemented
      
            cpu_unhalt   <= '0';
            cpu_irq_next <= '0';
            cpu_irq      <= cpu_irq_next;
            if ((IRPFLags and REG_IRP_IE) /= x"0000") then
               cpu_unhalt <= '1';
               if (REG_IME(0) = '1') then
                  cpu_irq_next <= '1';
               end if;
            end if;

         end if;

      end if;
   end process;
   
   new_halt <= '1' when (PC_in_BIOS = '1' and cpu_bus_ena = '1' and cpu_bus_rnw = '0' and cpu_bus_acc = ACCESS_32BIT and (cpu_bus_Adr(31 downto 2) & "00") = x"04000300") else 
               '1' when (PC_in_BIOS = '1' and cpu_bus_ena = '1' and cpu_bus_rnw = '0' and cpu_bus_acc = ACCESS_16BIT and (cpu_bus_Adr(31 downto 1) & "0")  = x"04000300") else 
               '1' when (PC_in_BIOS = '1' and cpu_bus_ena = '1' and cpu_bus_rnw = '0' and cpu_bus_acc = ACCESS_8BIT  and  cpu_bus_Adr                      = x"04000301") else 
               '0';
   
-- export
-- synthesis translate_off
   iexport : entity work.export
   port map
   (
      clk               => clk1x,
      ce                => ce,
      reset             => reset,
         
      new_export        => cpu_export_done,
      export_cpu        => cpu_export,
      export_line       => unsigned(DISPSTAT_debug(23 downto 16)),
      export_dispstat   => unsigned(DISPSTAT_debug(7 downto 0)),
      export_IRPFLags   => unsigned(IRPFLags),
      export_timer0     => timerdebug0,
      export_timer1     => timerdebug1,
      export_timer2     => timerdebug2,
      export_timer3     => timerdebug3,
      PF_count          => debug_PF_count,    
      PF_countdown      => debug_PF_countdown,
      sound_fifocount   => sound_fifocount
   );
-- synthesis translate_on


end architecture;





