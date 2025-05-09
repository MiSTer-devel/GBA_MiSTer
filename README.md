# [Gameboy Advance](https://en.wikipedia.org/wiki/Game_Boy_Advance) for [MiSTer Platform](https://github.com/MiSTer-devel/Main_MiSTer/wiki)

Accuracy branch

# HW Requirements/Features
The games can run from a naked DE10-Nano with the build-in DDR-RAM.
However, using SDRAM is highly recommended, as some games may slowdown or loose sync when using DDR-RAM.

When using SDRAM, it requires 32MB SDRAM for games less than 32MB. 32MB games require either 64MB or 128MB module.
SDRAM will be automatically used when available and size is sufficient.

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
~1600 games tested until ingame.
There is no known official game that doesn't work.
Exceptions are games that require rare extra hardware (mostly japanese).
Some small video glitches remain, see issue list.

# Features
- saving as in GBA
- Savestates
- Flickerblend - set to blend or 30Hz mode for games like F-Zero, Mario Kart or NES Classics to prevent flickering effects
- Cheats - not working yet
- Color optimizations: shader colors and desaturate
- Tilt: use analog stick (map stick in Mister Main before)
- Solar Sensor: Set brightness in OSD
- Gyro: use analog stick (map stick in Mister Main before)
- RTC: automatically used, works with RTC board or internet connection
- Rumble: for Drill Dozer, Wario Ware Twisted and some romhacks

# Savestates
Core provides 4 slots to save and restore the state. 
Those can be saved to SDCard or reside only in memory for temporary use(OSD Option). 
Usage with either Keyboard, Gamepad mappable button or OSD.

Keyboard Hotkeys for save states:
- Alt-F1..F4 - save the state
- F1...F4 - restore

Gamepad:
- Savestatebutton+Left or Right switches the savestate slot
- Savestatebutton+Down saves to the selected slot
- Savestatebutton+Up loads from the selected slot

# Cartridge Hardware supported games
- RTC: Pokemon Sapphire+Ruby+Emerald, Boktai 1+2+3, Sennen Kazoku, Rockman EXE 4.5
- Solar Sensor: Boktai 1+2+3
- Gyro: Wario Ware Twisted
- Tilt: Yoshi Topsy Turvy/Universal Gravitation, Koro Koro Puzzle - Happy Panechu!
- Rumble: Wario Ware Twisted, Drill Dozer

If there is a game you want to play that also uses one of these features, but is not listed, please open a bug request.

For romhacks you can activate the option "GPIO HACK(RTC+Rumble)". Make sure to deactivate it for other games, otherwise you will experience crashes.

# Not included
- Multiplayer features like serial communication
- E-Reader support
- Gameboy Player features
