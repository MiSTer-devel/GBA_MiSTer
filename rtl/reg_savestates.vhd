library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

use work.pProc_bus_gba.all;
use work.pRegmap_gba.all;

package pReg_savestates is

   --   (                                              adr   upper    lower    size   default   accesstype)  

   -- cpu
   constant REG_SAVESTATE_PC              : regmap_type := (  0,   31,      0,        1,        0,   readwrite);
   constant REG_SAVESTATE_REGS            : regmap_type := (  1,   31,      0,       18,        0,   readwrite);
   constant REG_SAVESTATE_REGS_0_8        : regmap_type := ( 19,   31,      0,        1,        0,   readwrite);
   constant REG_SAVESTATE_REGS_0_9        : regmap_type := ( 20,   31,      0,        1,        0,   readwrite);
   constant REG_SAVESTATE_REGS_0_10       : regmap_type := ( 21,   31,      0,        1,        0,   readwrite);
   constant REG_SAVESTATE_REGS_0_11       : regmap_type := ( 22,   31,      0,        1,        0,   readwrite);
   constant REG_SAVESTATE_REGS_0_12       : regmap_type := ( 23,   31,      0,        1,        0,   readwrite);
   constant REG_SAVESTATE_REGS_0_13       : regmap_type := ( 24,   31,      0,        1,        0,   readwrite);
   constant REG_SAVESTATE_REGS_0_14       : regmap_type := ( 25,   31,      0,        1,        0,   readwrite);
   constant REG_SAVESTATE_REGS_1_8        : regmap_type := ( 26,   31,      0,        1,        0,   readwrite);
   constant REG_SAVESTATE_REGS_1_9        : regmap_type := ( 27,   31,      0,        1,        0,   readwrite);
   constant REG_SAVESTATE_REGS_1_10       : regmap_type := ( 28,   31,      0,        1,        0,   readwrite);
   constant REG_SAVESTATE_REGS_1_11       : regmap_type := ( 29,   31,      0,        1,        0,   readwrite);
   constant REG_SAVESTATE_REGS_1_12       : regmap_type := ( 30,   31,      0,        1,        0,   readwrite);
   constant REG_SAVESTATE_REGS_1_13       : regmap_type := ( 31,   31,      0,        1,        0,   readwrite);
   constant REG_SAVESTATE_REGS_1_14       : regmap_type := ( 32,   31,      0,        1,        0,   readwrite);
   constant REG_SAVESTATE_REGS_1_17       : regmap_type := ( 33,   31,      0,        1,        0,   readwrite);
   constant REG_SAVESTATE_REGS_2_13       : regmap_type := ( 34,   31,      0,        1,        0,   readwrite);
   constant REG_SAVESTATE_REGS_2_14       : regmap_type := ( 35,   31,      0,        1,        0,   readwrite);
   constant REG_SAVESTATE_REGS_2_17       : regmap_type := ( 36,   31,      0,        1,        0,   readwrite);
   constant REG_SAVESTATE_REGS_3_13       : regmap_type := ( 37,   31,      0,        1,        0,   readwrite);
   constant REG_SAVESTATE_REGS_3_14       : regmap_type := ( 38,   31,      0,        1,        0,   readwrite);
   constant REG_SAVESTATE_REGS_3_17       : regmap_type := ( 39,   31,      0,        1,        0,   readwrite);
   constant REG_SAVESTATE_REGS_4_13       : regmap_type := ( 40,   31,      0,        1,        0,   readwrite);
   constant REG_SAVESTATE_REGS_4_14       : regmap_type := ( 41,   31,      0,        1,        0,   readwrite);
   constant REG_SAVESTATE_REGS_4_17       : regmap_type := ( 42,   31,      0,        1,        0,   readwrite);
   constant REG_SAVESTATE_REGS_5_13       : regmap_type := ( 43,   31,      0,        1,        0,   readwrite);
   constant REG_SAVESTATE_REGS_5_14       : regmap_type := ( 44,   31,      0,        1,        0,   readwrite);
   constant REG_SAVESTATE_REGS_5_17       : regmap_type := ( 45,   31,      0,        1,        0,   readwrite);
   
   constant REG_SAVESTATE_CPUMIXED        : regmap_type := ( 46,   11,      0,        1,  16#CC0#,   readwrite);
   constant REG_SAVESTATE_HALT            : regmap_type := ( 46,    0,      0,        1,        0,   readwrite);
   constant REG_SAVESTATE_Flag_Zero       : regmap_type := ( 46,    1,      1,        1,        0,   readwrite);
   constant REG_SAVESTATE_Flag_Carry      : regmap_type := ( 46,    2,      2,        1,        0,   readwrite);
   constant REG_SAVESTATE_Flag_Negative   : regmap_type := ( 46,    3,      3,        1,        0,   readwrite);
   constant REG_SAVESTATE_Flag_V_Overflow : regmap_type := ( 46,    4,      4,        1,        0,   readwrite);
   constant REG_SAVESTATE_thumbmode       : regmap_type := ( 46,    5,      5,        1,        0,   readwrite);
   constant REG_SAVESTATE_cpu_mode        : regmap_type := ( 46,    9,      6,        1,        3,   readwrite);
   constant REG_SAVESTATE_IRQ_disable     : regmap_type := ( 46,   10,     10,        1,        1,   readwrite);
   constant REG_SAVESTATE_FIQ_disable     : regmap_type := ( 46,   11,     11,        1,        1,   readwrite);
   
   constant REG_SAVESTATE_IRP             : regmap_type := ( 47,   15,      0,        1,        0,   readwrite);
   constant REG_SAVESTATE_GPIOBITS        : regmap_type := ( 47,   21,     16,        1,        0,   readwrite);
   
   constant REG_SAVESTATE_DMASOUNDA       : regmap_type := ( 47,   26,     22,        1,        0,   readwrite);
   constant REG_SAVESTATE_DMASOUNDB       : regmap_type := ( 47,   31,     27,        1,        0,   readwrite);
   
   -- memory
   constant REG_SAVESTATE_EEPROM          : regmap_type := ( 48,   31,      0,        1,        0,   readwrite);
   constant REG_SAVESTATE_FLASH           : regmap_type := ( 49,   16,      0,        1,        0,   readwrite);
   
   constant REG_SAVESTATE_SOUNDON         : regmap_type := ( 49,   20,     17,        1,        0,   readwrite);
   
   -- dma
   constant REG_SAVESTATE_DMASOURCE       : regmap_type := ( 50,   27,      0,        4,        0,   readwrite);
   constant REG_SAVESTATE_DMATARGET       : regmap_type := ( 54,   27,      0,        4,        0,   readwrite);
   constant REG_SAVESTATE_DMAMIXED        : regmap_type := ( 58,   30,      0,        4,        0,   readwrite);
   
   -- timer
   constant REG_SAVESTATE_TIMER           : regmap_type := ( 62,   29,      0,        4,        0,   readwrite);
   
   -- GPU
   constant REG_SAVESTATE_GPU             : regmap_type := ( 66,   24,      0,        1,        0,   readwrite);
   
   -- GPIO
   constant REG_SAVESTATE_GPIO            : regmap_type := ( 67,   29,      0,        1,        0,   readwrite);   
   
   
end package;
