library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

use work.pProc_bus_gba.all;
use work.pReg_gba_dma.all;

entity gba_dma is
   port 
   (
      clk100              : in    std_logic;  
      gb_bus              : inout proc_bus_gb_type := ((others => 'Z'), (others => 'Z'), (others => 'Z'), 'Z', 'Z', 'Z', "ZZ", "ZZZZ", 'Z');
      
      IRP_DMA             : out   std_logic_vector(3 downto 0);
      
      dma_on              : out   std_logic;
      CPU_bus_idle        : in    std_logic;
      do_step             : in    std_logic;
      
      sound_dma_req       : in    std_logic_vector(1 downto 0);
      hblank_trigger      : in    std_logic;
      vblank_trigger      : in    std_logic;
      
      dma_new_cycles      : out   std_logic := '0'; 
      dma_first_cycles    : out   std_logic := '0';
      dma_dword_cycles    : out   std_logic := '0';
      dma_cycles_adrup    : out   std_logic_vector(3 downto 0) := (others => '0'); 
      
      dma_eepromcount     : out   unsigned(16 downto 0);
      
      dma_bus_Adr         : out    std_logic_vector(27 downto 0);
      dma_bus_rnw         : buffer std_logic;
      dma_bus_ena         : out    std_logic;
      dma_bus_acc         : out    std_logic_vector(1 downto 0);
      dma_bus_dout        : out    std_logic_vector(31 downto 0);
      dma_bus_din         : in     std_logic_vector(31 downto 0);
      dma_bus_done        : in     std_logic
   );
end entity;

architecture arch of gba_dma is

   type tArray_Dout is array(0 to 3) of std_logic_vector(31 downto 0);
   type tArray_Adr  is array(0 to 3) of std_logic_vector(27 downto 0);
   type tArray_acc  is array(0 to 3) of std_logic_vector(1 downto 0);
   type tArray_rnw  is array(0 to 3) of std_logic;
   type tArray_ena  is array(0 to 3) of std_logic;
   type tArray_done is array(0 to 3) of std_logic;
   
   signal Array_Dout : tArray_Dout;
   signal Array_Adr  : tArray_Adr;
   signal Array_acc  : tArray_acc;
   signal Array_rnw  : tArray_rnw;
   signal Array_ena  : tArray_ena;
   signal Array_done : tArray_done;
             
   signal single_new_cycles   : std_logic_vector(3 downto 0);
   signal single_first_cycles : std_logic_vector(3 downto 0);
   signal single_dword_cycles : std_logic_vector(3 downto 0);
   signal single_cycles_adrup : std_logic_vector(15 downto 0);
   
             
   signal single_dma_on   : std_logic_vector(3 downto 0);
   signal single_allow_on : std_logic_vector(3 downto 0);
   
   signal dma_switch : integer range 0 to 3 := 0; 
   
   signal dma_idle   : std_logic := '1';
           
