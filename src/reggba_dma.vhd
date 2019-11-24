library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

use work.pProc_bus_gba.all;
use work.pRegmap_gba.all;

package pReg_gba_dma is

   -- range 0xB0 .. 0xE0
   --   (                                                adr      upper    lower    size   default   accesstype)                                     
   constant DMA0SAD                      : regmap_type := (16#B0#,  31,      0,        1,        0,   writeonly); -- Source Address       4    W  
   constant DMA0DAD                      : regmap_type := (16#B4#,  31,      0,        1,        0,   writeonly); -- Destination Address  4    W  
   constant DMA0CNT_L                    : regmap_type := (16#B8#,  15,      0,        1,        0,   writeDone); -- Word Count           2    W  
   constant DMA0CNT_H                    : regmap_type := (16#B8#,  31,     16,        1,        0,   writeonly); -- Control              2    R/W
   constant DMA0CNT_H_Dest_Addr_Control  : regmap_type := (16#B8#,  22,     21,        1,        0,   readwrite); -- 5-6   Dest Addr Control  (0=Increment,1=Decrement,2=Fixed,3=Increment/Reload)
   constant DMA0CNT_H_Source_Adr_Control : regmap_type := (16#B8#,  24,     23,        1,        0,   readwrite); -- 7-8   Source Adr Control (0=Increment,1=Decrement,2=Fixed,3=Prohibited)
   constant DMA0CNT_H_DMA_Repeat         : regmap_type := (16#B8#,  25,     25,        1,        0,   readwrite); -- 9     DMA Repeat                   (0=Off, 1=On) (Must be zero if Bit 11 set)
   constant DMA0CNT_H_DMA_Transfer_Type  : regmap_type := (16#B8#,  26,     26,        1,        0,   readwrite); -- 10    DMA Transfer Type            (0=16bit, 1=32bit)
   constant DMA0CNT_H_DMA_Start_Timing   : regmap_type := (16#B8#,  29,     28,        1,        0,   readwrite); -- 12-13 DMA Start Timing  (0=Immediately, 1=VBlank, 2=HBlank, 3=Special) The 'Special' setting (Start Timing=3) depends on the DMA channel: DMA0=Prohibited, DMA1/DMA2=Sound FIFO, DMA3=Video Capture
   constant DMA0CNT_H_IRQ_on             : regmap_type := (16#B8#,  30,     30,        1,        0,   readwrite); -- 14    IRQ upon end of Word Count   (0=Disable, 1=Enable)
   constant DMA0CNT_H_DMA_Enable         : regmap_type := (16#B8#,  31,     31,        1,        0,   readwrite); -- 15    DMA Enable                   (0=Off, 1=On)

   constant DMA1SAD                      : regmap_type := (16#BC#,  31,      0,        1,        0,   writeonly); -- Source Address       4    W  
   constant DMA1DAD                      : regmap_type := (16#C0#,  31,      0,        1,        0,   writeonly); -- Destination Address  4    W  
   constant DMA1CNT_L                    : regmap_type := (16#C4#,  15,      0,        1,        0,   writeDone); -- Word Count           2    W  
   constant DMA1CNT_H                    : regmap_type := (16#C4#,  31,     16,        1,        0,   writeonly); -- Control              2    R/W
   constant DMA1CNT_H_Dest_Addr_Control  : regmap_type := (16#C4#,  22,     21,        1,        0,   readwrite); -- 5-6   Dest Addr Control  (0=Increment,1=Decrement,2=Fixed,3=Increment/Reload)
   constant DMA1CNT_H_Source_Adr_Control : regmap_type := (16#C4#,  24,     23,        1,        0,   readwrite); -- 7-8   Source Adr Control (0=Increment,1=Decrement,2=Fixed,3=Prohibited)
   constant DMA1CNT_H_DMA_Repeat         : regmap_type := (16#C4#,  25,     25,        1,        0,   readwrite); -- 9     DMA Repeat                   (0=Off, 1=On) (Must be zero if Bit 11 set)
   constant DMA1CNT_H_DMA_Transfer_Type  : regmap_type := (16#C4#,  26,     26,        1,        0,   readwrite); -- 10    DMA Transfer Type            (0=16bit, 1=32bit)
   constant DMA1CNT_H_DMA_Start_Timing   : regmap_type := (16#C4#,  29,     28,        1,        0,   readwrite); -- 12-13 DMA Start Timing  (0=Immediately, 1=VBlank, 2=HBlank, 3=Special) The 'Special' setting (Start Timing=3) depends on the DMA channel: DMA0=Prohibited, DMA1/DMA2=Sound FIFO, DMA3=Video Capture
   constant DMA1CNT_H_IRQ_on             : regmap_type := (16#C4#,  30,     30,        1,        0,   readwrite); -- 14    IRQ upon end of Word Count   (0=Disable, 1=Enable)
   constant DMA1CNT_H_DMA_Enable         : regmap_type := (16#C4#,  31,     31,        1,        0,   readwrite); -- 15    DMA Enable                   (0=Off, 1=On)
   
   constant DMA2SAD                      : regmap_type := (16#C8#,  31,      0,        1,        0,   writeonly); -- Source Address       4    W  
   constant DMA2DAD                      : regmap_type := (16#CC#,  31,      0,        1,        0,   writeonly); -- Destination Address  4    W  
   constant DMA2CNT_L                    : regmap_type := (16#D0#,  15,      0,        1,        0,   writeDone); -- Word Count           2    W  
   constant DMA2CNT_H                    : regmap_type := (16#D0#,  31,     16,        1,        0,   writeonly); -- Control              2    R/W
   constant DMA2CNT_H_Dest_Addr_Control  : regmap_type := (16#D0#,  22,     21,        1,        0,   readwrite); -- 5-6   Dest Addr Control  (0=Increment,1=Decrement,2=Fixed,3=Increment/Reload)
   constant DMA2CNT_H_Source_Adr_Control : regmap_type := (16#D0#,  24,     23,        1,        0,   readwrite); -- 7-8   Source Adr Control (0=Increment,1=Decrement,2=Fixed,3=Prohibited)
   constant DMA2CNT_H_DMA_Repeat         : regmap_type := (16#D0#,  25,     25,        1,        0,   readwrite); -- 9     DMA Repeat                   (0=Off, 1=On) (Must be zero if Bit 11 set)
   constant DMA2CNT_H_DMA_Transfer_Type  : regmap_type := (16#D0#,  26,     26,        1,        0,   readwrite); -- 10    DMA Transfer Type            (0=16bit, 1=32bit)
   constant DMA2CNT_H_DMA_Start_Timing   : regmap_type := (16#D0#,  29,     28,        1,        0,   readwrite); -- 12-13 DMA Start Timing  (0=Immediately, 1=VBlank, 2=HBlank, 3=Special) The 'Special' setting (Start Timing=3) depends on the DMA channel: DMA0=Prohibited, DMA1/DMA2=Sound FIFO, DMA3=Video Capture
   constant DMA2CNT_H_IRQ_on             : regmap_type := (16#D0#,  30,     30,        1,        0,   readwrite); -- 14    IRQ upon end of Word Count   (0=Disable, 1=Enable)
   constant DMA2CNT_H_DMA_Enable         : regmap_type := (16#D0#,  31,     31,        1,        0,   readwrite); -- 15    DMA Enable                   (0=Off, 1=On)
   
   constant DMA3SAD                      : regmap_type := (16#D4#,  31,      0,        1,        0,   writeonly); -- Source Address       4    W  
   constant DMA3DAD                      : regmap_type := (16#D8#,  31,      0,        1,        0,   writeonly); -- Destination Address  4    W  
   constant DMA3CNT_L                    : regmap_type := (16#DC#,  15,      0,        1,        0,   writeDone); -- Word Count           2    W  
   constant DMA3CNT_H                    : regmap_type := (16#DC#,  31,     16,        1,        0,   writeonly); -- Control              2    R/W
   constant DMA3CNT_H_Dest_Addr_Control  : regmap_type := (16#DC#,  22,     21,        1,        0,   readwrite); -- 5-6   Dest Addr Control  (0=Increment,1=Decrement,2=Fixed,3=Increment/Reload)
   constant DMA3CNT_H_Source_Adr_Control : regmap_type := (16#DC#,  24,     23,        1,        0,   readwrite); -- 7-8   Source Adr Control (0=Increment,1=Decrement,2=Fixed,3=Prohibited)
   constant DMA3CNT_H_DMA_Repeat         : regmap_type := (16#DC#,  25,     25,        1,        0,   readwrite); -- 9     DMA Repeat                   (0=Off, 1=On) (Must be zero if Bit 11 set)
   constant DMA3CNT_H_DMA_Transfer_Type  : regmap_type := (16#DC#,  26,     26,        1,        0,   readwrite); -- 10    DMA Transfer Type            (0=16bit, 1=32bit)
   constant DMA3CNT_H_Game_Pak_DRQ       : regmap_type := (16#DC#,  27,     27,        1,        0,   readwrite); -- 11    Game Pak DRQ  - DMA3 only -  (0=Normal, 1=DRQ <from> Game Pak, DMA3)
   constant DMA3CNT_H_DMA_Start_Timing   : regmap_type := (16#DC#,  29,     28,        1,        0,   readwrite); -- 12-13 DMA Start Timing  (0=Immediately, 1=VBlank, 2=HBlank, 3=Special) The 'Special' setting (Start Timing=3) depends on the DMA channel: DMA0=Prohibited, DMA1/DMA2=Sound FIFO, DMA3=Video Capture
   constant DMA3CNT_H_IRQ_on             : regmap_type := (16#DC#,  30,     30,        1,        0,   readwrite); -- 14    IRQ upon end of Word Count   (0=Disable, 1=Enable)
   constant DMA3CNT_H_DMA_Enable         : regmap_type := (16#DC#,  31,     31,        1,        0,   readwrite); -- 15    DMA Enable                   (0=Off, 1=On)

   
end package;
