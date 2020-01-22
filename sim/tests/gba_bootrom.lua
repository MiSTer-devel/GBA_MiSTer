require("gba_lib")

wait_ns(220000)

reg_set(0, gameboy.Reg_GBA_on)
reg_set(0, gameboy.Reg_GBA_flash_1m)
reg_set(1, gameboy.Reg_GBA_SramFlashEna)
reg_set(0, gameboy.Reg_GBA_MemoryRemap )

transmit_rom("armwrestler.gba", 65536+131072 + 0xC000000, nil)

reg_set(0, gameboy.Reg_GBA_lockspeed)
reg_set(1, gameboy.Reg_GBA_on)

print("GBA ON")

brk()