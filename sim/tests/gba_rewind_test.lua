require("gba_lib")

reg_set(0, gameboy.Reg_GBA_on)
reg_set(1, gameboy.Reg_GBA_lockspeed)
reg_set(0x7C00000, gameboy.Reg_GBA_SaveStateAddr)

transmit_rom("armwrestler.gba", 65536+131072 + 0xC000000, nil)

wait_ns(220000)

reg_set(1, gameboy.Reg_GBA_lockspeed)
reg_set(1, gameboy.Reg_GBA_on)
reg_set(1, gameboy.Reg_GBA_Rewind_on)

wait_ns(3000000)

reg_set(1, gameboy.Reg_GBA_Rewind_active)

brk()