begin 

   igba_dma_module0 : entity work.gba_dma_module
   generic map
   (
      index                        => 0,
      has_DRQ                      => false,
      Reg_SAD                      => DMA0SAD                     ,
      Reg_DAD                      => DMA0DAD                     ,
      Reg_CNT_L                    => DMA0CNT_L                   ,
      Reg_CNT_H_Dest_Addr_Control  => DMA0CNT_H_Dest_Addr_Control ,
      Reg_CNT_H_Source_Adr_Control => DMA0CNT_H_Source_Adr_Control,
      Reg_CNT_H_DMA_Repeat         => DMA0CNT_H_DMA_Repeat        ,
      Reg_CNT_H_DMA_Transfer_Type  => DMA0CNT_H_DMA_Transfer_Type ,
      Reg_CNT_H_Game_Pak_DRQ       => DMA3CNT_H_Game_Pak_DRQ      , --unsued
      Reg_CNT_H_DMA_Start_Timing   => DMA0CNT_H_DMA_Start_Timing  ,
      Reg_CNT_H_IRQ_on             => DMA0CNT_H_IRQ_on            ,
      Reg_CNT_H_DMA_Enable         => DMA0CNT_H_DMA_Enable       
   )                                  
   port map
   (
      clk100           => clk100,          
      gb_bus           => gb_bus,
      
      IRP_DMA          => IRP_DMA(0),
                      
      dma_on           => single_dma_on(0),
      allow_on         => single_allow_on(0),
                      
      sound_dma_req    => '0', 
      hblank_trigger   => hblank_trigger,
      vblank_trigger   => vblank_trigger,
      
      dma_new_cycles   => single_new_cycles(0), 
      dma_first_cycles => single_first_cycles(0),
      dma_dword_cycles => single_dword_cycles(0),
      dma_cycles_adrup => single_cycles_adrup(3 downto 0),
      
      dma_eepromcount  => open,
      
      dma_bus_Adr      => Array_Adr(0),
      dma_bus_rnw      => Array_rnw(0), 
      dma_bus_ena      => Array_ena(0), 
      dma_bus_acc      => Array_acc(0), 
      dma_bus_dout     => Array_Dout(0), 
      dma_bus_din      => dma_bus_din,
      dma_bus_done     => Array_done(0)
   );
   
   igba_dma_module1 : entity work.gba_dma_module
   generic map
   (
      index                        => 1,
      has_DRQ                      => false,
      Reg_SAD                      => DMA1SAD                     ,
      Reg_DAD                      => DMA1DAD                     ,
      Reg_CNT_L                    => DMA1CNT_L                   ,
      Reg_CNT_H_Dest_Addr_Control  => DMA1CNT_H_Dest_Addr_Control ,
      Reg_CNT_H_Source_Adr_Control => DMA1CNT_H_Source_Adr_Control,
      Reg_CNT_H_DMA_Repeat         => DMA1CNT_H_DMA_Repeat        ,
      Reg_CNT_H_DMA_Transfer_Type  => DMA1CNT_H_DMA_Transfer_Type ,
      Reg_CNT_H_Game_Pak_DRQ       => DMA3CNT_H_Game_Pak_DRQ      , --unsued
      Reg_CNT_H_DMA_Start_Timing   => DMA1CNT_H_DMA_Start_Timing  ,
      Reg_CNT_H_IRQ_on             => DMA1CNT_H_IRQ_on            ,
      Reg_CNT_H_DMA_Enable         => DMA1CNT_H_DMA_Enable        
   )                                 
   port map
   (
      clk100           => clk100,          
      gb_bus           => gb_bus,
      
      IRP_DMA          => IRP_DMA(1),
                       
      dma_on           => single_dma_on(1),
      allow_on         => single_allow_on(1),
                       
      sound_dma_req    => sound_dma_req(0), 
      hblank_trigger   => hblank_trigger,
      vblank_trigger   => vblank_trigger,
      
      dma_new_cycles   => single_new_cycles(1), 
      dma_first_cycles => single_first_cycles(1),
      dma_dword_cycles => single_dword_cycles(1),
      dma_cycles_adrup => single_cycles_adrup(7 downto 4),
      
      dma_eepromcount  => open,
      
      dma_bus_Adr      => Array_Adr(1),
      dma_bus_rnw      => Array_rnw(1), 
      dma_bus_ena      => Array_ena(1), 
      dma_bus_acc      => Array_acc(1), 
      dma_bus_dout     => Array_Dout(1), 
      dma_bus_din      => dma_bus_din,
      dma_bus_done     => Array_done(1)
   );
   
   igba_dma_module2 : entity work.gba_dma_module
   generic map
   (
      index                        => 2,
      has_DRQ                      => false,
      Reg_SAD                      => DMA2SAD                     ,
      Reg_DAD                      => DMA2DAD                     ,
      Reg_CNT_L                    => DMA2CNT_L                   ,
      Reg_CNT_H_Dest_Addr_Control  => DMA2CNT_H_Dest_Addr_Control ,
      Reg_CNT_H_Source_Adr_Control => DMA2CNT_H_Source_Adr_Control,
      Reg_CNT_H_DMA_Repeat         => DMA2CNT_H_DMA_Repeat        ,
      Reg_CNT_H_DMA_Transfer_Type  => DMA2CNT_H_DMA_Transfer_Type ,
      Reg_CNT_H_Game_Pak_DRQ       => DMA3CNT_H_Game_Pak_DRQ      , --unsued
      Reg_CNT_H_DMA_Start_Timing   => DMA2CNT_H_DMA_Start_Timing  ,
      Reg_CNT_H_IRQ_on             => DMA2CNT_H_IRQ_on            ,
      Reg_CNT_H_DMA_Enable         => DMA2CNT_H_DMA_Enable        
   )                                  
   port map
   (
      clk100           => clk100,          
      gb_bus           => gb_bus,
                       
      IRP_DMA          => IRP_DMA(2),
                       
      dma_on           => single_dma_on(2),
      allow_on         => single_allow_on(2),
                       
      sound_dma_req    => sound_dma_req(1), 
      hblank_trigger   => hblank_trigger,
      vblank_trigger   => vblank_trigger,
      
      dma_new_cycles   => single_new_cycles(2), 
      dma_first_cycles => single_first_cycles(2),
      dma_dword_cycles => single_dword_cycles(2),
      dma_cycles_adrup => single_cycles_adrup(11 downto 8),
      
      dma_eepromcount  => open,
      
      dma_bus_Adr      => Array_Adr(2),
      dma_bus_rnw      => Array_rnw(2), 
      dma_bus_ena      => Array_ena(2), 
      dma_bus_acc      => Array_acc(2), 
      dma_bus_dout     => Array_Dout(2), 
      dma_bus_din      => dma_bus_din,
      dma_bus_done     => Array_done(2)
   );
   
   igba_dma_module3 : entity work.gba_dma_module
   generic map
   (
      index                        => 3,
      has_DRQ                      => true,
      Reg_SAD                      => DMA3SAD                     ,
      Reg_DAD                      => DMA3DAD                     ,
      Reg_CNT_L                    => DMA3CNT_L                   ,
      Reg_CNT_H_Dest_Addr_Control  => DMA3CNT_H_Dest_Addr_Control ,
      Reg_CNT_H_Source_Adr_Control => DMA3CNT_H_Source_Adr_Control,
      Reg_CNT_H_DMA_Repeat         => DMA3CNT_H_DMA_Repeat        ,
      Reg_CNT_H_DMA_Transfer_Type  => DMA3CNT_H_DMA_Transfer_Type ,
      Reg_CNT_H_Game_Pak_DRQ       => DMA3CNT_H_Game_Pak_DRQ      , --unsued
      Reg_CNT_H_DMA_Start_Timing   => DMA3CNT_H_DMA_Start_Timing  ,
      Reg_CNT_H_IRQ_on             => DMA3CNT_H_IRQ_on            ,
      Reg_CNT_H_DMA_Enable         => DMA3CNT_H_DMA_Enable        
   )                                  
   port map
   (
      clk100           => clk100,          
      gb_bus           => gb_bus,
      
      IRP_DMA          => IRP_DMA(3),
                       
      dma_on           => single_dma_on(3),
      allow_on         => single_allow_on(3),
                       
      sound_dma_req    => '0', 
      hblank_trigger   => hblank_trigger,
      vblank_trigger   => vblank_trigger,
      
      dma_new_cycles   => single_new_cycles(3), 
      dma_first_cycles => single_first_cycles(3),
      dma_dword_cycles => single_dword_cycles(3),
      dma_cycles_adrup => single_cycles_adrup(15 downto 12),
      
      dma_eepromcount  => dma_eepromcount,
      
      dma_bus_Adr      => Array_Adr(3),
      dma_bus_rnw      => Array_rnw(3), 
      dma_bus_ena      => Array_ena(3), 
      dma_bus_acc      => Array_acc(3), 
      dma_bus_dout     => Array_Dout(3), 
      dma_bus_din      => dma_bus_din,
      dma_bus_done     => Array_done(3)
   );
   
   
   dma_bus_dout <= Array_Dout(0) when dma_switch = 0 else Array_Dout(1) when dma_switch = 1 else Array_Dout(2) when dma_switch = 2 else Array_Dout(3);
   dma_bus_Adr  <= Array_Adr(0)  when dma_switch = 0 else Array_Adr(1)  when dma_switch = 1 else Array_Adr(2)  when dma_switch = 2 else Array_Adr(3) ;
   dma_bus_acc  <= Array_acc(0)  when dma_switch = 0 else Array_acc(1)  when dma_switch = 1 else Array_acc(2)  when dma_switch = 2 else Array_acc(3) ;
   dma_bus_rnw  <= Array_rnw(0)  when dma_switch = 0 else Array_rnw(1)  when dma_switch = 1 else Array_rnw(2)  when dma_switch = 2 else Array_rnw(3) ;
   dma_bus_ena  <= Array_ena(0)  when dma_switch = 0 else Array_ena(1)  when dma_switch = 1 else Array_ena(2)  when dma_switch = 2 else Array_ena(3) ;
   
   Array_done(0) <= dma_bus_done when dma_switch = 0 else '0';
   Array_done(1) <= dma_bus_done when dma_switch = 1 else '0';
   Array_done(2) <= dma_bus_done when dma_switch = 2 else '0';
   Array_done(3) <= dma_bus_done when dma_switch = 3 else '0';
   
   single_allow_on(0) <= '1' when (do_step = '1' and dma_idle = '0' and CPU_bus_idle = '1' and dma_switch = 0) else '0';
   single_allow_on(1) <= '1' when (do_step = '1' and dma_idle = '0' and CPU_bus_idle = '1' and dma_switch = 1) else '0';
   single_allow_on(2) <= '1' when (do_step = '1' and dma_idle = '0' and CPU_bus_idle = '1' and dma_switch = 2) else '0';
   single_allow_on(3) <= '1' when (do_step = '1' and dma_idle = '0' and CPU_bus_idle = '1' and dma_switch = 3) else '0';
   
   dma_new_cycles   <= single_new_cycles(0)            or single_new_cycles(1)            or single_new_cycles(2)             or single_new_cycles(3);
   dma_first_cycles <= single_first_cycles(0)          or single_first_cycles(1)          or single_first_cycles(2)           or single_first_cycles(3);
   dma_dword_cycles <= single_dword_cycles(0)          or single_dword_cycles(1)          or single_dword_cycles(2)           or single_dword_cycles(3);
   dma_cycles_adrup <= single_cycles_adrup(3 downto 0) or single_cycles_adrup(7 downto 4) or single_cycles_adrup(11 downto 8) or single_cycles_adrup(15 downto 12);
   
   dma_on <= single_dma_on(0) or single_dma_on(1) or  single_dma_on(2) or single_dma_on(3);
   
   process (clk100)
   begin
      if rising_edge(clk100) then
         
         -- possible speedup here, as if only 1 dma is requesting, it must wait 1 cycle after each r+w transfer
         -- currently implementing this speedup cannot work, as the dma module is turned off the cycle after dma_bus_done
         -- so we don't know here if it will require more
         
         if (dma_idle = '1') then
               if (single_dma_on(0) = '1') then dma_switch <= 0; dma_idle <= '0';
            elsif (single_dma_on(1) = '1') then dma_switch <= 1; dma_idle <= '0';
            elsif (single_dma_on(2) = '1') then dma_switch <= 2; dma_idle <= '0';
            elsif (single_dma_on(3) = '1') then dma_switch <= 3; dma_idle <= '0'; end if;
         elsif (dma_bus_done = '1' and dma_bus_rnw = '0') then 
            dma_idle <= '1';
         end if;

      end if;
   end process;
    
end architecture;


 
 