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
      clk100               : in    std_logic;  
      gb_on                : in  std_logic;
                           
      gb_bus               : inout proc_bus_gb_type := ((others => 'Z'), (others => 'Z'), (others => 'Z'), 'Z', 'Z', 'Z', "ZZ", "ZZZZ", 'Z');
                           
      pixel_out_addr       : out   integer range 0 to 38399;
      pixel_out_data       : out   std_logic_vector(14 downto 0);  
      pixel_out_we         : out   std_logic := '0';
                           
      new_cycles           : in    unsigned(7 downto 0);
      new_cycles_valid     : in    std_logic;
                                   
      IRP_HBlank           : out   std_logic;
      IRP_VBlank           : out   std_logic;
      IRP_LCDStat          : out   std_logic;
                           
      hblank_trigger       : buffer std_logic;
      vblank_trigger       : buffer std_logic;
                          
      VRAM_Lo_addr         : in    integer range 0 to 16383;
      VRAM_Lo_datain       : in    std_logic_vector(31 downto 0);
      VRAM_Lo_dataout      : out   std_logic_vector(31 downto 0);
      VRAM_Lo_we           : in    std_logic;
      VRAM_Lo_be           : in    std_logic_vector(3 downto 0);
      VRAM_Hi_addr         : in    integer range 0 to 8191;
      VRAM_Hi_datain       : in    std_logic_vector(31 downto 0);
      VRAM_Hi_dataout      : out   std_logic_vector(31 downto 0);
      VRAM_Hi_we           : in    std_logic;
      VRAM_Hi_be           : in    std_logic_vector(3 downto 0);
                           
      OAMRAM_PROC_addr     : in    integer range 0 to 255;
      OAMRAM_PROC_datain   : in    std_logic_vector(31 downto 0);
      OAMRAM_PROC_dataout  : out   std_logic_vector(31 downto 0);
      OAMRAM_PROC_we       : in    std_logic_vector(3 downto 0);
                           
      PALETTE_BG_addr      : in    integer range 0 to 128;
      PALETTE_BG_datain    : in    std_logic_vector(31 downto 0);
      PALETTE_BG_dataout   : out   std_logic_vector(31 downto 0);
      PALETTE_BG_we        : in    std_logic_vector(3 downto 0);
      PALETTE_OAM_addr     : in    integer range 0 to 128;
      PALETTE_OAM_datain   : in    std_logic_vector(31 downto 0);
      PALETTE_OAM_dataout  : out   std_logic_vector(31 downto 0);
      PALETTE_OAM_we       : in    std_logic_vector(3 downto 0);
      
      DISPSTAT_debug       : out std_logic_vector(31 downto 0)
   );
end entity;

architecture arch of gba_gpu is

   -- wiring
   signal drawline             : std_logic;
   signal refpoint_update      : std_logic;
   signal linecounter_drawer   : unsigned(7 downto 0);

   
begin 

   igba_gpu_timing : entity work.gba_gpu_timing
   generic map
   (
      is_simu => is_simu
   )
   port map
   (
      clk100                       => clk100,
      gb_on                        => gb_on,
            
      gb_bus                       => gb_bus,
            
      new_cycles                   => new_cycles,      
      new_cycles_valid             => new_cycles_valid,
                                   
      IRP_HBlank                   => IRP_HBlank,
      IRP_VBlank                   => IRP_VBlank, 
      IRP_LCDStat                  => IRP_LCDStat,
                                   
      hblank_trigger               => hblank_trigger,                            
      vblank_trigger               => vblank_trigger,                            
      drawline                     => drawline,   
      refpoint_update              => refpoint_update,   
      linecounter_drawer           => linecounter_drawer,             
                                   
      DISPSTAT_debug               => DISPSTAT_debug
   );

   igba_gpu_drawer : entity work.gba_gpu_drawer
   generic map
   (
      is_simu => is_simu
   )
   port map
   (
      clk100                 => clk100,
      
      gb_bus                 => gb_bus,
      
      pixel_out_addr         => pixel_out_addr,
      pixel_out_data         => pixel_out_data,
      pixel_out_we           => pixel_out_we,  
                             
      linecounter            => linecounter_drawer,  
      drawline               => drawline,
      refpoint_update        => refpoint_update,
      hblank_trigger         => hblank_trigger,  
      vblank_trigger         => vblank_trigger,  
      
      VRAM_Lo_addr           => VRAM_Lo_addr,   
      VRAM_Lo_datain         => VRAM_Lo_datain, 
      VRAM_Lo_dataout        => VRAM_Lo_dataout,
      VRAM_Lo_we             => VRAM_Lo_we,     
      VRAM_Lo_be             => VRAM_Lo_be,     
      VRAM_Hi_addr           => VRAM_Hi_addr,   
      VRAM_Hi_datain         => VRAM_Hi_datain, 
      VRAM_Hi_dataout        => VRAM_Hi_dataout,
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
      PALETTE_OAM_addr       => PALETTE_OAM_addr,   
      PALETTE_OAM_datain     => PALETTE_OAM_datain, 
      PALETTE_OAM_dataout    => PALETTE_OAM_dataout,
      PALETTE_OAM_we         => PALETTE_OAM_we     
   );         
   

end architecture;





