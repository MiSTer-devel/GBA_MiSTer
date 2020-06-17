# GBA_MiSTer
GBA for MiSTer

# HW Requirements/Features
The games can run from a naked DE10-Nano with the build-in DDR-RAM.
However, using SDRAM is highly recommended, as some games may slowdown or loose sync when using DDR-RAM.

When using SDRAM, it requires 32MB SDRAM for games less than 32MB. 32MB games require either 64MB or 128MB module.
SDRAM will be automatically used when available.

# Bios
Opensource Bios from Normmatt is included, however it has issues with some games.
Original GBA BIOS can be placed to GBA folder with name boot.rom

PLEASE do not report errors without testing with the original BIOS

Homebrew games are sometimes not supported by the official BIOS, 
because the BIOS checks for Nintendo Logo included in the ROM, which is protected by copyright.
To use these ROMs without renaming or removing the the boot.rom, 
you can activate the "Homebrew BIOS" settings in OSD.
As the BIOS is already replaced at boot time, you must save this settings and hard reset/reload the GBA core.

# Status
~1600 games tested until ingame:
- 99% without major issues (no crash, playable)

# Features
- all videomodes including affine and special effects
- all soundchannels
- saving as in GBA
- Savestates
- FastForward - speed up game by factor 2-4
- CPU Turbomode - give games additional CPU power
- Flickerblend - set to blend or 30Hz mode for games like F-Zero, Mario Kart or NES Classics to prevent flickering effects
- Spritelimit - turn on to prevent wrong sprites for games that rely on the limit (opt-in)
- Cheats
- Color optimizations: shader colors and desaturate
- Rewind: go back up to 60 seconds in time
- Tilt: use analog stick (map stick in Mister Main before)
- Solar Sensor: Set brightness in OSD
- Gyro: use analog stick (map stick in Mister Main before)
- RTC: automatically used, works with RTC board or internet connection
- 2x Resolution: game is rendered at 480x320 instead of 240x160 pixels

# Savestates
Core provides 4 slots to save the state. The first slot gets saved to disk and automatically loaded (but not applied)
upon next load of game. Rest 3 slots are residing only in memory for temporary use.
First slot save/restore is available from OSD as well. 


Hot keys for save states:
- Alt-F1..F4 - save the state
- F1...F4 - restore

# Rewind
To use rewind, turn on the OSD Option "Rewind Capture" and map the rewind button.
You may have to restart the game for the function to work properly.
Attention: Rewind capture will slow down your game by about 0.5% and may lead to light audio stutter.
Rewind capture is not compatible to "Pause when OSD is open", so pause is disabled when Rewind capture is on.

# Spritelimit
Currently there are only few games known that produce glitches without sprite pixel limit:
- Gunstar Super Heroes
- Famicon Mini Series Vol21 - Vol30

# 2x Resolution
Improved rendering resolution for:
- Affine background: "Mode7" games, typically racing games like Mario Kart
- Affine sprites: games that scale or rotate sprites
This rendering is experimental and can cause glitches, as not all game behavior can be supported.
Those glitches can not be fixed without gamespecific hacks and therefore will not be fixed. 
Please don't add bugs in such cases.

# Cartridge Hardware supported games
- RTC: Pokemon Sapphire+Ruby+Emerald, Boktai 1+2+3, Sennen Kazoku, Rockman EXE 4.5
- Solar Sensor: Boktai 1+2+3
- Gyro: Wario Ware Twisted
- Tilt: Yoshi Topsy Turvy/Universal Gravitation, Koro Koro Puzzle - Happy Panechu!

If there is a game you want to play that also uses one of these features, but is not listed, please open a bug request.

# Not included
- Multiplayer features like Serials
- E-Reader support
- other cartridge hardware

# Accuracy

(Status 03.02.2020)

>> Attention: the following comparisons are NOT intended for proving any solution is better than the other.
>> This is solely here for the purpose of showing the status compared to other great emulators available.
>> It is not unusual that an emulator can play games fine and still fail tests. 
>> Furthermore some of these tests are new and not yet addressed by most emulators.

There is great testsuite you can get from here: https://github.com/mgba-emu/suite
It tests out correct Memory, Timer, DMA, CPU, BIOS behavior and also instruction timing. It works 100% on the real GBA.
The suite itself has several thousand single tests.

Testname      | TestCount | Mister GBA| mGBA | VBA-M | Higan
--------------|-----------|-----------|------|-------|-------
Memory        |      1552 |  1552     | 1552 |  1338 | 1552
IOREAD        |       123 |   123     |  116 |   100 |  123
Timing        |      1660 |  1554     | 1540 |   692 | 1424
Timer         |       936 |   445     |  610 |   440 |  457
Timer IRQ     |        90 |    65     |   70 |     8 |   36
Shifter       |       140 |   140     |  140 |   132 |  132
Carry         |        93 |    93     |   93 |    93 |   93
BIOSMath      |       625 |   625     |  625 |   625 |  625
DMATests      |      1256 |  1248     | 1232 |  1032 | 1136
EdgeCase      |        10 |     3     |    7 |     3 |    1
Layer Toggle  |         1 |  pass     | pass |  pass | fail 
OAM Update    |         1 |  fail     | fail |  fail | fail


A complex CPU only testuite can be found here: https://github.com/jsmolka/gba-suite

Testname | Mister GBA| mGBA | VBA-M | Higan
---------|-----------|------|-------|-------
ARM      |  Pass     | Fail |  Fail |  Fail
THUMB    |  Pass     | Fail |  Fail |  Fail

# Information for developers

How to simulate:
https://github.com/MiSTer-devel/GBA_MiSTer/tree/master/sim

How to implement a GPIO module:
https://github.com/MiSTer-devel/GBA_MiSTer/blob/master/gpio_readme.md
