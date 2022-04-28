//============================================================================
//  GBA
//  Copyright (C) 2019 Robert Peip
//
//  Port to MiSTer
//  Copyright (C) 2019 Sorgelig
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [48:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM (USE_FB=1 in qsf)
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);

assign ADC_BUS  = 'Z;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign USER_OUT = '1;

assign AUDIO_S   = 1;
assign AUDIO_MIX = status[8:7];

assign LED_USER  = cart_download | bk_pending;
assign LED_DISK  = 0;
assign LED_POWER = 0;
assign BUTTONS   = 0;
assign VGA_SCALER= 0;
assign HDMI_FREEZE=0;

assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;

assign FB_EN      = status[21] || status[22];
assign FB_FORMAT  = 5'b00110;
assign FB_WIDTH   = 12'd480;
assign FB_HEIGHT  = 12'd320;
assign FB_STRIDE  = 0;
assign FB_FORCE_BLANK = 0;


///////////////////////  CLOCK/RESET  ///////////////////////////////////

wire pll_locked;
wire clk_sys;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_sys),
	.outclk_1(CLK_VIDEO),
	.locked(pll_locked)
);

wire reset = RESET | buttons[1] | status[0] | cart_download | bk_loading | hold_reset;

////////////////////////////  HPS I/O  //////////////////////////////////

// Status Bit Map: (0..31 => "O", 32..63 => "o")
// 0         1         2         3          4         5         6
// 01234567890123456789012345678901 23456789012345678901234567890123
// 0123456789ABCDEFGHIJKLMNOPQRSTUV 0123456789ABCDEFGHIJKLMNOPQRSTUV
// X XXXXXXXXXRXXXXXXX XXXXXXXXXXXX XXXXXXXX

`include "build_id.v"
parameter CONF_STR = {
	"GBA;SS3E000000:80000;",
	"FS,GBA,Load,300C0000;",
	"-;",
	"C,Cheats;",
	"H1O6,Cheats Enabled,Yes,No;",
	"-;",
	"D0RC,Reload Backup RAM;",
	"D0RD,Save Backup RAM;",
	"D0ON,Autosave,Off,On;",
	"D0-;",
	"o4,Savestates to SDCard,On,Off;",
	"o56,Savestate Slot,1,2,3,4;",
	"h4H3RH,Save state (Alt-F1);",
	"h4H3RI,Restore state (F1);",
	"-;",
	"P1,Video & Audio;",
	"P1-;",
	"P1o01,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"P1O24,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"P1o23,Scale,Normal,V-Integer,Narrower HV-Integer,Wider HV-Integer;",
	"P1-;",
	"P1OOQ,Modify Colors,Off,GBA 2.2,GBA 1.6,NDS 1.6,VBA 1.4,75%,50%,25%;",
	"P1-;",
	"P1o7,Sync core to video,On,Off;",
	"P1O9A,Flickerblend,Off,Blend,30Hz;",
	"P1OLM,2XResolution,Off,Background,Sprites,Both;",
	"P1OK,Spritelimit,Off,On;",	
	"P1-;",
	"P1O78,Stereo Mix,None,25%,50%,100%;",

	"P2,Hardware;",
	"P2-;",
	"H6P2OTV,Solar Sensor,0%,15%,30%,42%,55%,70%,85%,100%;",	
	"H2P2OG,Turbo,Off,On;",
	"P2OS,Homebrew BIOS(Reset!),Off,On;",

	"P3,Miscellaneous;",
	"P3-;",
	"P3OEF,Storage,Auto,SDRAM,DDR3;",
	"D5P3O5,Pause when OSD is open,Off,On;",
	"P3OR,Rewind Capture,Off,On;",

	"- ;",
	"R0,Reset;",
	"J1,A,B,L,R,Select,Start,FastForward,Rewind,Savestates;",
	"jn,A,B,L,R,Select,Start,X,X;",
	"I,",
	"Slot=DPAD|Save/Load=Start+DPAD,",
	"Active Slot 1,",
	"Active Slot 2,",
	"Active Slot 3,",
	"Active Slot 4,",
	"Save to state 1,",
	"Restore state 1,",
	"Save to state 2,",
	"Restore state 2,",
	"Save to state 3,",
	"Restore state 3,",
	"Save to state 4,",
	"Restore state 4,",
	"Rewinding...;",
	"V,v",`BUILD_DATE
};

wire  [1:0] buttons;
wire [63:0] status;
wire [15:0] status_menumask = {~solar_quirk, status[27], cart_loaded, |cart_type, force_turbo, ~gg_active, ~bk_ena};
wire        forced_scandoubler;
reg  [31:0] sd_lba;
reg         sd_rd = 0;
reg         sd_wr = 0;
wire        sd_ack;
wire  [7:0] sd_buff_addr;
wire [15:0] sd_buff_dout;
wire [15:0] sd_buff_din;
wire        sd_buff_wr;
wire        img_mounted;
wire        img_readonly;
wire [63:0] img_size;
wire        ioctl_download;
wire [26:0] ioctl_addr;
wire [15:0] ioctl_dout;
wire        ioctl_wr;
wire  [7:0] ioctl_index;
reg         ioctl_wait = 0;
wire [15:0] joy_rumble;

wire [15:0] joy;
wire [15:0] joy_unmod;
wire [10:0] ps2_key;

wire [21:0] gamma_bus;
wire [15:0] sdram_sz;

wire [15:0] joystick_analog_0;

wire [32:0] RTC_time;

