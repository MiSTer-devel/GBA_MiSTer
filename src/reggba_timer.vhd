library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

use work.pProc_bus_gba.all;
use work.pRegmap_gba.all;

package pReg_gba_timer is

   -- range 0x100 -  0x110
   --   (                              adr      upper    lower    size   default   accesstype)                                     
   constant TM0CNT_L                   : regmap_type := (16#100#,  15,      0,        1,        0,   readwrite); -- Timer 0 Counter/Reload  2    R/W
   constant TM0CNT_H                   : regmap_type := (16#100#,  31,     16,        1,        0,   readwrite); -- Timer 0 Control         2    R/W
   constant TM0CNT_H_Prescaler         : regmap_type := (16#100#,  17,     16,        1,        0,   readwrite); -- Prescaler Selection (0=F/1, 1=F/64, 2=F/256, 3=F/1024)
   constant TM0CNT_H_Count_up          : regmap_type := (16#100#,  18,     18,        1,        0,   readwrite); -- Count-up Timing   (0=Normal, 1=See below)
   constant TM0CNT_H_Timer_IRQ_Enable  : regmap_type := (16#100#,  22,     22,        1,        0,   readwrite); -- Timer IRQ Enable  (0=Disable, 1=IRQ on Timer overflow)
   constant TM0CNT_H_Timer_Start_Stop  : regmap_type := (16#100#,  23,     23,        1,        0,   readwrite); -- Timer Start/Stop  (0=Stop, 1=Operate)
   
   constant TM1CNT_L                   : regmap_type := (16#104#,  15,      0,        1,        0,   readwrite); -- Timer 1 Counter/Reload  2    R/W
   constant TM1CNT_H                   : regmap_type := (16#104#,  31,     16,        1,        0,   readwrite); -- Timer 1 Control         2    R/W
   constant TM1CNT_H_Prescaler         : regmap_type := (16#104#,  17,     16,        1,        0,   readwrite); -- Prescaler Selection (0=F/1, 1=F/64, 2=F/256, 3=F/1024)
   constant TM1CNT_H_Count_up          : regmap_type := (16#104#,  18,     18,        1,        0,   readwrite); -- Count-up Timing   (0=Normal, 1=See below)
   constant TM1CNT_H_Timer_IRQ_Enable  : regmap_type := (16#104#,  22,     22,        1,        0,   readwrite); -- Timer IRQ Enable  (0=Disable, 1=IRQ on Timer overflow)
   constant TM1CNT_H_Timer_Start_Stop  : regmap_type := (16#104#,  23,     23,        1,        0,   readwrite); -- Timer Start/Stop  (0=Stop, 1=Operate)
   
   constant TM2CNT_L                   : regmap_type := (16#108#,  15,      0,        1,        0,   readwrite); -- Timer 2 Counter/Reload  2    R/W
   constant TM2CNT_H                   : regmap_type := (16#108#,  31,     16,        1,        0,   readwrite); -- Timer 2 Control         2    R/W
   constant TM2CNT_H_Prescaler         : regmap_type := (16#108#,  17,     16,        1,        0,   readwrite); -- Prescaler Selection (0=F/1, 1=F/64, 2=F/256, 3=F/1024)
   constant TM2CNT_H_Count_up          : regmap_type := (16#108#,  18,     18,        1,        0,   readwrite); -- Count-up Timing   (0=Normal, 1=See below)
   constant TM2CNT_H_Timer_IRQ_Enable  : regmap_type := (16#108#,  22,     22,        1,        0,   readwrite); -- Timer IRQ Enable  (0=Disable, 1=IRQ on Timer overflow)
   constant TM2CNT_H_Timer_Start_Stop  : regmap_type := (16#108#,  23,     23,        1,        0,   readwrite); -- Timer Start/Stop  (0=Stop, 1=Operate)
   
   constant TM3CNT_L                   : regmap_type := (16#10C#,  15,      0,        1,        0,   readwrite); -- Timer 3 Counter/Reload  2    R/W
   constant TM3CNT_H                   : regmap_type := (16#10C#,  31,     16,        1,        0,   readwrite); -- Timer 3 Control         2    R/W
   constant TM3CNT_H_Prescaler         : regmap_type := (16#10C#,  17,     16,        1,        0,   readwrite); -- Prescaler Selection (0=F/1, 1=F/64, 2=F/256, 3=F/1024)
   constant TM3CNT_H_Count_up          : regmap_type := (16#10C#,  18,     18,        1,        0,   readwrite); -- Count-up Timing   (0=Normal, 1=See below)
   constant TM3CNT_H_Timer_IRQ_Enable  : regmap_type := (16#10C#,  22,     22,        1,        0,   readwrite); -- Timer IRQ Enable  (0=Disable, 1=IRQ on Timer overflow)
   constant TM3CNT_H_Timer_Start_Stop  : regmap_type := (16#10C#,  23,     23,        1,        0,   readwrite); -- Timer Start/Stop  (0=Stop, 1=Operate)
   
end package;
