library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

use work.pRegmap_gba.all;
use work.pProc_bus_gba.all;
use work.pReg_savestates.all;

entity gba_timer_module is
   generic
   (
      is_simu                : std_logic;
      index                  : integer;
      Reg_L                  : regmap_type;
      Reg_H_Prescaler        : regmap_type;
      Reg_H_Count_up         : regmap_type;
      Reg_H_Timer_IRQ_Enable : regmap_type;
      Reg_H_Timer_Start_Stop : regmap_type
   );
   port 
   (
      clk                 : in    std_logic; 
      ce                  : in    std_logic;
      reset               : in    std_logic;      
      
      savestate_bus       : in    proc_bus_gb_type;
      ss_wired_out        : out   std_logic_vector(proc_buswidth-1 downto 0) := (others => '0');
      ss_wired_done       : out   std_logic;
      loading_savestate   : in    std_logic;
      
      gb_bus              : in    proc_bus_gb_type;
      wired_out           : out   std_logic_vector(proc_buswidth-1 downto 0) := (others => '0');
      wired_done          : out   std_logic;
      
      prescaleCounter     : in    unsigned(9 downto 0);
      countup_in          : in    std_logic;
      
      tick                : out   std_logic := '0';
      IRP_Timer           : out   std_logic := '0';
      
      debugout            : out   unsigned(15 downto 0)
   );
end entity;

architecture arch of gba_timer_module is

   signal L_Counter_Reload   : std_logic_vector(Reg_L                 .upper downto Reg_L                 .lower) := (others => '0');
   signal H_Prescaler        : std_logic_vector(Reg_H_Prescaler       .upper downto Reg_H_Prescaler       .lower) := (others => '0');
   signal H_Count_up         : std_logic_vector(Reg_H_Count_up        .upper downto Reg_H_Count_up        .lower) := (others => '0');
   signal H_Timer_IRQ_Enable : std_logic_vector(Reg_H_Timer_IRQ_Enable.upper downto Reg_H_Timer_IRQ_Enable.lower) := (others => '0');
   signal H_Timer_Start_Stop : std_logic_vector(Reg_H_Timer_Start_Stop.upper downto Reg_H_Timer_Start_Stop.lower) := (others => '0');
   
   signal L_Counter_Reload_writeValue   : std_logic_vector(Reg_L                 .upper downto Reg_L                 .lower) := (others => '0');
   signal H_Prescaler_writeValue        : std_logic_vector(Reg_H_Prescaler       .upper downto Reg_H_Prescaler       .lower) := (others => '0');
   signal H_Timer_Start_Stop_writeValue : std_logic_vector(Reg_H_Timer_Start_Stop.upper downto Reg_H_Timer_Start_Stop.lower) := (others => '0');
   
   signal L_Counter_Reload_writeTo    : std_logic;                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   
   signal H_Timer_Start_Stop_writeTo    : std_logic;                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   

   type t_reg_wired_or is array(0 to 4) of std_logic_vector(31 downto 0);
   signal reg_wired_or    : t_reg_wired_or;   
   signal reg_wired_done  : unsigned(0 to 4);

   signal counter_readback : std_logic_vector(15 downto 0) := (others => '0');
   signal counter          : unsigned(15 downto 0) := (others => '0');
   signal newCounter       : unsigned(16 downto 0);
   signal prescaleMask     : unsigned(9 downto 0);  
   signal timer_on         : std_logic := '0';
   signal startwait        : std_logic := '0';
   
   -- savestate
   signal SAVESTATE_TIMER      : std_logic_vector(29 downto 0);
   signal SAVESTATE_TIMER_BACK : std_logic_vector(29 downto 0);
   
   signal debugout_next : unsigned(15 downto 0) := (others => '0');
   
