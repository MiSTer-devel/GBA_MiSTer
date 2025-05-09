library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

use work.pProc_bus_gba.all;
use work.pReg_gba_sound.all;

library MEM;

use work.pReg_savestates.all;

entity gba_sound is
   generic
   (
      turbosound          : std_logic  -- sound buffer to play sound in turbo mode without sound pitched up
   );
   port 
   (
      clk1x               : in    std_logic; 
      ce                  : in    std_logic;      
      reset               : in    std_logic;
      
      loading_savestate   : in    std_logic;  
      savestate_bus       : in     proc_bus_gb_type;
      ss_wired_out        : out    std_logic_vector(proc_buswidth-1 downto 0) := (others => '0');
      ss_wired_done       : out    std_logic;
      
      gb_bus              : in    proc_bus_gb_type;
      wired_out           : out   std_logic_vector(proc_buswidth-1 downto 0) := (others => '0');
      wired_done          : out   std_logic;
      
      lockspeed           : in    std_logic;
      
      timer0_tick         : in    std_logic;
      timer1_tick         : in    std_logic;
      sound_dma_req       : out   std_logic_vector(1 downto 0);
      
      sound_out_left      : out   std_logic_vector(15 downto 0) := (others => '0');
      sound_out_right     : out   std_logic_vector(15 downto 0) := (others => '0');
      
      debug_fifocount     : out   unsigned(15 downto 0)
   );
end entity;

