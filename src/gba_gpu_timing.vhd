library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

use work.pProc_bus_gba.all;
use work.pReg_gba_display.all;

entity gba_gpu_timing is
   generic
   (
      is_simu : std_logic
   );
   port 
   (
      clk100                       : in  std_logic;  
      gb_on                        : in  std_logic;
      
      gb_bus                       : inout proc_bus_gb_type := ((others => 'Z'), (others => 'Z'), (others => 'Z'), 'Z', 'Z', 'Z', "ZZ", "ZZZZ", 'Z');
                                   
      new_cycles                   : in  unsigned(7 downto 0);
      new_cycles_valid             : in  std_logic;
                                   
      IRP_HBlank                   : out std_logic := '0';
      IRP_VBlank                   : out std_logic := '0';
      IRP_LCDStat                  : out std_logic := '0';
      
      hblank_trigger               : out std_logic := '0';                              
      vblank_trigger               : out std_logic := '0';                              
      drawline                     : out std_logic := '0';                       
      refpoint_update              : out std_logic := '0';                       
      linecounter_drawer           : out unsigned(7 downto 0);      
      
      DISPSTAT_debug               : out std_logic_vector(31 downto 0)
   );
end entity;

architecture arch of gba_gpu_timing is
   
   signal REG_DISPSTAT_V_Blank_flag         : std_logic_vector(DISPSTAT_V_Blank_flag        .upper downto DISPSTAT_V_Blank_flag        .lower) := (others => '0');
   signal REG_DISPSTAT_H_Blank_flag         : std_logic_vector(DISPSTAT_H_Blank_flag        .upper downto DISPSTAT_H_Blank_flag        .lower) := (others => '0');
   signal REG_DISPSTAT_V_Counter_flag       : std_logic_vector(DISPSTAT_V_Counter_flag      .upper downto DISPSTAT_V_Counter_flag      .lower) := (others => '0');
   signal REG_DISPSTAT_V_Blank_IRQ_Enable   : std_logic_vector(DISPSTAT_V_Blank_IRQ_Enable  .upper downto DISPSTAT_V_Blank_IRQ_Enable  .lower) := (others => '0');
   signal REG_DISPSTAT_H_Blank_IRQ_Enable   : std_logic_vector(DISPSTAT_H_Blank_IRQ_Enable  .upper downto DISPSTAT_H_Blank_IRQ_Enable  .lower) := (others => '0');
   signal REG_DISPSTAT_V_Counter_IRQ_Enable : std_logic_vector(DISPSTAT_V_Counter_IRQ_Enable.upper downto DISPSTAT_V_Counter_IRQ_Enable.lower) := (others => '0');
   signal REG_DISPSTAT_V_Count_Setting      : std_logic_vector(DISPSTAT_V_Count_Setting     .upper downto DISPSTAT_V_Count_Setting     .lower) := (others => '0');
   signal REG_VCOUNT                        : std_logic_vector(VCOUNT                       .upper downto VCOUNT                       .lower) := (others => '0');
   
   type tGPUState is
   (
      VISIBLE,
      HBLANK,
      VBLANK,
      VBLANKHBLANK
   );
   signal gpustate : tGPUState;
   
   signal linecounter : unsigned(7 downto 0)  := (others => '0');
   signal cycles      : unsigned(11 downto 0) := (others => '0');
   
