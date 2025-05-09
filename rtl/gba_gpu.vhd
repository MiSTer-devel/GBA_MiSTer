library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

library MEM;

use work.pProc_bus_gba.all;
use work.pReg_gba_display.all;

entity gba_gpu is
   generic
   (
      is_simu : std_logic
   );
   port 
   (
      clk                  : in    std_logic;  
      ce                   : in    std_logic;
      reset                : in    std_logic;
      
      savestate_bus        : in    proc_bus_gb_type;
      ss_wired_out         : out   std_logic_vector(proc_buswidth-1 downto 0) := (others => '0');
      ss_wired_done        : out   std_logic;
                           
      gb_bus               : in    proc_bus_gb_type;
      wired_out            : out   std_logic_vector(proc_buswidth-1 downto 0) := (others => '0');
      wired_done           : out   std_logic;
                      
      lockspeed            : in    std_logic;
      interframe_blend     : in    std_logic_vector(1 downto 0);
      shade_mode           : in    std_logic_vector(2 downto 0);
      
      bitmapdrawmode       : out   std_logic;
                  
      pixel_out_x          : out   integer range 0 to 239;
      pixel_out_y          : out   integer range 0 to 159;
      pixel_out_addr       : out   integer range 0 to 38399;
      pixel_out_data       : out   std_logic_vector(14 downto 0);  
      pixel_out_we         : out   std_logic := '0';
                                   
      IRP_HBlank           : out   std_logic;
      IRP_VBlank           : out   std_logic;
      IRP_LCDStat          : out   std_logic;
                           
      hblank_trigger       : buffer std_logic;
      vblank_trigger       : buffer std_logic;
      videodma_start       : out    std_logic;
      videodma_stop        : out    std_logic;
                          
      VRAM_Lo_addr         : in    integer range 0 to 16383;
      VRAM_Lo_datain       : in    std_logic_vector(31 downto 0);
      VRAM_Lo_dataout      : out   std_logic_vector(31 downto 0);
      VRAM_Lo_ce           : in    std_logic;
      VRAM_Lo_we           : in    std_logic;
      VRAM_Lo_be           : in    std_logic_vector(3 downto 0);
      VRAM_Hi_addr         : in    integer range 0 to 8191;
      VRAM_Hi_datain       : in    std_logic_vector(31 downto 0);
      VRAM_Hi_dataout      : out   std_logic_vector(31 downto 0);
      VRAM_Hi_ce           : in    std_logic;
      VRAM_Hi_we           : in    std_logic;
      VRAM_Hi_be           : in    std_logic_vector(3 downto 0);
      vram_blocked         : out   std_logic;
                           
      OAMRAM_PROC_addr     : in    integer range 0 to 255;
      OAMRAM_PROC_datain   : in    std_logic_vector(31 downto 0);
      OAMRAM_PROC_dataout  : out   std_logic_vector(31 downto 0);
      OAMRAM_PROC_we       : in    std_logic_vector(3 downto 0);
                           
      PALETTE_BG_addr      : in    integer range 0 to 128;
      PALETTE_BG_datain    : in    std_logic_vector(31 downto 0);
      PALETTE_BG_dataout   : out   std_logic_vector(31 downto 0);
      PALETTE_BG_we        : in    std_logic_vector(3 downto 0);
      PALETTE_BG_re        : in    std_logic_vector(3 downto 0);
      PALETTE_OAM_addr     : in    integer range 0 to 128;
      PALETTE_OAM_datain   : in    std_logic_vector(31 downto 0);
      PALETTE_OAM_dataout  : out   std_logic_vector(31 downto 0);
      PALETTE_OAM_we       : in    std_logic_vector(3 downto 0);
      PALETTE_OAM_re       : in    std_logic_vector(3 downto 0);
      
      DISPSTAT_debug       : out std_logic_vector(31 downto 0)
   );
end entity;

architecture arch of gba_gpu is

   type t_reg_wired_or is array(0 to 1) of std_logic_vector(31 downto 0);
   signal reg_wired_or    : t_reg_wired_or;   
   signal reg_wired_done  : unsigned(0 to 1);

   -- wiring
   signal drawline             : std_logic;
   signal drawObj              : std_logic;
   signal line_trigger         : std_logic;
   signal refpoint_update      : std_logic;
   signal newline_invsync      : std_logic;
   signal linecounter_drawer   : unsigned(7 downto 0);
   signal linecounter_obj      : unsigned(7 downto 0);
   
   signal pixel_x              : integer range 0 to 239;
   signal pixel_y              : integer range 0 to 159;
   signal pixel_addr           : integer range 0 to 38399;
   signal pixel_data           : std_logic_vector(14 downto 0);  
   signal pixel_we             : std_logic := '0';

   signal vram_block_mode      : std_logic;
