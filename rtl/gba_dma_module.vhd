library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

use work.pRegmap_gba.all;
use work.pProc_bus_gba.all;

use work.pReg_savestates.all;

entity gba_dma_module is
   generic
   (
      index                        : integer range 0 to 3;
      has_DRQ                      : boolean;
      Reg_SAD                      : regmap_type;
      Reg_DAD                      : regmap_type;
      Reg_CNT_L                    : regmap_type;
      Reg_CNT_H_Dest_Addr_Control  : regmap_type;
      Reg_CNT_H_Source_Adr_Control : regmap_type;
      Reg_CNT_H_DMA_Repeat         : regmap_type;
      Reg_CNT_H_DMA_Transfer_Type  : regmap_type;
      Reg_CNT_H_Game_Pak_DRQ       : regmap_type;
      Reg_CNT_H_DMA_Start_Timing   : regmap_type;
      Reg_CNT_H_IRQ_on             : regmap_type;
      Reg_CNT_H_DMA_Enable         : regmap_type
   );
   port 
   (
      clk100              : in     std_logic;  
      reset               : in     std_logic;
                                   
      savestate_bus       : inout  proc_bus_gb_type;
      loading_savestate   : in     std_logic;
                                   
      gb_bus              : inout  proc_bus_gb_type := ((others => 'Z'), (others => 'Z'), (others => 'Z'), 'Z', 'Z', 'Z', "ZZ", "ZZZZ", 'Z');
                                   
      new_cycles          : in     unsigned(7 downto 0);
      new_cycles_valid    : in     std_logic;
                                   
      IRP_DMA             : out    std_logic := '0';
                                   
      dma_on              : out    std_logic := '0';
      allow_on            : in     std_logic;
      dma_soon            : out    std_logic := '0';
      lowprio_pending     : in     std_logic; 
                                   
      sound_dma_req       : in     std_logic;
      hblank_trigger      : in     std_logic;
      vblank_trigger      : in     std_logic;
      videodma_start      : in     std_logic;
      videodma_stop       : in     std_logic;
                                   
      dma_new_cycles      : out    std_logic := '0'; 
      dma_first_cycles    : out    std_logic := '0';
      dma_dword_cycles    : out    std_logic := '0';
      dma_toROM           : out    std_logic := '0';
      dma_init_cycles     : buffer std_logic := '0';
      dma_cycles_adrup    : out    std_logic_vector(3 downto 0) := (others => '0'); 
                                   
      dma_eepromcount     : out    unsigned(16 downto 0);
                                   
      last_dma_out        : out    std_logic_vector(31 downto 0) := (others => '0');
      last_dma_valid      : out    std_logic := '0';
      last_dma_in         : in     std_logic_vector(31 downto 0);
                                   
      dma_bus_Adr         : out    std_logic_vector(27 downto 0) := (others => '0'); 
      dma_bus_rnw         : out    std_logic := '0';
      dma_bus_ena         : out    std_logic := '0';
      dma_bus_acc         : out    std_logic_vector(1 downto 0) := (others => '0'); 
      dma_bus_dout        : out    std_logic_vector(31 downto 0) := (others => '0'); 
      dma_bus_din         : in     std_logic_vector(31 downto 0);
      dma_bus_done        : in     std_logic;
      dma_bus_unread      : in     std_logic;
                                   
      is_idle             : out    std_logic
   );
end entity;

