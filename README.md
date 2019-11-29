# GBA_MiSTer
GBA for MiSTer

# HW Requirements/Features
- Requires 32MB SDRAM for games less than 32MB. 32MB games require either 64MB or 128MB module.
- HDMI-only. Native VGA output is not implemented (yet). VGA output can be enabled with vga_scaler=1 option in MiSTer.ini, so it will output the same HDMI resolution.

# Bios
Opensource Bios from Normmatt is included, however it has issues with some games.
Original GBA BIOS can be placed to GBA folder with name boot.rom

PLEASE do not report errors without testing with the original BIOS

# Games with Crashes/Hang

- Banjo-Kazooie hangs after start. Workaround: instantly save ingame, reset the game and reload the save
- Boktai 2 hangs in language selection
- Bomberman Max 2 - Blue: black screen after intro

- Colin McRae Rally 2.0 hangs when going into race

- Iridium II: hangs at first boss

- Mobile Suit Gundam Seed Battle Assault (USA) - crashes during the intro
- Motoracer Advance (USA) : Game crashes upon starting a race.

- SuperMarioAdvance: MarioBros Minigame hangs. Same game is included  and working in Super Mario Advance 2

# Status
~200 games tested until ingame:
- 95% without major issues (no crash, playable)

# Features
- all videomodes including affine and special effects
- all soundchannels
- saving as in GBA
- turbomode

# Not included
- Multiplayer features like Serial
- GBA Module function(e.g. Boktai sun sensor)
- RTC
- probably some more
