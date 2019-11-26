library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

use work.pProc_bus_gba.all;
use work.pRegmap_gba.all;

package pReg_gba_display is

   -- range 0x00 .. 0x56
   --   (                                                   adr      upper    lower    size   default   accesstype)                                                     
   constant DISPCNT                       : regmap_type := (16#000#,  15,      0,        1, 16#0080#,   readwrite); -- LCD Control                                   2    R/W   
   constant DISPCNT_BG_Mode               : regmap_type := (16#000#,   2,      0,        1,        0,   readwrite); -- BG Mode                     (0-5=Video Mode 0-5, 6-7=Prohibited)
   constant DISPCNT_Reserved_CGB_Mode     : regmap_type := (16#000#,   3,      3,        1,        0,   readwrite); -- Reserved / CGB Mode         (0=GBA, 1=CGB; can be set only by BIOS opcodes)
   constant DISPCNT_Display_Frame_Select  : regmap_type := (16#000#,   4,      4,        1,        0,   readwrite); -- Display Frame Select        (0-1=Frame 0-1) (for BG Modes 4,5 only)
   constant DISPCNT_H_Blank_IntervalFree  : regmap_type := (16#000#,   5,      5,        1,        0,   readwrite); -- H-Blank Interval Free       (1=Allow access to OAM during H-Blank)
   constant DISPCNT_OBJ_Char_VRAM_Map     : regmap_type := (16#000#,   6,      6,        1,        0,   readwrite); -- OBJ Character VRAM Mapping  (0=Two dimensional, 1=One dimensional)
   constant DISPCNT_Forced_Blank          : regmap_type := (16#000#,   7,      7,        1,        1,   readwrite); -- Forced Blank                (1=Allow FAST access to VRAM,Palette,OAM)
   constant DISPCNT_Screen_Display_BG0    : regmap_type := (16#000#,   8,      8,        1,        0,   readwrite); -- Screen Display BG0          (0=Off, 1=On)
   constant DISPCNT_Screen_Display_BG1    : regmap_type := (16#000#,   9,      9,        1,        0,   readwrite); -- Screen Display BG1          (0=Off, 1=On)
   constant DISPCNT_Screen_Display_BG2    : regmap_type := (16#000#,  10,     10,        1,        0,   readwrite); -- Screen Display BG2          (0=Off, 1=On)
   constant DISPCNT_Screen_Display_BG3    : regmap_type := (16#000#,  11,     11,        1,        0,   readwrite); -- Screen Display BG3          (0=Off, 1=On)
   constant DISPCNT_Screen_Display_OBJ    : regmap_type := (16#000#,  12,     12,        1,        0,   readwrite); -- Screen Display OBJ          (0=Off, 1=On)
   constant DISPCNT_Window_0_Display_Flag : regmap_type := (16#000#,  13,     13,        1,        0,   readwrite); -- Window 0 Display Flag       (0=Off, 1=On)
   constant DISPCNT_Window_1_Display_Flag : regmap_type := (16#000#,  14,     14,        1,        0,   readwrite); -- Window 1 Display Flag       (0=Off, 1=On)
   constant DISPCNT_OBJ_Wnd_Display_Flag  : regmap_type := (16#000#,  15,     15,        1,        0,   readwrite); -- OBJ Window Display Flag     (0=Off, 1=On)
   
   constant GREENSWAP                     : regmap_type := (16#000#,  31,     16,        1,        0,   readwrite); -- Undocumented - Green Swap                     2    R/W
   
   constant DISPSTAT                      : regmap_type := (16#004#,  15,      0,        1,        0,   readwrite); -- General LCD Status (STAT,LYC)                 2    R/W
   constant DISPSTAT_V_Blank_flag         : regmap_type := (16#004#,   0,      0,        1,        0,   readonly ); -- V-Blank flag   (Read only) (1=VBlank) (set in line 160..226; not 227)
   constant DISPSTAT_H_Blank_flag         : regmap_type := (16#004#,   1,      1,        1,        0,   readonly ); -- H-Blank flag   (Read only) (1=HBlank) (toggled in all lines, 0..227)
   constant DISPSTAT_V_Counter_flag       : regmap_type := (16#004#,   2,      2,        1,        0,   readonly ); -- V-Counter flag (Read only) (1=Match)  (set in selected line)     (R)
   constant DISPSTAT_V_Blank_IRQ_Enable   : regmap_type := (16#004#,   3,      3,        1,        0,   readwrite); -- V-Blank IRQ Enable         (1=Enable)                          (R/W)
   constant DISPSTAT_H_Blank_IRQ_Enable   : regmap_type := (16#004#,   4,      4,        1,        0,   readwrite); -- H-Blank IRQ Enable         (1=Enable)                          (R/W)
   constant DISPSTAT_V_Counter_IRQ_Enable : regmap_type := (16#004#,   5,      5,        1,        0,   readwrite); -- V-Counter IRQ Enable       (1=Enable)                          (R/W)
                                                                                                                    -- Not used (0) / DSi: LCD Initialization Ready (0=Busy, 1=Ready)   (R)
                                                                                                                    -- Not used (0) / NDS: MSB of V-Vcount Setting (LYC.Bit8) (0..262)(R/W)
   constant DISPSTAT_V_Count_Setting      : regmap_type := (16#004#,  15,      8,        1,        0,   readwrite); -- V-Count Setting (LYC)      (0..227)                            (R/W)

   constant VCOUNT                        : regmap_type := (16#004#,  31,     16,        1,        0,   readonly ); -- Vertical Counter (LY)                         2    R  
   
   constant BG0CNT                        : regmap_type := (16#008#,  15,      0,        1,        0,   writeonly); -- BG0 Control                                   2    R/W
   constant BG0CNT_BG_Priority            : regmap_type := (16#008#,   1,      0,        1,        0,   readwrite); -- BG Priority           (0-3, 0=Highest)
   constant BG0CNT_Character_Base_Block   : regmap_type := (16#008#,   3,      2,        1,        0,   readwrite); -- Character Base Block  (0-3, in units of 16 KBytes) (=BG Tile Data)
   constant BG0CNT_UNUSED_4_5             : regmap_type := (16#008#,   5,      4,        1,        0,   readwrite); -- 4-5   Not used (must be zero)
   constant BG0CNT_Mosaic                 : regmap_type := (16#008#,   6,      6,        1,        0,   readwrite); -- Mosaic                (0=Disable, 1=Enable)
   constant BG0CNT_Colors_Palettes        : regmap_type := (16#008#,   7,      7,        1,        0,   readwrite); -- Colors/Palettes       (0=16/16, 1=256/1)
   constant BG0CNT_Screen_Base_Block      : regmap_type := (16#008#,  12,      8,        1,        0,   readwrite); -- Screen Base Block     (0-31, in units of 2 KBytes) (=BG Map Data)
   constant BG0CNT_Screen_Size            : regmap_type := (16#008#,  15,     14,        1,        0,   readwrite); -- Screen Size (0-3)
   
   constant BG1CNT                        : regmap_type := (16#008#,  31,     16,        1,        0,   writeonly); -- BG1 Control                                   2    R/W
   constant BG1CNT_BG_Priority            : regmap_type := (16#008#,  17,     16,        1,        0,   readwrite); -- BG Priority           (0-3, 0=Highest)
   constant BG1CNT_Character_Base_Block   : regmap_type := (16#008#,  19,     18,        1,        0,   readwrite); -- Character Base Block  (0-3, in units of 16 KBytes) (=BG Tile Data)
   constant BG1CNT_UNUSED_4_5             : regmap_type := (16#008#,  21,     20,        1,        0,   readwrite); -- 4-5   Not used (must be zero)
   constant BG1CNT_Mosaic                 : regmap_type := (16#008#,  22,     22,        1,        0,   readwrite); -- Mosaic                (0=Disable, 1=Enable)
   constant BG1CNT_Colors_Palettes        : regmap_type := (16#008#,  23,     23,        1,        0,   readwrite); -- Colors/Palettes       (0=16/16, 1=256/1)
   constant BG1CNT_Screen_Base_Block      : regmap_type := (16#008#,  28,     24,        1,        0,   readwrite); -- Screen Base Block     (0-31, in units of 2 KBytes) (=BG Map Data)
   constant BG1CNT_Screen_Size            : regmap_type := (16#008#,  31,     30,        1,        0,   readwrite); -- Screen Size (0-3)
   
   constant BG2CNT                        : regmap_type := (16#00C#,  15,      0,        1,        0,   readwrite); -- BG2 Control                                   2    R/W
   constant BG2CNT_BG_Priority            : regmap_type := (16#00C#,   1,      0,        1,        0,   readwrite); -- BG Priority           (0-3, 0=Highest)
   constant BG2CNT_Character_Base_Block   : regmap_type := (16#00C#,   3,      2,        1,        0,   readwrite); -- Character Base Block  (0-3, in units of 16 KBytes) (=BG Tile Data)
   constant BG2CNT_UNUSED_4_5             : regmap_type := (16#00C#,   5,      4,        1,        0,   readwrite); -- 4-5   Not used (must be zero)
   constant BG2CNT_Mosaic                 : regmap_type := (16#00C#,   6,      6,        1,        0,   readwrite); -- Mosaic                (0=Disable, 1=Enable)
   constant BG2CNT_Colors_Palettes        : regmap_type := (16#00C#,   7,      7,        1,        0,   readwrite); -- Colors/Palettes       (0=16/16, 1=256/1)
   constant BG2CNT_Screen_Base_Block      : regmap_type := (16#00C#,  12,      8,        1,        0,   readwrite); -- Screen Base Block     (0-31, in units of 2 KBytes) (=BG Map Data)
   constant BG2CNT_Display_Area_Overflow  : regmap_type := (16#00C#,  13,     13,        1,        0,   readwrite); -- Display Area Overflow (0=Transparent, 1=Wraparound; BG2CNT/BG3CNT only)
   constant BG2CNT_Screen_Size            : regmap_type := (16#00C#,  15,     14,        1,        0,   readwrite); -- Screen Size (0-3)
   
   constant BG3CNT                        : regmap_type := (16#00C#,  31,     16,        1,        0,   readwrite); -- BG3 Control                                   2    R/W
   constant BG3CNT_BG_Priority            : regmap_type := (16#00C#,  17,     16,        1,        0,   readwrite); -- BG Priority           (0-3, 0=Highest)
   constant BG3CNT_Character_Base_Block   : regmap_type := (16#00C#,  19,     18,        1,        0,   readwrite); -- Character Base Block  (0-3, in units of 16 KBytes) (=BG Tile Data)
   constant BG3CNT_UNUSED_4_5             : regmap_type := (16#00C#,  21,     20,        1,        0,   readwrite); -- 4-5   Not used (must be zero)
   constant BG3CNT_Mosaic                 : regmap_type := (16#00C#,  22,     22,        1,        0,   readwrite); -- Mosaic                (0=Disable, 1=Enable)
   constant BG3CNT_Colors_Palettes        : regmap_type := (16#00C#,  23,     23,        1,        0,   readwrite); -- Colors/Palettes       (0=16/16, 1=256/1)
   constant BG3CNT_Screen_Base_Block      : regmap_type := (16#00C#,  28,     24,        1,        0,   readwrite); -- Screen Base Block     (0-31, in units of 2 KBytes) (=BG Map Data)
   constant BG3CNT_Display_Area_Overflow  : regmap_type := (16#00C#,  29,     29,        1,        0,   readwrite); -- Display Area Overflow (0=Transparent, 1=Wraparound; BG2CNT/BG3CNT only)
   constant BG3CNT_Screen_Size            : regmap_type := (16#00C#,  31,     30,        1,        0,   readwrite); -- Screen Size (0-3)
   
   constant BG0HOFS                       : regmap_type := (16#010#,  15,      0,        1,        0,   writeonly); -- BG0 X-Offset                                  2    W  
   constant BG0VOFS                       : regmap_type := (16#010#,  31,     16,        1,        0,   writeonly); -- BG0 Y-Offset                                  2    W  
   constant BG1HOFS                       : regmap_type := (16#014#,  15,      0,        1,        0,   writeonly); -- BG1 X-Offset                                  2    W  
   constant BG1VOFS                       : regmap_type := (16#014#,  31,     16,        1,        0,   writeonly); -- BG1 Y-Offset                                  2    W  
   constant BG2HOFS                       : regmap_type := (16#018#,  15,      0,        1,        0,   writeonly); -- BG2 X-Offset                                  2    W  
   constant BG2VOFS                       : regmap_type := (16#018#,  31,     16,        1,        0,   writeonly); -- BG2 Y-Offset                                  2    W  
   constant BG3HOFS                       : regmap_type := (16#01C#,  15,      0,        1,        0,   writeonly); -- BG3 X-Offset                                  2    W  
   constant BG3VOFS                       : regmap_type := (16#01C#,  31,     16,        1,        0,   writeonly); -- BG3 Y-Offset                                  2    W  
   
   constant BG2RotScaleParDX              : regmap_type := (16#020#,  15,      0,        1,      256,   writeonly); -- BG2 Rotation/Scaling Parameter A (dx)         2    W  
   constant BG2RotScaleParDMX             : regmap_type := (16#020#,  31,     16,        1,        0,   writeonly); -- BG2 Rotation/Scaling Parameter B (dmx)        2    W  
   constant BG2RotScaleParDY              : regmap_type := (16#024#,  15,      0,        1,        0,   writeonly); -- BG2 Rotation/Scaling Parameter C (dy)         2    W  
   constant BG2RotScaleParDMY             : regmap_type := (16#024#,  31,     16,        1,      256,   writeonly); -- BG2 Rotation/Scaling Parameter D (dmy)        2    W  
   constant BG2RefX                       : regmap_type := (16#028#,  27,      0,        1,        0,   writeonly); -- BG2 Reference Point X-Coordinate              4    W  
   constant BG2RefY                       : regmap_type := (16#02C#,  27,      0,        1,        0,   writeonly); -- BG2 Reference Point Y-Coordinate              4    W  
   
   constant BG3RotScaleParDX              : regmap_type := (16#030#,  15,      0,        1,      256,   writeonly); -- BG3 Rotation/Scaling Parameter A (dx)         2    W  
   constant BG3RotScaleParDMX             : regmap_type := (16#030#,  31,     16,        1,        0,   writeonly); -- BG3 Rotation/Scaling Parameter B (dmx)        2    W  
   constant BG3RotScaleParDY              : regmap_type := (16#034#,  15,      0,        1,        0,   writeonly); -- BG3 Rotation/Scaling Parameter C (dy)         2    W  
   constant BG3RotScaleParDMY             : regmap_type := (16#034#,  31,     16,        1,      256,   writeonly); -- BG3 Rotation/Scaling Parameter D (dmy)        2    W  
   constant BG3RefX                       : regmap_type := (16#038#,  27,      0,        1,        0,   writeonly); -- BG3 Reference Point X-Coordinate              4    W  
   constant BG3RefY                       : regmap_type := (16#03C#,  27,      0,        1,        0,   writeonly); -- BG3 Reference Point Y-Coordinate              4    W  
   
   constant WIN0H                         : regmap_type := (16#040#,  15,      0,        1,        0,   writeonly); -- Window 0 Horizontal Dimensions                2    W  
   constant WIN0H_X2                      : regmap_type := (16#040#,   7,      0,        1,        0,   writeonly); -- Window 0 Horizontal Dimensions                2    W  
   constant WIN0H_X1                      : regmap_type := (16#040#,  15,      8,        1,        0,   writeonly); -- Window 0 Horizontal Dimensions                2    W  
   
   constant WIN1H                         : regmap_type := (16#040#,  31,     16,        1,        0,   writeonly); -- Window 1 Horizontal Dimensions                2    W  
   constant WIN1H_X2                      : regmap_type := (16#040#,  23,     16,        1,        0,   writeonly); -- Window 1 Horizontal Dimensions                2    W  
   constant WIN1H_X1                      : regmap_type := (16#040#,  31,     24,        1,        0,   writeonly); -- Window 1 Horizontal Dimensions                2    W  
   
   constant WIN0V                         : regmap_type := (16#044#,  15,      0,        1,        0,   writeonly); -- Window 0 Vertical Dimensions                  2    W  
   constant WIN0V_Y2                      : regmap_type := (16#044#,   7,      0,        1,        0,   writeonly); -- Window 0 Vertical Dimensions                  2    W  
   constant WIN0V_Y1                      : regmap_type := (16#044#,  15,      8,        1,        0,   writeonly); -- Window 0 Vertical Dimensions                  2    W  
                                                                      
   constant WIN1V                         : regmap_type := (16#044#,  31,     16,        1,        0,   writeonly); -- Window 1 Vertical Dimensions                  2    W  
   constant WIN1V_Y2                      : regmap_type := (16#044#,  23,     16,        1,        0,   writeonly); -- Window 1 Vertical Dimensions                  2    W  
   constant WIN1V_Y1                      : regmap_type := (16#044#,  31,     24,        1,        0,   writeonly); -- Window 1 Vertical Dimensions                  2    W  
   
   constant WININ                         : regmap_type := (16#048#,  15,      0,        1,        0,   writeonly); -- Inside of Window 0 and 1                      2    R/W
   constant WININ_Window_0_BG0_Enable     : regmap_type := (16#048#,   0,      0,        1,        0,   readwrite); -- 0-3   Window_0_BG0_BG3_Enable     (0=No Display, 1=Display)
   constant WININ_Window_0_BG1_Enable     : regmap_type := (16#048#,   1,      1,        1,        0,   readwrite); -- 0-3   Window_0_BG0_BG3_Enable     (0=No Display, 1=Display)
   constant WININ_Window_0_BG2_Enable     : regmap_type := (16#048#,   2,      2,        1,        0,   readwrite); -- 0-3   Window_0_BG0_BG3_Enable     (0=No Display, 1=Display)
   constant WININ_Window_0_BG3_Enable     : regmap_type := (16#048#,   3,      3,        1,        0,   readwrite); -- 0-3   Window_0_BG0_BG3_Enable     (0=No Display, 1=Display)
   constant WININ_Window_0_OBJ_Enable     : regmap_type := (16#048#,   4,      4,        1,        0,   readwrite); -- 4     Window_0_OBJ_Enable         (0=No Display, 1=Display)
   constant WININ_Window_0_Special_Effect : regmap_type := (16#048#,   5,      5,        1,        0,   readwrite); -- 5     Window_0_Special_Effect     (0=Disable, 1=Enable)
   constant WININ_Window_1_BG0_Enable     : regmap_type := (16#048#,   8,      8,        1,        0,   readwrite); -- 8-11  Window_1_BG0_BG3_Enable     (0=No Display, 1=Display)
   constant WININ_Window_1_BG1_Enable     : regmap_type := (16#048#,   9,      9,        1,        0,   readwrite); -- 8-11  Window_1_BG0_BG3_Enable     (0=No Display, 1=Display)
   constant WININ_Window_1_BG2_Enable     : regmap_type := (16#048#,  10,     10,        1,        0,   readwrite); -- 8-11  Window_1_BG0_BG3_Enable     (0=No Display, 1=Display)
   constant WININ_Window_1_BG3_Enable     : regmap_type := (16#048#,  11,     11,        1,        0,   readwrite); -- 8-11  Window_1_BG0_BG3_Enable     (0=No Display, 1=Display)
   constant WININ_Window_1_OBJ_Enable     : regmap_type := (16#048#,  12,     12,        1,        0,   readwrite); -- 12    Window_1_OBJ_Enable         (0=No Display, 1=Display)
   constant WININ_Window_1_Special_Effect : regmap_type := (16#048#,  13,     13,        1,        0,   readwrite); -- 13    Window_1_Special_Effect     (0=Disable, 1=Enable)
   
   constant WINOUT                        : regmap_type := (16#048#,  31,     16,        1,        0,   writeonly); -- Inside of OBJ Window & Outside of Windows     2    R/W
   constant WINOUT_Outside_BG0_Enable     : regmap_type := (16#048#,  16,     16,        1,        0,   readwrite); -- 0-3   Outside_BG0_BG3_Enable     (0=No Display, 1=Display)
   constant WINOUT_Outside_BG1_Enable     : regmap_type := (16#048#,  17,     17,        1,        0,   readwrite); -- 0-3   Outside_BG0_BG3_Enable     (0=No Display, 1=Display)
   constant WINOUT_Outside_BG2_Enable     : regmap_type := (16#048#,  18,     18,        1,        0,   readwrite); -- 0-3   Outside_BG0_BG3_Enable     (0=No Display, 1=Display)
   constant WINOUT_Outside_BG3_Enable     : regmap_type := (16#048#,  19,     19,        1,        0,   readwrite); -- 0-3   Outside_BG0_BG3_Enable     (0=No Display, 1=Display)
   constant WINOUT_Outside_OBJ_Enable     : regmap_type := (16#048#,  20,     20,        1,        0,   readwrite); -- 4     Outside_OBJ_Enable         (0=No Display, 1=Display)
   constant WINOUT_Outside_Special_Effect : regmap_type := (16#048#,  21,     21,        1,        0,   readwrite); -- 5     Outside_Special_Effect     (0=Disable, 1=Enable)
   constant WINOUT_Objwnd_BG0_Enable      : regmap_type := (16#048#,  24,     24,        1,        0,   readwrite); -- 8-11  object window_BG0_BG3_Enable     (0=No Display, 1=Display)
   constant WINOUT_Objwnd_BG1_Enable      : regmap_type := (16#048#,  25,     25,        1,        0,   readwrite); -- 8-11  object window_BG0_BG3_Enable     (0=No Display, 1=Display)
   constant WINOUT_Objwnd_BG2_Enable      : regmap_type := (16#048#,  26,     26,        1,        0,   readwrite); -- 8-11  object window_BG0_BG3_Enable     (0=No Display, 1=Display)
   constant WINOUT_Objwnd_BG3_Enable      : regmap_type := (16#048#,  27,     27,        1,        0,   readwrite); -- 8-11  object window_BG0_BG3_Enable     (0=No Display, 1=Display)
   constant WINOUT_Objwnd_OBJ_Enable      : regmap_type := (16#048#,  28,     28,        1,        0,   readwrite); -- 12    object window_OBJ_Enable         (0=No Display, 1=Display)
   constant WINOUT_Objwnd_Special_Effect  : regmap_type := (16#048#,  29,     29,        1,        0,   readwrite); -- 13    object window_Special_Effect     (0=Disable, 1=Enable)
   
   constant MOSAIC                        : regmap_type := (16#04C#,  15,      0,        1,        0,   writeonly); -- Mosaic Size                                   2    W  
   constant MOSAIC_BG_Mosaic_H_Size       : regmap_type := (16#04C#,   3,      0,        1,        0,   writeonly); --   0-3   BG_Mosaic_H_Size  (minus 1)  
   constant MOSAIC_BG_Mosaic_V_Size       : regmap_type := (16#04C#,   7,      4,        1,        0,   writeonly); --   4-7   BG_Mosaic_V_Size  (minus 1)  
   constant MOSAIC_OBJ_Mosaic_H_Size      : regmap_type := (16#04C#,  11,      8,        1,        0,   writeonly); --   8-11  OBJ_Mosaic_H_Size (minus 1)  
   constant MOSAIC_OBJ_Mosaic_V_Size      : regmap_type := (16#04C#,  15,     12,        1,        0,   writeonly); --   12-15 OBJ_Mosaic_V_Size (minus 1)  
                              
   constant BLDCNT                        : regmap_type := (16#050#,  13,      0,        1,        0,   readwrite); -- Color Special Effects Selection               2    R/W
   constant BLDCNT_BG0_1st_Target_Pixel   : regmap_type := (16#050#,   0,      0,        1,        0,   readwrite); -- 0      (Background 0)
   constant BLDCNT_BG1_1st_Target_Pixel   : regmap_type := (16#050#,   1,      1,        1,        0,   readwrite); -- 1      (Background 1)
   constant BLDCNT_BG2_1st_Target_Pixel   : regmap_type := (16#050#,   2,      2,        1,        0,   readwrite); -- 2      (Background 2)
   constant BLDCNT_BG3_1st_Target_Pixel   : regmap_type := (16#050#,   3,      3,        1,        0,   readwrite); -- 3      (Background 3)
   constant BLDCNT_OBJ_1st_Target_Pixel   : regmap_type := (16#050#,   4,      4,        1,        0,   readwrite); -- 4      (Top-most OBJ pixel)
   constant BLDCNT_BD_1st_Target_Pixel    : regmap_type := (16#050#,   5,      5,        1,        0,   readwrite); -- 5      (Backdrop)
   constant BLDCNT_Color_Special_Effect   : regmap_type := (16#050#,   7,      6,        1,        0,   readwrite); -- 6-7    (0-3, see below) 0 = None (Special effects disabled), 1 = Alpha Blending (1st+2nd Target mixed), 2 = Brightness Increase (1st Target becomes whiter), 3 = Brightness Decrease (1st Target becomes blacker)
   constant BLDCNT_BG0_2nd_Target_Pixel   : regmap_type := (16#050#,   8,      8,        1,        0,   readwrite); -- 8      (Background 0)
   constant BLDCNT_BG1_2nd_Target_Pixel   : regmap_type := (16#050#,   9,      9,        1,        0,   readwrite); -- 9      (Background 1)
   constant BLDCNT_BG2_2nd_Target_Pixel   : regmap_type := (16#050#,  10,     10,        1,        0,   readwrite); -- 10     (Background 2)
   constant BLDCNT_BG3_2nd_Target_Pixel   : regmap_type := (16#050#,  11,     11,        1,        0,   readwrite); -- 11     (Background 3)
   constant BLDCNT_OBJ_2nd_Target_Pixel   : regmap_type := (16#050#,  12,     12,        1,        0,   readwrite); -- 12     (Top-most OBJ pixel)
   constant BLDCNT_BD_2nd_Target_Pixel    : regmap_type := (16#050#,  13,     13,        1,        0,   readwrite); -- 13     (Backdrop)

   constant BLDALPHA                      : regmap_type := (16#050#,  28,     16,        1,        0,   writeonly); -- Alpha Blending Coefficients                   2    W  
   constant BLDALPHA_EVA_Coefficient      : regmap_type := (16#050#,  20,     16,        1,        0,   readwrite); -- 0-4   (1st Target) (0..16 = 0/16..16/16, 17..31=16/16)
   constant BLDALPHA_EVB_Coefficient      : regmap_type := (16#050#,  28,     24,        1,        0,   readwrite); -- 8-12  (2nd Target) (0..16 = 0/16..16/16, 17..31=16/16)
    
   constant BLDY                          : regmap_type := (16#054#,   4,      0,        1,        0,   writeonly); -- Brightness (Fade-In/Out) Coefficient  0-4   EVY Coefficient (Brightness) (0..16 = 0/16..16/16, 17..31=16/16 
   
end package;