begin 

   SAVESTATE_TIMER_BACK(0)            <= timer_on;       
   SAVESTATE_TIMER_BACK(1)            <= '0';  
   SAVESTATE_TIMER_BACK(18 downto 2)  <= '0' & std_logic_vector(counter);        
   SAVESTATE_TIMER_BACK(29 downto 19) <= '0' & std_logic_vector(prescalecounter) when (index = 0) else (others => '0');

   iSAVESTATE_TIMER : entity work.eProcReg_gba generic map (REG_SAVESTATE_TIMER, index) port map (clk, savestate_bus, ss_wired_out, ss_wired_done, SAVESTATE_TIMER_BACK, SAVESTATE_TIMER);


   iL_Counter_Reload   : entity work.eProcReg_gba generic map ( Reg_L                  ) port map  (clk, gb_bus, reg_wired_or(0), reg_wired_done(0), counter_readback   , L_Counter_Reload   , open, L_Counter_Reload_writeValue  , L_Counter_Reload_writeTo);  
   iH_Prescaler        : entity work.eProcReg_gba generic map ( Reg_H_Prescaler        ) port map  (clk, gb_bus, reg_wired_or(1), reg_wired_done(1), H_Prescaler        , H_Prescaler        , open, H_Prescaler_writeValue);  
   iH_Count_up         : entity work.eProcReg_gba generic map ( Reg_H_Count_up         ) port map  (clk, gb_bus, reg_wired_or(2), reg_wired_done(2), H_Count_up         , H_Count_up        );   
   iH_Timer_IRQ_Enable : entity work.eProcReg_gba generic map ( Reg_H_Timer_IRQ_Enable ) port map  (clk, gb_bus, reg_wired_or(3), reg_wired_done(3), H_Timer_IRQ_Enable , H_Timer_IRQ_Enable);  
   iH_Timer_Start_Stop : entity work.eProcReg_gba generic map ( Reg_H_Timer_Start_Stop ) port map  (clk, gb_bus, reg_wired_or(4), reg_wired_done(4), H_Timer_Start_Stop , H_Timer_Start_Stop , open, H_Timer_Start_Stop_writeValue, H_Timer_Start_Stop_writeTo );  
   
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
   
   prescaleMask <= 10x"001" when H_Prescaler = "00" else
                   10x"03F" when H_Prescaler = "01" else
                   10x"0FF" when H_Prescaler = "10" else
                   10x"3FF";
   
   process (all)
   begin
      newCounter <= '0' & counter;
      
      if (timer_on = '1' and startwait = '0') then
         if (H_Count_up = "0" or index = 0) then
            if (H_Prescaler = "00" or ((prescaleCounter and prescaleMask) = prescaleMask)) then
               newCounter <= resize(counter, newCounter'length) + 1;
            end if;
         elsif (H_Count_up = "1" and countup_in = '1') then
            newCounter <= resize(counter, newCounter'length) + 1;
         end if;
      end if;
   
   end process;
   
   
   process (all)
   begin

      tick      <= '0';
      IRP_Timer <= '0';
      
      if (startwait = '1') then
        if (counter = x"FFFF" and H_Timer_IRQ_Enable = "1") then
           IRP_Timer <= '1';
        end if;
     end if;

      if (timer_on = '1' and startwait = '0') then   
         if (newCounter(16) = '1') then
            tick             <= '1';
            if (H_Timer_IRQ_Enable = "1") then
               IRP_Timer <= '1';
            end if;
         end if;
      end if;
   
   end process;
   
   
   process (clk)
   begin
      if rising_edge(clk) then
      


         debugout_next  <= unsigned(counter_readback);
         debugout       <= debugout_next;
         
         if (reset = '1') then
      
            timer_on         <= SAVESTATE_TIMER(0);
            counter          <= unsigned(SAVESTATE_TIMER(17 downto 2));
      
         elsif (ce = '1') then
         
            if (startwait = '1') then
               startwait        <= '0';
               counter          <= unsigned(L_Counter_Reload);
               counter_readback <= L_Counter_Reload;
            end if;

            if (timer_on = '1' and startwait = '0') then   

               counter          <= newCounter(15 downto 0);
               counter_readback <= std_logic_vector(newCounter(15 downto 0));
            
               if (newCounter(16) = '1') then
                  counter          <= unsigned(L_Counter_Reload);
                  counter_readback <= L_Counter_Reload;
               end if;

            end if;

            -- set_settings
            if (H_Timer_Start_Stop_writeTo = '1' and loading_savestate = '0') then
               timer_on <= H_Timer_Start_Stop_writeValue(H_Timer_Start_Stop'left);
               if (H_Timer_Start_Stop_writeValue = "1" and timer_on = '0') then
                  if (H_Prescaler_writeValue = "00") then
                     startwait <= '1';
                  else
                     if (L_Counter_Reload_writeTo = '1') then
                        counter           <= unsigned(L_Counter_Reload_writeValue);
                        counter_readback  <= L_Counter_Reload_writeValue;
                     else
                        counter           <= unsigned(L_Counter_Reload);
                        counter_readback  <= L_Counter_Reload;
                     end if;
                  end if;
               end if;
            end if;

            
         end if;
      
      end if;
   end process;
  

end architecture;





