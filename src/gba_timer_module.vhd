library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

use work.pRegmap_gba.all;
use work.pProc_bus_gba.all;

entity gba_timer_module is
   generic
   (
      is_simu                : std_logic;
      Reg_L                  : regmap_type;
      Reg_H_Prescaler        : regmap_type;
      Reg_H_Count_up         : regmap_type;
      Reg_H_Timer_IRQ_Enable : regmap_type;
      Reg_H_Timer_Start_Stop : regmap_type
   );
   port 
   (
      clk100              : in    std_logic; 
      gb_on               : in    std_logic;      
      gb_bus              : inout proc_bus_gb_type := ((others => 'Z'), (others => 'Z'), (others => 'Z'), 'Z', 'Z', 'Z', "ZZ", "ZZZZ", 'Z');
      
      new_cycles          : in    unsigned(7 downto 0);
      new_cycles_valid    : in    std_logic;
      countup_in          : in    std_logic;
      
      tick                : out   std_logic := '0';
      IRP_Timer           : out   std_logic := '0';
      
      debugout            : out   std_logic_vector(31 downto 0)
   );
end entity;

architecture arch of gba_timer_module is

   signal L_Counter_Reload   : std_logic_vector(Reg_L                 .upper downto Reg_L                 .lower) := (others => '0');
   signal H_Prescaler        : std_logic_vector(Reg_H_Prescaler       .upper downto Reg_H_Prescaler       .lower) := (others => '0');
   signal H_Count_up         : std_logic_vector(Reg_H_Count_up        .upper downto Reg_H_Count_up        .lower) := (others => '0');
   signal H_Timer_IRQ_Enable : std_logic_vector(Reg_H_Timer_IRQ_Enable.upper downto Reg_H_Timer_IRQ_Enable.lower) := (others => '0');
   signal H_Timer_Start_Stop : std_logic_vector(Reg_H_Timer_Start_Stop.upper downto Reg_H_Timer_Start_Stop.lower) := (others => '0');
                                                                                                                                                    
   signal H_Timer_Start_Stop_written : std_logic;                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   

   signal counter_readback : std_logic_vector(15 downto 0) := (others => '0');
   signal counter          : unsigned(16 downto 0) := (others => '0');
   signal prescalecounter  : unsigned(10 downto 0) := (others => '0');
   signal prescaleborder   : integer range 1 to 1024 := 1;
   signal timer_on         : std_logic := '0';
   signal timer_on_next    : std_logic := '0';
   
begin 

   iL_Counter_Reload   : entity work.eProcReg_gba generic map ( Reg_L                  ) port map  (clk100, gb_bus, counter_readback   , L_Counter_Reload  );  
   iH_Prescaler        : entity work.eProcReg_gba generic map ( Reg_H_Prescaler        ) port map  (clk100, gb_bus, H_Prescaler        , H_Prescaler       );  
   iH_Count_up         : entity work.eProcReg_gba generic map ( Reg_H_Count_up         ) port map  (clk100, gb_bus, H_Count_up         , H_Count_up        );   
   iH_Timer_IRQ_Enable : entity work.eProcReg_gba generic map ( Reg_H_Timer_IRQ_Enable ) port map  (clk100, gb_bus, H_Timer_IRQ_Enable , H_Timer_IRQ_Enable);  
   iH_Timer_Start_Stop : entity work.eProcReg_gba generic map ( Reg_H_Timer_Start_Stop ) port map  (clk100, gb_bus, H_Timer_Start_Stop , H_Timer_Start_Stop , H_Timer_Start_Stop_written );  
   
   debugout <= x"00" & H_Timer_Start_Stop & H_Timer_IRQ_Enable & "000" & H_Count_up & H_Prescaler & counter_readback;
   
   process (clk100)
   begin
      if rising_edge(clk100) then
      
         tick      <= '0';
         IRP_Timer <= '0';

         if (gb_on = '0' and is_simu = '0') then -- reset
      
            timer_on         <= '0';
            counter          <= (others => '0');
            prescalecounter  <= (others => '0');
            counter_readback <= (others => '0');
      
         else
         
            -- set_settings
            if (H_Timer_Start_Stop_written = '1') then
               if (H_Timer_Start_Stop = "1" and timer_on = '0') then
                  counter         <= '0' & unsigned(L_Counter_Reload);
                  prescalecounter <= (others => '0');
               end if;
               timer_on_next <= H_Timer_Start_Stop(H_Timer_Start_Stop'left);
            end if;
            
            case (to_integer(unsigned(H_Prescaler))) is
               when 0 => prescaleborder <= 1;
               when 1 => prescaleborder <= 64;
               when 2 => prescaleborder <= 256;
               when 3 => prescaleborder <= 1024;
               when others => null;
            end case;

            --work
            
            if (new_cycles_valid = '1') then
               timer_on <= timer_on_next;
            end if;
         
            if (timer_on = '1' and timer_on_next = '1') then
               if (H_Count_up = "1" and countup_in = '1') then
                  counter <= counter + 1;
               elsif (H_Count_up = "0" and new_cycles_valid = '1') then
                  if (H_Prescaler = "00") then
                     counter <= counter + new_cycles;
                  else
                     prescalecounter <= prescalecounter + new_cycles;
                  end if;
               elsif (prescalecounter >= prescaleborder) then
                  prescalecounter <= prescalecounter - prescaleborder;
                  counter <= counter + 1;
               elsif (counter(16) = '1') then
                  counter <= counter - 16#10000# + unsigned(L_Counter_Reload);
                  tick    <= '1';
                  if (H_Timer_IRQ_Enable = "1") then
                     IRP_Timer <= '1';
                  end if;
               end if;
            end if;
            
         end if;
         
         counter_readback <= std_logic_vector(counter(15 downto 0));
      
      end if;
   end process;
  

end architecture;





