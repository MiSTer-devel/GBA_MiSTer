library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

use work.pProc_bus_gba.all;
use work.pReg_gba_dma.all;

entity gba_dma is
   port 
   (
      clk                 : in     std_logic;  
      reset               : in     std_logic;
                                   
      savestate_bus       : in     proc_bus_gb_type;
      ss_wired_out        : out    std_logic_vector(proc_buswidth-1 downto 0) := (others => '0');
      ss_wired_done       : out    std_logic;
      loading_savestate   : in     std_logic;
      
      gb_bus              : in     proc_bus_gb_type;
      wired_out           : out    std_logic_vector(proc_buswidth-1 downto 0) := (others => '0');
      wired_done          : out    std_logic;
                                   
      IRP_DMA             : out    std_logic_vector(3 downto 0);
      lastread_dma        : out    std_logic_vector(31 downto 0);
                                   
      dma_on              : out    std_logic;
      dma_on_next         : out    std_logic;
      CPU_bus_idle        : in     std_logic;
                                   
      sound_dma_req       : in     std_logic_vector(1 downto 0);
      hblank_trigger      : in     std_logic;
      vblank_trigger      : in     std_logic;
      videodma_start      : in     std_logic;
      videodma_stop       : in     std_logic;
      
      dma_eepromcount     : out    unsigned(16 downto 0);
      
      dma_bus_Adr         : out    std_logic_vector(27 downto 0);
      dma_bus_rnw         : buffer std_logic;
      dma_bus_ena         : out    std_logic;
      dma_bus_seq         : out    std_logic;
      dma_bus_norom       : out    std_logic;
      dma_bus_acc         : out    std_logic_vector(1 downto 0);
      dma_bus_dout        : out    std_logic_vector(31 downto 0);
      dma_bus_din         : in     std_logic_vector(31 downto 0);
      dma_bus_done        : in     std_logic;
      dma_bus_unread      : in     std_logic;
      
      debug_dma           : out    std_logic_vector(31 downto 0)
   );
end entity;

