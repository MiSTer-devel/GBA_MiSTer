//============================================================================
//  GBA
//  Copyright (C) 2025 Robert Peip
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
	output        VGA_DISABLE, // analog out is off

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM
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

assign LED_USER    = cart_download | bk_pending;
assign LED_DISK    = 0;
assign LED_POWER   = 0;
assign BUTTONS     = 0;
assign VGA_SCALER  = 0;
assign VGA_DISABLE = 0;
assign HDMI_FREEZE = 0;

assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;

///////////////////////  CLOCK/RESET  ///////////////////////////////////

wire pll_locked;
wire clk_6x;
wire clk_sys;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_6x),
	.outclk_1(CLK_VIDEO),
	.outclk_2(clk_sys),
	.locked(pll_locked)
);

wire reset = RESET | buttons[1] | status[0] | cart_download | bk_loading;

////////////////////////////  HPS I/O  //////////////////////////////////

// Status Bit Map: (0..31 => "O", 32..63 => "o")
// 0         1         2         3          4         5         6
// 01234567890123456789012345678901 23456789012345678901234567890123
// 0123456789ABCDEFGHIJKLMNOPQRSTUV 0123456789ABCDEFGHIJKLMNOPQRSTUV
// X XXXXXXXXXRXXXXXXXXXXXXXXXXXXXX XXXXXXXXXXXX      xxxxxxxxxx

