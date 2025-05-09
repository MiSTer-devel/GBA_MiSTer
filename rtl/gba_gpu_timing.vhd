library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

use work.pProc_bus_gba.all;
use work.pReg_gba_display.all;

use work.pReg_savestates.all;

entity gba_gpu_timing is
   generic
   (
      is_simu : std_logic
   );
   port 
   (
      clk                  : in  std_logic;  
      ce                   : in  std_logic;
      reset                : in  std_logic;
      lockspeed            : in  std_logic;
      
      savestate_bus        : in    proc_bus_gb_type;
      ss_wired_out         : out   std_logic_vector(proc_buswidth-1 downto 0) := (others => '0');
      ss_wired_done        : out   std_logic;
      
      gb_bus               : in  proc_bus_gb_type;
      wired_out            : out std_logic_vector(proc_buswidth-1 downto 0) := (others => '0');
      wired_done           : out std_logic;
                           
      IRP_HBlank           : out std_logic := '0';
      IRP_VBlank           : out std_logic := '0';
      IRP_LCDStat          : out std_logic := '0';
      
      vram_block_mode      : in  std_logic;
      vram_blocked         : out std_logic := '0';
      
      videodma_start       : out std_logic := '0';
      videodma_stop        : out std_logic := '0';
      
      line_trigger         : out std_logic := '0';                              
      hblank_trigger       : out std_logic := '0';                              
      vblank_trigger       : out std_logic := '0';                              
      drawline             : out std_logic := '0';                       
      drawObj              : out std_logic := '0';                       
      refpoint_update      : out std_logic := '0';                       
      newline_invsync      : out std_logic := '0';                       
      linecounter_drawer   : out unsigned(7 downto 0);
      linecounter_obj      : out unsigned(7 downto 0);
      
      DISPSTAT_debug       : out std_logic_vector(31 downto 0)
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
   
   type t_reg_wired_or is array(0 to 7) of std_logic_vector(31 downto 0);
   signal reg_wired_or    : t_reg_wired_or;   
   signal reg_wired_done  : unsigned(0 to 7);
   
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
   signal drawsoon    : std_logic := '0';

   -- savestate
   signal SAVESTATE_GPU       : std_logic_vector(24 downto 0);
   signal SAVESTATE_GPU_BACK  : std_logic_vector(24 downto 0);
   
   signal DISPSTAT_debug_next : std_logic_vector(31 downto 0);
   
begin 
   
   SAVESTATE_GPU_BACK(11 downto  0) <= std_logic_vector(cycles);
   SAVESTATE_GPU_BACK(19 downto 12) <= std_logic_vector(linecounter);
   SAVESTATE_GPU_BACK(21 downto 20) <= std_logic_vector(to_unsigned(tGPUState'POS(gpustate), 2));
   SAVESTATE_GPU_BACK(22 downto 22) <= REG_DISPSTAT_V_Counter_flag;
   SAVESTATE_GPU_BACK(23 downto 23) <= REG_DISPSTAT_H_Blank_flag;  
   SAVESTATE_GPU_BACK(24 downto 24) <= REG_DISPSTAT_V_Blank_flag;  
   
   iSAVESTATE_GPU : entity work.eProcReg_gba generic map (REG_SAVESTATE_GPU) port map (clk, savestate_bus, ss_wired_out, ss_wired_done, SAVESTATE_GPU_BACK , SAVESTATE_GPU);
   
   
   iREG_DISPSTAT_V_Blank_flag         : entity work.eProcReg_gba generic map (DISPSTAT_V_Blank_flag        ) port map  (clk, gb_bus, reg_wired_or(0), reg_wired_done(0), REG_DISPSTAT_V_Blank_flag  ); 
   iREG_DISPSTAT_H_Blank_flag         : entity work.eProcReg_gba generic map (DISPSTAT_H_Blank_flag        ) port map  (clk, gb_bus, reg_wired_or(1), reg_wired_done(1), REG_DISPSTAT_H_Blank_flag  ); 
   iREG_DISPSTAT_V_Counter_flag       : entity work.eProcReg_gba generic map (DISPSTAT_V_Counter_flag      ) port map  (clk, gb_bus, reg_wired_or(2), reg_wired_done(2), REG_DISPSTAT_V_Counter_flag); 
   iREG_DISPSTAT_V_Blank_IRQ_Enable   : entity work.eProcReg_gba generic map (DISPSTAT_V_Blank_IRQ_Enable  ) port map  (clk, gb_bus, reg_wired_or(3), reg_wired_done(3), REG_DISPSTAT_V_Blank_IRQ_Enable   , REG_DISPSTAT_V_Blank_IRQ_Enable   ); 
   iREG_DISPSTAT_H_Blank_IRQ_Enable   : entity work.eProcReg_gba generic map (DISPSTAT_H_Blank_IRQ_Enable  ) port map  (clk, gb_bus, reg_wired_or(4), reg_wired_done(4), REG_DISPSTAT_H_Blank_IRQ_Enable   , REG_DISPSTAT_H_Blank_IRQ_Enable   ); 
   iREG_DISPSTAT_V_Counter_IRQ_Enable : entity work.eProcReg_gba generic map (DISPSTAT_V_Counter_IRQ_Enable) port map  (clk, gb_bus, reg_wired_or(5), reg_wired_done(5), REG_DISPSTAT_V_Counter_IRQ_Enable , REG_DISPSTAT_V_Counter_IRQ_Enable ); 
   iREG_DISPSTAT_V_Count_Setting      : entity work.eProcReg_gba generic map (DISPSTAT_V_Count_Setting     ) port map  (clk, gb_bus, reg_wired_or(6), reg_wired_done(6), REG_DISPSTAT_V_Count_Setting      , REG_DISPSTAT_V_Count_Setting      ); 
   iREG_VCOUNT                        : entity work.eProcReg_gba generic map (VCOUNT                       ) port map  (clk, gb_bus, reg_wired_or(7), reg_wired_done(7), REG_VCOUNT); 
   
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
   
   linecounter_drawer <= linecounter;
   
   REG_VCOUNT(23 downto 16) <= std_logic_vector(linecounter);
   REG_VCOUNT(31 downto 24) <= (others => '0');
   
   IRP_HBlank  <= '1' when ((gpustate = VISIBLE or gpustate = VBLANK) and cycles >= 1006 and REG_DISPSTAT_H_Blank_IRQ_Enable = "1") else '0';
   IRP_LCDStat <= '1' when (linecounter = unsigned(REG_DISPSTAT_V_Count_Setting) and REG_DISPSTAT_V_Counter_flag = "0" and REG_DISPSTAT_V_Counter_IRQ_Enable = "1") else '0';
   
   process (clk)
   begin
      if rising_edge(clk) then
      
         IRP_VBlank      <= '0';
                     
         drawline        <= '0';
         drawObj         <= '0';
         refpoint_update <= '0';
         line_trigger    <= '0';
         hblank_trigger  <= '0';
         vblank_trigger  <= '0';
         newline_invsync <= '0';
         
         videodma_start  <= '0';
         videodma_stop   <= '0';
         
         vram_blocked <= '0';
         if (gpustate = visible and vram_block_mode = '1' and cycles < 980) then
            vram_blocked <= '1';
         end if;
         
         DISPSTAT_debug    <= DISPSTAT_debug_next;
         DISPSTAT_debug(5 downto 3) <= REG_DISPSTAT_V_Counter_IRQ_Enable &
                                       REG_DISPSTAT_H_Blank_IRQ_Enable &
                                       REG_DISPSTAT_V_Blank_IRQ_Enable;
         
         DISPSTAT_debug_next <= REG_VCOUNT &
                                REG_DISPSTAT_V_Count_Setting &
                                "00" &
                                REG_DISPSTAT_V_Counter_IRQ_Enable &
                                REG_DISPSTAT_H_Blank_IRQ_Enable &
                                REG_DISPSTAT_V_Blank_IRQ_Enable &
                                REG_DISPSTAT_V_Counter_flag &
                                REG_DISPSTAT_H_Blank_flag &
                                REG_DISPSTAT_V_Blank_flag;

         if (reset = '1') then
         
            gpustate    <= tGPUState'VAL(to_integer(unsigned(SAVESTATE_GPU(21 downto 20))));
            cycles      <= unsigned(SAVESTATE_GPU(11 downto 0));
            linecounter <= unsigned(SAVESTATE_GPU(19 downto 12));
            
            REG_DISPSTAT_V_Counter_flag <= SAVESTATE_GPU(22 downto 22);
            REG_DISPSTAT_H_Blank_flag   <= SAVESTATE_GPU(23 downto 23);
            REG_DISPSTAT_V_Blank_flag   <= SAVESTATE_GPU(24 downto 24);
            
         elsif (ce = '1') then
         
            -- really required?
            -- if (forcedblank && !new_forcedblank) then
            --    gpustate = GPUState.VISIBLE
            --    cycles = 0
            --    GBRegs.Sect_display.DISPSTAT_V_Blank_flag.write(0);
            --    GBRegs.Sect_display.DISPSTAT_H_Blank_flag.write(0);
            -- end if;
         
            cycles <= cycles + 1;
            
            if (linecounter = unsigned(REG_DISPSTAT_V_Count_Setting)) then
               if (REG_DISPSTAT_V_Counter_flag = "0" and REG_DISPSTAT_V_Counter_IRQ_Enable = "1") then
               end if;
               REG_DISPSTAT_V_Counter_flag <= "1";
            else
               REG_DISPSTAT_V_Counter_flag <= "0";
            end if;
            
            case (gpustate) is
               when VISIBLE =>
                  if (cycles = 32) then
                     if (drawsoon = '1') then
                        drawline  <= '1';
                        drawsoon  <= '0';
                        if (cycles = 32 and linecounter_obj < 159) then
                           drawObj         <= '1';
                           linecounter_obj <= linecounter_obj + 1;
                        end if;
                     end if;
                  end if;
                  if (cycles >= 1006) then -- 960 is drawing time
                     cycles                    <= (others => '0');
                     gpustate                  <= HBLANK;
                     REG_DISPSTAT_H_Blank_flag <= "1";
                     hblank_trigger            <= '1';
                     if (linecounter >= 2) then
                        videodma_start  <= '1';
                     end if;
                  end if;
               
               when HBLANK =>
                  if (cycles >= 224) then
                     cycles          <= (others => '0');
                     linecounter     <= linecounter + 1;
   
                     REG_DISPSTAT_H_Blank_flag <= "0";
                     if ((linecounter + 1) < 160) then
                        gpustate     <= VISIBLE;
                        drawsoon     <= '1';
                        line_trigger <= '1';
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
                  if (cycles = 32 and linecounter = 227) then
                     drawObj         <= '1';
                     linecounter_obj <= (others => '0');
                  end if;
                  if (cycles >= 1006) then
                     cycles                     <= (others => '0');
                     gpustate                   <= VBLANKHBLANK;
                     REG_DISPSTAT_H_Blank_flag  <= "1";
                     newline_invsync            <= '1';
                     -- don't do hblank for dma here!
                     if (linecounter < 162) then
                        videodma_start <= '1';
                     end if;
                     if (linecounter = 162) then
                        videodma_stop  <= '1';
                     end if;
                  end if;
               
               when VBLANKHBLANK =>
                  if (cycles >= 224) then
                     cycles      <= (others => '0');
                     linecounter <= linecounter + 1;
                     
                     REG_DISPSTAT_H_Blank_flag <= "0";
                     line_trigger <= '1';
                     if ((linecounter + 1) = 228) then
                        linecounter <= (others => '0');
                        gpustate    <= VISIBLE;
                        drawsoon    <= '1';
                     else
                        gpustate <= VBLANK;
                        if ((linecounter + 1) = 227) then
                           REG_DISPSTAT_V_Blank_flag <= "0";  -- (set in line 160..226; not 227)
                        end if;
                     end if;
                  end if;
            
            end case;
         
         end if;
      
      end if;
   end process;

end architecture;





