# Purpose of this document

This readme shall deliver a small introduction on what the simulation can be used for and how to simulate the GBA core.

Requirements: Modelsim or compatible Simulator. Windows 7/10 for viewing gpu output.
Tested Version: Modelsim 10.5 

# Available features

The simulation framework allows:
- running ROM like on real hardware
- running ROM together with savestate
- running automated regression tests

Debugging options:
- waveform viewer in modelsim
- live graphical output
- debug output of the CPU: every register for every instruction 

Speed:
1 second realtime(FPGA) will take in the range of 1 hour in simulation. So don't expect to run deep into a game.
For specific situations, savestates can be used. 

# BIOS

The simulation can run with the opensource BIOS. 
However, it is highly recommended to use a BIOS that skips directly into the game as the simulation is MUCH slower than real hardware.
Going through the official BIOS easily takes hours in simulation.
The compile process will hint you by requiring a "gba_bios_fast.vhd".
You can copy and rename the normal "gba_bios.vhd" as a first start, but should replace it later.

# Shortcoming

- Currently the simulation runs on DDR-Ram only
- The HPS Framework/Top level is not simulated at all, Cart download is done through a debug interface
- Sound cannot be checked other than viewing waveform

# How to start

- Provide File: src/gba_bios_fast.vhd
- run sim/vmap_all.bat
- run sim/vcom_all.bat
- run sim/vsim_start.bat

Simualtion will now open. 
- Start it with "Run All" button or command
- go with a cmd tool into sim/tests
- run "luajit gba_bootrom.lua" or any other .lua testscript

Test is now running. Watch command line or waveform.

# Debug graphic

In the sim folder, there is a "graeval.exe" (sourcecode is provided)
When the simulation has run for a while and the file "gra_fb_out.gra" exsists and the size is not zero,
you can pull this file onto the graeval.exe
A new window will open and draw everything the core outputs in simulation.

# Debug CPU

The cpu will write files beginning with debug_gbasim.txt into the sim folder.
For every Million of CPU instructions, a new file it created to keep the filesize reasonable.
The header in this file will guide you what you see.

# How to simulate a specific ROM

Change the path to the ROM in the luascript "sim/tests/gba_bootrom.lua"
As the script and the simulator run in different paths, you may have to change the path or copy the file locally.