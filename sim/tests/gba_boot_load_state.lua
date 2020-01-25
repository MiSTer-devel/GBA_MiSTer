require("gba_lib")

wait_ns(220000)

reg_set(0, gameboy.Reg_GBA_on)
reg_set(0, gameboy.Reg_GBA_flash_1m)
reg_set(0, gameboy.Reg_GBA_SramFlashEna)
reg_set(0, gameboy.Reg_GBA_MemoryRemap )

transmit_rom("armwrestler.gba", 65536+131072 + 0xC000000, nil)
print("Game transfered")

reg_set_file("tests\\savestate.ss", 58720256 + 0xC000000, 0, 0)
print("Savestate transfered")

reg_set(100, gameboy.Reg_GBA_CyclePrecalc)
reg_set(1, gameboy.Reg_GBA_lockspeed)
reg_set(1, gameboy.Reg_GBA_on)

reg_set(1, gameboy.Reg_GBA_LoadState)

print("GBA ON")

brk()