`include "build_id.v"
parameter CONF_STR = {
	"GBA;SS3E000000:80000;",
	"FS1,GBA,Load,30080000;",
	"-;",
	"C,Cheats;",
	"H1O[6],Cheats Enabled,Yes,No;",
	"-;",
	"D0R[12],Reload Backup RAM;",
	"D0R[13],Save Backup RAM;",
	"D0O[23],Autosave,Off,On;",
	"D0-;",
	"O[36],Savestates to SDCard,On,Off;",
	"O[43],Autoincrement Slot,Off,On;",
	"O[38:37],Savestate Slot,1,2,3,4;",
	"h4H3R[17],Save state (Alt-F1);",
	"h4H3R[18],Restore state (F1);",
	"-;",
	"P1,Video & Audio;",
	"P1-;",
	"P1O[33:32],Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"P1O[4:2],Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"P1O[35:34],Scale,Normal,V-Integer,Narrower HV-Integer,Wider HV-Integer;",
	"P1-;",
	"P1O[26:24],Modify Colors,Off,GBA 2.2,GBA 1.6,NDS 1.6,VBA 1.4,75%,50%,25%;",
	"P1-;",
   "P1O[55:52],CRT H-Sync Adjust,0,1,2,3,4,5,6,7,-8,-7,-6,-5,-4,-3,-2,-1;",
	"P1O[58:56],CRT V-Sync Adjust,0,1,2,3,-4,-3,-2,-1;",
	"P1-;",
	"P1O[51],Borders,Off,On;",
	"P1FC2,BOR,Load Border,3D000000;",
	"P1-;",
	"P1O[39],Sync core to video,On,Off;",
	"P1O[10:9],Flickerblend,Off,Blend,30Hz;",
	"P1-;",
	"P1O[8:7],Stereo Mix,None,25%,50%,100%;",

	"P2,Hardware;",
	"P2-;",
	"H6P2O[31:29],Solar Sensor,0%,15%,30%,42%,55%,70%,85%,100%;",
   "P2-;",
   "P2-,Save setting + reload Core;",
	"P2O[28],Homebrew BIOS,Off,On;",

	"P3,Miscellaneous;",
	"P3-;",
   "D5P3O[5],Pause when OSD is open,Off,On;",
   "P3O[50],Error Overlay,Off,On;",
   "P3-;",
	"P3-,Only Romhacks or Crash!;",
	"P3O[40],GPIO HACK(RTC+Rumble),Off,On;",

	"- ;",
	"R0,Reset;",
	"J1,A,B,L,R,Select,Start,Savestates,Pause;",
	"jn,A,B,L,R,Select,Start,X,X;",
	"I,",
	"Load=DPAD Up|Save=Down|Slot=L+R,",
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

wire [63:0] status_in = cart_download ? {status[63:39],ss_slot,status[36:19],3'b000,status[15:0]} : {status[63:39],ss_slot,status[36:19],2'b00,status[16:0]};

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
	cart_download <= ioctl_download & (ioctl_index == 1);
end

reg [26:0] last_addr;
reg        flash_1m;
reg  [1:0] cart_type;
reg        cart_loaded = 0;
always @(posedge clk_sys) begin
	reg old_download;
	old_download <= cart_download;
	if (old_download & ~cart_download) last_addr <= ioctl_addr;
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
	.autoincslot    (status[43]    ),
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

wire [15:0] GBA_AUDIO_L;
wire [15:0] GBA_AUDIO_R;

reg gba_on = 1'b0;
reg pause = 1'b0;
wire inPause;
always @(posedge clk_sys) begin
	gba_on <= (~reset);
   pause <= (status[5] & OSD_STATUS); // pause "pause in osd"
   if (bram_tx_start & ~bram_tx_finish & ~bk_loading) pause <= 1'b1;
end

wire sdram_refresh;

gba_wrap
#(
   // assume: cart may have either flash or eeprom, not both! (need to verify)
	.Softmap_GBA_FLASH_ADDR  (0),                   // 131072 (8bit)  -- 128 Kbyte Data for GBA Flash
	.Softmap_GBA_EEPROM_ADDR (0),                   //   8192 (8bit)  --   8 Kbyte Data for GBA EEProm
	.Softmap_GBA_Gamerom_ADDR(524288),              //  32MB of ROM
	.Softmap_SaveState_ADDR  (58720256),            // 65536 (64bit) -- ~512kbyte Data for SaveState (separate memory)
	.Softmap_Rewind_ADDR     (33554432),            // 65536 qwords*64 -- 64*512 Kbyte Data for Savestates
	.turbosound('0)                                 // sound buffer to play sound in turbo mode without sound pitched up
)
gba
(
	.clk1x(clk_sys),
	.clk3x(CLK_VIDEO),
	.clk6x(clk_6x),
	.GBA_on(gba_on),  // switching from off to on = reset
   .pause(pause),
   .inPause(inPause),
	.GBA_lockspeed(1'b1),       // 1 = 100% speed, 0 = max speed
	.GBA_cputurbo(1'b0),
	.GBA_flash_1m(flash_1m),          // 1 when string "FLASH1M_V" is anywhere in gamepak
	.Underclock(status[42:41]),
   .MaxPakAddr(last_addr[26:2]),     // max byte address that will contain data, required for buggy games that read behind their own memory, e.g. zelda minish cap
	.CyclesMissing(),                 // debug only for speed measurement, keep open
	.CyclesVsyncSpeed(),              // debug only for speed measurement, keep open
	.SramFlashEnable(~sram_quirk),
	.memory_remap(memory_remap_quirk),
   .increaseSSHeaderCount(!status[36]),
   .save_state(ss_save),
   .load_state(ss_load),
   .interframe_blend(status[10:9]),
   .shade_mode(status[26:24]),
   .borderOn(status[51]),
   .videoHshift(status[55:52]),
   .videoVshift(status[58:56]),
	.specialmodule(gpio_quirk | status[40]),
	.solar_in(status[31:29]),
	.tilt(tilt_quirk),
	.overlay_error_on(status[50]),
   .rewind_on(1'b0),
   .rewind_active(1'b0),
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
   
	.sdram_Din(bus_din),              
	.sdram_Adr(bus_addr),             
	.sdram_rnw(bus_rd),               
	.sdram_ena(bus_req),              
	.sdram_cancel(sdram_cancel),              
	.sdram_refresh(sdram_refresh),              
   .sdram_Dout(bus_dout),      
	.sdram_done16(bus_ack16),             
	.sdram_done32(bus_ack32),        

   .ddr3_BUSY         (DDRAM_BUSY      ),
   .ddr3_BURSTCNT     (DDRAM_BURSTCNT  ),
   .ddr3_ADDR         (DDRAM_ADDR      ),
   .ddr3_DOUT         (DDRAM_DOUT      ),
   .ddr3_DOUT_READY   (DDRAM_DOUT_READY),
   .ddr3_RD           (DDRAM_RD        ),
   .ddr3_DIN          (DDRAM_DIN       ),
   .ddr3_BE           (DDRAM_BE        ),
   .ddr3_WE           (DDRAM_WE        ),   

   .romcopy_start(romcopy_start),
   .romcopy_size(romcopy_size),
   .rom_addr(rom_addr),
   .rom_dout(rom_dout),
   .rom_wr(rom_wr),
   .rom_copy(rom_copy),
   .romcopy_req(romcopy_req),     
   .romcopy_data(romcopy_data),   
   .romcopy_writepos(romcopy_writepos),

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
   .KeyPause(joy[11]),

   .videoout_hsync    (hs),
   .videoout_vsync    (vs),
   .videoout_hblank   (hbl),
   .videoout_vblank   (vbl),
   .videoout_ce       (ce_pix),
   .videoout_interlace(),
   .videoout_r        (r_out),
   .videoout_g        (g_out),
   .videoout_b        (b_out),

	.sound_out_left(GBA_AUDIO_L),
	.sound_out_right(GBA_AUDIO_R)
);

assign AUDIO_L = GBA_AUDIO_L;
assign AUDIO_R = GBA_AUDIO_R;

////////////////////////////  QUIRKS  //////////////////////////////////

reg [26:0] romcopy_size;
reg        romcopy_start = 0;
always @(posedge clk_sys) begin
	
   romcopy_start <= 0;
   if (~ioctl_download && ioctl_download_1 && ioctl_index[5:0] == 1) begin
      romcopy_size    <= ioctl_addr;
      romcopy_start   <= 1;
   end

end 

reg [63:0] str;
reg [31:0] cart_id;
reg sram_quirk = 0;            // game tries to use SRAM as emulation detection. This bit forces to pretent we have no SRAM
reg memory_remap_quirk = 0;    // game uses memory mirroring, e.g. access 4Mbyte but is only 1 Mbyte. 
reg gpio_quirk = 0;            // game exchanges some addresses to be GPIO lines for e.g. Solar or RTC
reg tilt_quirk = 0;            // game exchanges some addresses to be Tilt module
reg solar_quirk = 0;           // game has solar module

always @(posedge clk_6x) begin

	if (~ioctl_download && ioctl_download_1 && ioctl_index == 1) begin
		flash_1m <= 0;
		cart_type <= ioctl_index[7:6];
		cart_loaded <= 1;
	end
   
  if (~ioctl_download && ioctl_download_1 && ioctl_index == 1) begin
      sram_quirk         <= 0;
      memory_remap_quirk <= 0;
      gpio_quirk         <= 0;
      tilt_quirk         <= 0;
      solar_quirk        <= 0;
   end

	if(rom_wr) begin
		if({str, rom_dout[7:0]} == "FLASH1M_V") flash_1m <= 1;
		if({str[55:0], rom_dout[7:0], rom_dout[15:8]} == "FLASH1M_V") flash_1m <= 1;

		str <= {str[47:0], rom_dout[7:0], rom_dout[15:8]};
	end


	if(rom_wr) begin
		if(rom_addr[26:4] == 'hA) begin
			if(rom_addr[3:0] >= 12) cart_id[{4'd14 - rom_addr[3:0], 3'd0} +:16] <= {rom_dout[7:0],rom_dout[15:8]};
		end
		if(rom_addr == 'hB0) begin
			if(cart_id[31:8] == "AR8" ) begin sram_quirk <= 1;                                             end // Rocky US
			if(cart_id[31:8] == "ARO" ) begin sram_quirk <= 1;                                             end // Rocky EU
			if(cart_id[31:8] == "ALG" ) begin sram_quirk <= 1;                                             end // Dragon Ball Z - The Legacy of Goku
			if(cart_id[31:8] == "ALF" ) begin sram_quirk <= 1;                                             end // Dragon Ball Z - The Legacy of Goku II
			if(cart_id[31:8] == "BLF" ) begin sram_quirk <= 1;                                             end // 2 Games in 1 - Dragon Ball Z - The Legacy of Goku I & II
			if(cart_id[31:8] == "BDB" ) begin sram_quirk <= 1;                                             end // Dragon Ball Z - Taiketsu
			if(cart_id[31:8] == "BG3" ) begin sram_quirk <= 1;                                             end // Dragon Ball Z - Buu's Fury
			if(cart_id[31:8] == "BDV" ) begin sram_quirk <= 1;                                             end // Dragon Ball Z - Advanced Adventure
			if(cart_id[31:8] == "A2Y" ) begin sram_quirk <= 1;                                             end // Top Gun - Combat Zones
			if(cart_id[31:8] == "AI2" ) begin sram_quirk <= 1;                                             end // Iridion II
			if(cart_id[31:8] == "BT4" ) begin sram_quirk <= 1;                                             end // Dragon Ball GT Transformation			
			if(cart_id[31:8] == "BPE" ) begin gpio_quirk <= 1;                                             end // POKEMON Emerald
			if(cart_id[31:8] == "AXV" ) begin gpio_quirk <= 1;                                             end // POKEMON Ruby
			if(cart_id[31:8] == "AXP" ) begin gpio_quirk <= 1;                                             end // POKEMON Sapphire
			if(cart_id[31:8] == "RZW" ) begin gpio_quirk <= 1;                                             end // WarioWare Twisted
			if(cart_id[31:8] == "BKA" ) begin gpio_quirk <= 1;                                             end // Sennen Kazoku
			if(cart_id[31:8] == "BR4" ) begin gpio_quirk <= 1;                                             end // Rockman EXE 4.5
			if(cart_id[31:8] == "V49" ) begin gpio_quirk <= 1;                                             end // Drill Dozer
			if(cart_id[31:8] == "2GB" ) begin gpio_quirk <= 1;                                             end // Goodboy Galaxy
			if(cart_id[31:8] == "BHG" ) begin                                                              end // Gunstar Super Heroes
			if(cart_id[31:8] == "BGX" ) begin                                                              end // Gunstar Super Heroes
			if(cart_id[31:8] == "KHP" ) begin tilt_quirk <= 1;                                             end // Koro Koro Puzzle JP
			if(cart_id[31:8] == "KYG" ) begin tilt_quirk <= 1;                                             end // Yoshi's Topsy-Turvy
			if(cart_id[31:8] == "U3I" ) begin gpio_quirk <= 1; solar_quirk <= 1;                           end // Boktai 1
			if(cart_id[31:8] == "U32" ) begin gpio_quirk <= 1; solar_quirk <= 1;                           end // Boktai 2
			if(cart_id[31:8] == "U33" ) begin gpio_quirk <= 1; solar_quirk <= 1;                           end // Boktai 3
			if(cart_id       == "FBME") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Classic NES Series Bomberman
			if(cart_id       == "FADE") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Classic NES Series Castlevania
			if(cart_id       == "FDKE") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Classic NES Series Donkey Kong
			if(cart_id       == "FDME") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Classic NES Series DR. MARIO
			if(cart_id       == "FEBE") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Classic NES Series EXCITEBIKE
			if(cart_id       == "FICE") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Classic NES Series ICE CLIMBER
			if(cart_id       == "FMRE") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Classic NES Series NES METROID
			if(cart_id       == "FP7E") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Classic NES Series PAC-MAN
			if(cart_id       == "FSME") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Classic NES Series SUPER MARIO Bros
			if(cart_id       == "FZLE") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Classic NES Series The Legend of Zelda
			if(cart_id       == "FXVE") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Classic NES Series XEVIOUS
			if(cart_id       == "FLBE") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Classic NES Series Zelda II - The Adventure of Link
			if(cart_id       == "FSRJ") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Famicom Mini - Dai-2-ji Super Robot Taisen (Japan) (Promo)
			if(cart_id       == "FGZJ") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Famicom Mini - Kidou Senshi Z Gundam - Hot Scramble (Japan) (Promo)
			if(cart_id       == "FSDJ") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Famicom Mini 30 - SD Gundam World - Gachapon Senshi Scramble Wars
			if(cart_id       == "FADJ") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Famicom Mini 29 - Akumajou Dracula
			if(cart_id       == "FTUJ") begin sram_quirk <= 1;                                             end // Famicom Mini 28 - Famicom Tantei Club Part II - Ushiro ni Tatsu Shoujo - Zen, Kouhen
			if(cart_id       == "FTKJ") begin sram_quirk <= 1;                                             end // Famicom Mini 27 - Famicom Tantei Club - Kieta Koukeisha - Zen, Kouhen
			if(cart_id       == "FFMJ") begin sram_quirk <= 1;                                             end // Famicom Mini 26 - Famicom Mukashibanashi - Shin Onigashima - Zen, Kouhen
			if(cart_id       == "FLBJ") begin sram_quirk <= 1;                                             end // Famicom Mini 25 - The Legend of Zelda 2 - Link no Bouken
			if(cart_id       == "FPTJ") begin sram_quirk <= 1;                                             end // Famicom Mini 24 - Hikari Shinwa - Palthena no Kagami
			if(cart_id       == "FMRJ") begin sram_quirk <= 1;                                             end // Famicom Mini 23 - Metroid
			if(cart_id       == "FNMJ") begin sram_quirk <= 1;                                             end // Famicom Mini 22 - Nazo no Murasame Jou
			if(cart_id       == "FM2J") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Famicom Mini 21 - Super Mario Bros. 2
			if(cart_id       == "FGGJ") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Famicom Mini 20 - Ganbare Goemon! - Karakuri Douchuu
			if(cart_id       == "FTWJ") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Famicom Mini 19 - Twin Bee
			if(cart_id       == "FMKJ") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Famicom Mini 18 - Makaimura
			if(cart_id       == "FTBJ") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Famicom Mini 17 - Takahashi Meijin no Bouken-jima
			if(cart_id       == "FDDJ") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Famicom Mini 16 - Dig Dug
			if(cart_id       == "FDMJ") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Famicom Mini 15 - Dr. Mario
			if(cart_id       == "FWCJ") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Famicom Mini 14 - Wrecking Crew
			if(cart_id       == "FBFJ") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Famicom Mini 13 - Balloon Fight
			if(cart_id       == "FCLJ") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Famicom Mini 12 - Clu Clu Land
			if(cart_id       == "FMBJ") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Famicom Mini 11 - Mario Bros.
			if(cart_id       == "FSOJ") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Famicom Mini 10 - Star Soldier
			if(cart_id       == "FBMJ") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Famicom Mini 09 - Bomber Man
			if(cart_id       == "FMPJ") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Famicom Mini 08 - Mappy
			if(cart_id       == "FXVJ") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Famicom Mini 07 - Xevious
			if(cart_id       == "FPMJ") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Famicom Mini 06 - Pac-Man
			if(cart_id       == "FZLJ") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Famicom Mini 05 - Zelda no Densetsu 1 - The Hyrule Fantasy
			if(cart_id       == "FEBJ") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Famicom Mini 04 - Excitebike
			if(cart_id       == "FICJ") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Famicom Mini 03 - Ice Climber
			if(cart_id       == "FDKJ") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Famicom Mini 02 - Donkey Kong
			if(cart_id       == "FSMJ") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Famicom Mini 01 - Super Mario Bros.
		end
	end
end

////////////////////////////  MEMORY  ///////////////////////////////////

localparam ROM_START = 131072*4;

wire [25:2] sdram_addr;
wire [31:0] sdram_dout1 = sdr_sdram_dout1;
wire [31:0] sdram_dout2 = sdr_sdram_dout2;
wire        sdram_ack   = sdr_sdram_ack;
wire        sdram_req;

wire [26:0] bus_addr;
wire [31:0] bus_din;
wire [31:0] bus_dout = sdr_bus_dout;
wire        bus_ack16  = sdr_bus_ack_16;
wire        bus_ack32  = sdr_bus_ack;
wire        bus_rd, bus_req;
wire        sdram_cancel;

wire [31:0] sdr_sdram_dout1, sdr_sdram_dout2, sdr_bus_dout;
wire [15:0] sdr_bram_din;
wire        sdr_sdram_ack, sdr_bus_ack, sdr_bus_ack_16, sdr_bram_ack;

sdram sdram
(
	.*,
	.init(~pll_locked),
	.clk(clk_6x),
   
   .refresh_req(sdram_refresh),

	.ch1_addr({sdram_addr, 1'b0}),
	.ch1_din(16'b0),
	.ch1_dout({sdr_sdram_dout2, sdr_sdram_dout1}),
	.ch1_req(1'b0),
	.ch1_rnw(cart_download ? 1'b0     : 1'b1     ),
	.ch1_ready(sdr_sdram_ack),

	.ch2_addr(rom_copy ? romcopy_writepos[26:1] : bus_addr[26:1]),
	.ch2_din(rom_copy ? romcopy_data : bus_din),
	.ch2_dout(sdr_bus_dout),
	.ch2_req(rom_copy ? romcopy_req : ~cart_download & bus_req),
	.ch2_cancel(sdram_cancel),
	.ch2_rnw(rom_copy ? 1'b0 : bus_rd),
	.ch2_ready(sdr_bus_ack),
	.ch2_ready16(sdr_bus_ack_16),

	.ch3_addr({sd_lba[7:0],bram_addr}),
	.ch3_din(bram_dout),
	.ch3_dout(sdr_bram_din),
	.ch3_req(bram_req),
	.ch3_rnw(~bk_loading || extra_data_addr),
	.ch3_ready(sdr_bram_ack)
);

always @(posedge clk_6x) begin
	if(cart_download) begin
		if(ioctl_wr)  ioctl_wait <= 1;
		if(sdram_ack) ioctl_wait <= 0;
	end
	else ioctl_wait <= 0;
end

assign DDRAM_CLK = clk_sys;

wire [26:0]  romcopy_writepos; 
wire         romcopy_req; 
wire [31:0]  romcopy_data; 

wire [26:0] rom_addr;
wire [15:0] rom_dout;
wire        rom_wr  ;
wire        rom_copy;

/////////////////

wire [127:0] time_din_h = {32'd0, time_din, "RT"};
wire [15:0] bram_dout;
wire [15:0] bram_din = sdr_bram_din;
wire        bram_ack = sdr_bram_ack;
assign sd_buff_din = extra_data_addr ? (time_din_h[{sd_buff_addr[2:0], 4'b0000} +: 16]) : bram_buff_out;
wire [15:0] bram_buff_out;

altsyncram	altsyncram_component
(
	.address_a (bram_addr),
	.address_b (sd_buff_addr),
	.clock0 (clk_6x),
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

always @(posedge clk_6x) begin
	reg state;

	bram_req <= 0;

	if (sd_lba[8] || (extra_data_addr && bram_tx_start)) begin
		if (~&bram_addr)
			bram_tx_finish <= 1;
	end else if(~bram_tx_start) {bram_addr, state, bram_tx_finish} <= 0;
	else if(~bram_tx_finish) begin
      if (bk_loading || inPause) begin
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
end

////////////////////////////  VIDEO  ////////////////////////////////////

wire hs, vs, hbl, vbl, ce_pix;
wire [7:0] r_out, g_out, b_out;

assign VGA_F1 = 0;
assign VGA_SL = sl[1:0];

wire [2:0] scale = status[4:2];
wire [2:0] sl = scale ? scale - 1'd1 : 3'd0;

video_mixer #(.LINE_LENGTH(520), .GAMMA(1)) video_mixer
(
	.*,
   .scandoubler(1'b0),
	.hq2x(1'b0),
	.freeze_sync(),
   .ce_pix(ce_pix),
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

	.ARX((!ar) ? ((status[51]) ? 12'd4 : 12'd3) : (ar - 1'd1)),
	.ARY((!ar) ? ((status[51]) ? 12'd3 : 12'd2) : 12'd0),
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

always @(posedge clk_6x) begin
	if (bk_write)      bk_pending <= 1;
	else if (bk_state) bk_pending <= 0;
end
reg use_img;
reg [8:0] save_sz;

always @(posedge clk_6x) begin : size_block
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
