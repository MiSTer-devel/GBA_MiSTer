
vcom -93 -quiet -work  sim/tb ^
src/tb/globals.vhd

vcom -93 -quiet -work  sim/mem ^
../src/SyncRam.vhd ^
../src/SyncRamDual.vhd ^
../src/SyncRamDualNotPow2.vhd ^
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
../src/proc_bus_gba.vhd ^
../src/cache.vhd ^
../src/reggba_timer.vhd ^
../src/reggba_keypad.vhd ^
../src/reggba_serial.vhd ^
../src/reggba_sound.vhd ^
../src/reggba_display.vhd ^
../src/reggba_dma.vhd ^
../src/reggba_system.vhd ^
../src/reg_savestates.vhd ^
../src/gba_bios_fast.vhd ^
../src/gba_reservedregs.vhd ^
../src/gba_sound_ch1.vhd ^
../src/gba_sound_ch3.vhd ^
../src/gba_sound_ch4.vhd ^
../src/gba_sound_dma.vhd ^
../src/gba_sound.vhd ^
../src/gba_joypad.vhd ^
../src/gba_serial.vhd ^
../src/gba_dma_module.vhd ^
../src/gba_dma.vhd ^
../src/gba_memorymux.vhd ^
../src/gba_timer_module.vhd ^
../src/gba_timer.vhd ^
../src/gba_gpu_timing.vhd ^
../src/gba_drawer_mode0.vhd ^
../src/gba_drawer_mode2.vhd ^
../src/gba_drawer_mode345.vhd ^
../src/gba_drawer_obj.vhd ^
../src/gba_drawer_merge.vhd ^
../src/gba_gpu_drawer.vhd ^
../src/gba_gpu_colorshade.vhd ^
../src/gba_gpu.vhd ^
../src/gba_savestates.vhd ^
../src/gba_statemanager.vhd ^
../src/gba_cheats.vhd ^
../src/gba_gpiodummy.vhd

vcom -2008 -quiet -work sim/gba ^
../src/gba_cpu.vhd ^
../src/gba_top.vhd

vlog -sv -quiet -work sim/top ^
../ddram.sv

vcom -quiet -work sim/tb ^
src/tb/stringprocessor.vhd ^
src/tb/tb_interpreter.vhd ^
src/tb/ddrram_model.vhd ^
src/tb/framebuffer.vhd ^
src/tb/tb.vhd