begin 

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

   igba_gpu_timing : entity work.gba_gpu_timing
   generic map
   (
      is_simu => is_simu
   )
   port map
   (
      clk                          => clk,
      ce                           => ce,
      reset                        => reset,
      lockspeed                    => lockspeed,
      
      savestate_bus                => savestate_bus,
      ss_wired_out                 => ss_wired_out, 
      ss_wired_done                => ss_wired_done,
            
      gb_bus                       => gb_bus,           
      wired_out                    => reg_wired_or(0),
      wired_done                   => reg_wired_done(0),
                                   
      IRP_HBlank                   => IRP_HBlank,
      IRP_VBlank                   => IRP_VBlank, 
      IRP_LCDStat                  => IRP_LCDStat,
      
      vram_block_mode              => vram_block_mode,
      vram_blocked                 => vram_blocked, 

      videodma_start               => videodma_start,
      videodma_stop                => videodma_stop,       
           
      line_trigger                 => line_trigger,
      hblank_trigger               => hblank_trigger,                            
      vblank_trigger               => vblank_trigger,                            
      drawline                     => drawline,   
      drawObj                      => drawObj,   
      refpoint_update              => refpoint_update,   
      newline_invsync              => newline_invsync,   
      linecounter_drawer           => linecounter_drawer, 
      linecounter_obj              => linecounter_obj, 
                                   
      DISPSTAT_debug               => DISPSTAT_debug
   );

   igba_gpu_drawer : entity work.gba_gpu_drawer
   generic map
   (
      is_simu => is_simu
   )
   port map
   (
      clk                    => clk,
      
      gb_bus                 => gb_bus,           
      wired_out              => reg_wired_or(1),
      wired_done             => reg_wired_done(1),
      
      lockspeed              => lockspeed,
      interframe_blend       => interframe_blend,
      
      bitmapdrawmode         => bitmapdrawmode,
      vram_block_mode        => vram_block_mode,
      
      pixel_out_x            => pixel_out_x,       
      pixel_out_y            => pixel_out_y,   
      pixel_out_addr         => pixel_out_addr,
      pixel_out_data         => pixel_out_data,
      pixel_out_we           => pixel_out_we, 
                             
      linecounter            => linecounter_drawer,    
      linecounter_obj        => linecounter_obj,    
      drawline               => drawline,
      drawObj                => drawObj,
      refpoint_update        => refpoint_update,
      hblank_trigger         => hblank_trigger,  
      vblank_trigger         => vblank_trigger,  
      line_trigger           => line_trigger,  
      newline_invsync        => newline_invsync,         
            
      VRAM_Lo_addr           => VRAM_Lo_addr,   
      VRAM_Lo_datain         => VRAM_Lo_datain, 
      VRAM_Lo_dataout        => VRAM_Lo_dataout,
      VRAM_Lo_ce             => VRAM_Lo_ce,     
      VRAM_Lo_we             => VRAM_Lo_we,     
      VRAM_Lo_be             => VRAM_Lo_be,     
      VRAM_Hi_addr           => VRAM_Hi_addr,   
      VRAM_Hi_datain         => VRAM_Hi_datain, 
      VRAM_Hi_dataout        => VRAM_Hi_dataout,
      VRAM_Hi_ce             => VRAM_Hi_ce,           
      VRAM_Hi_we             => VRAM_Hi_we,           
      VRAM_Hi_be             => VRAM_Hi_be,           
                                                
      OAMRAM_PROC_addr       => OAMRAM_PROC_addr,    
      OAMRAM_PROC_datain     => OAMRAM_PROC_datain,  
      OAMRAM_PROC_dataout    => OAMRAM_PROC_dataout, 
      OAMRAM_PROC_we         => OAMRAM_PROC_we,      
                                                 
      PALETTE_BG_addr        => PALETTE_BG_addr,    
      PALETTE_BG_datain      => PALETTE_BG_datain,  
      PALETTE_BG_dataout     => PALETTE_BG_dataout, 
      PALETTE_BG_we          => PALETTE_BG_we,      
      PALETTE_BG_re          => PALETTE_BG_re,      
      PALETTE_OAM_addr       => PALETTE_OAM_addr,   
      PALETTE_OAM_datain     => PALETTE_OAM_datain, 
      PALETTE_OAM_dataout    => PALETTE_OAM_dataout,
      PALETTE_OAM_we         => PALETTE_OAM_we,     
      PALETTE_OAM_re         => PALETTE_OAM_re     
   ); 

end architecture;





