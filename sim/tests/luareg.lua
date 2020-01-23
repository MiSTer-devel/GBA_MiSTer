--space.name = {address, upper, lower, size, default}
gameboy = {}
gameboy.Reg_GBA_on = {1056768,0,0,1,0,"gameboy.Reg_GBA_on"} -- on = 1
gameboy.Reg_GBA_lockspeed = {1056769,0,0,1,0,"gameboy.Reg_GBA_lockspeed"} -- 1 = 100% speed
gameboy.Reg_GBA_flash_1m = {1056770,0,0,1,0,"gameboy.Reg_GBA_flash_1m"}
gameboy.Reg_GBA_CyclePrecalc = {1056771,15,0,1,100,"gameboy.Reg_GBA_CyclePrecalc"}
gameboy.Reg_GBA_CyclesMissing = {1056772,31,0,1,0,"gameboy.Reg_GBA_CyclesMissing"}
gameboy.Reg_GBA_BusAddr = {1056773,27,0,1,0,"gameboy.Reg_GBA_BusAddr"}
gameboy.Reg_GBA_BusRnW = {1056773,28,28,1,0,"gameboy.Reg_GBA_BusRnW"}
gameboy.Reg_GBA_BusACC = {1056773,30,29,1,0,"gameboy.Reg_GBA_BusACC"}
gameboy.Reg_GBA_BusWriteData = {1056774,31,0,1,0,"gameboy.Reg_GBA_BusWriteData"}
gameboy.Reg_GBA_BusReadData = {1056775,31,0,1,0,"gameboy.Reg_GBA_BusReadData"}
gameboy.Reg_GBA_MaxPakAddr = {1056776,24,0,1,0,"gameboy.Reg_GBA_MaxPakAddr"}
gameboy.Reg_GBA_VsyncSpeed = {1056777,31,0,1,0,"gameboy.Reg_GBA_VsyncSpeed"}
gameboy.Reg_GBA_KeyUp = {1056778,0,0,1,0,"gameboy.Reg_GBA_KeyUp"}
gameboy.Reg_GBA_KeyDown = {1056778,1,1,1,0,"gameboy.Reg_GBA_KeyDown"}
gameboy.Reg_GBA_KeyLeft = {1056778,2,2,1,0,"gameboy.Reg_GBA_KeyLeft"}
gameboy.Reg_GBA_KeyRight = {1056778,3,3,1,0,"gameboy.Reg_GBA_KeyRight"}
gameboy.Reg_GBA_KeyA = {1056778,4,4,1,0,"gameboy.Reg_GBA_KeyA"}
gameboy.Reg_GBA_KeyB = {1056778,5,5,1,0,"gameboy.Reg_GBA_KeyB"}
gameboy.Reg_GBA_KeyL = {1056778,6,6,1,0,"gameboy.Reg_GBA_KeyL"}
gameboy.Reg_GBA_KeyR = {1056778,7,7,1,0,"gameboy.Reg_GBA_KeyR"}
gameboy.Reg_GBA_KeyStart = {1056778,8,8,1,0,"gameboy.Reg_GBA_KeyStart"}
gameboy.Reg_GBA_KeySelect = {1056778,9,9,1,0,"gameboy.Reg_GBA_KeySelect"}
gameboy.Reg_GBA_cputurbo = {1056780,0,0,1,0,"gameboy.Reg_GBA_cputurbo"} -- 1 = cpu free running, all other 16 mhz
gameboy.Reg_GBA_SramFlashEna = {1056781,0,0,1,0,"gameboy.Reg_GBA_SramFlashEna"} -- 1 = enabled, 0 = disable (disable for copy protection in some games)
gameboy.Reg_GBA_MemoryRemap = {1056782,0,0,1,0,"gameboy.Reg_GBA_MemoryRemap"} -- 1 = enabled, 0 = disable (enable for copy protection in some games)
gameboy.Reg_GBA_SaveState = {1056783,0,0,1,0,"gameboy.Reg_GBA_SaveState"}
gameboy.Reg_GBA_LoadState = {1056784,0,0,1,0,"gameboy.Reg_GBA_LoadState"}
gameboy.Reg_GBA_FrameBlend = {1056785,0,0,1,0,"gameboy.Reg_GBA_FrameBlend"} -- mix last and current frame
gameboy.Reg_GBA_Pixelshade = {1056786,2,0,1,0,"gameboy.Reg_GBA_Pixelshade"} -- pixel shade 1..4, 0 = off
gameboy.Reg_GBA_SaveStateAddr = {1056787,25,0,1,0,"gameboy.Reg_GBA_SaveStateAddr"} -- address to save/load savestate
gameboy.Reg_GBA_Rewind_on = {1056788,0,0,1,0,"gameboy.Reg_GBA_Rewind_on"}
gameboy.Reg_GBA_Rewind_active = {1056789,0,0,1,0,"gameboy.Reg_GBA_Rewind_active"}
gameboy.Reg_GBA_DEBUG_CPU_PC = {1056800,31,0,1,0,"gameboy.Reg_GBA_DEBUG_CPU_PC"}
gameboy.Reg_GBA_DEBUG_CPU_MIX = {1056801,31,0,1,0,"gameboy.Reg_GBA_DEBUG_CPU_MIX"}
gameboy.Reg_GBA_DEBUG_IRQ = {1056802,31,0,1,0,"gameboy.Reg_GBA_DEBUG_IRQ"}
gameboy.Reg_GBA_DEBUG_DMA = {1056803,31,0,1,0,"gameboy.Reg_GBA_DEBUG_DMA"}
gameboy.Reg_GBA_DEBUG_MEM = {1056804,31,0,1,0,"gameboy.Reg_GBA_DEBUG_MEM"}
gameboy.Reg_GBA_CHEAT_FLAGS = {1056810,31,0,1,0,"gameboy.Reg_GBA_CHEAT_FLAGS"}
gameboy.Reg_GBA_CHEAT_ADDRESS = {1056811,31,0,1,0,"gameboy.Reg_GBA_CHEAT_ADDRESS"}
gameboy.Reg_GBA_CHEAT_COMPARE = {1056812,31,0,1,0,"gameboy.Reg_GBA_CHEAT_COMPARE"}
gameboy.Reg_GBA_CHEAT_REPLACE = {1056813,31,0,1,0,"gameboy.Reg_GBA_CHEAT_REPLACE"}
gameboy.Reg_GBA_CHEAT_RESET = {1056814,0,0,1,0,"gameboy.Reg_GBA_CHEAT_RESET"}