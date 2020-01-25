require("gba_lib")

-- prepare
testerrorcount = 0

local HEADERCOUNT = 2
local INTERNALSCOUNT = 67
local REGISTERPOS = HEADERCOUNT + INTERNALSCOUNT
local WRAMLARGEPOS = REGISTERPOS + 256
local WRAMSMALLPOS = WRAMLARGEPOS + 65536
local PALETTEPOS = WRAMSMALLPOS + 8192
local VRAMPOS = PALETTEPOS + 256
local OAMPOS = VRAMPOS + 24576

reg_set(0, gameboy.Reg_GBA_on)
reg_set(1, gameboy.Reg_GBA_lockspeed)

transmit_rom("armwrestler.gba", 65536+131072 + 0xC000000, nil)

wait_ns(220000)

-- set memory
write_gbbus_32bit(0x1234, 0x2000000)
write_gbbus_32bit(0x1235, 0x2000004)
write_gbbus_32bit(0x1236, 0x2000008)
write_gbbus_32bit(0x1237, 0x200000C)
write_gbbus_32bit(0x1238, 0x2000010)

write_gbbus_32bit(0x2345, 0x3000000)
write_gbbus_32bit(0x2346, 0x3000004)

write_gbbus_32bit(0x3332, 0x4000010)
write_gbbus_32bit(0x3333, 0x4000050)
write_gbbus_32bit(0xFFFFFFFF, 0x40000B8)
write_gbbus_32bit(0x3334, 0x4000208)

write_gbbus_32bit(0x4444, 0x5000000)
write_gbbus_32bit(0x4445, 0x5000004)

write_gbbus_32bit(0x5555, 0x6000000)
write_gbbus_32bit(0x5556, 0x6000004)

write_gbbus_32bit(0x6666, 0x7000000)
write_gbbus_32bit(0x6667, 0x7000004)

-- check if all written correct
compare_gbbus_32bit(0x1234, 0x2000000)
compare_gbbus_32bit(0x1235, 0x2000004)
compare_gbbus_32bit(0x1236, 0x2000008)
compare_gbbus_32bit(0x1237, 0x200000C)
compare_gbbus_32bit(0x1238, 0x2000010)
                            
compare_gbbus_32bit(0x2345, 0x3000000)
compare_gbbus_32bit(0x2346, 0x3000004)
                            
compare_gbbus_32bit(0x3333, 0x4000050)
compare_gbbus_32bit(0x3334, 0x4000208)
                            
compare_gbbus_32bit(0x4444, 0x5000000)
compare_gbbus_32bit(0x4445, 0x5000004)
                            
compare_gbbus_32bit(0x5555, 0x6000000)
compare_gbbus_32bit(0x5556, 0x6000004)
                            
compare_gbbus_32bit(0x6666, 0x7000000)
compare_gbbus_32bit(0x6667, 0x7000004)

-- save state
reg_set(1, gameboy.Reg_GBA_lockspeed)
reg_set(1, gameboy.Reg_GBA_on)

reg_set(1, gameboy.Reg_GBA_SaveState)
wait_ns(8000000)

-- reset to wrong
write_gbbus_32bit(0xFA11, 0x2000000)
write_gbbus_32bit(0xFA11, 0x2000004)
write_gbbus_32bit(0xFA11, 0x2000008)
write_gbbus_32bit(0xFA11, 0x200000C)
write_gbbus_32bit(0xFA11, 0x2000010)

write_gbbus_32bit(0xFA11, 0x3000000)
write_gbbus_32bit(0xFA11, 0x3000004)

write_gbbus_32bit(0xFA11, 0x4000010)
write_gbbus_32bit(0xFA11, 0x4000050)
write_gbbus_32bit(0xFA11FA11, 0x40000B8)
write_gbbus_32bit(0xFA11, 0x4000208)
                    
write_gbbus_32bit(0xFA11, 0x5000000)
write_gbbus_32bit(0xFA11, 0x5000004)

write_gbbus_32bit(0xFA11, 0x6000000)
write_gbbus_32bit(0xFA11, 0x6000004)

write_gbbus_32bit(0xFA11, 0x7000000)
write_gbbus_32bit(0xFA11, 0x7000004)

-- load state
reg_set(1, gameboy.Reg_GBA_LoadState)
reg_set(0, gameboy.Reg_GBA_CyclePrecalc) -- pause
wait_ns(10000000)

-- test loaded data
compare_gbbus_32bit(0x1234, 0x2000000)
compare_gbbus_32bit(0x1235, 0x2000004)
compare_gbbus_32bit(0x1236, 0x2000008)
compare_gbbus_32bit(0x1237, 0x200000C)
compare_gbbus_32bit(0x1238, 0x2000010)
                            
compare_gbbus_32bit(0x2345, 0x3000000)
compare_gbbus_32bit(0x2346, 0x3000004)
                            
compare_gbbus_32bit(0x3333, 0x4000050)
compare_gbbus_32bit(0x3334, 0x4000208)
                            
compare_gbbus_32bit(0x4444, 0x5000000)
compare_gbbus_32bit(0x4445, 0x5000004)
                            
compare_gbbus_32bit(0x5555, 0x6000000)
compare_gbbus_32bit(0x5556, 0x6000004)
                            
compare_gbbus_32bit(0x6666, 0x7000000)
compare_gbbus_32bit(0x6667, 0x7000004)


print (testerrorcount.." Errors found")

return (testerrorcount)