architecture arch of gba_dma_module is

   signal SAD                      : std_logic_vector(Reg_SAD                     .upper downto Reg_SAD                     .lower) := (others => '0');
   signal DAD                      : std_logic_vector(Reg_DAD                     .upper downto Reg_DAD                     .lower) := (others => '0');
   signal CNT_L                    : std_logic_vector(Reg_CNT_L                   .upper downto Reg_CNT_L                   .lower) := (others => '0');
   signal CNT_H_Dest_Addr_Control  : std_logic_vector(Reg_CNT_H_Dest_Addr_Control .upper downto Reg_CNT_H_Dest_Addr_Control .lower) := (others => '0');
   signal CNT_H_Source_Adr_Control : std_logic_vector(Reg_CNT_H_Source_Adr_Control.upper downto Reg_CNT_H_Source_Adr_Control.lower) := (others => '0');
   signal CNT_H_DMA_Repeat         : std_logic_vector(Reg_CNT_H_DMA_Repeat        .upper downto Reg_CNT_H_DMA_Repeat        .lower) := (others => '0');
   signal CNT_H_DMA_Transfer_Type  : std_logic_vector(Reg_CNT_H_DMA_Transfer_Type .upper downto Reg_CNT_H_DMA_Transfer_Type .lower) := (others => '0');
   signal CNT_H_Game_Pak_DRQ       : std_logic_vector(Reg_CNT_H_Game_Pak_DRQ      .upper downto Reg_CNT_H_Game_Pak_DRQ      .lower) := (others => '0');
   signal CNT_H_DMA_Start_Timing   : std_logic_vector(Reg_CNT_H_DMA_Start_Timing  .upper downto Reg_CNT_H_DMA_Start_Timing  .lower) := (others => '0');
   signal CNT_H_IRQ_on             : std_logic_vector(Reg_CNT_H_IRQ_on            .upper downto Reg_CNT_H_IRQ_on            .lower) := (others => '0');
   signal CNT_H_DMA_Enable         : std_logic_vector(Reg_CNT_H_DMA_Enable        .upper downto Reg_CNT_H_DMA_Enable        .lower) := (others => '0');
                                                                                                                                                   
   signal CNT_H_DMA_Enable_written           : std_logic;   

   signal Enable    : std_logic_vector(0 downto 0) := "0";
   signal running   : std_logic := '0';
   signal waiting   : std_logic := '0';
   signal first     : std_logic := '0';
   signal dmaon     : std_logic := '0';
   signal waitTicks : integer range 0 to 3 := 0;
   
   signal dest_Addr_Control  : integer range 0 to 3;
   signal source_Adr_Control : integer range 0 to 3;
   signal Start_Timing       : integer range 0 to 3;
   signal Repeat             : std_logic;
   signal Transfer_Type_DW   : std_logic;

   signal addr_source        : unsigned(27 downto 0);
   signal addr_target        : unsigned(27 downto 0);
   signal count              : unsigned(16 downto 0);
   signal fullcount          : unsigned(16 downto 0);

   type tstate is
   (
      IDLE,
      START,
      READING,
      WRITING
   );
   signal state : tstate := IDLE;

   -- savestate
   signal SAVESTATE_DMASOURCE     : std_logic_vector(27 downto 0);
   signal SAVESTATE_DMATARGET     : std_logic_vector(27 downto 0);
   signal SAVESTATE_DMAMIXED      : std_logic_vector(30 downto 0);
   signal SAVESTATE_DMAMIXED_BACK : std_logic_vector(30 downto 0); 
   
   
