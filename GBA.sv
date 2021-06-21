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
	inout  [45:0] HPS_BUS,

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

`ifdef USE_FB
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

	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
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

`ifdef USE_DDRAM
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
`endif

`ifdef USE_SDRAM
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
`endif

`ifdef DUAL_SDRAM
	//Secondary SDRAM
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

assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;

assign FB_EN      = 1'b1;
assign FB_FORMAT  = 5'b00110;
assign FB_WIDTH   = status[10] ? 12'd240 : status[9] ? 12'd480 : 12'd240;
assign FB_HEIGHT  = status[10] ? 12'd160 : status[9] ? 12'd160 : 12'd320;
assign FB_STRIDE  = 0;
assign FB_FORCE_BLANK = 0;
assign FB_PAL_CLK = 0;
assign FB_PAL_ADDR= 0;
assign FB_PAL_DOUT= 0;
assign FB_PAL_WR  = 0;


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
// x    x xxxx xx xx   x  x         xxxx

`include "build_id.v"
parameter CONF_STR = {
	"GBA2P;SS3E000000:80000;",
	"FS,GBA,Load,300C0000;",
	"-;",
	"D0RC,Reload Backup RAM;",
	"D0RD,Save Backup RAM;",
	"D0ON,Autosave,Off,On;",
	"D0-;",
	"O9A,Split,Vert,Horz,Screen 1,Screen 2;",
	"OFG,Audioselect,GBA 1,GBA 2,Mixed,Split 1=L 2=R;",
	"o01,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"O78,Stereo Mix,None,25%,50%,100%;",
	"OK,Spritelimit,Off,On;",	 
	"o23,Scale,Normal,V-Integer,Narrower HV-Integer,Wider HV-Integer;",
	"O5,Pause when OSD is open,Off,On;",
	"- ;",
	"R0,Reset;",
	"J1,A,B,L,R,Select,Start;",
	"jn,A,B,L,R,Select,Start;",
	"V,v",`BUILD_DATE
};