begin 
   
   iREG_DISPSTAT_V_Blank_flag         : entity work.eProcReg_gba generic map (DISPSTAT_V_Blank_flag        ) port map  (clk100, gb_bus, REG_DISPSTAT_V_Blank_flag  ); 
   iREG_DISPSTAT_H_Blank_flag         : entity work.eProcReg_gba generic map (DISPSTAT_H_Blank_flag        ) port map  (clk100, gb_bus, REG_DISPSTAT_H_Blank_flag  ); 
   iREG_DISPSTAT_V_Counter_flag       : entity work.eProcReg_gba generic map (DISPSTAT_V_Counter_flag      ) port map  (clk100, gb_bus, REG_DISPSTAT_V_Counter_flag); 
   iREG_DISPSTAT_V_Blank_IRQ_Enable   : entity work.eProcReg_gba generic map (DISPSTAT_V_Blank_IRQ_Enable  ) port map  (clk100, gb_bus, REG_DISPSTAT_V_Blank_IRQ_Enable   , REG_DISPSTAT_V_Blank_IRQ_Enable   ); 
   iREG_DISPSTAT_H_Blank_IRQ_Enable   : entity work.eProcReg_gba generic map (DISPSTAT_H_Blank_IRQ_Enable  ) port map  (clk100, gb_bus, REG_DISPSTAT_H_Blank_IRQ_Enable   , REG_DISPSTAT_H_Blank_IRQ_Enable   ); 
   iREG_DISPSTAT_V_Counter_IRQ_Enable : entity work.eProcReg_gba generic map (DISPSTAT_V_Counter_IRQ_Enable) port map  (clk100, gb_bus, REG_DISPSTAT_V_Counter_IRQ_Enable , REG_DISPSTAT_V_Counter_IRQ_Enable ); 
   iREG_DISPSTAT_V_Count_Setting      : entity work.eProcReg_gba generic map (DISPSTAT_V_Count_Setting     ) port map  (clk100, gb_bus, REG_DISPSTAT_V_Count_Setting      , REG_DISPSTAT_V_Count_Setting      ); 
   iREG_VCOUNT                        : entity work.eProcReg_gba generic map (VCOUNT                       ) port map  (clk100, gb_bus, REG_VCOUNT); 
   
   linecounter_drawer <= linecounter;
   
   REG_VCOUNT(23 downto 16) <= std_logic_vector(linecounter);

   DISPSTAT_debug <= REG_VCOUNT &
                     REG_DISPSTAT_V_Count_Setting &
                     "00" &
                     REG_DISPSTAT_V_Counter_IRQ_Enable &
                     REG_DISPSTAT_H_Blank_IRQ_Enable &
                     REG_DISPSTAT_V_Blank_IRQ_Enable &
                     REG_DISPSTAT_V_Counter_flag &
                     REG_DISPSTAT_H_Blank_flag &
                     REG_DISPSTAT_V_Blank_flag;
   
   process (clk100)
   begin
      if rising_edge(clk100) then
      
         IRP_HBlank        <= '0';
         IRP_VBlank        <= '0';
         IRP_LCDStat       <= '0';
               
         drawline          <= '0';
         refpoint_update   <= '0';
         hblank_trigger    <= '0';
         vblank_trigger    <= '0';
         
         if (gb_on = '0' and is_simu = '0') then
            gpustate    <= VISIBLE;
            cycles      <= (others => '0');
            linecounter <= (others => '0');
         else
         
            -- really required?
            -- if (forcedblank && !new_forcedblank) then
            --    gpustate = GPUState.VISIBLE
            --    cycles = 0
            --    GBRegs.Sect_display.DISPSTAT_V_Blank_flag.write(0);
            --    GBRegs.Sect_display.DISPSTAT_H_Blank_flag.write(0);
            -- end if;
         
            if (new_cycles_valid = '1') then
               cycles <= cycles + new_cycles;
            else
         
               case (gpustate) is
                  when VISIBLE =>
                     if (cycles >= 1008) then -- 960 is drawing time
                        cycles                    <= cycles - 1008;
                        gpustate                  <= HBLANK;
                        REG_DISPSTAT_H_Blank_flag <= "1";
                        hblank_trigger            <= '1';
                        if (REG_DISPSTAT_H_Blank_IRQ_Enable = "1") then
                           IRP_HBlank <= '1';
                        end if;
                     end if;
                  
                  when HBLANK =>
                     if (cycles >= 224) then -- 272
                        cycles      <= cycles - 224;
                        linecounter <= linecounter + 1;
                        if ((linecounter + 1) = unsigned(REG_DISPSTAT_V_Count_Setting)) then
                           if (REG_DISPSTAT_V_Counter_IRQ_Enable = "1") then
                              IRP_LCDStat <= '1';
                           end if;
                           REG_DISPSTAT_V_Counter_flag <= "1";
                        else
                           REG_DISPSTAT_V_Counter_flag <= "0";
                        end if;
   
                        REG_DISPSTAT_H_Blank_flag <= "0";
                        if ((linecounter + 1) < 160) then
                           gpustate <= VISIBLE;
                           drawline <= '1';
                        else
                           gpustate                  <= VBLANK;
                           refpoint_update           <= '1';
                           REG_DISPSTAT_V_Blank_flag <= "1";
                           vblank_trigger            <= '1';
                           if (REG_DISPSTAT_V_Blank_IRQ_Enable = "1") then
                              IRP_VBlank <= '1';
                           end if;
                        end if;
                     end if;
                  
                  when VBLANK =>
                     if (cycles >= 1008) then
                        cycles                     <= cycles - 1008;
                        gpustate                   <= VBLANKHBLANK;
                        REG_DISPSTAT_H_Blank_flag  <= "1";
                        -- don't do hblank for dma here!
                        if (REG_DISPSTAT_H_Blank_IRQ_Enable = "1") then
                           IRP_HBlank <= '1'; -- Note that no H-Blank interrupts are generated within V-Blank period. Really? Seems to work this way...
                        end if;
                     end if;
                  
                  when VBLANKHBLANK =>
                     if (cycles >= 224) then -- 272
                        cycles      <= cycles - 224;
                        linecounter <= linecounter + 1;
                        if ((linecounter + 1) = unsigned(REG_DISPSTAT_V_Count_Setting) or ((linecounter + 1) = 228 and REG_DISPSTAT_V_Count_Setting = x"00")) then
                           if (REG_DISPSTAT_V_Counter_IRQ_Enable = "1") then
                              IRP_LCDStat <= '1';
                           end if;
                           REG_DISPSTAT_V_Counter_flag <= "1";
                        else
                           REG_DISPSTAT_V_Counter_flag <= "0";
                        end if;
                        
                        REG_DISPSTAT_H_Blank_flag <= "0";
                        if ((linecounter + 1) = 228) then
                           linecounter <= (others => '0');
                           gpustate    <= VISIBLE;
                           drawline    <= '1';
                           REG_DISPSTAT_V_Blank_flag <= "0";
                        else
                           gpustate <= VBLANK;
                           --if ((linecounter + 1) = 227)
                              -- GBRegs.Sect_display.DISPSTAT_V_Blank_flag.write(0);  where does this come from? commented out in emulator
                           --end if;
                        end if;
                     end if;
               
               end case;
         
            end if;
         
         end if;
      
      end if;
   end process;

end architecture;