architecture arch of gba_dma is

   type tstate is
   (
      IDLE,
      READING,
      WRITING
   );
   signal state : tstate := IDLE;

   type t_reg_wired_or is array(0 to 3) of std_logic_vector(31 downto 0);
   signal reg_wired_or    : t_reg_wired_or;   
   signal reg_wired_done  : unsigned(0 to 3);

   type tArray_Dout is array(0 to 3) of std_logic_vector(31 downto 0);
   type tArray_Adr  is array(0 to 3) of std_logic_vector(27 downto 0);
   type tArray_acc  is array(0 to 3) of std_logic_vector(1 downto 0);
   type tArray_bit  is array(0 to 3) of std_logic;
   
   signal Array_Dout  : tArray_Dout;
   signal Array_Adr   : tArray_Adr;
   signal Array_acc   : tArray_acc;
   signal Array_rnw   : tArray_bit;
   signal Array_ena   : tArray_bit;
   signal Array_seq   : tArray_bit;
   signal Array_norom : tArray_bit;
   signal Array_done  : tArray_bit;
             
   signal single_dma_on      : std_logic_vector(3 downto 0);
   signal single_dma_on_next : std_logic_vector(3 downto 0);
   signal single_allow_on    : std_logic_vector(3 downto 0);
   signal single_soon        : std_logic_vector(3 downto 0);
                             
   signal lowprio_pending    : std_logic_vector(3 downto 0);
                             
   signal dma_switch         : integer range 0 to 3 := 0; 
   signal dma_idle           : std_logic := '1';
                             
   signal last_dma_value     : std_logic_vector(31 downto 0) := (others => '0');
                             
   signal last_dma0          : std_logic_vector(31 downto 0);
   signal last_dma1          : std_logic_vector(31 downto 0);
   signal last_dma2          : std_logic_vector(31 downto 0);
   signal last_dma3          : std_logic_vector(31 downto 0);
   signal last_dma_valid0    : std_logic;
   signal last_dma_valid1    : std_logic;
   signal last_dma_valid2    : std_logic;
   signal last_dma_valid3    : std_logic;
                             
   signal single_is_idle     : std_logic_vector(3 downto 0);
       
   -- savestates
   type t_ss_wired_or is array(0 to 3) of std_logic_vector(31 downto 0);
   signal save_wired_or        : t_ss_wired_or;   
   signal save_wired_done      : unsigned(0 to 3);
       
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
      clk               => clk,     
      reset             => reset,
                        
      savestate_bus     => savestate_bus,
      ss_wired_out      => save_wired_or(0),
      ss_wired_done     => save_wired_done(0),
      loading_savestate => loading_savestate,
      
      gb_bus            => gb_bus,           
      wired_out         => reg_wired_or(0),
      wired_done        => reg_wired_done(0),
                        
      IRP_DMA           => IRP_DMA(0),
        
      CPU_bus_idle      => CPU_bus_idle,
      dma_on            => single_dma_on(0),
      dma_on_next       => single_dma_on_next(0),
      allow_on          => single_allow_on(0),
      dma_soon          => single_soon(0),
      lowprio_pending   => lowprio_pending(0),
                        
      sound_dma_req     => '0', 
      hblank_trigger    => hblank_trigger,
      vblank_trigger    => vblank_trigger,
      videodma_start    => '0',
      videodma_stop     => '0',                

      dma_eepromcount   => open,
                        
      last_dma_out      => last_dma0,
      last_dma_valid    => last_dma_valid0,
      last_dma_in       => last_dma_value,
                        
      dma_bus_Adr       => Array_Adr(0),
      dma_bus_rnw       => Array_rnw(0), 
      dma_bus_ena       => Array_ena(0), 
      dma_bus_seq       => Array_seq(0), 
      dma_bus_norom     => Array_norom(0), 
      dma_bus_acc       => Array_acc(0), 
      dma_bus_dout      => Array_Dout(0), 
      dma_bus_din       => dma_bus_din,
      dma_bus_done      => Array_done(0),
      dma_bus_unread    => dma_bus_unread,
      
      is_idle           => single_is_idle(0)
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
      clk               => clk,
      reset             => reset,
                         
      savestate_bus     => savestate_bus,
      ss_wired_out      => save_wired_or(1),
      ss_wired_done     => save_wired_done(1),
      loading_savestate => loading_savestate,
      
      gb_bus            => gb_bus,           
      wired_out         => reg_wired_or(1),
      wired_done        => reg_wired_done(1),
                        
      IRP_DMA           => IRP_DMA(1),
           
      CPU_bus_idle      => CPU_bus_idle,
      dma_on            => single_dma_on(1),
      dma_on_next       => single_dma_on_next(1),
      allow_on          => single_allow_on(1),
      dma_soon          => single_soon(1),
      lowprio_pending   => lowprio_pending(1),
                        
      sound_dma_req     => sound_dma_req(0), 
      hblank_trigger    => hblank_trigger,
      vblank_trigger    => vblank_trigger,
      videodma_start    => '0',
      videodma_stop     => '0',     
                        
      dma_eepromcount   => open,
                        
      last_dma_out      => last_dma1,
      last_dma_valid    => last_dma_valid1,
      last_dma_in       => last_dma_value,
                        
      dma_bus_Adr       => Array_Adr(1),
      dma_bus_rnw       => Array_rnw(1), 
      dma_bus_ena       => Array_ena(1), 
      dma_bus_seq       => Array_seq(1), 
      dma_bus_norom     => Array_norom(1), 
      dma_bus_acc       => Array_acc(1), 
      dma_bus_dout      => Array_Dout(1), 
      dma_bus_din       => dma_bus_din,
      dma_bus_done      => Array_done(1),
      dma_bus_unread    => dma_bus_unread,
      
      is_idle           => single_is_idle(1)
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
      clk               => clk, 
      reset             => reset,
                        
      savestate_bus     => savestate_bus,
      ss_wired_out      => save_wired_or(2),
      ss_wired_done     => save_wired_done(2),
      loading_savestate => loading_savestate,
      
      gb_bus            => gb_bus,           
      wired_out         => reg_wired_or(2),
      wired_done        => reg_wired_done(2),
                        
      IRP_DMA           => IRP_DMA(2),
                 
      CPU_bus_idle      => CPU_bus_idle,
      dma_on            => single_dma_on(2),
      dma_on_next       => single_dma_on_next(2),
      allow_on          => single_allow_on(2),
      dma_soon          => single_soon(2),
      lowprio_pending   => lowprio_pending(2),
                        
      sound_dma_req     => sound_dma_req(1), 
      hblank_trigger    => hblank_trigger,
      vblank_trigger    => vblank_trigger,
      videodma_start    => '0',
      videodma_stop     => '0',     
         
      dma_eepromcount   => open,
         
      last_dma_out      => last_dma2,
      last_dma_valid    => last_dma_valid2,
      last_dma_in       => last_dma_value,
         
      dma_bus_Adr       => Array_Adr(2),
      dma_bus_rnw       => Array_rnw(2), 
      dma_bus_ena       => Array_ena(2), 
      dma_bus_seq       => Array_seq(2), 
      dma_bus_norom     => Array_norom(2), 
      dma_bus_acc       => Array_acc(2), 
      dma_bus_dout      => Array_Dout(2), 
      dma_bus_din       => dma_bus_din,
      dma_bus_done      => Array_done(2),
      dma_bus_unread    => dma_bus_unread,
      
      is_idle           => single_is_idle(2)
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
      clk               => clk,   
      reset             => reset,
                        
      savestate_bus     => savestate_bus,
      ss_wired_out      => save_wired_or(3),
      ss_wired_done     => save_wired_done(3),
      loading_savestate => loading_savestate,      
      
      gb_bus            => gb_bus,           
      wired_out         => reg_wired_or(3),
      wired_done        => reg_wired_done(3),
         
      IRP_DMA           => IRP_DMA(3),
                        
      CPU_bus_idle      => CPU_bus_idle,
      dma_on            => single_dma_on(3),
      dma_on_next       => single_dma_on_next(3),
      allow_on          => single_allow_on(3),
      dma_soon          => single_soon(3),
      lowprio_pending   => lowprio_pending(3),
                        
      sound_dma_req     => '0', 
      hblank_trigger    => hblank_trigger,
      vblank_trigger    => vblank_trigger,
      videodma_start    => videodma_start,
      videodma_stop     => videodma_stop ,     
         
      dma_eepromcount   => dma_eepromcount,
         
      last_dma_out      => last_dma3,
      last_dma_valid    => last_dma_valid3,
      last_dma_in       => last_dma_value,
         
      dma_bus_Adr       => Array_Adr(3),
      dma_bus_rnw       => Array_rnw(3), 
      dma_bus_ena       => Array_ena(3), 
      dma_bus_seq       => Array_seq(3), 
      dma_bus_norom     => Array_norom(3), 
      dma_bus_acc       => Array_acc(3), 
      dma_bus_dout      => Array_Dout(3), 
      dma_bus_din       => dma_bus_din,
      dma_bus_done      => Array_done(3),
      dma_bus_unread    => dma_bus_unread,
      
      is_idle           => single_is_idle(3)
   );
   
   lastread_dma <= last_dma_value;
   
   dma_idle <= '1' when (state = IDLE) else
               '1' when (state = WRITING and dma_bus_done = '1') else
               '0';
   
   dma_bus_dout  <= Array_Dout(0)  when Array_ena(0) = '1' else Array_Dout(1)  when Array_ena(1) = '1' else Array_Dout(2)  when Array_ena(2) = '1' else Array_Dout(3);
   dma_bus_Adr   <= Array_Adr(0)   when Array_ena(0) = '1' else Array_Adr(1)   when Array_ena(1) = '1' else Array_Adr(2)   when Array_ena(2) = '1' else Array_Adr(3);
   dma_bus_acc   <= Array_acc(0)   when Array_ena(0) = '1' else Array_acc(1)   when Array_ena(1) = '1' else Array_acc(2)   when Array_ena(2) = '1' else Array_acc(3);
   dma_bus_rnw   <= Array_rnw(0)   when Array_ena(0) = '1' else Array_rnw(1)   when Array_ena(1) = '1' else Array_rnw(2)   when Array_ena(2) = '1' else Array_rnw(3);
   dma_bus_ena   <= Array_ena(0)   when Array_ena(0) = '1' else Array_ena(1)   when Array_ena(1) = '1' else Array_ena(2)   when Array_ena(2) = '1' else Array_ena(3);
   dma_bus_seq   <= Array_seq(0)   when Array_ena(0) = '1' else Array_seq(1)   when Array_ena(1) = '1' else Array_seq(2)   when Array_ena(2) = '1' else Array_seq(3);
   dma_bus_norom <= Array_norom(0) when Array_ena(0) = '1' else Array_norom(1) when Array_ena(1) = '1' else Array_norom(2) when Array_ena(2) = '1' else Array_norom(3);
   
   Array_done(0) <= dma_bus_done when dma_switch = 0 else '0';
   Array_done(1) <= dma_bus_done when dma_switch = 1 else '0';
   Array_done(2) <= dma_bus_done when dma_switch = 2 else '0';
   Array_done(3) <= dma_bus_done when dma_switch = 3 else '0';
   
   single_allow_on(0) <= '1' when (lowprio_pending(0) = '0' and dma_idle = '1' and CPU_bus_idle = '1') else '0';
   single_allow_on(1) <= '1' when (lowprio_pending(1) = '0' and dma_idle = '1' and CPU_bus_idle = '1') else '0';
   single_allow_on(2) <= '1' when (lowprio_pending(2) = '0' and dma_idle = '1' and CPU_bus_idle = '1') else '0';
   single_allow_on(3) <= '1' when (lowprio_pending(3) = '0' and dma_idle = '1' and CPU_bus_idle = '1') else '0';
   
   lowprio_pending(0) <= '0';
   lowprio_pending(1) <= single_soon(0);
   lowprio_pending(2) <= single_soon(0) or single_soon(1);
   lowprio_pending(3) <= single_soon(0) or single_soon(1) or single_soon(2);
   
   dma_on       <= single_dma_on(0) or single_dma_on(1) or  single_dma_on(2) or single_dma_on(3);
   dma_on_next  <= single_dma_on_next(0) or single_dma_on_next(1) or  single_dma_on_next(2) or single_dma_on_next(3);
   
   process (clk)
   begin
      if rising_edge(clk) then
      
         if (last_dma_valid0 = '1') then
            last_dma_value <= last_dma0;
         elsif (last_dma_valid1 = '1') then
            last_dma_value <= last_dma1;
         elsif (last_dma_valid2 = '1') then
            last_dma_value <= last_dma2;
         elsif (last_dma_valid3 = '1') then
            last_dma_value <= last_dma3;
         end if;
         
         if (reset = '1') then
         
            dma_switch <= 0;
            state      <= IDLE;
        
         else
         
            if    (Array_ena(0) = '1') then dma_switch <= 0;
            elsif (Array_ena(1) = '1') then dma_switch <= 1;
            elsif (Array_ena(2) = '1') then dma_switch <= 2;
            elsif (Array_ena(3) = '1') then dma_switch <= 3; end if;
            
            case (state) is
            
               when IDLE =>
                  if (dma_bus_ena = '1') then
                     state <= READING;
                  end if;
                  
               when READING =>
                  if (dma_bus_ena = '1') then
                     state <= WRITING;
                  elsif (dma_on = '0') then
                     state <= IDLE;
                  end if;
                  
               when WRITING =>
                  if (dma_bus_ena = '1') then
                     state <= READING;
                  elsif (dma_bus_done = '1') then
                     state <= IDLE;
                  end if;
            
            end case;
            
         end if;

      end if;
   end process;
   
   debug_dma(0) <= dma_idle;
   debug_dma(2 downto 1) <= std_logic_vector(to_unsigned(dma_switch, 2));
   debug_dma(3) <= single_dma_on(0);
   debug_dma(4) <= single_dma_on(1);
   debug_dma(5) <= single_dma_on(2);
   debug_dma(6) <= single_dma_on(3);
   debug_dma(7) <= '0';
   debug_dma(8) <= single_allow_on(0);
   debug_dma(9) <= single_allow_on(1);
   debug_dma(10) <= single_allow_on(2);
   debug_dma(11) <= single_allow_on(3);
   debug_dma(12) <= single_is_idle(0);
   debug_dma(13) <= single_is_idle(1);
   debug_dma(14) <= single_is_idle(2);
   debug_dma(15) <= single_is_idle(3);
   debug_dma(31 downto 16) <= (others => '0');
    
end architecture;


 
 