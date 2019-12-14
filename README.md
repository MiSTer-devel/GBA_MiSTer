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

# Games with crashes/hang
- Banjo-Kazooie hangs after start. Workaround: instantly save ingame, reset the game and reload the save
- Bomberman Max 2 - Blue: black screen after intro

- Classic NES Series: controls not working

- Colin McRae Rally 2.0 hangs when going into race

- Digimon Racing: hang on 3rd screen(Griptonite)

- Fear Factor Unleashed: hang after ~4 seconds

- Madden06/06: crash at coin toss

- Iridium II: hangs at first boss -> maybe due to bad rom?

- Sennen Kazoku: hang on first screen
- Starsky & Hutch: crash going ingame
- SuperMarioAdvance: MarioBros Minigame hangs. Same game is included  and working in Super Mario Advance 2

- TOCA World Touring Cars: hangs going into race

# Games that are unplayable because of catridge hardware missing
- Boktai 1/2/Shin Bokura no Taiyou(Japanese Boktai)
- Warioware Twisted
- Yoshi's Universal Gravitation

# Status
~1600 games tested until ingame:
- 95% without major issues (no crash, playable)

# Features
- all videomodes including affine and special effects
- all soundchannels
- saving as in GBA
- turbomode

# Not included
- Multiplayer features like Serial
- Tilt/Gyro/Rumble/Sun sensor)
- RTC

# Accuracy

There is great testsuite you can get from here: https://github.com/mgba-emu/suite
It tests out correct Memory, Timer, DMA, CPU, BIOS behavior and also instruction timing. It works 100% on the real GBA.
The suite itself has several thousand single tests. Here is a comparison with mGBA, VBA-M and Higan

Testname | TestCount | Mister GBA| mGBA | VBA-M | Higan
---------|-----------|-----------|------|-------|-------
Memory   |      1552 |  1538     | 1552 |  1337 | 1552
IOREAD   |       123 |   123     |  116 |   100 |  123
Timing   |      1660 |  1408     | 1520 |   628 | 1424
Timer    |       936 |   445     |  511 |   440 |  464
Carry    |        93 |    93     |   93 |    93 |   93
BIOSMath |       625 |   625     |  625 |   425 |  625
DMATests |      1256 |  1212     | 1232 |  1008 | 1064