wire [63:0] status_in = cart_download ? {status[63:39],ss_slot,status[36:17],1'b0,status[15:0]} : {status[63:39],ss_slot,status[36:0]};

hps_io #(.CONF_STR(CONF_STR), .WIDE(1)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.buttons(buttons),
	.forced_scandoubler(forced_scandoubler),

	.joystick_0(joy_unmod),
	.joystick_0_rumble(joy_rumble),
	.ps2_key(ps2_key),

	.status(status),
	.status_in(status_in),
	.status_set(cart_download | statusUpdate),
	.status_menumask(status_menumask),
	.info_req(ss_info_req),
	.info(ss_info),

	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_wr(ioctl_wr),
	.ioctl_download(ioctl_download),
	.ioctl_index(ioctl_index),
	.ioctl_wait(ioctl_wait),

	.sd_lba('{sd_lba}),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(sd_ack),
	.sd_buff_addr(sd_buff_addr),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_din('{sd_buff_din}),
	.sd_buff_wr(sd_buff_wr),

	.TIMESTAMP(RTC_time),

	.img_mounted(img_mounted),
	.img_readonly(img_readonly),
	.img_size(img_size),

	.sdram_sz(sdram_sz),
	.gamma_bus(gamma_bus),

   .joystick_l_analog_0(joystick_analog_0)
);

assign joy = joy_unmod[12] ? 16'b0 : joy_unmod;

//////////////////////////  ROM DETECT  /////////////////////////////////

reg code_download, bios_download, cart_download;
always @(posedge clk_sys) begin
	code_download <= ioctl_download & &ioctl_index;
	bios_download <= ioctl_download & !ioctl_index;
	cart_download <= ioctl_download & ~&ioctl_index & |ioctl_index;
end

reg [26:0] last_addr;
reg        flash_1m;
reg  [1:0] cart_type;
reg        cart_loaded = 0;
always @(posedge clk_sys) begin
	reg [63:0] str;
	reg old_download;

	old_download <= cart_download;
	if (old_download & ~cart_download) last_addr <= ioctl_addr;

	if (~ioctl_download && ioctl_download_1 && ioctl_index == 1) begin
		flash_1m <= 0;
		cart_type <= ioctl_index[7:6];
		cart_loaded <= 1;
	end

	if(rom_wr) begin
		if({str, rom_dout[7:0]} == "FLASH1M_V") flash_1m <= 1;
		if({str[55:0], rom_dout[7:0], rom_dout[15:8]} == "FLASH1M_V") flash_1m <= 1;

		str <= {str[47:0], rom_dout[7:0], rom_dout[15:8]};
	end
end

wire force_turbo = |cart_type;

reg [11:0] bios_wraddr;
reg [31:0] bios_wrdata;
reg        bios_wr;
always @(posedge clk_sys) begin
	bios_wr <= 0;
	if(bios_download & ioctl_wr & ~status[28]) begin
		if(~ioctl_addr[1]) bios_wrdata[15:0] <= ioctl_dout;
		else begin
			bios_wrdata[31:16] <= ioctl_dout;
			bios_wraddr <= ioctl_addr[13:2];
			bios_wr <= 1;
		end
	end
end

///////////////////////////  SAVESTATE  /////////////////////////////////

wire [1:0] ss_slot;
wire [7:0] ss_info;
wire ss_save, ss_load, ss_info_req;
wire statusUpdate;

savestate_ui savestate_ui
(
	.clk            (clk_sys       ),
	.ps2_key        (ps2_key[10:0] ),
	.allow_ss       (cart_loaded   ),
	.joySS          (joy_unmod[12] ),
	.joyRight       (joy_unmod[0]  ),
	.joyLeft        (joy_unmod[1]  ),
	.joyDown        (joy_unmod[2]  ),
	.joyUp          (joy_unmod[3]  ),
	.joyStart       (joy_unmod[9]  ),
	.joyRewind      (joy_unmod[11] ),
	.rewindEnable   (status[27]    ), 
	.status_slot    (status[38:37] ),
	.OSD_saveload   (status[18:17] ),
	.ss_save        (ss_save       ),
	.ss_load        (ss_load       ),
	.ss_info_req    (ss_info_req   ),
	.ss_info        (ss_info       ),
	.statusUpdate   (statusUpdate  ),
	.selected_slot  (ss_slot       )
);
defparam savestate_ui.INFO_TIMEOUT_BITS = 27;

////////////////////////////  SYSTEM  ///////////////////////////////////

wire save_eeprom, save_sram, save_flash, ss_loaded;

reg fast_forward, pause, cpu_turbo;
reg ff_latch;

always @(posedge clk_sys) begin : ffwd
	reg last_ffw;
	reg ff_was_held;
	longint ff_count;

	last_ffw <= joy[10];

	if (joy[10])
		ff_count <= ff_count + 1;

	if (~last_ffw & joy[10]) begin
		ff_latch <= 0;
		ff_count <= 0;
	end

	if ((last_ffw & ~joy[10])) begin // 100mhz clock, 0.2 seconds
		ff_was_held <= 0;

		if (ff_count < 10000000 && ~ff_was_held) begin
			ff_was_held <= 1;
			ff_latch <= 1;
		end
	end

	fast_forward <= (joy[10] | ff_latch) & ~force_turbo;
	pause <= force_pause | (status[5] & OSD_STATUS & ~status[27]); // pause from "sync to core" or "pause in osd", but not if rewind capture is on
	cpu_turbo <= ((status[16] & ~fast_forward) | force_turbo) & ~pause;
end

reg [79:0] time_dout = 41'd0;
wire [79:0] time_din;
assign time_din[42 + 32 +: 80 - (42 + 32)] = '0;

wire has_rtc;
wire cart_rumble;
reg RTC_load = 0;

reg [7:0] rumble_reg = 0;

always @(posedge clk_sys) begin
	rumble_reg <= (cart_rumble ? 8'd128 : 8'd0);
end

assign joy_rumble = {8'd0, rumble_reg};

gba_top
#(
   // assume: cart may have either flash or eeprom, not both! (need to verify)
	.Softmap_GBA_FLASH_ADDR  (0),                   // 131072 (8bit)  -- 128 Kbyte Data for GBA Flash
	.Softmap_GBA_EEPROM_ADDR (0),                   //   8192 (8bit)  --   8 Kbyte Data for GBA EEProm
	.Softmap_GBA_WRam_ADDR   (131072),              //  65536 (32bit) -- 256 Kbyte Data for GBA WRam Large
	.Softmap_GBA_Gamerom_ADDR(65536+131072),        //   32MB of ROM
	.Softmap_SaveState_ADDR  (58720256),            // 65536 (64bit) -- ~512kbyte Data for SaveState (separate memory)
	.Softmap_Rewind_ADDR     (33554432),            // 65536 qwords*64 -- 64*512 Kbyte Data for Savestates
	.turbosound('1)                                 // sound buffer to play sound in turbo mode without sound pitched up
)
gba
(
	.clk100(clk_sys),
	.GBA_on(~reset && ~romcopy_active),  // switching from off to on = reset
	.GBA_lockspeed(~fast_forward),       // 1 = 100% speed, 0 = max speed
	.GBA_cputurbo(cpu_turbo),
	.GBA_flash_1m(flash_1m),          // 1 when string "FLASH1M_V" is anywhere in gamepak
	.CyclePrecalc(pause ? 16'd0 : 16'd100), // 100 seems to be ok to keep fullspeed for all games
	.MaxPakAddr(last_addr[26:2]),     // max byte address that will contain data, required for buggy games that read behind their own memory, e.g. zelda minish cap
	.CyclesMissing(),                 // debug only for speed measurement, keep open
	.CyclesVsyncSpeed(),              // debug only for speed measurement, keep open
	.SramFlashEnable(~sram_quirk),
	.memory_remap(memory_remap_quirk),
   .increaseSSHeaderCount(!status[36]),
   .save_state(ss_save),
   .load_state(ss_load),
   .interframe_blend(status[10:9]),
   .maxpixels(status[20] | sprite_quirk),
   .hdmode2x_bg(status[21]),
   .hdmode2x_obj(status[22]),
   .shade_mode(shadercolors),
	.specialmodule(gpio_quirk),
	.solar_in(status[31:29]),
	.tilt(tilt_quirk),
   .rewind_on(status[27]),
   .rewind_active(status[27] & joy[11]),
   .savestate_number(ss_slot),

   .RTC_timestampNew(RTC_time[32]),
   .RTC_timestampIn(RTC_time[31:0]),
   .RTC_timestampSaved(time_dout[42 +: 32]),
   .RTC_savedtimeIn(time_dout[0 +: 42]),
   .RTC_saveLoaded(RTC_load),
   .RTC_timestampOut(time_din[42 +: 32]),
   .RTC_savedtimeOut(time_din[0 +: 42]),
   .RTC_inuse(has_rtc),

   .cheat_clear(gg_reset),
   .cheats_enabled(~status[6]),
   .cheat_on(gg_valid),
   .cheat_in(gg_code),
   .cheats_active(gg_active),

	.sdram_read_ena(sdram_req),       // triggered once for read request
	.sdram_read_done(sdram_ack),      // must be triggered once when sdram_read_data is valid after last read
	.sdram_read_addr(sdram_addr),     // all addresses are DWORD addresses!
	.sdram_read_data(sdram_dout1),    // data from last request, valid when done = 1
	.sdram_second_dword(sdram_dout2), // second dword to be read for buffering/prefetch. Must be valid 1 cycle after done = 1

	.bus_out_Din(bus_din),            // data read from WRam Large, SRAM/Flash/EEPROM
	.bus_out_Dout(bus_dout),          // data written to WRam Large, SRAM/Flash/EEPROM
	.bus_out_Adr(bus_addr),           // all addresses are DWORD addresses!
	.bus_out_rnw(bus_rd),             // read = 1, write = 0
	.bus_out_ena(bus_req),            // one cycle high for each action
	.bus_out_done(bus_ack),           // should be one cycle high when write is done or read value is valid

   .SAVE_out_Din(ss_din),            // data read from savestate
   .SAVE_out_Dout(ss_dout),          // data written to savestate
   .SAVE_out_Adr(ss_addr),           // all addresses are DWORD addresses!
   .SAVE_out_rnw(ss_rnw),            // read = 1, write = 0
   .SAVE_out_ena(ss_req),            // one cycle high for each action
   .SAVE_out_be(ss_be),              
   .SAVE_out_done(ss_ack),           // should be one cycle high when write is done or read value is valid

	.save_eeprom(save_eeprom),
	.save_sram(save_sram),
	.save_flash(save_flash),
	.load_done(ss_loaded),

	.bios_wraddr(bios_wraddr),
	.bios_wrdata(bios_wrdata),
	.bios_wr(bios_wr),

	.KeyA(joy[4]),
	.KeyB(joy[5]),
	.KeySelect(joy[8]),
	.KeyStart(joy[9]),
	.KeyRight(joy[0]),
	.KeyLeft(joy[1]),
	.KeyUp(joy[3]),
	.KeyDown(joy[2]),
	.KeyR(joy[7]),
	.KeyL(joy[6]),
	.AnalogTiltX(joystick_analog_0[7:0]),
	.AnalogTiltY(joystick_analog_0[15:8]),
	.Rumble(cart_rumble),

	.pixel_out_addr(pixel_addr),      // integer range 0 to 38399;       -- address for framebuffer
	.pixel_out_data(pixel_data),      // RGB data for framebuffer
	.pixel_out_we(pixel_we),          // new pixel for framebuffer

   .largeimg_out_base(FB_BASE),
   .largeimg_out_addr(fb_addr),
   .largeimg_out_data(fb_din),
   .largeimg_out_req(fb_req),
   .largeimg_out_done(fb_ack),
   .largeimg_newframe(FB_VBL),
   .largeimg_singlebuf(FB_LL),

	.sound_out_left(AUDIO_L),
	.sound_out_right(AUDIO_R)
);

////////////////////////////  QUIRKS  //////////////////////////////////

reg sram_quirk = 0;            // game tries to use SRAM as emulation detection. This bit forces to pretent we have no SRAM
reg memory_remap_quirk = 0;    // game uses memory mirroring, e.g. access 4Mbyte but is only 1 Mbyte. 
reg gpio_quirk = 0;            // game exchanges some addresses to be GPIO lines for e.g. Solar or RTC
reg tilt_quirk = 0;            // game exchanges some addresses to be Tilt module
reg solar_quirk = 0;           // game has solar module
reg sprite_quirk = 0;          // game depends on using max sprite pixels per line, otherwise glitches appear
always @(posedge clk_sys) begin
	reg [31:0] cart_id;

	if (~ioctl_download && ioctl_download_1 && ioctl_index == 1) begin
      sram_quirk         <= 0;
      memory_remap_quirk <= 0;
      gpio_quirk         <= 0;
      tilt_quirk         <= 0;
      solar_quirk        <= 0;
      sprite_quirk       <= 0;
   end

	if(rom_wr) begin
		if(rom_addr[26:4] == 'hA) begin
			if(rom_addr[3:0] >= 12) cart_id[{4'd14 - rom_addr[3:0], 3'd0} +:16] <= {rom_dout[7:0],rom_dout[15:8]};
		end
		if(rom_addr == 'hB0) begin
			if(cart_id[31:8] == "AR8") begin sram_quirk <= 1;                                             end // Rocky US
			if(cart_id[31:8] == "ARO") begin sram_quirk <= 1;                                             end // Rocky EU
			if(cart_id[31:8] == "ALG") begin sram_quirk <= 1;                                             end // Dragon Ball Z - The Legacy of Goku
			if(cart_id[31:8] == "ALF") begin sram_quirk <= 1;                                             end // Dragon Ball Z - The Legacy of Goku II
			if(cart_id[31:8] == "BLF") begin sram_quirk <= 1;                                             end // 2 Games in 1 - Dragon Ball Z - The Legacy of Goku I & II
			if(cart_id[31:8] == "BDB") begin sram_quirk <= 1;                                             end // Dragon Ball Z - Taiketsu
			if(cart_id[31:8] == "BG3") begin sram_quirk <= 1;                                             end // Dragon Ball Z - Buu's Fury
			if(cart_id[31:8] == "BDV") begin sram_quirk <= 1;                                             end // Dragon Ball Z - Advanced Adventure
			if(cart_id[31:8] == "A2Y") begin sram_quirk <= 1;                                             end // Top Gun - Combat Zones
			if(cart_id[31:8] == "AI2") begin sram_quirk <= 1;                                             end // Iridion II
			if(cart_id[31:8] == "BPE") begin gpio_quirk <= 1;                                             end // POKEMON Emerald
			if(cart_id[31:8] == "AXV") begin gpio_quirk <= 1;                                             end // POKEMON Ruby
			if(cart_id[31:8] == "AXP") begin gpio_quirk <= 1;                                             end // POKEMON Sapphire
			if(cart_id[31:8] == "RZW") begin gpio_quirk <= 1;                                             end // WarioWare Twisted
			if(cart_id[31:8] == "BKA") begin gpio_quirk <= 1;                                             end // Sennen Kazoku
			if(cart_id[31:8] == "BR4") begin gpio_quirk <= 1;                                             end // Rockman EXE 4.5
			if(cart_id[31:8] == "BHG") begin                                           sprite_quirk <= 1; end // Gunstar Super Heroes
			if(cart_id[31:8] == "BGX") begin                                           sprite_quirk <= 1; end // Gunstar Super Heroes
			if(cart_id[31:24] == "K")  begin tilt_quirk <= 1;                                             end // All tilt sensor games
			if(cart_id[31:24] == "U")  begin gpio_quirk <= 1; solar_quirk <= 1;                           end // All solar sensor games
			if(cart_id[31:24] == "F")  begin
				sram_quirk <= 1; memory_remap_quirk <= 1;                                    // All Classic NES / Famicom Mini games
				if(cart_id == "FSDJ" ) begin                          sprite_quirk <= 1; end // Famicom Mini 30 - SD Gundam World - Gachapon Senshi Scramble Wars
				if(cart_id == "FADJ" ) begin                          sprite_quirk <= 1; end // Famicom Mini 29 - Akumajou Dracula
				if(cart_id == "FTUJ" ) begin memory_remap_quirk <= 0; sprite_quirk <= 1; end // Famicom Mini 28 - Famicom Tantei Club Part II - Ushiro ni Tatsu Shoujo - Zen, Kouhen
				if(cart_id == "FTKJ" ) begin memory_remap_quirk <= 0; sprite_quirk <= 1; end // Famicom Mini 27 - Famicom Tantei Club - Kieta Koukeisha - Zen, Kouhen
				if(cart_id == "FFMJ" ) begin memory_remap_quirk <= 0; sprite_quirk <= 1; end // Famicom Mini 26 - Famicom Mukashibanashi - Shin Onigashima - Zen, Kouhen
				if(cart_id == "FLBJ" ) begin memory_remap_quirk <= 0; sprite_quirk <= 1; end // Famicom Mini 25 - The Legend of Zelda 2 - Link no Bouken
				if(cart_id == "FPTJ" ) begin memory_remap_quirk <= 0; sprite_quirk <= 1; end // Famicom Mini 24 - Hikari Shinwa - Palthena no Kagami
				if(cart_id == "FMRJ" ) begin memory_remap_quirk <= 0; sprite_quirk <= 1; end // Famicom Mini 23 - Metroid
				if(cart_id == "FNMJ" ) begin memory_remap_quirk <= 0; sprite_quirk <= 1; end // Famicom Mini 22 - Nazo no Murasame Jou
				if(cart_id == "FM2J" ) begin                          sprite_quirk <= 1; end // Famicom Mini 21 - Super Mario Bros. 2
			end
		end
	end
end

////////////////////////////  MEMORY  ///////////////////////////////////

localparam ROM_START = (65536+131072)*4;

reg sdram_en;
always @(posedge clk_sys) if(reset) sdram_en <= (!status[15:14]) ? |sdram_sz[2:0] : status[14];


wire [25:2] sdram_addr;
wire [31:0] sdram_dout1 = sdram_en ? sdr_sdram_dout1 : ddr_sdram_dout1;
wire [31:0] sdram_dout2 = sdram_en ? sdr_sdram_dout2 : ddr_sdram_dout2;
wire        sdram_ack   = sdram_en ? sdr_sdram_ack   : ddr_sdram_ack;
wire        sdram_req;

wire [25:2] bus_addr;
wire [31:0] bus_din;
wire [31:0] bus_dout = sdram_en ? sdr_bus_dout : ddr_bus_dout;
wire        bus_ack  = sdram_en ? sdr_bus_ack  : ddr_bus_ack;
wire        bus_rd, bus_req;

wire [31:0] sdr_sdram_dout1, sdr_sdram_dout2, sdr_bus_dout;
wire [15:0] sdr_bram_din;
wire        sdr_sdram_ack, sdr_bus_ack, sdr_bram_ack;

wire [27:2] fb_addr;
wire [63:0] fb_din;
wire        fb_req;
wire        fb_ack;

sdram sdram
(
	.*,
	.init(~pll_locked),
	.clk(clk_sys),

	.ch1_addr({sdram_addr, 1'b0}),
	.ch1_din(16'b0),
	.ch1_dout({sdr_sdram_dout2, sdr_sdram_dout1}),
	.ch1_req(sdram_req & sdram_en),
	.ch1_rnw(cart_download ? 1'b0     : 1'b1     ),
	.ch1_ready(sdr_sdram_ack),

	.ch2_addr(romcopysd_active ? romcopy_writepos[26:1]+ROM_START[26:1] : {bus_addr, 1'b0}),
	.ch2_din(romcopysd_active ? romcopy_data : bus_din),
	.ch2_dout(sdr_bus_dout),
	.ch2_req(romcopysd_active ? romcopysd_req : ~cart_download & bus_req & sdram_en),
	.ch2_rnw(romcopysd_active ? 1'b0 : bus_rd),
	.ch2_ready(sdr_bus_ack),

	.ch3_addr({sd_lba[7:0],bram_addr}),
	.ch3_din(bram_dout),
	.ch3_dout(sdr_bram_din),
	.ch3_req(bram_req & sdram_en),
	.ch3_rnw(~bk_loading || extra_data_addr),
	.ch3_ready(sdr_bram_ack)
);

always @(posedge clk_sys) begin
	if(cart_download) begin
		if(ioctl_wr)  ioctl_wait <= 1;
		if(sdram_ack) ioctl_wait <= 0;
	end
	else ioctl_wait <= 0;
end

wire [31:0] ddr_sdram_dout1, ddr_sdram_dout2, ddr_bus_dout;
wire [15:0] ddr_bram_din;
wire        ddr_sdram_ack, ddr_bus_ack, ddr_bram_ack;

wire [63:0] ss_dout, ss_din;
wire [27:2] ss_addr;
wire [7:0]  ss_be;
wire        ss_rnw, ss_req, ss_ack;

assign DDRAM_CLK = clk_sys;
ddram ddram
(
	.*,

	.ch1_addr(romcopy_active ? romcopy_readpos[26:1]+ROM_START[26:1] : {sdram_addr, 1'b0}),
	.ch1_din(16'b0),
	.ch1_dout({ddr_sdram_dout2, ddr_sdram_dout1}),
	.ch1_req(romcopy_active ? romcopy_ddrreq : sdram_req & ~sdram_en),
	.ch1_rnw(1'b1),
	.ch1_ready(ddr_sdram_ack),

	.ch2_addr({bus_addr, 1'b0}),
	.ch2_din(bus_din),
	.ch2_dout(ddr_bus_dout),
	.ch2_req(~cart_download & bus_req & ~sdram_en),
	.ch2_rnw(bus_rd),
	.ch2_ready(ddr_bus_ack),

	.ch3_addr({sd_lba[7:0],bram_addr}),
	.ch3_din(bram_dout),
	.ch3_dout(ddr_bram_din),
	.ch3_req(bram_req & ~sdram_en),
	.ch3_rnw(~bk_loading || extra_data_addr),
	.ch3_ready(ddr_bram_ack),

	.ch4_addr({ss_addr, 1'b0}),
	.ch4_din(ss_din),
	.ch4_dout(ss_dout),
	.ch4_req(ss_req),
	.ch4_rnw(ss_rnw),
	.ch4_be(ss_be),
	.ch4_ready(ss_ack),
   
   .ch5_addr({fb_addr, 1'b0}),
   .ch5_din(fb_din),
   .ch5_req(fb_req),
   .ch5_ready(fb_ack)
   
);

///////////////// copy rom data from ddrram to sdram

localparam STATE_ROMCOPY_IDLE = 0;
localparam STATE_ROMCOPY_READ = 1;
localparam STATE_ROMCOPY_WAIT = 2;
localparam STATE_ROMCOPY_ACK  = 3;
reg[1:0]  romcopy_state = 0;
reg       romcopy_active = 0;
reg[26:0] romcopy_size;
reg[26:0] romcopy_readpos; 
reg       romcopy_ddrreq = 0; 

always @(posedge clk_sys) begin

   romcopy_ddrreq <= 0;

	case (romcopy_state)
      STATE_ROMCOPY_IDLE : begin
         if (~ioctl_download && ioctl_download_1 && ioctl_index == 1) begin
            romcopy_state   <= STATE_ROMCOPY_READ;
            romcopy_size    <= ioctl_addr;
            romcopy_readpos <= 0;
            romcopy_active  <= 1;
         end
      end
      
      STATE_ROMCOPY_READ : begin
         if (romcopy_readpos >= romcopy_size) begin
            romcopy_state  <= STATE_ROMCOPY_IDLE;
            romcopy_active <= 0;
         end else begin 
            romcopy_ddrreq <= 1;
            romcopy_state  <= STATE_ROMCOPY_WAIT;
         end
      end
      
      STATE_ROMCOPY_WAIT : begin
         if (ddr_sdram_ack) begin
            romcopy_readpos <= romcopy_readpos + 4'd8;
            romcopy_state   <= STATE_ROMCOPY_ACK; 
         end
      end
      
      STATE_ROMCOPY_ACK : begin
         if (romcopysd_state == STATE_ROMCOPYSD_IDLE) begin
            romcopy_state <= STATE_ROMCOPY_READ;
         end
      end
   endcase
end

localparam STATE_ROMCOPYSD_IDLE   = 0;
localparam STATE_ROMCOPYSD_WAIT1  = 1;
localparam STATE_ROMCOPYSD_WAIT2  = 2;
reg[1:0]   romcopysd_state = 0;
reg[26:0]  romcopy_writepos; 
reg        romcopysd_active = 0;
reg        romcopysd_req = 0; 
reg[31:0]  romcopy_data; 
reg[31:0]  romcopy_datanext; 

reg [2:0]  rom_state;
reg [26:0] rom_addr;
reg [26:0] rom_addrnext;
reg [15:0] rom_dout;
reg [63:0] rom_data;
reg        rom_wr = 0;

always @(posedge clk_sys) begin

   romcopysd_req <= 0;

	case (romcopysd_state)
      STATE_ROMCOPYSD_IDLE : begin
         if (ioctl_download && ~ioctl_download_1 && ioctl_index == 1) begin
            romcopy_writepos <= 0;
         end
         if (romcopy_state == STATE_ROMCOPY_ACK) begin
            romcopysd_state  <= STATE_ROMCOPYSD_WAIT1;
            romcopysd_active <= 1;
            romcopysd_req    <= sdram_en;
            romcopy_data     <= ddr_sdram_dout1;
            romcopy_datanext <= ddr_sdram_dout2;
            
            rom_state        <= 4;
            rom_data         <= {ddr_sdram_dout2, ddr_sdram_dout1};
            rom_addrnext     <= romcopy_writepos;
         end
      end
      
      STATE_ROMCOPYSD_WAIT1 : begin
         if (sdr_bus_ack || ~sdram_en) begin
            romcopy_writepos <= romcopy_writepos + 3'd4;
            romcopysd_state  <= STATE_ROMCOPYSD_WAIT2;
            romcopysd_req    <= sdram_en;
            romcopy_data     <= romcopy_datanext;
         end
      end
      
      STATE_ROMCOPYSD_WAIT2 : begin
         if (sdr_bus_ack || ~sdram_en) begin
            romcopy_writepos <= romcopy_writepos + 3'd4;
            romcopysd_state  <= STATE_ROMCOPYSD_IDLE;
            romcopysd_active <= 0;
         end
      end
   endcase
   
   // rebuild download bus for flash1M and quirk detection 
   rom_wr <= 0;
   if (rom_state > 0) begin
      rom_state     <= rom_state - 1'd1;
      rom_wr        <= 1;
      rom_dout      <= rom_data[15:0];
      rom_addr      <= rom_addrnext;
      rom_addrnext  <= rom_addrnext + 2'd2;
      rom_data      <= {16'b0, rom_data[63:16]};
   end
end

/////////////////

wire [127:0] time_din_h = {32'd0, time_din, "RT"};
wire [15:0] bram_dout;
wire [15:0] bram_din = sdram_en ? sdr_bram_din : ddr_bram_din;
wire        bram_ack = sdram_en ? sdr_bram_ack : ddr_bram_ack;
assign sd_buff_din = extra_data_addr ? (time_din_h[{sd_buff_addr[2:0], 4'b0000} +: 16]) : bram_buff_out;
wire [15:0] bram_buff_out;

altsyncram	altsyncram_component
(
	.address_a (bram_addr),
	.address_b (sd_buff_addr),
	.clock0 (clk_sys),
	.clock1 (clk_sys),
	.data_a (bram_din),
	.data_b (sd_buff_dout),
	.wren_a (~bk_loading & bram_ack),
	.wren_b (sd_buff_wr && ~extra_data_addr),
	.q_a (bram_dout),
	.q_b (bram_buff_out),
	.byteena_a (1'b1),
	.byteena_b (1'b1),
	.clocken0 (1'b1),
	.clocken1 (1'b1),
	.rden_a (1'b1),
	.rden_b (1'b1)
);
defparam
	altsyncram_component.address_reg_b = "CLOCK1",
	altsyncram_component.clock_enable_input_a = "BYPASS",
	altsyncram_component.clock_enable_input_b = "BYPASS",
	altsyncram_component.clock_enable_output_a = "BYPASS",
	altsyncram_component.clock_enable_output_b = "BYPASS",
	altsyncram_component.indata_reg_b = "CLOCK1",
	altsyncram_component.intended_device_family = "Cyclone V",
	altsyncram_component.lpm_type = "altsyncram",
	altsyncram_component.numwords_a = 256,
	altsyncram_component.numwords_b = 256,
	altsyncram_component.operation_mode = "BIDIR_DUAL_PORT",
	altsyncram_component.outdata_aclr_a = "NONE",
	altsyncram_component.outdata_aclr_b = "NONE",
	altsyncram_component.outdata_reg_a = "UNREGISTERED",
	altsyncram_component.outdata_reg_b = "UNREGISTERED",
	altsyncram_component.power_up_uninitialized = "FALSE",
	altsyncram_component.read_during_write_mode_port_a = "NEW_DATA_NO_NBE_READ",
	altsyncram_component.read_during_write_mode_port_b = "NEW_DATA_NO_NBE_READ",
	altsyncram_component.widthad_a = 8,
	altsyncram_component.widthad_b = 8,
	altsyncram_component.width_a = 16,
	altsyncram_component.width_b = 16,
	altsyncram_component.width_byteena_a = 1,
	altsyncram_component.width_byteena_b = 1,
	altsyncram_component.wrcontrol_wraddress_reg_b = "CLOCK1";

reg [7:0] bram_addr;
reg bram_tx_start;
reg bram_tx_finish;
reg bram_req;

always @(posedge clk_sys) begin
	reg state;

	bram_req <= 0;

	if (extra_data_addr && bram_tx_start) begin
		if (~&bram_addr)
			bram_tx_finish <= 1;
	end else if(~bram_tx_start) {bram_addr, state, bram_tx_finish} <= 0;
	else if(~bram_tx_finish) begin
		if(!state) begin
			bram_req <= 1;
			state <= 1;
		end
		else if(bram_ack) begin
			state <= 0;
			if(~&bram_addr) bram_addr <= bram_addr + 1'd1;
			else bram_tx_finish <= 1;
		end
	end
end

////////////////////////////  VIDEO  ////////////////////////////////////

wire [15:0] pixel_addr;
wire [17:0] pixel_data;
wire        pixel_we;

reg vsync;
always @(posedge clk_sys) begin
	reg [7:0] sync;

	sync <= sync << 1;
	if(pixel_we && pixel_addr == 0) sync <= 1;

	vsync <= |sync;
end

reg [17:0] vram[38400];
always @(posedge clk_sys) if(pixel_we) vram[pixel_addr] <= pixel_data;
always @(posedge CLK_VIDEO) rgb <= vram[px_addr];

wire [15:0] px_addr;
reg  [17:0] rgb;
wire sync_core = ~status[39];

reg hs, vs, hbl, vbl, ce_pix;
reg [5:0] r,g,b;
reg hold_reset, force_pause;
reg [13:0] force_pause_cnt;

always @(posedge CLK_VIDEO) begin
	localparam V_START = 62;

	reg [8:0] x,y;
	reg [2:0] div;
	reg old_vsync;

	div <= div + 1'd1;

	ce_pix <= 0;
	if(!div) begin
		ce_pix <= 1;

		{r,g,b} <= rgb;

		if(x == 240) hbl <= 1;
		if(x == 000) hbl <= 0;

		if(x == 293) begin
			hs <= 1;

			if(y == 1)   vs <= 1;
			if(y == 4)   vs <= 0;
		end

		if(x == 293+32)    hs  <= 0;

		if(y == V_START)     vbl <= 0;
		if(y >= V_START+160) vbl <= 1;
	end

	if(ce_pix) begin
		if(vbl) px_addr <= 0;
		else if(!hbl) px_addr <= px_addr + 1'd1;

		x <= x + 1'd1;
		if(x == 398) begin
			x <= 0;
			if (~&y) y <= y + 1'd1;
			if (sync_core && y >= 263) y <= 0;

			if (y == V_START-1) begin
				// Pause the core for 22 Gameboy lines to avoid reading & writing overlap (tearing)
				force_pause <= (sync_core && ~fast_forward && pixel_addr < (240*22));
				force_pause_cnt <= 14'd10164; // 22* 264/228 *399
			end
		end

		if (force_pause) begin
			if (force_pause_cnt > 0)
				force_pause_cnt <= force_pause_cnt - 1'b1;
			else
				force_pause <= 0;
		end

	end

	old_vsync <= vsync;
	if(~old_vsync & vsync) begin
		if(~sync_core & vbl) begin
			x <= 0;
			y <= 0;
			vs <= 0;
			hs <= 0;
		end
	end

	// Avoid lost sync by reset
	if (x == 0 && y == 0)
		hold_reset <= 1'b0;
	else if (reset & sync_core)
		hold_reset <= 1'b1;

end

assign VGA_F1 = 0;
assign VGA_SL = sl[1:0];

wire [2:0] scale = status[4:2];
wire [2:0] sl = scale ? scale - 1'd1 : 3'd0;
wire       scandoubler = (scale || forced_scandoubler);

wire [7:0] r_in = {r,r[5:4]};
wire [7:0] g_in = {g,g[5:4]};
wire [7:0] b_in = {b,b[5:4]};

//wire [7:0] luma = r_in[7:3] + g_in[7:1] + g_in[7:2] + b_in[7:3];
wire [7:0] luma = r_in[7:2] + g_in[7:1] + g_in[7:3] + b_in[7:3];

wire [7:0] r_out, g_out, b_out;
always_comb begin
	case(desatcolors)
		0: begin
				r_out = r_in;
				g_out = g_in;
				b_out = b_in;
			end
		1: begin
				r_out = r_in[7:1] + r_in[7:2] + luma[7:2];
				g_out = g_in[7:1] + g_in[7:2] + luma[7:2];
				b_out = b_in[7:1] + b_in[7:2] + luma[7:2];
			end
		2: begin
				r_out = r_in[7:1] + luma[7:1];
				g_out = g_in[7:1] + luma[7:1];
				b_out = b_in[7:1] + luma[7:1];
			end
      3: begin
				r_out = luma[7:1] + luma[7:2] + r_in[7:2];
				g_out = luma[7:1] + luma[7:2] + g_in[7:2];
				b_out = luma[7:1] + luma[7:2] + b_in[7:2];
			end
	endcase
end

reg [2:0] shadercolors;
reg [1:0] desatcolors;
always @(posedge clk_sys) begin
	if(status[26:24] < 5) begin
      shadercolors = status[26:24];
      desatcolors  = 0;
   end
   else begin
      shadercolors = 0;
      desatcolors  = status[25:24];
   end
end

video_mixer #(.LINE_LENGTH(520), .GAMMA(1)) video_mixer
(
	.*,
	.hq2x(scale==1),
	.freeze_sync(),
	.HSync(hs),
	.VSync(vs),
	.HBlank(hbl),
	.VBlank(vbl),
	.R(r_out),
	.G(g_out),
	.B(b_out)
);

wire [1:0] ar = status[33:32];
video_freak video_freak
(
	.*,
	.VGA_DE_IN(VGA_DE),
	.VGA_DE(),

	.ARX((!ar) ? 12'd3 : (ar - 1'd1)),
	.ARY((!ar) ? 12'd2 : 12'd0),
	.CROP_SIZE(0),
	.CROP_OFF(0),
	.SCALE(status[35:34])
);


/////////////////////////  STATE SAVE/LOAD  /////////////////////////////
wire bk_load     = status[12];
wire bk_save     = status[13];
wire bk_autosave = status[23];
wire bk_write    = (save_eeprom|save_sram|save_flash) && bus_req;

reg  bk_ena      = 0;
reg  bk_pending  = 0;
reg  bk_loading  = 0;

reg bk_record_rtc = 0;

wire extra_data_addr = sd_lba[8:0] > save_sz;

always @(posedge clk_sys) begin
	if (bk_write)      bk_pending <= 1;
	else if (bk_state) bk_pending <= 0;
end
reg use_img;
reg [8:0] save_sz;

always @(posedge clk_sys) begin : size_block
	reg old_downloading;

	old_downloading <= cart_download;
	if(~old_downloading & cart_download) {use_img, save_sz} <= 0;

	if(bus_req & ~use_img) begin
		if(save_eeprom) save_sz <= save_sz | 8'hF;
		if(save_sram)   save_sz <= save_sz | 8'h3F;
		if(save_flash)  save_sz <= save_sz | {flash_1m, 7'h7F};
	end

	if(img_mounted && img_size && !img_readonly) begin
		use_img <= 1;
		if (!(img_size[17:9] & (img_size[17:9] - 9'd1))) // Power of two
			save_sz <= img_size[17:9] - 1'd1;
		else                                             // Assume one extra sector of RTC data
			save_sz <= img_size[17:9] - 2'd2;
	end

	bk_ena <= |save_sz;
end

reg  bk_state  = 0;
wire bk_save_a = OSD_STATUS & bk_autosave;

always @(posedge clk_sys) begin
	reg old_load = 0, old_save = 0, old_save_a = 0, old_ack;
	reg [1:0] state;

	old_load   <= bk_load;
	old_save   <= bk_save;
	old_save_a <= bk_save_a;
	old_ack    <= sd_ack;

	if(~old_ack & sd_ack) {sd_rd, sd_wr} <= 0;

	if(!bk_state) begin
		bram_tx_start <= 0;
		state <= 0;
		sd_lba <= 0;
		time_dout <= {5'd0, RTC_time, 42'd0};
		bk_loading <= 0;
		if(bk_ena & ((~old_load & bk_load) | (~old_save & bk_save) | (~old_save_a & bk_save_a & bk_pending) | (cart_download & img_mounted))) begin
			bk_state <= 1;
			bk_loading <= bk_load | img_mounted;
		end
	end
	else if(bk_loading) begin
		case(state)
			0: begin
					sd_rd <= 1;
					state <= 1;
				end
			1: if(old_ack & ~sd_ack) begin
					bram_tx_start <= 1;
					state <= 2;
				end
			2: if(bram_tx_finish) begin
					bram_tx_start <= 0;
					state <= 0;
					sd_lba <= sd_lba + 1'd1;

					// always read max possible size
					if(sd_lba[8:0] == 9'h100) begin
						bk_record_rtc <= 0;
						bk_state <= 0;
						RTC_load <= 0;
					end
				end
		endcase

		if (extra_data_addr) begin
			if (~|sd_buff_addr && sd_buff_wr && sd_buff_dout == "RT") begin
				bk_record_rtc <= 1;
				RTC_load <= 0;
			end
		end

		if (bk_record_rtc) begin
			if (sd_buff_addr < 6 && sd_buff_addr >= 1)
				time_dout[{sd_buff_addr[2:0] - 3'd1, 4'b0000} +: 16] <= sd_buff_dout;

			if (sd_buff_addr > 5)
				RTC_load <= 1;

			if (&sd_buff_addr)
				bk_record_rtc <= 0;
		end
	end
	else begin
		case(state)
			0: begin
					bram_tx_start <= 1;
					state <= 1;
				end
			1: if(bram_tx_finish) begin
					bram_tx_start <= 0;
					sd_wr <= 1;
					state <= 2;
				end
			2: if(old_ack & ~sd_ack) begin
					state <= 0;
					sd_lba <= sd_lba + 1'd1;

					if (sd_lba[8:0] == {1'b0, save_sz} + (has_rtc ? 9'd1 : 9'd0))
						bk_state <= 0;
				end
		endcase
	end
end

////////////////////////////  CODES  ///////////////////////////////////

// Code layout:
// {code flags,     32'b address, 32'b compare, 32'b replace}
//  127:96          95:64         63:32         31:0
// Integer values are in BIG endian byte order, so it up to the loader
// or generator of the code to re-arrange them correctly.
reg [127:0] gg_code;
reg gg_valid;
reg gg_reset;
reg ioctl_download_1;
wire gg_active;
always_ff @(posedge clk_sys) begin

   gg_reset <= 0;
   ioctl_download_1 <= ioctl_download;
	if (ioctl_download && ~ioctl_download_1 && ioctl_index == 255) begin
      gg_reset <= 1;
   end

   gg_valid <= 0;
	if (code_download & ioctl_wr) begin
		case (ioctl_addr[3:0])
			0:  gg_code[111:96]  <= ioctl_dout; // Flags Bottom Word
			2:  gg_code[127:112] <= ioctl_dout; // Flags Top Word
			4:  gg_code[79:64]   <= ioctl_dout; // Address Bottom Word
			6:  gg_code[95:80]   <= ioctl_dout; // Address Top Word
			8:  gg_code[47:32]   <= ioctl_dout; // Compare Bottom Word
			10: gg_code[63:48]   <= ioctl_dout; // Compare top Word
			12: gg_code[15:0]    <= ioctl_dout; // Replace Bottom Word
			14: begin
				gg_code[31:16]    <= ioctl_dout; // Replace Top Word
				gg_valid          <= 1;          // Clock it in
			end
		endcase
	end
end

endmodule
