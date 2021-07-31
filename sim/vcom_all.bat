
vcom -93 -quiet -work  sim/tb ^
src/tb/globals.vhd

vcom -93 -quiet -work  sim/mem ^
../rtl/SyncRam.vhd ^
../rtl/SyncRamDual.vhd ^
../rtl/SyncRamDualNotPow2.vhd ^
src/mem/SyncRamDualByteEnable.vhd ^
src/mem/SyncFifo.vhd 

vcom -quiet -work  sim/rs232 ^
src/rs232/rs232_receiver.vhd ^
src/rs232/rs232_transmitter.vhd ^
src/rs232/tbrs232_receiver.vhd ^
src/rs232/tbrs232_transmitter.vhd

vcom -quiet -work sim/procbus ^
src/procbus/proc_bus.vhd ^
src/procbus/testprocessor.vhd

vcom -quiet -work sim/reg_map ^
src/reg_map/reg_gameboy.vhd

vcom -quiet -work sim/gba ^
../rtl/proc_bus_gba.vhd ^
../rtl/cache.vhd ^
../rtl/reggba_timer.vhd ^
../rtl/reggba_keypad.vhd ^
../rtl/reggba_serial.vhd ^
../rtl/reggba_sound.vhd ^
../rtl/reggba_display.vhd ^
../rtl/reggba_dma.vhd ^
../rtl/reggba_system.vhd ^
../rtl/reg_savestates.vhd ^
../rtl/gba_bios_fast.vhd ^
../rtl/gba_reservedregs.vhd ^
../rtl/gba_sound_ch1.vhd ^
../rtl/gba_sound_ch3.vhd ^
../rtl/gba_sound_ch4.vhd ^
../rtl/gba_sound_dma.vhd ^
../rtl/gba_sound.vhd ^
../rtl/gba_joypad.vhd ^
../rtl/gba_serial.vhd ^
../rtl/gba_dma_module.vhd ^
../rtl/gba_dma.vhd ^
../rtl/gba_memorymux.vhd ^
../rtl/gba_timer_module.vhd ^
../rtl/gba_timer.vhd ^
../rtl/gba_gpu_timing.vhd ^
../rtl/gba_drawer_mode0.vhd ^
../rtl/gba_drawer_mode2.vhd ^
../rtl/gba_drawer_mode345.vhd ^
../rtl/gba_drawer_obj.vhd ^
../rtl/gba_drawer_merge.vhd ^
../rtl/gba_gpu_drawer.vhd ^
../rtl/gba_gpu_colorshade.vhd ^
../rtl/gba_gpu.vhd ^
../rtl/gba_savestates.vhd ^
../rtl/gba_statemanager.vhd ^
../rtl/gba_cheats.vhd ^
../rtl/gba_gpioRTCSolarGyro.vhd

vcom -2008 -quiet -work sim/gba ^
../rtl/gba_cpu.vhd ^
../rtl/gba_top.vhd

vlog -sv -quiet -work sim/top ^
../rtl/ddram.sv

vcom -quiet -work sim/tb ^
src/tb/stringprocessor.vhd ^
src/tb/tb_interpreter.vhd ^
src/tb/ddrram_model.vhd ^
src/tb/framebuffer.vhd ^
src/tb/framebuffer_large.vhd ^
src/tb/tb.vhd

