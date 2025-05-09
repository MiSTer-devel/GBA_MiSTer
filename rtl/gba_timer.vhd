library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

use work.pProc_bus_gba.all;
use work.pReg_gba_timer.all;
use work.pReg_savestates.all;

entity gba_timer is
   generic
   (
      is_simu : std_logic
   );
   port 
   (
      clk               : in    std_logic;  
      ce                : in    std_logic;
      reset             : in    std_logic;
                        
      savestate_bus     : in    proc_bus_gb_type;
      ss_wired_out      : out   std_logic_vector(proc_buswidth-1 downto 0) := (others => '0');
      ss_wired_done     : out   std_logic;
      loading_savestate : in    std_logic;
      
      gb_bus            : in    proc_bus_gb_type;
      wired_out         : out   std_logic_vector(proc_buswidth-1 downto 0) := (others => '0');
      wired_done        : out   std_logic;
      
      IRP_Timer         : out   std_logic_vector(3 downto 0);
                        
      timer0_tick       : out   std_logic;
      timer1_tick       : out   std_logic;
                        
      debugout0         : out   unsigned(15 downto 0);
      debugout1         : out   unsigned(15 downto 0);
      debugout2         : out   unsigned(15 downto 0);
      debugout3         : out   unsigned(15 downto 0)
   );
end entity;

architecture arch of gba_timer is
 
   type t_reg_wired_or is array(0 to 3) of std_logic_vector(31 downto 0);
   signal reg_wired_or    : t_reg_wired_or;   
   signal reg_wired_done  : unsigned(0 to 3);
 
   signal timerticks : std_logic_vector(3 downto 0);
   
   signal prescaleCounter : unsigned(9 downto 0) := (others => '0');
 
   -- savestates
   signal SAVESTATE_TIMER      : std_logic_vector(29 downto 0);
    
   type t_ss_wired_or is array(0 to 3) of std_logic_vector(31 downto 0);
   signal save_wired_or        : t_ss_wired_or;   
   signal save_wired_done      : unsigned(0 to 3);
 
begin 

   iSAVESTATE_TIMER : entity work.eProcReg_gba generic map (REG_SAVESTATE_TIMER, 0) port map (clk, savestate_bus, open, open, 30x"0", SAVESTATE_TIMER);

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

   timer0_tick <= timerticks(0);
   timer1_tick <= timerticks(1);


   process (clk)
   begin
      if rising_edge(clk) then
         if (reset = '1') then
            prescaleCounter <= unsigned(SAVESTATE_TIMER(28 downto 19));
         elsif (ce = '1') then
            prescaleCounter <= prescaleCounter + 1;
         end if;
      end if;
   end process;

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
      clk               => clk,   
      ce                => ce,  
      reset             => reset,
                        
      savestate_bus     => savestate_bus,
      ss_wired_out      => save_wired_or(0),
      ss_wired_done     => save_wired_done(0),
      loading_savestate => loading_savestate,
      
      gb_bus            => gb_bus,           
      wired_out         => reg_wired_or(0),
      wired_done        => reg_wired_done(0),
                        
      prescaleCounter   => prescaleCounter,
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
      clk               => clk,   
      ce                => ce,
      reset             => reset,
                        
      savestate_bus     => savestate_bus,
      ss_wired_out      => save_wired_or(1),
      ss_wired_done     => save_wired_done(1),
      loading_savestate => loading_savestate,
      
      gb_bus            => gb_bus,           
      wired_out         => reg_wired_or(1),
      wired_done        => reg_wired_done(1),
                        
      prescaleCounter   => prescaleCounter,
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
      clk               => clk,
      ce                => ce,  
      reset             => reset,
                        
      savestate_bus     => savestate_bus,
      ss_wired_out      => save_wired_or(2),
      ss_wired_done     => save_wired_done(2),
      loading_savestate => loading_savestate,
      
      gb_bus            => gb_bus,           
      wired_out         => reg_wired_or(2),
      wired_done        => reg_wired_done(2),

      prescaleCounter   => prescaleCounter,
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
      clk               => clk,   
      ce                => ce, 
      reset             => reset,
                        
      savestate_bus     => savestate_bus,
      ss_wired_out      => save_wired_or(3),
      ss_wired_done     => save_wired_done(3),
      loading_savestate => loading_savestate,
      
      gb_bus            => gb_bus,           
      wired_out         => reg_wired_or(3),
      wired_done        => reg_wired_done(3),
       
      prescaleCounter   => prescaleCounter,
      countup_in        => timerticks(2),
                        
      tick              => timerticks(3),
      IRP_Timer         => IRP_Timer(3),
                        
      debugout          => debugout3      
   );
    

end architecture;