architecture arch of gba_sound is

   signal Sound_1_4_Master_Volume_RIGHT: std_logic_vector(SOUNDCNT_L_Sound_1_4_Master_Volume_RIGHT.upper downto SOUNDCNT_L_Sound_1_4_Master_Volume_RIGHT.lower) := (others => '0');
   signal Sound_1_4_Master_Volume_LEFT : std_logic_vector(SOUNDCNT_L_Sound_1_4_Master_Volume_LEFT .upper downto SOUNDCNT_L_Sound_1_4_Master_Volume_LEFT .lower) := (others => '0');
   signal Sound_1_Enable_Flags_RIGHT   : std_logic_vector(SOUNDCNT_L_Sound_1_Enable_Flags_RIGHT   .upper downto SOUNDCNT_L_Sound_1_Enable_Flags_RIGHT   .lower) := (others => '0');
   signal Sound_2_Enable_Flags_RIGHT   : std_logic_vector(SOUNDCNT_L_Sound_2_Enable_Flags_RIGHT   .upper downto SOUNDCNT_L_Sound_2_Enable_Flags_RIGHT   .lower) := (others => '0');
   signal Sound_3_Enable_Flags_RIGHT   : std_logic_vector(SOUNDCNT_L_Sound_3_Enable_Flags_RIGHT   .upper downto SOUNDCNT_L_Sound_3_Enable_Flags_RIGHT   .lower) := (others => '0');
   signal Sound_4_Enable_Flags_RIGHT   : std_logic_vector(SOUNDCNT_L_Sound_4_Enable_Flags_RIGHT   .upper downto SOUNDCNT_L_Sound_4_Enable_Flags_RIGHT   .lower) := (others => '0');
   signal Sound_1_Enable_Flags_LEFT    : std_logic_vector(SOUNDCNT_L_Sound_1_Enable_Flags_LEFT    .upper downto SOUNDCNT_L_Sound_1_Enable_Flags_LEFT    .lower) := (others => '0');
   signal Sound_2_Enable_Flags_LEFT    : std_logic_vector(SOUNDCNT_L_Sound_2_Enable_Flags_LEFT    .upper downto SOUNDCNT_L_Sound_2_Enable_Flags_LEFT    .lower) := (others => '0');
   signal Sound_3_Enable_Flags_LEFT    : std_logic_vector(SOUNDCNT_L_Sound_3_Enable_Flags_LEFT    .upper downto SOUNDCNT_L_Sound_3_Enable_Flags_LEFT    .lower) := (others => '0');
   signal Sound_4_Enable_Flags_LEFT    : std_logic_vector(SOUNDCNT_L_Sound_4_Enable_Flags_LEFT    .upper downto SOUNDCNT_L_Sound_4_Enable_Flags_LEFT    .lower) := (others => '0');
                                                                                                                
   signal Sound_1_4_Volume             : std_logic_vector(SOUNDCNT_H_Sound_1_4_Volume             .upper downto SOUNDCNT_H_Sound_1_4_Volume             .lower) := (others => '0');
   signal DMA_Sound_A_Volume           : std_logic_vector(SOUNDCNT_H_DMA_Sound_A_Volume           .upper downto SOUNDCNT_H_DMA_Sound_A_Volume           .lower) := (others => '0');
   signal DMA_Sound_B_Volume           : std_logic_vector(SOUNDCNT_H_DMA_Sound_B_Volume           .upper downto SOUNDCNT_H_DMA_Sound_B_Volume           .lower) := (others => '0');
   signal DMA_Sound_A_Enable_RIGHT     : std_logic_vector(SOUNDCNT_H_DMA_Sound_A_Enable_RIGHT     .upper downto SOUNDCNT_H_DMA_Sound_A_Enable_RIGHT     .lower) := (others => '0');
   signal DMA_Sound_A_Enable_LEFT      : std_logic_vector(SOUNDCNT_H_DMA_Sound_A_Enable_LEFT      .upper downto SOUNDCNT_H_DMA_Sound_A_Enable_LEFT      .lower) := (others => '0');
   signal DMA_Sound_A_Timer_Select     : std_logic_vector(SOUNDCNT_H_DMA_Sound_A_Timer_Select     .upper downto SOUNDCNT_H_DMA_Sound_A_Timer_Select     .lower) := (others => '0');
   signal DMA_Sound_A_Reset_FIFO       : std_logic_vector(SOUNDCNT_H_DMA_Sound_A_Reset_FIFO       .upper downto SOUNDCNT_H_DMA_Sound_A_Reset_FIFO       .lower) := (others => '0');
   signal DMA_Sound_B_Enable_RIGHT     : std_logic_vector(SOUNDCNT_H_DMA_Sound_B_Enable_RIGHT     .upper downto SOUNDCNT_H_DMA_Sound_B_Enable_RIGHT     .lower) := (others => '0');
   signal DMA_Sound_B_Enable_LEFT      : std_logic_vector(SOUNDCNT_H_DMA_Sound_B_Enable_LEFT      .upper downto SOUNDCNT_H_DMA_Sound_B_Enable_LEFT      .lower) := (others => '0');
   signal DMA_Sound_B_Timer_Select     : std_logic_vector(SOUNDCNT_H_DMA_Sound_B_Timer_Select     .upper downto SOUNDCNT_H_DMA_Sound_B_Timer_Select     .lower) := (others => '0');
   signal DMA_Sound_B_Reset_FIFO       : std_logic_vector(SOUNDCNT_H_DMA_Sound_B_Reset_FIFO       .upper downto SOUNDCNT_H_DMA_Sound_B_Reset_FIFO       .lower) := (others => '0');
                                                                                                                
   signal Sound_1_ON_flag              : std_logic_vector(SOUNDCNT_X_Sound_1_ON_flag              .upper downto SOUNDCNT_X_Sound_1_ON_flag              .lower) := (others => '0');
   signal Sound_2_ON_flag              : std_logic_vector(SOUNDCNT_X_Sound_2_ON_flag              .upper downto SOUNDCNT_X_Sound_2_ON_flag              .lower) := (others => '0');
   signal Sound_3_ON_flag              : std_logic_vector(SOUNDCNT_X_Sound_3_ON_flag              .upper downto SOUNDCNT_X_Sound_3_ON_flag              .lower) := (others => '0');
   signal Sound_4_ON_flag              : std_logic_vector(SOUNDCNT_X_Sound_4_ON_flag              .upper downto SOUNDCNT_X_Sound_4_ON_flag              .lower) := (others => '0');
   signal PSG_FIFO_Master_Enable       : std_logic_vector(SOUNDCNT_X_PSG_FIFO_Master_Enable       .upper downto SOUNDCNT_X_PSG_FIFO_Master_Enable       .lower) := (others => '0');
                                                                                                                    
   signal REG_SOUNDBIAS                : std_logic_vector(SOUNDBIAS                               .upper downto SOUNDBIAS                               .lower) := (others => '0');
               
   signal SOUNDCNT_H_DMA_written  : std_logic;
   
   type t_reg_wired_or is array(0 to 34) of std_logic_vector(31 downto 0);
   signal reg_wired_or    : t_reg_wired_or;   
   signal reg_wired_done  : unsigned(0 to 34);
   
   signal gbsound_on          : std_logic := '0';

   signal new_cycles_valid    : std_logic := '0';
   signal bus_cycles_sum      : unsigned(1 downto 0) := (others => '0');

   signal sound_out_ch1  : signed(15 downto 0);
   signal sound_out_ch2  : signed(15 downto 0);
   signal sound_out_ch3  : signed(15 downto 0);
   signal sound_out_ch4  : signed(15 downto 0);
   
   signal sound_out_dmaA_l : signed(15 downto 0);
   signal sound_out_dmaA_r : signed(15 downto 0);
   signal sound_out_dmaB_l : signed(15 downto 0);
   signal sound_out_dmaB_r : signed(15 downto 0);
   
   signal sound_on_ch1  : std_logic;
   signal sound_on_ch2  : std_logic;
   signal sound_on_ch3  : std_logic;
   signal sound_on_ch4  : std_logic;
   signal sound_on_dmaA : std_logic;
   signal sound_on_dmaB : std_logic;
   
   signal soundmix1_l  : signed(15 downto 0) := (others => '0'); 
   signal soundmix1_r  : signed(15 downto 0) := (others => '0'); 
   signal soundmix2_l  : signed(15 downto 0) := (others => '0'); 
   signal soundmix2_r  : signed(15 downto 0) := (others => '0'); 
   signal soundmix3_l  : signed(15 downto 0) := (others => '0'); 
   signal soundmix3_r  : signed(15 downto 0) := (others => '0'); 
   signal soundmix4_l  : signed(15 downto 0) := (others => '0'); 
   signal soundmix4_r  : signed(15 downto 0) := (others => '0'); 
   signal soundmix14_l : signed(15 downto 0) := (others => '0'); 
   signal soundmix14_r : signed(15 downto 0) := (others => '0'); 
   
   signal soundmix5_l : signed(15 downto 0) := (others => '0'); 
   signal soundmix5_r : signed(15 downto 0) := (others => '0'); 
   signal soundmix6_l : signed(15 downto 0) := (others => '0'); 
   signal soundmix6_r : signed(15 downto 0) := (others => '0'); 
   signal soundmix7_l : signed(15 downto 0) := (others => '0'); 
   signal soundmix7_r : signed(15 downto 0) := (others => '0'); 
   
   signal soundmix8_l : signed(15 downto 0) := (others => '0'); 
   signal soundmix8_r : signed(15 downto 0) := (others => '0'); 
   
   -- savestates
   signal SAVESTATE_SOUNDON      : std_logic_vector(3 downto 0);
   signal SAVESTATE_SOUNDON_back : std_logic_vector(3 downto 0);
   
   type t_ss_wired_or is array(0 to 2) of std_logic_vector(31 downto 0);
   signal save_wired_or        : t_ss_wired_or;   
   signal save_wired_done      : unsigned(0 to 2);
           