wire  [1:0] buttons;
wire [63:0] status;
wire [15:0] status_menumask = {1'b0, 1'b0, cart_loaded, |cart_type, force_turbo, 1'b1, ~bk_ena};
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

wire [15:0] joy1;
wire [15:0] joy2;
wire [15:0] joy_unmod;
wire [10:0] ps2_key;

wire [21:0] gamma_bus;
wire [15:0] sdram_sz;

wire [32:0] RTC_time;

wire [63:0] status_in = cart_download ? {status[63:39],2'b00,status[36:17],1'b0,status[15:0]} : {status[63:39],2'b00,status[36:0]};

hps_io #(.STRLEN($size(CONF_STR)>>3), .WIDE(1)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),
	.conf_str(CONF_STR),

	.buttons(buttons),
	.forced_scandoubler(forced_scandoubler),

	.joystick_0(joy1),
	.joystick_1(joy2),
	.ps2_key(ps2_key),

	.status(status),
	.status_in(status_in),
	.status_set(cart_download),
	.status_menumask(status_menumask),
	.info_req(1'b0),
	.info(0),

	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_wr(ioctl_wr),
	.ioctl_download(ioctl_download),
	.ioctl_index(ioctl_index),
	.ioctl_wait(ioctl_wait),

	.sd_lba(sd_lba),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(sd_ack),
	.sd_buff_addr(sd_buff_addr),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_din(sd_buff_din),
	.sd_buff_wr(sd_buff_wr),

	.TIMESTAMP(RTC_time),

	.img_mounted(img_mounted),
	.img_readonly(img_readonly),
	.img_size(img_size),

	.sdram_sz(sdram_sz),
	.gamma_bus(gamma_bus)
);

//////////////////////////  ROM DETECT  /////////////////////////////////

reg bios_download, cart_download;
always @(posedge clk_sys) begin
	bios_download <= ioctl_download & !ioctl_index;
	cart_download <= ioctl_download & ~&ioctl_index & |ioctl_index;
end

reg [26:0] last_addr;
reg        flash_1m;
reg  [1:0] cart_type;
reg        cart_loaded = 0;
reg        ioctl_download_1;
always @(posedge clk_sys) begin
	reg [63:0] str;
	reg old_download;

	old_download <= cart_download;
	if (old_download & ~cart_download) last_addr <= ioctl_addr;

   ioctl_download_1 <= ioctl_download;
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
	if(bios_download & ioctl_wr) begin
		if(~ioctl_addr[1]) bios_wrdata[15:0] <= ioctl_dout;
		else begin
			bios_wrdata[31:16] <= ioctl_dout;
			bios_wraddr <= ioctl_addr[13:2];
			bios_wr <= 1;
		end
	end
end

////////////////////////////  SYSTEM  ///////////////////////////////////

wire save_eeprom, save_sram, save_flash, ss_loaded;

reg pause;

always @(posedge clk_sys) begin : ffwd
	pause <= (status[5] & OSD_STATUS); // pause from "pause in osd"
end

wire serial1_clockout;
wire serial2_clockout;
wire serial1_dataout; 
wire serial2_dataout;

wire [15:0] AUDIO_L1;
wire [15:0] AUDIO_R1;	
wire [15:0] AUDIO_L2;
wire [15:0] AUDIO_R2;
 
gba_top
#(
   // assume: cart may have either flash or eeprom, not both! (need to verify)
	.Softmap_GBA_FLASH_ADDR  (0),                   // 131072 (8bit)  -- 128 Kbyte Data for GBA Flash
	.Softmap_GBA_EEPROM_ADDR (0),                   //   8192 (8bit)  --   8 Kbyte Data for GBA EEProm
	.Softmap_GBA_WRam_ADDR   (131072),              //  65536 (32bit) -- 256 Kbyte Data for GBA WRam Large
	.Softmap_GBA_Gamerom_ADDR(65536+131072),        //   32MB of ROM
	.Softmap_SaveState_ADDR  (58720256),            // 65536 (64bit) -- ~512kbyte Data for SaveState (separate memory)
	.Softmap_Rewind_ADDR     (33554432),            // 65536 qwords*64 -- 64*512 Kbyte Data for Savestates
	.turbosound('0)                                 // sound buffer to play sound in turbo mode without sound pitched up
)
gba1
(
	.clk100(clk_sys),
	.GBA_on(~reset && ~romcopy_active),  // switching from off to on = reset
	.GBA_lockspeed(1'b1),       // 1 = 100% speed, 0 = max speed
	.GBA_cputurbo(1'b0),
	.GBA_flash_1m(flash_1m),          // 1 when string "FLASH1M_V" is anywhere in gamepak
	.CyclePrecalc(pause ? 16'd0 : 16'd100), // 100 seems to be ok to keep fullspeed for all games
	.MaxPakAddr(last_addr[26:2]),     // max byte address that will contain data, required for buggy games that read behind their own memory, e.g. zelda minish cap
	.CyclesMissing(),                 // debug only for speed measurement, keep open
	.CyclesVsyncSpeed(),              // debug only for speed measurement, keep open
	.SramFlashEnable(~sram_quirk),
	.memory_remap(memory_remap_quirk),
   .increaseSSHeaderCount(1'b0),
   .save_state(1'b0),
   .load_state(1'b0),
   .interframe_blend(2'b00),
   .maxpixels(status[20] | sprite_quirk),
	.specialmodule(1'b0),
   .rewind_on(1'b0),
   .rewind_active(1'b0),
   .savestate_number(2'b00),

	.sdram_read_ena    (rom1_req),       // triggered once for read request
	.sdram_read_done   (rom1_ack),      // must be triggered once when sdram_read_data is valid after last read
	.sdram_read_addr   (rom1_addr),     // all addresses are DWORD addresses!
	.sdram_read_data   (rom1_dout1),    // data from last request, valid when done = 1
	.sdram_second_dword(rom1_dout2), // second dword to be read for buffering/prefetch. Must be valid 1 cycle after done = 1

	.bus_out_Din (bus1_din),            // data read from WRam Large, SRAM/Flash/EEPROM
	.bus_out_Dout(bus1_dout),          // data written to WRam Large, SRAM/Flash/EEPROM
	.bus_out_Adr (bus1_addr),           // all addresses are DWORD addresses!
	.bus_out_rnw (bus1_rd),             // read = 1, write = 0
	.bus_out_ena (bus1_req),            // one cycle high for each action
	.bus_out_done(bus1_ack),           // should be one cycle high when write is done or read value is valid

   .SAVE_out_Din(),            // data read from savestate
   .SAVE_out_Dout(0),          // data written to savestate
   .SAVE_out_Adr(),           // all addresses are DWORD addresses!
   .SAVE_out_rnw(),            // read = 1, write = 0
   .SAVE_out_ena(),            // one cycle high for each action
   .SAVE_out_be(),              
   .SAVE_out_done(1'b0),           // should be one cycle high when write is done or read value is valid

	.save_eeprom(save_eeprom),
	.save_sram(save_sram),
	.save_flash(save_flash),
	.load_done(ss_loaded),

	.bios_wraddr(bios_wraddr),
	.bios_wrdata(bios_wrdata),
	.bios_wr(bios_wr),

	.KeyA(joy1[4]),
	.KeyB(joy1[5]),
	.KeySelect(joy1[8]),
	.KeyStart(joy1[9]),
	.KeyRight(joy1[0]),
	.KeyLeft(joy1[1]),
	.KeyUp(joy1[3]),
	.KeyDown(joy1[2]),
	.KeyR(joy1[7]),
	.KeyL(joy1[6]),

	.pixel_out_addr(pixel_addr),      // integer range 0 to 38399;       -- address for framebuffer
	.pixel_out_data(pixel_data),      // RGB data for framebuffer
	.pixel_out_we(pixel_we),          // new pixel for framebuffer

	.fb_hoffset       (1'b0),
   .fb_voffset       ((status[10:9] == 2'd3) ? 1'b1 : 1'b0),
   .fb_linesize      ((status[10:9] == 2'd1) ? 512  : 256),

   .largeimg_out_base(),
   .largeimg_out_addr(fb1_addr),
   .largeimg_out_data(fb1_din),
   .largeimg_out_req (fb1_req),
   .largeimg_out_done(fb1_ack),
   .largeimg_newframe(FB_VBL),
   .largeimg_singlebuf(FB_LL),

	.sound_out_left (AUDIO_L1),
	.sound_out_right(AUDIO_R1),
   
   .serial_clockout (serial1_clockout), 
   .serial_clockin  (serial2_clockout), 
   .serial_dataout  (serial1_dataout ), 
   .serial_datain   (serial2_dataout ), 
   .si_terminal     (1'b0), 
   .sd_terminal     (1'b1) 
);

assign AUDIO_L = (status[16:15] == 3'd0) ? AUDIO_L1 : 
                 (status[16:15] == 3'd1) ? AUDIO_L2 : 
                 (status[16:15] == 3'd2) ? ({AUDIO_L1[15], AUDIO_L1[15:1]} + {AUDIO_L2[15], AUDIO_L2[15:1]}) : 
                                           ({AUDIO_L1[15], AUDIO_L1[15:1]} + {AUDIO_R1[15], AUDIO_R1[15:1]});

assign AUDIO_R = (status[16:15] == 3'd0) ? AUDIO_R1 : 
                 (status[16:15] == 3'd1) ? AUDIO_R2 : 
                 (status[16:15] == 3'd2) ? ({AUDIO_R1[15], AUDIO_R1[15:1]} + {AUDIO_R2[15], AUDIO_R2[15:1]}) : 
                                           ({AUDIO_L2[15], AUDIO_L2[15:1]} + {AUDIO_R2[15], AUDIO_R2[15:1]});

gba_top
#(
   // assume: cart may have either flash or eeprom, not both! (need to verify)
	.Softmap_GBA_FLASH_ADDR  (0),                   // 131072 (8bit)  -- 128 Kbyte Data for GBA Flash
	.Softmap_GBA_EEPROM_ADDR (0),                   //   8192 (8bit)  --   8 Kbyte Data for GBA EEProm
	.Softmap_GBA_WRam_ADDR   (131072),              //  65536 (32bit) -- 256 Kbyte Data for GBA WRam Large
	.Softmap_GBA_Gamerom_ADDR(65536+131072),        //   32MB of ROM
	.Softmap_SaveState_ADDR  (58720256),            // 65536 (64bit) -- ~512kbyte Data for SaveState (separate memory)
	.Softmap_Rewind_ADDR     (33554432),            // 65536 qwords*64 -- 64*512 Kbyte Data for Savestates
	.turbosound('0)                                 // sound buffer to play sound in turbo mode without sound pitched up
)
gba2
(
	.clk100(clk_sys),
	.GBA_on(~reset && ~romcopy_active),  // switching from off to on = reset
	.GBA_lockspeed(1'b1),       // 1 = 100% speed, 0 = max speed
	.GBA_cputurbo(1'b0),
	.GBA_flash_1m(flash_1m),          // 1 when string "FLASH1M_V" is anywhere in gamepak
	.CyclePrecalc(pause ? 16'd0 : 16'd100), // 100 seems to be ok to keep fullspeed for all games
	.MaxPakAddr(last_addr[26:2]),     // max byte address that will contain data, required for buggy games that read behind their own memory, e.g. zelda minish cap
	.CyclesMissing(),                 // debug only for speed measurement, keep open
	.CyclesVsyncSpeed(),              // debug only for speed measurement, keep open
	.SramFlashEnable(~sram_quirk),
	.memory_remap(memory_remap_quirk),
   .increaseSSHeaderCount(1'b0),
   .save_state(1'b0),
   .load_state(1'b0),
   .interframe_blend(2'b00),
   .maxpixels(status[20] | sprite_quirk),
	.specialmodule(1'b0),
   .rewind_on(1'b0),
   .rewind_active(1'b0),
   .savestate_number(2'b00),

	.sdram_read_ena    (rom2_req),       // triggered once for read request
	.sdram_read_done   (rom2_ack),      // must be triggered once when sdram_read_data is valid after last read
	.sdram_read_addr   (rom2_addr),     // all addresses are DWORD addresses!
	.sdram_read_data   (rom2_dout1),    // data from last request, valid when done = 1
	.sdram_second_dword(rom2_dout2), // second dword to be read for buffering/prefetch. Must be valid 1 cycle after done = 1

	.bus_out_Din (bus2_din),            // data read from WRam Large, SRAM/Flash/EEPROM
	.bus_out_Dout(bus2_dout),          // data written to WRam Large, SRAM/Flash/EEPROM
	.bus_out_Adr (bus2_addr),           // all addresses are DWORD addresses!
	.bus_out_rnw (bus2_rd),             // read = 1, write = 0
	.bus_out_ena (bus2_req),            // one cycle high for each action
	.bus_out_done(bus2_ack),           // should be one cycle high when write is done or read value is valid

   .SAVE_out_Din(),            // data read from savestate
   .SAVE_out_Dout(0),          // data written to savestate
   .SAVE_out_Adr(),           // all addresses are DWORD addresses!
   .SAVE_out_rnw(),            // read = 1, write = 0
   .SAVE_out_ena(),            // one cycle high for each action
   .SAVE_out_be(),              
   .SAVE_out_done(1'b0),           // should be one cycle high when write is done or read value is valid

	.save_eeprom(),
	.save_sram(),
	.save_flash(),
	.load_done(),

	.bios_wraddr(bios_wraddr),
	.bios_wrdata(bios_wrdata),
	.bios_wr(bios_wr),

	.KeyA(joy2[4]),
	.KeyB(joy2[5]),
	.KeySelect(joy2[8]),
	.KeyStart(joy2[9]),
	.KeyRight(joy2[0]),
	.KeyLeft(joy2[1]),
	.KeyUp(joy2[3]),
	.KeyDown(joy2[2]),
	.KeyR(joy2[7]),
	.KeyL(joy2[6]),

	.pixel_out_addr(),      // integer range 0 to 38399;       -- address for framebuffer
	.pixel_out_data(),      // RGB data for framebuffer
	.pixel_out_we(),          // new pixel for framebuffer

	.fb_hoffset       ((status[10:9] == 2'd1) ? 1'b1 : 1'b0),
   .fb_voffset       (status[9]  ? 1'b0 : 1'b1),
   .fb_linesize      ((status[10:9] == 2'd1) ? 512 : 256),

   .largeimg_out_base(FB_BASE),
   .largeimg_out_addr(fb2_addr),
   .largeimg_out_data(fb2_din),
   .largeimg_out_req (fb2_req),
   .largeimg_out_done(fb2_ack),
   .largeimg_newframe(FB_VBL),
   .largeimg_singlebuf(FB_LL),

	.sound_out_left (AUDIO_L2),
	.sound_out_right(AUDIO_R2),
   
   .serial_clockout (serial2_clockout), 
   .serial_clockin  (serial1_clockout), 
   .serial_dataout  (serial2_dataout ), 
   .serial_datain   (serial1_dataout ), 
   .si_terminal     (1'b1), 
   .sd_terminal     (1'b1) 
);

////////////////////////////  QUIRKS  //////////////////////////////////

reg sram_quirk = 0;            // game tries to use SRAM as emulation detection. This bit forces to pretent we have no SRAM
reg memory_remap_quirk = 0;    // game uses memory mirroring, e.g. access 4Mbyte but is only 1 Mbyte. 
reg sprite_quirk = 0;          // game depends on using max sprite pixels per line, otherwise glitches appear
always @(posedge clk_sys) begin
	reg [95:0] cart_id;

	if (~ioctl_download && ioctl_download_1 && ioctl_index == 1) begin
      sram_quirk         <= 0;
      memory_remap_quirk <= 0;
      sprite_quirk       <= 0;
   end

	// TODO: better to use game ID (fixed 6 bytes after name of game) - less data to check.
	if(rom_wr) begin
		if(rom_addr[26:4] == 'hA) begin
			if(rom_addr[3:0] <  12) cart_id[{4'd10 - rom_addr[3:0], 3'd0} +:16] <= {rom_dout[7:0],rom_dout[15:8]};
			if(rom_addr[3:0] == 12) begin
				if(cart_id == {"ROCKY BOXING"} )               begin sram_quirk <= 1;                                             end // Rocky US
				if(cart_id == {"ROCKY", 56'h00000000000000} )  begin sram_quirk <= 1;                                             end // Rocky EU
				if(cart_id == {"DBZ LGCYGOKU"} )               begin sram_quirk <= 1;                                             end // Dragon Ball Z - The Legacy of Goku US
				if(cart_id == {"DRAGONBALL Z"} )               begin sram_quirk <= 1;                                             end // Dragon Ball Z - The Legacy of Goku EU + Dragon Ball Z - The Legacy of Goku II EU
				if(cart_id == {"DBZLEGACY1&2"} )               begin sram_quirk <= 1;                                             end // 2 Games in 1 - Dragon Ball Z - The Legacy of Goku I & II (USA)
				if(cart_id == {"DBZ TAIKETSU"} )               begin sram_quirk <= 1;                                             end // Dragon Ball Z - Taiketsu US
				if(cart_id == {"DRAGON BALLZ"} )               begin sram_quirk <= 1;                                             end // Dragon Ball Z - Taiketsu EU
				if(cart_id == {"DBZBUUSFURY", 8'h00} )         begin sram_quirk <= 1;                                             end // Dragon Ball Z - Buu's Fury US
				if(cart_id == {"DBZLGCYGOKU2"} )               begin sram_quirk <= 1;                                             end // Dragon Ball Z - The Legacy of Goku II US
				if(cart_id == {"DRAGONBALLAA"} )               begin sram_quirk <= 1;                                             end // Dragon Ball Z - Advanced Adventure EU + US + J + K
				if(cart_id == {"TOPGUN CZ", 24'h000000} )      begin sram_quirk <= 1;                                             end // Top Gun - Combat Zones
				if(cart_id == {"IRIDIONII", 24'h000000} )      begin sram_quirk <= 1;                                             end // Iridion II EU and US
				if(cart_id == {"BOMBER MAN", 16'h0000} )       begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Classic NES Series Bomberman / Famicom Mini 09 - Bomber Man
				if(cart_id == {"CASTLEVANIA", 8'h00} )         begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Classic NES Series Castlevania
				if(cart_id == {"DONKEY KONG", 8'h00} )         begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Classic NES Series Donkey Kong / Famicom Mini 02 - Donkey Kong
				if(cart_id == {"DR. MARIO", 24'h000000} )      begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Classic NES Series DR. MARIO / Famicom Mini 15 - Dr. Mario
				if(cart_id == {"EXCITEBIKE", 16'h0000} )       begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Classic NES Series EXCITEBIKE / Famicom Mini 04 - Excitebike
				if(cart_id == {"ICE CLIMBER", 8'h00} )         begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Classic NES Series ICE CLIMBER / Famicom Mini 03 - Ice Climber
				if(cart_id == {"NES METROID", 8'h00} )         begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Classic NES Series NES METROID
				if(cart_id == {"PAC-MAN", 40'h0000000000} )    begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Classic NES Series PAC-MAN / Famicom Mini 06 - Pac-Man
				if(cart_id == {"SUPER MARIO", 8'h00} )         begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Classic NES Series SUPER MARIO Bros / Famicom Mini 01 - Super Mario Bros.
				if(cart_id == {"ZELDA 1", 40'h0000000000} )    begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Classic NES Series The Legend of Zelda / Famicom Mini 05 - Zelda no Densetsu 1 - The Hyrule Fantasy
				if(cart_id == {"XEVIOUS", 40'h0000000000} )    begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Classic NES Series XEVIOUS / Famicom Mini 07 - Xevious
				if(cart_id == {"NES ZELDA 2", 8'h00} )         begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Classic NES Series Zelda II - The Adventure of Link
				if(cart_id == {"SUPER ROBOT2"} )               begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Famicom Mini - Dai-2-ji Super Robot Taisen (Japan) (Promo)
				if(cart_id == {"Z-GUNDAM", 32'h00000000} )     begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Famicom Mini - Kidou Senshi Z Gundam - Hot Scramble (Japan) (Promo)
				if(cart_id == {"SD GACHAPON1"} )               begin sram_quirk <= 1; memory_remap_quirk <= 1; sprite_quirk <= 1; end // Famicom Mini 30 - SD Gundam World - Gachapon Senshi Scramble Wars
				if(cart_id == {"DRACULA 1", 24'h000000} )      begin sram_quirk <= 1; memory_remap_quirk <= 1; sprite_quirk <= 1; end // Famicom Mini 29 - Akumajou Dracula
				if(cart_id == {"TANTEI CLUB2"} )               begin sram_quirk <= 1;                          sprite_quirk <= 1; end // Famicom Mini 28 - Famicom Tantei Club Part II - Ushiro ni Tatsu Shoujo - Zen, Kouhen
				if(cart_id == {"TANTEI CLUB1"} )               begin sram_quirk <= 1;                          sprite_quirk <= 1; end // Famicom Mini 27 - Famicom Tantei Club - Kieta Koukeisha - Zen, Kouhen
				if(cart_id == {"ONIGASHIMA", 16'h0000} )       begin sram_quirk <= 1;                          sprite_quirk <= 1; end // Famicom Mini 26 - Famicom Mukashibanashi - Shin Onigashima - Zen, Kouhen
				if(cart_id == {"LINK", 64'h0000000000000000} ) begin sram_quirk <= 1;                          sprite_quirk <= 1; end // Famicom Mini 25 - The Legend of Zelda 2 - Link no Bouken
				if(cart_id == {"PARTHENA", 32'h00000000} )     begin sram_quirk <= 1;                          sprite_quirk <= 1; end // Famicom Mini 24 - Hikari Shinwa - Palthena no Kagami
				if(cart_id == {"FMS METROID", 8'h00} )         begin sram_quirk <= 1;                          sprite_quirk <= 1; end // Famicom Mini 23 - Metroid
				if(cart_id == {"MURASAME", 32'h00000000} )     begin sram_quirk <= 1;                          sprite_quirk <= 1; end // Famicom Mini 22 - Nazo no Murasame Jou
				if(cart_id == {"SUPER MARIO2"} )               begin sram_quirk <= 1; memory_remap_quirk <= 1; sprite_quirk <= 1; end // Famicom Mini 21 - Super Mario Bros. 2
				if(cart_id == {"GOEMON 1", 32'h00000000} )     begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Famicom Mini 20 - Ganbare Goemon! - Karakuri Douchuu
				if(cart_id == {"TWINBEE", 40'h0000000000} )    begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Famicom Mini 19 - Twin Bee
				if(cart_id == {"MAKAIMURA", 24'h000000} )      begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Famicom Mini 18 - Makaimura
				if(cart_id == {"BOKENJIMA 1", 8'h00} )         begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Famicom Mini 17 - Takahashi Meijin no Bouken-jima
				if(cart_id == {"DIG DUG", 40'h0000000000} )    begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Famicom Mini 16 - Dig Dug
				if(cart_id == {"WRECKINGCREW"} )               begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Famicom Mini 14 - Wrecking Crew
				if(cart_id == {"BALLOONFIGHT"} )               begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Famicom Mini 13 - Balloon Fight
				if(cart_id == {"CLU CLU LAND"} )               begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Famicom Mini 12 - Clu Clu Land
				if(cart_id == {"MARIO BROS.", 8'h00} )         begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Famicom Mini 11 - Mario Bros.
				if(cart_id == {"STAR SOLDIER"} )               begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Famicom Mini 10 - Star Soldier
				if(cart_id == {"MAPPY", 56'h00000000000000} )  begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Famicom Mini 08 - Mappy
				if(cart_id == {"GUNSTAR FH", 12'h000} )        begin                                           sprite_quirk <= 1; end // Gunstar Super/Future Heroes J+EU+US
			end
		end
	end
end

////////////////////////////  MEMORY  ///////////////////////////////////

localparam ROM_START = (65536+131072)*4;

reg sdram_en = 1'b1;


wire [25:2] rom1_addr;
wire [31:0] rom1_dout1 = sdr_sdram_dout1;
wire [31:0] rom1_dout2 = sdr_sdram_dout2;
wire        rom1_ack   = sdr_sdram_ack;
wire        rom1_req;

wire [25:2] rom2_addr;
wire [31:0] rom2_dout1 = ddr_sdram_dout1;
wire [31:0] rom2_dout2 = ddr_sdram_dout2;
wire        rom2_ack   = ddr_sdram_ack;
wire        rom2_req;

wire [25:2] bus1_addr;
wire [31:0] bus1_din;
wire [31:0] bus1_dout = sdr_bus_dout;
wire        bus1_ack  = sdr_bus_ack ;
wire        bus1_rd;
wire        bus1_req;

wire [25:2] bus2_addr;
wire [31:0] bus2_din;
wire [31:0] bus2_dout = ddr_bus_dout;
wire        bus2_ack  = ddr_bus_ack;
wire        bus2_rd;
wire        bus2_req;

wire [31:0] sdr_sdram_dout1, sdr_sdram_dout2, sdr_bus_dout;
wire [15:0] sdr_bram_din;
wire        sdr_sdram_ack, sdr_bus_ack, sdr_bram_ack;

wire [27:2] fb1_addr;
wire [63:0] fb1_din;
wire        fb1_req;
wire        fb1_ack;

wire [27:2] fb2_addr;
wire [63:0] fb2_din;
wire        fb2_req;
wire        fb2_ack;

sdram sdram
(
	.*,
	.init(~pll_locked),
	.clk(clk_sys),

	.ch1_addr({rom1_addr, 1'b0}),
	.ch1_din(16'b0),
	.ch1_dout({sdr_sdram_dout2, sdr_sdram_dout1}),
	.ch1_req(rom1_req),
	.ch1_rnw(cart_download ? 1'b0     : 1'b1     ),
	.ch1_ready(sdr_sdram_ack),

	.ch2_addr(romcopysd_active ? romcopy_writepos[26:1]+ROM_START[26:1] : {bus1_addr, 1'b0}),
	.ch2_din(romcopysd_active ? romcopy_data : bus1_din),
	.ch2_dout(sdr_bus_dout),
	.ch2_req(romcopysd_active ? romcopysd_req : ~cart_download & bus1_req),
	.ch2_rnw(romcopysd_active ? 1'b0 : bus1_rd),
	.ch2_ready(sdr_bus_ack),

	.ch3_addr({sd_lba[7:0],bram_addr}),
	.ch3_din(bram_dout),
	.ch3_dout(sdr_bram_din),
	.ch3_req(bram_req & ~sd_lba[8]),
	.ch3_rnw(~bk_loading),
	.ch3_ready(sdr_bram_ack)
);

always @(posedge clk_sys) begin
	if(cart_download) begin
		if(ioctl_wr)      ioctl_wait <= 1;
		if(ddr_sdram_ack) ioctl_wait <= 0;
	end
	else ioctl_wait <= 0;
end

wire [31:0] ddr_sdram_dout1, ddr_sdram_dout2, ddr_bus_dout;
wire [15:0] ddr_bram_din;
wire        ddr_sdram_ack, ddr_bus_ack, ddr_bram_ack;

assign DDRAM_CLK = clk_sys;
ddram ddram
(
	.*,

	.ch1_addr(romcopy_active ? romcopy_readpos[26:1]+ROM_START[26:1] : {rom2_addr, 1'b0}),
	.ch1_din(16'b0),
	.ch1_dout({ddr_sdram_dout2, ddr_sdram_dout1}),
	.ch1_req(romcopy_active ? romcopy_ddrreq : rom2_req),
	.ch1_rnw(1'b1),
	.ch1_ready(ddr_sdram_ack),

	.ch2_addr({bus2_addr, 1'b0}),
	.ch2_din(bus2_din),
	.ch2_dout(ddr_bus_dout),
	.ch2_req(~cart_download & bus2_req),
	.ch2_rnw(bus2_rd),
	.ch2_ready(ddr_bus_ack),

	.ch3_addr({sd_lba[7:0],bram_addr}),
	.ch3_din(bram_dout),
	.ch3_dout(ddr_bram_din),
	.ch3_req(bram_req & sd_lba[8]),
	.ch3_rnw(~bk_loading),
	.ch3_ready(ddr_bram_ack),

	.ch4_addr(0),
	.ch4_din(0),
	.ch4_dout(),
	.ch4_req(1'b0),
	.ch4_rnw(1'b0),
	.ch4_be(0),
	.ch4_ready(),
   
   .ch5_addr({fb1_addr, 1'b0}),
   .ch5_din(fb1_din),
   .ch5_req(fb1_req),
   .ch5_ready(fb1_ack),
   
   .ch6_addr({fb2_addr, 1'b0}),
   .ch6_din(fb2_din),
   .ch6_req(fb2_req),
   .ch6_ready(fb2_ack)
   
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

wire [15:0] bram_dout;
wire [15:0] bram_din = sd_lba[8] ? ddr_bram_din : sdr_bram_din;
wire        bram_ack = sd_lba[8] ? ddr_bram_ack : sdr_bram_ack;
assign sd_buff_din = bram_buff_out;
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
	.wren_b (sd_buff_wr),
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
reg [1:0] bram_acked;

always @(posedge clk_sys) begin
	reg state;

	bram_req <= 0;
   
   if (sdr_bram_ack) bram_acked[0] <= 1'b1;
   if (ddr_bram_ack) bram_acked[1] <= 1'b1;

	if(~bram_tx_start) {bram_addr, state, bram_tx_finish} <= 0;
	else if(~bram_tx_finish) begin
		if(!state) begin
			bram_req   <= 1;
			state      <= 1;
         bram_acked <= 2'b00;
		end
		else if(bram_acked > 2'd0) begin
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

wire [15:0] px_addr;

reg hs, vs, hbl, vbl, ce_pix;
reg hold_reset;

always @(posedge CLK_VIDEO) begin
	localparam V_START = 62;

	reg [8:0] x,y;
	reg [2:0] div;

	div <= div + 1'd1;

	ce_pix <= 0;
	if(!div) begin
		ce_pix <= 1;

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
			if (y >= 263) y <= 0;
		end
	end

	// Avoid lost sync by reset
	if (x == 0 && y == 0)
		hold_reset <= 1'b0;
	else if (reset)
		hold_reset <= 1'b1;

end

assign VGA_F1 = 0;
assign VGA_SL = sl[1:0];

wire [2:0] scale = 3'b000;
wire [2:0] sl = scale ? scale - 1'd1 : 3'd0;
wire       scandoubler = (scale || forced_scandoubler);

video_mixer #(.LINE_LENGTH(520), .GAMMA(1)) video_mixer
(
	.*,
	.hq2x(1'b0),
	.HSync(hs),
	.VSync(vs),
	.HBlank(hbl),
	.VBlank(vbl),
	.R(8'b0),
	.G(8'b0),
	.B(8'b0)
);

wire [1:0] ar = status[33:32];
video_freak video_freak
(
	.*,
	.VGA_DE_IN(VGA_DE),
	.VGA_DE(),

	.ARX((!ar) ? (status[10] ? 12'd3 : status[9] ? 12'd3 : 12'd3) : (ar - 1'd1)),
	.ARY((!ar) ? (status[10] ? 12'd2 : status[9] ? 12'd1 : 12'd4) : 12'd0),
	.CROP_SIZE(0),
	.CROP_OFF(0),
	.SCALE(status[35:34])
);


/////////////////////////  STATE SAVE/LOAD  /////////////////////////////
wire bk_load     = status[12];
wire bk_save     = status[13];
wire bk_autosave = status[23];
wire bk_write    = (save_eeprom|save_sram|save_flash) && (bus1_req || bus2_req);

reg  bk_ena      = 1'b1;
reg  bk_pending  = 0;
reg  bk_loading  = 0;

always @(posedge clk_sys) begin
	if (bk_write)      bk_pending <= 1;
	else if (bk_state) bk_pending <= 0;
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
					if(sd_lba[8:0] == 9'h1FF) begin
						bk_state <= 0;
					end
				end
		endcase

	end
	else begin
		case(state)
			0: begin
					bram_tx_start <= 1;
					state <= 1;
				end
			1: if(bram_tx_finish) begin
					bram_tx_start <= 0;
					sd_wr  <= 1;
					state  <= 2;
				end
			2: if(old_ack & ~sd_ack) begin
					state <= 0;
					sd_lba <= sd_lba + 1'd1;

					if (sd_lba[8:0] == 9'h1FF)
						bk_state <= 0;
				end
		endcase
	end
end

endmodule