begin 

   gDRQ : if has_DRQ = true generate
   begin
      iCNT_H_Game_Pak_DRQ       : entity work.eProcReg_gba generic map ( Reg_CNT_H_Game_Pak_DRQ       ) port map  (clk100, gb_bus, CNT_H_Game_Pak_DRQ       , CNT_H_Game_Pak_DRQ);  
   end generate;
   
   iSAD                      : entity work.eProcReg_gba generic map ( Reg_SAD                      ) port map  (clk100, gb_bus, x"00000000"              , SAD                     );  
   iDAD                      : entity work.eProcReg_gba generic map ( Reg_DAD                      ) port map  (clk100, gb_bus, x"00000000"              , DAD                     );  
   iCNT_L                    : entity work.eProcReg_gba generic map ( Reg_CNT_L                    ) port map  (clk100, gb_bus, x"0000"                  , CNT_L                   );   
   iCNT_H_Dest_Addr_Control  : entity work.eProcReg_gba generic map ( Reg_CNT_H_Dest_Addr_Control  ) port map  (clk100, gb_bus, CNT_H_Dest_Addr_Control  , CNT_H_Dest_Addr_Control );  
   iCNT_H_Source_Adr_Control : entity work.eProcReg_gba generic map ( Reg_CNT_H_Source_Adr_Control ) port map  (clk100, gb_bus, CNT_H_Source_Adr_Control , CNT_H_Source_Adr_Control);  
   iCNT_H_DMA_Repeat         : entity work.eProcReg_gba generic map ( Reg_CNT_H_DMA_Repeat         ) port map  (clk100, gb_bus, CNT_H_DMA_Repeat         , CNT_H_DMA_Repeat        );  
   iCNT_H_DMA_Transfer_Type  : entity work.eProcReg_gba generic map ( Reg_CNT_H_DMA_Transfer_Type  ) port map  (clk100, gb_bus, CNT_H_DMA_Transfer_Type  , CNT_H_DMA_Transfer_Type );  
   iCNT_H_DMA_Start_Timing   : entity work.eProcReg_gba generic map ( Reg_CNT_H_DMA_Start_Timing   ) port map  (clk100, gb_bus, CNT_H_DMA_Start_Timing   , CNT_H_DMA_Start_Timing  );  
   iCNT_H_IRQ_on             : entity work.eProcReg_gba generic map ( Reg_CNT_H_IRQ_on             ) port map  (clk100, gb_bus, CNT_H_IRQ_on             , CNT_H_IRQ_on            );  
   iCNT_H_DMA_Enable         : entity work.eProcReg_gba generic map ( Reg_CNT_H_DMA_Enable         ) port map  (clk100, gb_bus, Enable                   , CNT_H_DMA_Enable         , CNT_H_DMA_Enable_written);  
   
   dma_eepromcount <= fullcount;
   
   -- save state
   iSAVESTATE_DMASOURCE : entity work.eProcReg_gba generic map (REG_SAVESTATE_DMASOURCE, index) port map (clk100, savestate_bus, std_logic_vector(addr_source) , SAVESTATE_DMASOURCE);
   iSAVESTATE_DMATARGET : entity work.eProcReg_gba generic map (REG_SAVESTATE_DMATARGET, index) port map (clk100, savestate_bus, std_logic_vector(addr_target) , SAVESTATE_DMATARGET);
   iSAVESTATE_DMAMIXED  : entity work.eProcReg_gba generic map (REG_SAVESTATE_DMAMIXED , index) port map (clk100, savestate_bus,       SAVESTATE_DMAMIXED_BACK , SAVESTATE_DMAMIXED );
   
   SAVESTATE_DMAMIXED_BACK(16 downto 0)  <= std_logic_vector(count);
   SAVESTATE_DMAMIXED_BACK(17 downto 17) <= Enable;            
   SAVESTATE_DMAMIXED_BACK(18)           <= '1' when running = '1' or waitTicks > 0 else '0';           
   SAVESTATE_DMAMIXED_BACK(19)           <= waiting;           
   SAVESTATE_DMAMIXED_BACK(20)           <= first;             
   SAVESTATE_DMAMIXED_BACK(22 downto 21) <= std_logic_vector(to_unsigned(dest_Addr_Control, 2)); 
   SAVESTATE_DMAMIXED_BACK(24 downto 23) <= std_logic_vector(to_unsigned(source_Adr_Control, 2));
   SAVESTATE_DMAMIXED_BACK(26 downto 25) <= std_logic_vector(to_unsigned(Start_Timing, 2));      
   SAVESTATE_DMAMIXED_BACK(27)           <= Repeat;           
   SAVESTATE_DMAMIXED_BACK(28)           <= Transfer_Type_DW; 
   SAVESTATE_DMAMIXED_BACK(29)           <= '0';
   SAVESTATE_DMAMIXED_BACK(30)           <= dmaon;            
   
   is_idle <= '1' when state = IDLE else '0';
   
   dma_on <= dmaon;
   
   process (clk100)
   begin
      if rising_edge(clk100) then
      
         IRP_DMA       <= '0';
         
         dma_bus_ena   <= '0';
         
         last_dma_valid   <= '0';
         
         dma_new_cycles   <= '0';
         dma_first_cycles <= '0';
         dma_dword_cycles <= '0';
         dma_toROM        <= '0';
         dma_init_cycles  <= '0';
         dma_cycles_adrup <= (others => '0');
         
         if (reset = '1') then
            addr_source        <= unsigned(SAVESTATE_DMASOURCE);
            addr_target        <= unsigned(SAVESTATE_DMATARGET);
            count              <= unsigned(SAVESTATE_DMAMIXED(16 downto 0));
            
            Enable             <= SAVESTATE_DMAMIXED(17 downto 17);
            running            <= SAVESTATE_DMAMIXED(18);
            waiting            <= SAVESTATE_DMAMIXED(19);
            first              <= SAVESTATE_DMAMIXED(20);
            dest_Addr_Control  <= to_integer(unsigned(SAVESTATE_DMAMIXED(22 downto 21)));
            source_Adr_Control <= to_integer(unsigned(SAVESTATE_DMAMIXED(24 downto 23)));
            Start_Timing       <= to_integer(unsigned(SAVESTATE_DMAMIXED(26 downto 25)));
            Repeat             <= SAVESTATE_DMAMIXED(27);
            Transfer_Type_DW   <= SAVESTATE_DMAMIXED(28);
            dmaon              <= SAVESTATE_DMAMIXED(30);
         
            waitTicks          <= 0;
            state              <= IDLE;
         else
      
            -- dma init
            if (CNT_H_DMA_Enable_written= '1' and loading_savestate = '0') then
            
               Enable <= CNT_H_DMA_Enable;
               
               if (CNT_H_DMA_Enable = "0") then
                  running <= '0';
                  waiting <= '0';
                  dmaon   <= '0';
               end if;
            
               if (Enable = "0" and CNT_H_DMA_Enable = "1") then
                  
                  -- drq not implemented! Reg_CNT_H_Game_Pak_DRQ
                  
                  dest_Addr_Control  <= to_integer(unsigned(CNT_H_Dest_Addr_Control));
                  source_Adr_Control <= to_integer(unsigned(CNT_H_Source_Adr_Control));
                  Start_Timing       <= to_integer(unsigned(CNT_H_DMA_Start_Timing));
                  Repeat             <= CNT_H_DMA_Repeat(CNT_H_DMA_Repeat'left);
                  Transfer_Type_DW   <= CNT_H_DMA_Transfer_Type(CNT_H_DMA_Transfer_Type'left);
   
                  addr_source <= unsigned(SAD(27 downto 0));
                  addr_target <= unsigned(DAD(27 downto 0));
   
                  case (index) is
                     when 0 => addr_source(27) <= '0'; addr_target(27) <= '0';
                     when 1 =>                         addr_target(27) <= '0';
                     when 2 =>                         addr_target(27) <= '0';
                     when 3 => null;
                  end case;
                     
                  if (index = 3) then
                     if (CNT_L(15 downto 0) = (15 downto 0 => '0')) then
                        count <= '1' & x"0000";
                     else
                        count <= '0' & unsigned(CNT_L(15 downto 0));
                     end if;  
                  else
                     if (CNT_L(13 downto 0) = (13 downto 0 => '0')) then
                        count <= '0' & x"4000";
                     else
                        count <= "000" & unsigned(CNT_L(13 downto 0));
                     end if;  
                  end if;
   
                  waiting <= '1';
                  
                  if (CNT_H_DMA_Start_Timing = "11" and (index = 1 or index = 2)) then -- sound dma
                     count             <= to_unsigned(4, 17);
                     dest_Addr_Control <= 3;
                     Transfer_Type_DW  <= '1';
                  end if;
            
               end if;
            
            end if;
         
            -- dma checkrun
            if (Enable = "1") then 
               if (waiting = '1') then
                  if (Start_Timing = 0 or 
                  (Start_Timing = 1 and vblank_trigger = '1') or 
                  (Start_Timing = 2 and hblank_trigger = '1') or 
                  (Start_Timing = 3 and sound_dma_req = '1') or
                  (Start_Timing = 3 and videodma_start = '1')) then
                     dma_soon   <= '1';
                     waitTicks  <= 3;
                     waiting    <= '0';
                     first      <= '1';
                     fullcount  <= count;
                  end if ;   
               end if;
               
               if (Start_Timing = 3 and videodma_stop = '1') then
                  Enable <= "0";
               end if;
      
               if (waitTicks > 0) then
                  if (new_cycles_valid = '1') then
                     if (new_cycles >= waitTicks) then
                        running   <= '1';
                        dmaon     <= '1';
                        waitTicks <= 0;
                        dma_soon  <= '0';
                        state     <= IDLE;
                     else
                        waitTicks <= waitTicks - to_integer(new_cycles);
                     end if;
                  end if;
               end if;
                  
      
               -- dma work
               if (running = '1') then
                  
                  case state is
                  
                     when IDLE =>
                        if (allow_on = '1') then
                           if (lowprio_pending = '0') then
                              dma_init_cycles  <= '1';
                           end if;
                           state            <= START;
                        end if;
                  
                     when START =>
                        if (allow_on = '1' and dma_init_cycles = '0') then
                           state <= READING;
                           dma_bus_rnw <= '1';
                           dma_bus_ena <= '1';
                           if (Transfer_Type_DW = '1') then
                              dma_bus_Adr <= std_logic_vector(addr_source(27 downto 2)) & "00";
                              dma_bus_acc <= ACCESS_32BIT;
                           else
                              dma_bus_Adr <= std_logic_vector(addr_source(27 downto 1)) & "0";
                              dma_bus_acc <= ACCESS_16BIT;
                           end if;  
                           -- timing
                           count <= count - 1;
                           first <= '0';
                           dma_new_cycles   <= '1';
                           dma_first_cycles <= first;
                           dma_dword_cycles <= Transfer_Type_DW;
                           dma_cycles_adrup <= std_logic_vector(addr_source(27 downto 24)); 
                           if ((addr_source(27) = '0') and (addr_target(27) = '1')) then
                              dma_toROM <= '1';
                           end if;
                        end if;
                     
                     when READING =>
                        if (dma_bus_done = '1') then
                           state <= WRITING;
                           dma_bus_rnw  <= '0';
                           dma_bus_ena  <= '1';
                           if (Transfer_Type_DW = '1') then
                              dma_bus_Adr <= std_logic_vector(addr_target(27 downto 2)) & "00";
                           else
                              dma_bus_Adr <= std_logic_vector(addr_target(27 downto 1)) & "0";
                           end if;
                           
                           if (addr_source >= 16#2000000# and dma_bus_unread = '0') then
                              dma_bus_dout   <= dma_bus_din;
                              last_dma_valid <= '1';
                              if (Transfer_Type_DW = '1') then                           
                                 last_dma_out   <= dma_bus_din;
                              else
                                 last_dma_out   <= dma_bus_din(15 downto 0) & dma_bus_din(15 downto 0);
                              end if;
                           else
                              dma_bus_dout <= last_dma_in;
                           end if;
                           
                           -- next settings
                           if (Transfer_Type_DW = '1') then
                              if (source_Adr_Control = 0 or source_Adr_Control = 3 or (addr_source >= 16#8000000# and addr_source < 16#E000000#)) then 
                                 addr_source <= addr_source + 4; 
                              elsif (source_Adr_Control = 1) then
                                 addr_source <= addr_source - 4;
                              end if;
   
                              if (dest_Addr_Control = 0 or (dest_Addr_Control = 3 and Start_Timing /= 3)) then
                                 addr_target <= addr_target + 4;
                              elsif (dest_Addr_Control = 1) then
                                 addr_target <= addr_target - 4;
                              end if;
                           else
                              if (source_Adr_Control = 0 or source_Adr_Control = 3 or (addr_source >= 16#8000000# and addr_source < 16#E000000#)) then 
                                 addr_source <= addr_source + 2; 
                              elsif (source_Adr_Control = 1) then
                                 addr_source <= addr_source - 2;
                              end if;
   
                              if (dest_Addr_Control = 0 or (dest_Addr_Control = 3 and Start_Timing /= 3)) then
                                 addr_target <= addr_target + 2;
                              elsif (dest_Addr_Control = 1) then
                                 addr_target <= addr_target - 2;
                              end if;
                           end if;
                           -- timing
                           dma_new_cycles   <= '1';
                           dma_first_cycles <= first;
                           dma_dword_cycles <= Transfer_Type_DW;
                           dma_cycles_adrup <= std_logic_vector(addr_target(27 downto 24));
                        end if;
                        
                     
                     when WRITING =>
                        if (dma_bus_done = '1') then
                           state <= START;
                           if (count = 0) then
                              state   <= IDLE;
                              running <= '0';
                              dmaon   <= '0';
   
                              IRP_DMA <= CNT_H_IRQ_on(CNT_H_IRQ_on'left);
   
                              if (Repeat = '1' and Start_Timing /= 0) then
                                 waiting <= '1';
                                 if (Start_Timing = 3 and (index = 1 or index = 2)) then
                                    count <= to_unsigned(4, 17);
                                 else
                                    
                                    if (index = 3) then
                                       if (CNT_L(15 downto 0) = (15 downto 0 => '0')) then
                                          count <= '1' & x"0000";
                                       else
                                          count <= '0' & unsigned(CNT_L(15 downto 0));
                                       end if;  
                                    else
                                       if (CNT_L(13 downto 0) = (13 downto 0 => '0')) then
                                          count <= '0' & x"4000";
                                       else
                                          count <= "000" & unsigned(CNT_L(13 downto 0));
                                       end if;  
                                    end if;
                                    
                                    if (dest_Addr_Control = 3) then
                                       addr_target <= unsigned(DAD(27 downto 0));
                                       if (index < 3) then
                                          addr_target(27) <= '0';
                                       end if;
                                    end if;
                                 end if;
                              else
                                 Enable <= "0";
                              end if;
                           end if;
                        end if;
                     
                  end case;
                  
               
               end if;
            end if;
            
         end if;
      
      end if;
   end process;
  

end architecture;


