library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

use work.pProc_bus_gba.all;
use work.pReg_gba_timer.all;

entity gba_timer is
   generic
   (
      is_simu : std_logic
   );
   port 
   (
      clk100            : in    std_logic;  
      gb_on             : in    std_logic;
      reset             : in    std_logic;
                        
      savestate_bus     : inout proc_bus_gb_type;
      loading_savestate : in    std_logic;
      
      gb_bus            : inout proc_bus_gb_type := ((others => 'Z'), (others => 'Z'), (others => 'Z'), 'Z', 'Z', 'Z', "ZZ", "ZZZZ", 'Z');
      new_cycles        : in    unsigned(7 downto 0);
      new_cycles_valid  : in    std_logic;
      IRP_Timer         : out   std_logic_vector(3 downto 0);
                        
      timer0_tick       : out   std_logic;
      timer1_tick       : out   std_logic;
                        
      debugout0         : out   std_logic_vector(31 downto 0);
      debugout1         : out   std_logic_vector(31 downto 0);
      debugout2         : out   std_logic_vector(31 downto 0);
      debugout3         : out   std_logic_vector(31 downto 0)
   );
end entity;

architecture arch of gba_timer is
   
   signal timerticks : std_logic_vector(3 downto 0);
 
begin 

   timer0_tick <= timerticks(0);
   timer1_tick <= timerticks(1);

   igba_timer_module0 : entity work.gba_timer_module
   generic map
   (
      is_simu                => is_simu,
      index                  => 0, 
      Reg_L                  => TM0CNT_L,
      Reg_H_Prescaler        => TM0CNT_H_Prescaler       ,
      Reg_H_Count_up         => TM0CNT_H_Count_up        ,
      Reg_H_Timer_IRQ_Enable => TM0CNT_H_Timer_IRQ_Enable,
      Reg_H_Timer_Start_Stop => TM0CNT_H_Timer_Start_Stop   
   )                                  
   port map
   (
      clk100            => clk100,   
      gb_on             => gb_on,  
      reset             => reset,
                        
      savestate_bus     => savestate_bus,
      loading_savestate => loading_savestate,
      
      gb_bus            => gb_bus,
                        
      new_cycles        => new_cycles,      
      new_cycles_valid  => new_cycles_valid,
      countup_in        => '0',
                        
      tick              => timerticks(0),
      IRP_Timer         => IRP_Timer(0),
                        
      debugout          => debugout0
   );
   
   igba_timer_module1 : entity work.gba_timer_module
   generic map
   (
      is_simu                => is_simu,
      index                  => 1, 
      Reg_L                  => TM1CNT_L,
      Reg_H_Prescaler        => TM1CNT_H_Prescaler       ,
      Reg_H_Count_up         => TM1CNT_H_Count_up        ,
      Reg_H_Timer_IRQ_Enable => TM1CNT_H_Timer_IRQ_Enable,
      Reg_H_Timer_Start_Stop => TM1CNT_H_Timer_Start_Stop   
   )                                  
   port map
   (
      clk100            => clk100,   
      gb_on             => gb_on,
      reset             => reset,
                        
      savestate_bus     => savestate_bus,
      loading_savestate => loading_savestate,
      
      gb_bus            => gb_bus,
                        
      new_cycles        => new_cycles,      
      new_cycles_valid  => new_cycles_valid,
      countup_in        => timerticks(0),
                        
      tick              => timerticks(1),
      IRP_Timer         => IRP_Timer(1),
                        
      debugout          => debugout1      
   );
   
   igba_timer_module2 : entity work.gba_timer_module
   generic map
   (
      is_simu                => is_simu,
      index                  => 2, 
      Reg_L                  => TM2CNT_L,
      Reg_H_Prescaler        => TM2CNT_H_Prescaler       ,
      Reg_H_Count_up         => TM2CNT_H_Count_up        ,
      Reg_H_Timer_IRQ_Enable => TM2CNT_H_Timer_IRQ_Enable,
      Reg_H_Timer_Start_Stop => TM2CNT_H_Timer_Start_Stop   
   )                                  
   port map
   (
      clk100            => clk100,
      gb_on             => gb_on,  
      reset             => reset,
                        
      savestate_bus     => savestate_bus,
      loading_savestate => loading_savestate,
      
      gb_bus            => gb_bus,
                        
      new_cycles        => new_cycles,      
      new_cycles_valid  => new_cycles_valid,
      countup_in        => timerticks(1),
                        
      tick              => timerticks(2),
      IRP_Timer         => IRP_Timer(2),
                        
      debugout          => debugout2      
   );
   
   igba_timer_module3 : entity work.gba_timer_module
   generic map
   (
      is_simu                => is_simu,
      index                  => 3, 
      Reg_L                  => TM3CNT_L,
      Reg_H_Prescaler        => TM3CNT_H_Prescaler       ,
      Reg_H_Count_up         => TM3CNT_H_Count_up        ,
      Reg_H_Timer_IRQ_Enable => TM3CNT_H_Timer_IRQ_Enable,
      Reg_H_Timer_Start_Stop => TM3CNT_H_Timer_Start_Stop   
   )                                  
   port map
   (
      clk100            => clk100,   
      gb_on             => gb_on, 
      reset             => reset,
                        
      savestate_bus     => savestate_bus,
      loading_savestate => loading_savestate,
      
      gb_bus            => gb_bus,
                        
      new_cycles        => new_cycles,      
      new_cycles_valid  => new_cycles_valid,
      countup_in        => timerticks(2),
                        
      tick              => timerticks(3),
      IRP_Timer         => IRP_Timer(3),
                        
      debugout          => debugout3      
   );
    

end architecture;





