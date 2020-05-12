library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

use work.pProc_bus_gba.all;
use work.pRegmap_gba.all;

package pReg_gba_sound is

   -- range 0x60 .. 0xA8
   --   (                                                              adr      upper    lower    size   default   accesstype)                                     
   constant SOUND1CNT_L                              : regmap_type := (16#060#,   6,      0,        1,        0,   readwrite); -- Channel 1 Sweep register       (NR10)   
   constant SOUND1CNT_L_Number_of_sweep_shift        : regmap_type := (16#060#,   2,      0,        1,        0,   readwrite); -- 0-2   R/W  (n=0-7)
   constant SOUND1CNT_L_Sweep_Frequency_Direction    : regmap_type := (16#060#,   3,      3,        1,        0,   readwrite); -- 3     R/W  (0=Increase, 1=Decrease)
   constant SOUND1CNT_L_Sweep_Time                   : regmap_type := (16#060#,   6,      4,        1,        0,   readwrite); -- 4-6   R/W  units of 7.8ms (0-7, min=7.8ms, max=54.7ms)
                                                     
   constant SOUND1CNT_H                              : regmap_type := (16#060#,  31,     16,        1,        0,   writeonly); -- Channel 1 Duty/Length/Envelope (NR11, NR12)  
   constant SOUND1CNT_H_Sound_length                 : regmap_type := (16#060#,  21,     16,        1,        0,   writeonly); -- 0-5   W    units of (64-n)/256s  (0-63)
   constant SOUND1CNT_H_Wave_Pattern_Duty            : regmap_type := (16#060#,  23,     22,        1,        0,   readwrite); -- 6-7   R/W  (0-3, see below)
   constant SOUND1CNT_H_Envelope_Step_Time           : regmap_type := (16#060#,  26,     24,        1,        0,   readwrite); -- 8-10  R/W  units of n/64s  (1-7, 0=No Envelope)
   constant SOUND1CNT_H_Envelope_Direction           : regmap_type := (16#060#,  27,     27,        1,        0,   readwrite); -- 11    R/W  (0=Decrease, 1=Increase)
   constant SOUND1CNT_H_Initial_Volume_of_envelope   : regmap_type := (16#060#,  31,     28,        1,        0,   readwrite); -- 12-15 R/W  (1-15, 0=No Sound)
                                                     
   constant SOUND1CNT_X                              : regmap_type := (16#064#,  15,      0,        1,        0,   writeonly); -- Channel 1 Frequency/Control    (NR13, NR14)  
   constant SOUND1CNT_X_Frequency                    : regmap_type := (16#064#,  10,      0,        1,        0,   writeDone); -- 0-10  W    131072/(2048-n)Hz  (0-2047)  
   constant SOUND1CNT_X_Length_Flag                  : regmap_type := (16#064#,  14,     14,        1,        0,   readwrite); -- 14    R/W  (1=Stop output when length in NR11 expires)  
   constant SOUND1CNT_X_Initial                      : regmap_type := (16#064#,  15,     15,        1,        0,   writeonly); -- 15    W    (1=Restart Sound)                        
                        
   constant SOUND1CNT_XHighZero                      : regmap_type := (16#064#,  31,     16,        1,        0,   readonly);  -- must return zero                                
                        
   constant SOUND2CNT_L                              : regmap_type := (16#068#,  15,      0,        1,        0,   writeonly); -- Channel 2 Duty/Length/Envelope (NR21, NR22) 
   constant SOUND2CNT_L_Sound_length                 : regmap_type := (16#068#,   5,      0,        1,        0,   writeDone); -- 0-5   W    units of (64-n)/256s  (0-63)
   constant SOUND2CNT_L_Wave_Pattern_Duty            : regmap_type := (16#068#,   7,      6,        1,        0,   readwrite); -- 6-7   R/W  (0-3, see below)
   constant SOUND2CNT_L_Envelope_Step_Time           : regmap_type := (16#068#,  10,      8,        1,        0,   readwrite); -- 8-10  R/W  units of n/64s  (1-7, 0=No Envelope)
   constant SOUND2CNT_L_Envelope_Direction           : regmap_type := (16#068#,  11,     11,        1,        0,   readwrite); -- 11    R/W  (0=Decrease, 1=Increase)
   constant SOUND2CNT_L_Initial_Volume_of_envelope   : regmap_type := (16#068#,  15,     12,        1,        0,   readwrite); -- 12-15 R/W  (1-15, 0=No Sound)
                                                     
   constant SOUND2CNT_H                              : regmap_type := (16#06C#,  15,      0,        1,        0,   writeonly); -- Channel 2 Frequency/Control    (NR23, NR24)
   constant SOUND2CNT_H_Frequency                    : regmap_type := (16#06C#,  10,      0,        1,        0,   writeDone); -- 0-10  W    131072/(2048-n)Hz  (0-2047)  
   constant SOUND2CNT_H_Length_Flag                  : regmap_type := (16#06C#,  14,     14,        1,        0,   readwrite); -- 14    R/W  (1=Stop output when length in NR11 expires)  
   constant SOUND2CNT_H_Initial                      : regmap_type := (16#06C#,  15,     15,        1,        0,   writeonly); -- 15    W    (1=Restart Sound)                        
    
   constant SOUND2CNT_HHighZero                      : regmap_type := (16#06C#,  31,     16,        1,        0,   readonly);  -- must return zero                                
    
   constant SOUND3CNT_L                              : regmap_type := (16#070#,  15,      0,        1,        0,   writeonly); -- Channel 3 Stop/Wave RAM select (NR30)  
   constant SOUND3CNT_L_Wave_RAM_Dimension           : regmap_type := (16#070#,   5,      5,        1,        0,   readwrite); -- 5     R/W   (0=One bank/32 digits, 1=Two banks/64 digits)
   constant SOUND3CNT_L_Wave_RAM_Bank_Number         : regmap_type := (16#070#,   6,      6,        1,        0,   readwrite); -- 6     R/W   (0-1, see below)
   constant SOUND3CNT_L_Sound_Channel_3_Off          : regmap_type := (16#070#,   7,      7,        1,        0,   readwrite); -- 7     R/W   (0=Stop, 1=Playback)  
                                                     
   constant SOUND3CNT_H                              : regmap_type := (16#070#,  31,     16,        1,        0,   writeonly); -- Channel 3 Length/Volume        (NR31, NR32)  
   constant SOUND3CNT_H_Sound_length                 : regmap_type := (16#070#,  23,     16,        1,        0,   writeonly); -- 0-7   W   units of (256-n)/256s  (0-255)
   constant SOUND3CNT_H_Sound_Volume                 : regmap_type := (16#070#,  30,     29,        1,        0,   readwrite); -- 13-14 R/W (0=Mute/Zero, 1=100%, 2=50%, 3=25%)
   constant SOUND3CNT_H_Force_Volume                 : regmap_type := (16#070#,  31,     31,        1,        0,   readwrite); -- 15    R/W (0=Use above, 1=Force 75% regardless of above)
                                                     
   constant SOUND3CNT_X                              : regmap_type := (16#074#,  15,      0,        1,        0,   writeonly); -- Channel 3 Frequency/Control    (NR33, NR34)  
   constant SOUND3CNT_X_Sample_Rate                  : regmap_type := (16#074#,  10,      0,        1,        0,   writeDone); -- 0-10  W   2097152/(2048-n) Hz   (0-2047)
   constant SOUND3CNT_X_Length_Flag                  : regmap_type := (16#074#,  14,     14,        1,        0,   readwrite); -- 14    R/W (1=Stop output when length in NR31 expires)
   constant SOUND3CNT_X_Initial                      : regmap_type := (16#074#,  15,     15,        1,        0,   writeonly); -- 15    W   (1=Restart Sound)

   constant SOUND3CNT_XHighZero                      : regmap_type := (16#074#,  31,     16,        1,        0,   readonly);  -- must return zero                                 
     
   constant SOUND4CNT_L                              : regmap_type := (16#078#,  15,      0,        1,        0,   writeonly); -- Channel 4 Length/Envelope      (NR41, NR42)  
   constant SOUND4CNT_L_Sound_length                 : regmap_type := (16#078#,   5,      0,        1,        0,   writeDone); -- 0-5   W    units of (64-n)/256s  (0-63)
   constant SOUND4CNT_L_Envelope_Step_Time           : regmap_type := (16#078#,  10,      8,        1,        0,   readwrite); -- 8-10  R/W  units of n/64s  (1-7, 0=No Envelope)
   constant SOUND4CNT_L_Envelope_Direction           : regmap_type := (16#078#,  11,     11,        1,        0,   readwrite); -- 11    R/W  (0=Decrease, 1=Increase)
   constant SOUND4CNT_L_Initial_Volume_of_envelope   : regmap_type := (16#078#,  15,     12,        1,        0,   readwrite); -- 12-15 R/W  (1-15, 0=No Sound)
    
   constant SOUND4CNT_LHighZero                      : regmap_type := (16#078#,  31,     16,        1,        0,   readonly);  -- must return zero                                 
                                                 
   constant SOUND4CNT_H                              : regmap_type := (16#07C#,  15,      0,        1,        0,   writeonly); -- Channel 4 Frequency/Control    (NR43, NR44)  
   constant SOUND4CNT_H_Dividing_Ratio_of_Freq       : regmap_type := (16#07C#,   2,      0,        1,        0,   readwrite); -- 0-2   R/W   (r)     524288 Hz / r / 2^(s+1) ;For r=0 assume r=0.5 instead
   constant SOUND4CNT_H_Counter_Step_Width           : regmap_type := (16#07C#,   3,      3,        1,        0,   readwrite); -- 3     R/W   (0=15 bits, 1=7 bits)
   constant SOUND4CNT_H_Shift_Clock_Frequency        : regmap_type := (16#07C#,   7,      4,        1,        0,   readwrite); -- 4-7   R/W   (s)     524288 Hz / r / 2^(s+1) ;For r=0 assume r=0.5 instead
   constant SOUND4CNT_H_Length_Flag                  : regmap_type := (16#07C#,  14,     14,        1,        0,   readwrite); -- 14    R/W   (1=Stop output when length in NR41 expires)
   constant SOUND4CNT_H_Initial                      : regmap_type := (16#07C#,  15,     15,        1,        0,   writeonly); -- 15    W     (1=Restart Sound)

   constant SOUND4CNT_HHighZero                      : regmap_type := (16#07C#,  31,     16,        1,        0,   readonly);  -- must return zero                                  
    
   constant SOUNDCNT_L                               : regmap_type := (16#080#,  15,      0,        1,        0,   writeonly); -- Control Stereo/Volume/Enable   (NR50, NR51)  
   constant SOUNDCNT_L_Sound_1_4_Master_Volume_RIGHT : regmap_type := (16#080#,   2,      0,        1,        0,   readwrite); -- 0-2    (0-7)
   constant SOUNDCNT_L_Sound_1_4_Master_Volume_LEFT  : regmap_type := (16#080#,   6,      4,        1,        0,   readwrite); -- 4-6    (0-7)
   constant SOUNDCNT_L_Sound_1_Enable_Flags_RIGHT    : regmap_type := (16#080#,   8,      8,        1,        0,   readwrite); -- 8-11   (each Bit 8-11, 0=Disable, 1=Enable)
   constant SOUNDCNT_L_Sound_2_Enable_Flags_RIGHT    : regmap_type := (16#080#,   9,      9,        1,        0,   readwrite); -- 8-11   (each Bit 8-11, 0=Disable, 1=Enable)
   constant SOUNDCNT_L_Sound_3_Enable_Flags_RIGHT    : regmap_type := (16#080#,  10,     10,        1,        0,   readwrite); -- 8-11   (each Bit 8-11, 0=Disable, 1=Enable)
   constant SOUNDCNT_L_Sound_4_Enable_Flags_RIGHT    : regmap_type := (16#080#,  11,     11,        1,        0,   readwrite); -- 8-11   (each Bit 8-11, 0=Disable, 1=Enable)
   constant SOUNDCNT_L_Sound_1_Enable_Flags_LEFT     : regmap_type := (16#080#,  12,     12,        1,        0,   readwrite); -- 12-15  (each Bit 12-15, 0=Disable, 1=Enable)
   constant SOUNDCNT_L_Sound_2_Enable_Flags_LEFT     : regmap_type := (16#080#,  13,     13,        1,        0,   readwrite); -- 12-15  (each Bit 12-15, 0=Disable, 1=Enable)
   constant SOUNDCNT_L_Sound_3_Enable_Flags_LEFT     : regmap_type := (16#080#,  14,     14,        1,        0,   readwrite); -- 12-15  (each Bit 12-15, 0=Disable, 1=Enable)
   constant SOUNDCNT_L_Sound_4_Enable_Flags_LEFT     : regmap_type := (16#080#,  15,     15,        1,        0,   readwrite); -- 12-15  (each Bit 12-15, 0=Disable, 1=Enable)
                                                                 
   constant SOUNDCNT_H                               : regmap_type := (16#080#,  31,     16,        1,        0,   readwrite); -- Control Mixing/DMA Control  
   constant SOUNDCNT_H_Sound_1_4_Volume              : regmap_type := (16#080#,  17,     16,        1,        0,   readwrite); -- 0-1   Sound # 1-4 Volume   (0=25%, 1=50%, 2=100%, 3=Prohibited)  
   constant SOUNDCNT_H_DMA_Sound_A_Volume            : regmap_type := (16#080#,  18,     18,        1,        0,   readwrite); -- 2     DMA Sound A Volume   (0=50%, 1=100%)  
   constant SOUNDCNT_H_DMA_Sound_B_Volume            : regmap_type := (16#080#,  19,     19,        1,        0,   readwrite); -- 3     DMA Sound B Volume   (0=50%, 1=100%)  
   constant SOUNDCNT_H_DMA_Sound_A_Enable_RIGHT      : regmap_type := (16#080#,  24,     24,        1,        0,   readwrite); -- 8     DMA Sound A Enable RIGHT (0=Disable, 1=Enable)  
   constant SOUNDCNT_H_DMA_Sound_A_Enable_LEFT       : regmap_type := (16#080#,  25,     25,        1,        0,   readwrite); -- 9     DMA Sound A Enable LEFT  (0=Disable, 1=Enable)  
   constant SOUNDCNT_H_DMA_Sound_A_Timer_Select      : regmap_type := (16#080#,  26,     26,        1,        0,   readwrite); -- 10    DMA Sound A Timer Select (0=Timer 0, 1=Timer 1)  
   constant SOUNDCNT_H_DMA_Sound_A_Reset_FIFO        : regmap_type := (16#080#,  27,     27,        1,        0,   readwrite); -- 11    DMA Sound A Reset FIFO   (1=Reset)  
   constant SOUNDCNT_H_DMA_Sound_B_Enable_RIGHT      : regmap_type := (16#080#,  28,     28,        1,        0,   readwrite); -- 12    DMA Sound B Enable RIGHT (0=Disable, 1=Enable)  
   constant SOUNDCNT_H_DMA_Sound_B_Enable_LEFT       : regmap_type := (16#080#,  29,     29,        1,        0,   readwrite); -- 13    DMA Sound B Enable LEFT  (0=Disable, 1=Enable)  
   constant SOUNDCNT_H_DMA_Sound_B_Timer_Select      : regmap_type := (16#080#,  30,     30,        1,        0,   readwrite); -- 14    DMA Sound B Timer Select (0=Timer 0, 1=Timer 1)  
   constant SOUNDCNT_H_DMA_Sound_B_Reset_FIFO        : regmap_type := (16#080#,  31,     31,        1,        0,   readwrite); -- 15    DMA Sound B Reset FIFO   (1=Reset)  
                                                     
   constant SOUNDCNT_X                               : regmap_type := (16#084#,   7,      0,        1,        0,   readwrite); -- Control Sound on/off           (NR52)   
   constant SOUNDCNT_X_Sound_1_ON_flag               : regmap_type := (16#084#,   0,      0,        1,        0,   readonly ); -- 0 (Read Only) 
   constant SOUNDCNT_X_Sound_2_ON_flag               : regmap_type := (16#084#,   1,      1,        1,        0,   readonly ); -- 1 (Read Only) 
   constant SOUNDCNT_X_Sound_3_ON_flag               : regmap_type := (16#084#,   2,      2,        1,        0,   readonly ); -- 2 (Read Only) 
   constant SOUNDCNT_X_Sound_4_ON_flag               : regmap_type := (16#084#,   3,      3,        1,        0,   readonly ); -- 3 (Read Only) 
   constant SOUNDCNT_X_PSG_FIFO_Master_Enable        : regmap_type := (16#084#,   7,      7,        1,        0,   readwrite); -- 7 (0=Disable, 1=Enable) (Read/Write) 
   
   constant SOUNDCNT_XHighZero                       : regmap_type := (16#084#,  31,     16,        1,        0,   readonly);  -- must return zero                                  
   
   constant SOUNDBIAS                                : regmap_type := (16#088#,  15,      0,        1, 16#0200#,   readwrite); -- Sound PWM Control (R/W)
   constant SOUNDBIAS_Bias_Level                     : regmap_type := (16#088#,   9,      0,        1, 16#0200#,   readwrite); -- 0-9    (Default=200h, converting signed samples into unsigned) 
   constant SOUNDBIAS_Amp_Res_Sampling_Cycle         : regmap_type := (16#088#,  15,     14,        1,        0,   readwrite); -- 14-15  (Default=0, see below) 

   constant SOUNDBIAS_HighZero                       : regmap_type := (16#088#,  31,     16,        1,        0,   readonly);  -- must return zero                                  

   constant WAVE_RAM                                 : regmap_type := (16#090#,  31,      0,        4,        0,   readwrite); -- Channel 3 Wave Pattern RAM (2 banks!!)
   constant WAVE_RAM2                                : regmap_type := (16#094#,  31,      0,        1,        0,   readwrite); -- Channel 3 Wave Pattern RAM (2 banks!!)
   constant WAVE_RAM3                                : regmap_type := (16#098#,  31,      0,        1,        0,   readwrite); -- Channel 3 Wave Pattern RAM (2 banks!!)
   constant WAVE_RAM4                                : regmap_type := (16#09C#,  31,      0,        1,        0,   readwrite); -- Channel 3 Wave Pattern RAM (2 banks!!)

   constant FIFO_A                                   : regmap_type := (16#0A0#,  31,      0,        1,        0,   writeonly); -- Channel A FIFO, Data 0-3  
   constant FIFO_B                                   : regmap_type := (16#0A4#,  31,      0,        1,        0,   writeonly); -- Channel B FIFO, Data 0-3  

   
end package;