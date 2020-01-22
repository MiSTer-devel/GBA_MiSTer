RMDIR /s /q sim
MKDIR sim

vlib sim/mem
vmap mem sim/mem

vlib sim/rs232
vmap rs232 sim/rs232

vlib sim/procbus
vmap procbus sim/procbus

vlib sim/reg_map
vmap reg_map sim/reg_map

vlib sim/softcore
vmap softcore sim/softcore

vlib sim/vga
vmap vga sim/vga

vlib sim/ps2
vmap ps2 sim/ps2

vlib sim/sdram
vmap sdram sim/sdram

vlib sim/specialcore
vmap specialcore sim/specialcore

vlib sim/sdcard
vmap sdcard sim/sdcard

vlib sim/audio
vmap audio sim/audio

vlib sim/gameboy
vmap gameboy sim/gameboy

vlib sim/gba
vmap gba sim/gba

vlib sim/top
vmap top sim/top

vlib sim/tb
vmap tb sim/tb