begin 

   iSound_1_4_Master_Volume_RIGHT : entity work.eProcReg_gba generic map ( SOUNDCNT_L_Sound_1_4_Master_Volume_RIGHT ) port map  (clk1x, gb_bus, reg_wired_or( 0), reg_wired_done( 0), Sound_1_4_Master_Volume_RIGHT , Sound_1_4_Master_Volume_RIGHT );  
   iSound_1_4_Master_Volume_LEFT  : entity work.eProcReg_gba generic map ( SOUNDCNT_L_Sound_1_4_Master_Volume_LEFT  ) port map  (clk1x, gb_bus, reg_wired_or( 1), reg_wired_done( 1), Sound_1_4_Master_Volume_LEFT  , Sound_1_4_Master_Volume_LEFT  );  
   iSound_1_Enable_Flags_RIGHT    : entity work.eProcReg_gba generic map ( SOUNDCNT_L_Sound_1_Enable_Flags_RIGHT    ) port map  (clk1x, gb_bus, reg_wired_or( 2), reg_wired_done( 2), Sound_1_Enable_Flags_RIGHT    , Sound_1_Enable_Flags_RIGHT    );  
   iSound_2_Enable_Flags_RIGHT    : entity work.eProcReg_gba generic map ( SOUNDCNT_L_Sound_2_Enable_Flags_RIGHT    ) port map  (clk1x, gb_bus, reg_wired_or( 3), reg_wired_done( 3), Sound_2_Enable_Flags_RIGHT    , Sound_2_Enable_Flags_RIGHT    );  
   iSound_3_Enable_Flags_RIGHT    : entity work.eProcReg_gba generic map ( SOUNDCNT_L_Sound_3_Enable_Flags_RIGHT    ) port map  (clk1x, gb_bus, reg_wired_or( 4), reg_wired_done( 4), Sound_3_Enable_Flags_RIGHT    , Sound_3_Enable_Flags_RIGHT    );  
   iSound_4_Enable_Flags_RIGHT    : entity work.eProcReg_gba generic map ( SOUNDCNT_L_Sound_4_Enable_Flags_RIGHT    ) port map  (clk1x, gb_bus, reg_wired_or( 5), reg_wired_done( 5), Sound_4_Enable_Flags_RIGHT    , Sound_4_Enable_Flags_RIGHT    );  
   iSound_1_Enable_Flags_LEFT     : entity work.eProcReg_gba generic map ( SOUNDCNT_L_Sound_1_Enable_Flags_LEFT     ) port map  (clk1x, gb_bus, reg_wired_or( 6), reg_wired_done( 6), Sound_1_Enable_Flags_LEFT     , Sound_1_Enable_Flags_LEFT     );  
   iSound_2_Enable_Flags_LEFT     : entity work.eProcReg_gba generic map ( SOUNDCNT_L_Sound_2_Enable_Flags_LEFT     ) port map  (clk1x, gb_bus, reg_wired_or( 7), reg_wired_done( 7), Sound_2_Enable_Flags_LEFT     , Sound_2_Enable_Flags_LEFT     );  
   iSound_3_Enable_Flags_LEFT     : entity work.eProcReg_gba generic map ( SOUNDCNT_L_Sound_3_Enable_Flags_LEFT     ) port map  (clk1x, gb_bus, reg_wired_or( 8), reg_wired_done( 8), Sound_3_Enable_Flags_LEFT     , Sound_3_Enable_Flags_LEFT     );  
   iSound_4_Enable_Flags_LEFT     : entity work.eProcReg_gba generic map ( SOUNDCNT_L_Sound_4_Enable_Flags_LEFT     ) port map  (clk1x, gb_bus, reg_wired_or( 9), reg_wired_done( 9), Sound_4_Enable_Flags_LEFT     , Sound_4_Enable_Flags_LEFT     );  
                                                                                                                                                                                                          
   iSound_1_4_Volume              : entity work.eProcReg_gba generic map ( SOUNDCNT_H_Sound_1_4_Volume              ) port map  (clk1x, gb_bus, reg_wired_or(10), reg_wired_done(10), Sound_1_4_Volume              , Sound_1_4_Volume              );  
   iDMA_Sound_A_Volume            : entity work.eProcReg_gba generic map ( SOUNDCNT_H_DMA_Sound_A_Volume            ) port map  (clk1x, gb_bus, reg_wired_or(11), reg_wired_done(11), DMA_Sound_A_Volume            , DMA_Sound_A_Volume            );  
   iDMA_Sound_B_Volume            : entity work.eProcReg_gba generic map ( SOUNDCNT_H_DMA_Sound_B_Volume            ) port map  (clk1x, gb_bus, reg_wired_or(12), reg_wired_done(12), DMA_Sound_B_Volume            , DMA_Sound_B_Volume            );  
   iDMA_Sound_A_Enable_RIGHT      : entity work.eProcReg_gba generic map ( SOUNDCNT_H_DMA_Sound_A_Enable_RIGHT      ) port map  (clk1x, gb_bus, reg_wired_or(13), reg_wired_done(13), DMA_Sound_A_Enable_RIGHT      , DMA_Sound_A_Enable_RIGHT      , SOUNDCNT_H_DMA_written);  
   iDMA_Sound_A_Enable_LEFT       : entity work.eProcReg_gba generic map ( SOUNDCNT_H_DMA_Sound_A_Enable_LEFT       ) port map  (clk1x, gb_bus, reg_wired_or(14), reg_wired_done(14), DMA_Sound_A_Enable_LEFT       , DMA_Sound_A_Enable_LEFT       );  
   iDMA_Sound_A_Timer_Select      : entity work.eProcReg_gba generic map ( SOUNDCNT_H_DMA_Sound_A_Timer_Select      ) port map  (clk1x, gb_bus, reg_wired_or(15), reg_wired_done(15), DMA_Sound_A_Timer_Select      , DMA_Sound_A_Timer_Select      );  
   iDMA_Sound_A_Reset_FIFO        : entity work.eProcReg_gba generic map ( SOUNDCNT_H_DMA_Sound_A_Reset_FIFO        ) port map  (clk1x, gb_bus, reg_wired_or(16), reg_wired_done(16), "0"                           , DMA_Sound_A_Reset_FIFO        );  
   iDMA_Sound_B_Enable_RIGHT      : entity work.eProcReg_gba generic map ( SOUNDCNT_H_DMA_Sound_B_Enable_RIGHT      ) port map  (clk1x, gb_bus, reg_wired_or(17), reg_wired_done(17), DMA_Sound_B_Enable_RIGHT      , DMA_Sound_B_Enable_RIGHT      );  
   iDMA_Sound_B_Enable_LEFT       : entity work.eProcReg_gba generic map ( SOUNDCNT_H_DMA_Sound_B_Enable_LEFT       ) port map  (clk1x, gb_bus, reg_wired_or(18), reg_wired_done(18), DMA_Sound_B_Enable_LEFT       , DMA_Sound_B_Enable_LEFT       );  
   iDMA_Sound_B_Timer_Select      : entity work.eProcReg_gba generic map ( SOUNDCNT_H_DMA_Sound_B_Timer_Select      ) port map  (clk1x, gb_bus, reg_wired_or(19), reg_wired_done(19), DMA_Sound_B_Timer_Select      , DMA_Sound_B_Timer_Select      );  
   iDMA_Sound_B_Reset_FIFO        : entity work.eProcReg_gba generic map ( SOUNDCNT_H_DMA_Sound_B_Reset_FIFO        ) port map  (clk1x, gb_bus, reg_wired_or(20), reg_wired_done(20), "0"                           , DMA_Sound_B_Reset_FIFO        );  
                                                                                                                                                                                                          
   iSound_1_ON_flag               : entity work.eProcReg_gba generic map ( SOUNDCNT_X_Sound_1_ON_flag               ) port map  (clk1x, gb_bus, reg_wired_or(21), reg_wired_done(21), Sound_1_ON_flag);  
   iSound_2_ON_flag               : entity work.eProcReg_gba generic map ( SOUNDCNT_X_Sound_2_ON_flag               ) port map  (clk1x, gb_bus, reg_wired_or(22), reg_wired_done(22), Sound_2_ON_flag);  
   iSound_3_ON_flag               : entity work.eProcReg_gba generic map ( SOUNDCNT_X_Sound_3_ON_flag               ) port map  (clk1x, gb_bus, reg_wired_or(23), reg_wired_done(23), Sound_3_ON_flag);  
   iSound_4_ON_flag               : entity work.eProcReg_gba generic map ( SOUNDCNT_X_Sound_4_ON_flag               ) port map  (clk1x, gb_bus, reg_wired_or(24), reg_wired_done(24), Sound_4_ON_flag);  
   iPSG_FIFO_Master_Enable        : entity work.eProcReg_gba generic map ( SOUNDCNT_X_PSG_FIFO_Master_Enable        ) port map  (clk1x, gb_bus, reg_wired_or(25), reg_wired_done(25), PSG_FIFO_Master_Enable        , PSG_FIFO_Master_Enable        );  
                                                                                                                                                                                 
   iREG_SOUNDBIAS                 : entity work.eProcReg_gba generic map ( SOUNDBIAS                                ) port map  (clk1x, gb_bus, reg_wired_or(26), reg_wired_done(26), REG_SOUNDBIAS                 , REG_SOUNDBIAS                 );  
                                                                                                                                                                                 
   iSOUNDCNT_XHighZero            : entity work.eProcReg_gba generic map ( SOUNDCNT_XHighZero                       ) port map  (clk1x, gb_bus, reg_wired_or(27), reg_wired_done(27), x"0000");  
   iSOUNDBIAS_HighZero            : entity work.eProcReg_gba generic map ( SOUNDBIAS_HighZero                       ) port map  (clk1x, gb_bus, reg_wired_or(28), reg_wired_done(28), x"0000");  

   
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

   Sound_1_ON_flag(Sound_1_ON_flag'right) <= '1' when sound_on_ch1 = '1' and (Sound_1_Enable_Flags_LEFT = "1" or Sound_1_Enable_Flags_RIGHT = "1") else '0';
   Sound_2_ON_flag(Sound_2_ON_flag'right) <= '1' when sound_on_ch2 = '1' and (Sound_2_Enable_Flags_LEFT = "1" or Sound_2_Enable_Flags_RIGHT = "1") else '0';
   Sound_3_ON_flag(Sound_3_ON_flag'right) <= '1' when sound_on_ch3 = '1' and (Sound_3_Enable_Flags_LEFT = "1" or Sound_3_Enable_Flags_RIGHT = "1") else '0';
   Sound_4_ON_flag(Sound_4_ON_flag'right) <= '1' when sound_on_ch4 = '1' and (Sound_4_Enable_Flags_LEFT = "1" or Sound_4_Enable_Flags_RIGHT = "1") else '0';
    
   -- save state
   iSAVESTATE_SOUNDON : entity work.eProcReg_gba generic map (REG_SAVESTATE_SOUNDON) port map (clk1x, savestate_bus, save_wired_or(0), save_wired_done(0), SAVESTATE_SOUNDON_back, SAVESTATE_SOUNDON);

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

   SAVESTATE_SOUNDON_back(0) <= sound_on_ch1;
   SAVESTATE_SOUNDON_back(1) <= sound_on_ch2;
   SAVESTATE_SOUNDON_back(2) <= sound_on_ch3;
   SAVESTATE_SOUNDON_back(3) <= sound_on_ch4;

    
   igba_sound_ch1 : entity work.gba_sound_ch1
   generic map
   (
      has_sweep                      => true,
      Reg_Number_of_sweep_shift      => SOUND1CNT_L_Number_of_sweep_shift    ,
      Reg_Sweep_Frequency_Direction  => SOUND1CNT_L_Sweep_Frequency_Direction,
      Reg_Sweep_Time                 => SOUND1CNT_L_Sweep_Time               ,
      Reg_Sound_length               => SOUND1CNT_H_Sound_length              ,
      Reg_Wave_Pattern_Duty          => SOUND1CNT_H_Wave_Pattern_Duty         ,
      Reg_Envelope_Step_Time         => SOUND1CNT_H_Envelope_Step_Time        ,
      Reg_Envelope_Direction         => SOUND1CNT_H_Envelope_Direction        ,
      Reg_Initial_Volume_of_envelope => SOUND1CNT_H_Initial_Volume_of_envelope,
      Reg_Frequency                  => SOUND1CNT_X_Frequency  ,
      Reg_Length_Flag                => SOUND1CNT_X_Length_Flag,
      Reg_Initial                    => SOUND1CNT_X_Initial    ,
      Reg_HighZero                   => SOUND1CNT_XHighZero
   )
   port map
   (
      clk1x             => clk1x, 
      reset             => reset, 
      gb_on             => gbsound_on,   
      ch_on_ss          => SAVESTATE_SOUNDON(0),   
      loading_savestate => loading_savestate,      
      gb_bus            => gb_bus,           
      wired_out         => reg_wired_or(29),
      wired_done        => reg_wired_done(29),
      new_cycles_valid  => new_cycles_valid,
      sound_out         => sound_out_ch1,
      sound_on          => sound_on_ch1 
   );
   
   igba_sound_ch2 : entity work.gba_sound_ch1
   generic map
   (
      has_sweep                      => false,
      Reg_Number_of_sweep_shift      => SOUND1CNT_L_Number_of_sweep_shift    ,  -- unused
      Reg_Sweep_Frequency_Direction  => SOUND1CNT_L_Sweep_Frequency_Direction,  -- unused
      Reg_Sweep_Time                 => SOUND1CNT_L_Sweep_Time               ,  -- unused
      Reg_Sound_length               => SOUND2CNT_L_Sound_length              ,
      Reg_Wave_Pattern_Duty          => SOUND2CNT_L_Wave_Pattern_Duty         ,
      Reg_Envelope_Step_Time         => SOUND2CNT_L_Envelope_Step_Time        ,
      Reg_Envelope_Direction         => SOUND2CNT_L_Envelope_Direction        ,
      Reg_Initial_Volume_of_envelope => SOUND2CNT_L_Initial_Volume_of_envelope,
      Reg_Frequency                  => SOUND2CNT_H_Frequency  ,
      Reg_Length_Flag                => SOUND2CNT_H_Length_Flag,
      Reg_Initial                    => SOUND2CNT_H_Initial    ,
      Reg_HighZero                   => SOUND2CNT_HHighZero
   )
   port map
   (
      clk1x             => clk1x, 
      reset             => reset, 
      gb_on             => gbsound_on,    
      ch_on_ss          => SAVESTATE_SOUNDON(1),
      loading_savestate => loading_savestate,
      gb_bus            => gb_bus,           
      wired_out         => reg_wired_or(30),
      wired_done        => reg_wired_done(30),        
      new_cycles_valid  => new_cycles_valid,
      sound_out         => sound_out_ch2,
      sound_on          => sound_on_ch2 
   );
   
   igba_sound_ch3 : entity work.gba_sound_ch3
   port map
   (
      clk1x             => clk1x,  
      reset             => reset,       
      gb_on             => gbsound_on, 
      ch_on_ss          => SAVESTATE_SOUNDON(2),   
      loading_savestate => loading_savestate,      
      gb_bus            => gb_bus,           
      wired_out         => reg_wired_or(31),
      wired_done        => reg_wired_done(31),         
      new_cycles_valid  => new_cycles_valid,
      sound_out         => sound_out_ch3,
      sound_on          => sound_on_ch3 
   );
   
   igba_sound_ch4 : entity work.gba_sound_ch4
   port map
   (
      clk1x             => clk1x,  
      reset             => reset, 
      gb_on             => gbsound_on, 
      ch_on_ss          => SAVESTATE_SOUNDON(3),     
      loading_savestate => loading_savestate,      
      gb_bus            => gb_bus,           
      wired_out         => reg_wired_or(32),
      wired_done        => reg_wired_done(32),            
      new_cycles_valid  => new_cycles_valid,
      sound_out         => sound_out_ch4,
      sound_on          => sound_on_ch4 
   );
   
   igba_sound_dmaA : entity work.gba_sound_dma
   generic map
   (
      REG_FIFO                => FIFO_A,
      REG_SAVESTATE_DMASOUND  => REG_SAVESTATE_DMASOUNDA
   )
   port map
   (
      clk1x               => clk1x,
      ce                  => ce,
      reset               => reset, 
      
      savestate_bus       => savestate_bus,
      ss_wired_out        => save_wired_or(1),
      ss_wired_done       => save_wired_done(1),
      loading_savestate   => loading_savestate,
      
      gb_bus              => gb_bus,           
      wired_out           => reg_wired_or(33),
      wired_done          => reg_wired_done(33),
                           
      settings_new        => SOUNDCNT_H_DMA_written,
      Enable_RIGHT        => DMA_Sound_A_Enable_RIGHT(DMA_Sound_A_Enable_RIGHT'left),
      Enable_LEFT         => DMA_Sound_A_Enable_LEFT(DMA_Sound_A_Enable_LEFT'left), 
      Timer_Select        => DMA_Sound_A_Timer_Select(DMA_Sound_A_Timer_Select'left),
      Reset_FIFO          => DMA_Sound_A_Reset_FIFO(DMA_Sound_A_Reset_FIFO'left),  
      volume_high         => DMA_Sound_A_Volume(DMA_Sound_A_Volume'left),  
      
      timer0_tick         => timer0_tick,
      timer1_tick         => timer1_tick,
      dma_req             => sound_dma_req(0),
                           
      sound_out_left      => sound_out_dmaA_l,
      sound_out_right     => sound_out_dmaA_r,
      sound_on            => sound_on_dmaA,
      
      new_sample_out      => open,
      
      debug_fifocount     => debug_fifocount(7 downto 0)
   );
   
   igba_sound_dmaB : entity work.gba_sound_dma
   generic map
   (
      REG_FIFO                => FIFO_B,
      REG_SAVESTATE_DMASOUND  => REG_SAVESTATE_DMASOUNDB
   )
   port map
   (
      clk1x               => clk1x,
      ce                  => ce,
      reset               => reset, 
      
      savestate_bus       => savestate_bus,
      ss_wired_out        => save_wired_or(2),
      ss_wired_done       => save_wired_done(2),
      loading_savestate   => loading_savestate,
      
      gb_bus              => gb_bus,           
      wired_out           => reg_wired_or(34),
      wired_done          => reg_wired_done(34),
                           
      settings_new        => SOUNDCNT_H_DMA_written,
      Enable_RIGHT        => DMA_Sound_B_Enable_RIGHT(DMA_Sound_B_Enable_RIGHT'left),
      Enable_LEFT         => DMA_Sound_B_Enable_LEFT(DMA_Sound_B_Enable_LEFT'left), 
      Timer_Select        => DMA_Sound_B_Timer_Select(DMA_Sound_B_Timer_Select'left),
      Reset_FIFO          => DMA_Sound_B_Reset_FIFO(DMA_Sound_B_Reset_FIFO'left),  
      volume_high         => DMA_Sound_B_Volume(DMA_Sound_B_Volume'left),
                           
      timer0_tick         => timer0_tick,
      timer1_tick         => timer1_tick,
      dma_req             => sound_dma_req(1),
                           
      sound_out_left      => sound_out_dmaB_l,
      sound_out_right     => sound_out_dmaB_r,
      sound_on            => sound_on_dmaB,
      
      new_sample_out      => open, 
      
      debug_fifocount     => debug_fifocount(15 downto 8)
   );
   
   process (clk1x)
   begin
      if rising_edge(clk1x) then
        
         -- PSG_FIFO_Master_Enable should usually also reset all sound registers
         gbsound_on <= ce and PSG_FIFO_Master_Enable(PSG_FIFO_Master_Enable'left);
        
         new_cycles_valid <= '0';
                
         -- channels 1-4 are from GB, they still work with 4 MHZ, so clock is divided by 4 here.
         if (ce = '1') then
            if (bus_cycles_sum < 3) then
               bus_cycles_sum <= bus_cycles_sum + 1;
            else
               new_cycles_valid <= '1';
               bus_cycles_sum   <= (others => '0');
            end if;
         end if;
         
         -- sound channel mixing
         
         -- channel 1
         if (sound_on_ch1 = '1' and Sound_1_Enable_Flags_LEFT = "1") then
            soundmix1_l <= sound_out_ch1;
         else
            soundmix1_l <= (others => '0');
         end if;
         if (sound_on_ch1 = '1' and Sound_1_Enable_Flags_RIGHT = "1") then
            soundmix1_r <= sound_out_ch1;
         else
            soundmix1_r <= (others => '0');
         end if;
         
         -- channel 2
         if (sound_on_ch2 = '1' and Sound_2_Enable_Flags_LEFT = "1") then
            soundmix2_l <= soundmix1_l + sound_out_ch2;
         else
            soundmix2_l <= soundmix1_l;
         end if;
         if (sound_on_ch2 = '1' and Sound_2_Enable_Flags_RIGHT = "1") then
            soundmix2_r <= soundmix1_r + sound_out_ch2;
         else
            soundmix2_r <= soundmix1_r;
         end if;
         
         -- channel 3
         if (sound_on_ch3 = '1' and Sound_3_Enable_Flags_LEFT = "1") then
            soundmix3_l <= soundmix2_l + sound_out_ch3;
         else
            soundmix3_l <= soundmix2_l;
         end if;
         if (sound_on_ch3 = '1' and Sound_3_Enable_Flags_RIGHT = "1") then
            soundmix3_r <= soundmix2_r + sound_out_ch3;
         else
            soundmix3_r <= soundmix2_r;
         end if;
         
         -- channel 4
         if (sound_on_ch4 = '1' and Sound_4_Enable_Flags_LEFT = "1") then
            soundmix4_l <= soundmix3_l + sound_out_ch4;
         else
            soundmix4_l <= soundmix3_l;
         end if;
         if (sound_on_ch4 = '1' and Sound_4_Enable_Flags_RIGHT = "1") then
            soundmix4_r <= soundmix3_r + sound_out_ch4;
         else
            soundmix4_r <= soundmix3_r;
         end if;
         
         -- sound1-4 volume control
         soundmix14_l <= resize(soundmix4_l * to_integer(unsigned(Sound_1_4_Master_Volume_LEFT)), 16);
         soundmix14_r <= resize(soundmix4_r * to_integer(unsigned(Sound_1_4_Master_Volume_RIGHT)), 16);
         
         case (to_integer(unsigned(Sound_1_4_Volume))) is
             when 0     => soundmix5_l <= soundmix14_l / 4;   soundmix5_r <= soundmix14_r / 4;
             when 1     => soundmix5_l <= soundmix14_l / 2;   soundmix5_r <= soundmix14_r / 2;
             when 2     => soundmix5_l <= soundmix14_l;       soundmix5_r <= soundmix14_r;
             when 3     => soundmix5_l <= (others => '0');    soundmix5_r <= (others => '0');  -- 3 is not allowed
             when others => null;
         end case;

         -- mix in dma sound
         if (sound_on_dmaA = '1') then
            soundmix6_l <= soundmix5_l - sound_out_dmaA_l;
            soundmix6_r <= soundmix5_r - sound_out_dmaA_r;
         else
            soundmix6_l <= soundmix5_l;
            soundmix6_r <= soundmix5_r;
         end if;
         
         if (sound_on_dmaB = '1') then
            soundmix7_l <= soundmix6_l - sound_out_dmaB_l;
            soundmix7_r <= soundmix6_r - sound_out_dmaB_r;
         else
            soundmix7_l <= soundmix6_l;
            soundmix7_r <= soundmix6_r;
         end if;
         
         -- skip sound bias and clip on signed instead
         soundmix8_l <= soundmix7_l; -- + to_integer(unsigned(REG_SOUNDBIAS));
         soundmix8_r <= soundmix7_r; -- + to_integer(unsigned(REG_SOUNDBIAS));
      
      end if;
   end process;
   
   sound_out_left  <= std_logic_vector(resize(soundmix8_l * 16, 16)) when PSG_FIFO_Master_Enable = "1" and lockspeed = '1' else 
                      std_logic_vector(resize(soundmix8_l * 4, 16)) when PSG_FIFO_Master_Enable = "1" and lockspeed = '0' else 
                      (others => '0');
   sound_out_right <= std_logic_vector(resize(soundmix8_r * 16, 16)) when PSG_FIFO_Master_Enable = "1" and lockspeed = '1' else 
                      std_logic_vector(resize(soundmix8_r * 4, 16)) when PSG_FIFO_Master_Enable = "1" and lockspeed = '0' else 
                      (others => '0');
   
    
end architecture;


 
 