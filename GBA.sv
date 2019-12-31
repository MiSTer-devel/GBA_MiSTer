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
	output  [7:0] VIDEO_ARX,
	output  [7:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,

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

	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S, // 1 - signed audio samples, 0 - unsigned
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

assign VIDEO_ARX = status[1] ? 8'd16 : 8'd3;
assign VIDEO_ARY = status[1] ? 8'd9  : 8'd2;

assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;

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

// Status Bit Map:
// 0         1         2         3
// 01234567890123456789012345678901
// 0123456789ABCDEFGHIJKLMNOPQRSTUV
// XXXXXXXXXXXXXXXXXXX    X

`include "build_id.v"
parameter CONF_STR = {
    "GBA;;",
    "FS,GBA;",
    "-;",
    //"C,Cheats;",
    //"H1O6,Cheats Enabled,Yes,No;",
    //"-;",
    "D0RC,Reload Backup RAM;",
    "D0RD,Save Backup RAM;",
    "D0ON,Autosave,Off,On;",
    "D0-;",
    "RH,Save state;",
    "RI,Restore state;",
	 "-;",
    "O1,Aspect Ratio,3:2,16:9;",
    "O9A,Desaturate,Off,Level 1,Level 2,Level 3;",
    "OB,Sync core to video,Off,On;",
    "O24,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
    "O78,Stereo Mix,None,25%,50%,100%;", 
    "-;",
    "OEF,Storage,Auto,SDRAM,DDR3;",
    "O5,Pause,Off,On;",
    "H2OG,Turbo,Off,On;",
    "R0,Reset;",
    "J1,A,B,L,R,Select,Start,FastForward;",
    "jn,A,B,L,R,Select,Start,X;",
    "V,v",`BUILD_DATE
};

wire  [1:0] buttons;
wire [31:0] status;
wire [15:0] status_menumask = {force_turbo, ~gg_available, ~bk_ena};
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

wire [11:0] joy;
wire [21:0] gamma_bus;
reg         ioctl_wait = 0;

wire [15:0] sdram_sz;

hps_io #(.STRLEN($size(CONF_STR)>>3), .WIDE(1)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),
	.conf_str(CONF_STR),

	.buttons(buttons),
	.forced_scandoubler(forced_scandoubler),

	.joystick_0(joy),

	.status(status),
	.status_menumask(status_menumask),

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

	.img_mounted(img_mounted),
	.img_readonly(img_readonly),
	.img_size(img_size),

	.sdram_sz(sdram_sz),
	.gamma_bus(gamma_bus)
);

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
always @(posedge clk_sys) begin
	reg [63:0] str;
	reg old_download;
	
	old_download <= cart_download;
	if (old_download & ~cart_download) last_addr <= ioctl_addr;
	
	if(~old_download & cart_download) begin
		flash_1m <= 0;
		cart_type <= ioctl_index[7:6];
	end

	if(cart_download & ioctl_wr) begin
		if({str, ioctl_dout[7:0]} == "FLASH1M_V") flash_1m <= 1;
		if({str[55:0], ioctl_dout[7:0], ioctl_dout[15:8]} == "FLASH1M_V") flash_1m <= 1;

		str <= {str[47:0], ioctl_dout[7:0], ioctl_dout[15:8]};
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

wire        save_eeprom, save_sram, save_flash;
wire [31:0] cpu_addr, cpu_frombus;

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
	pause <= force_pause | status[5];
	cpu_turbo <= ((status[16] & ~fast_forward) | force_turbo) & ~pause;
end

gba_top
#(
   // assume: cart may have either flash or eeprom, not both! (need to verify)
	.Softmap_GBA_FLASH_ADDR  (0),                   // 131072 (8bit)  -- 128 Kbyte Data for GBA Flash
	.Softmap_GBA_EEPROM_ADDR (0),                   //   8192 (8bit)  --   8 Kbyte Data for GBA EEProm
	.Softmap_GBA_WRam_ADDR   (131072),              //  65536 (32bit) -- 256 Kbyte Data for GBA WRam Large
	.Softmap_GBA_Gamerom_ADDR(65536+131072),        //   32MB of ROM
	.Softmap_SaveState_ADDR  (0),                   // 262144 (32bit) -- ~1Mbyte Data for SaveState (separate memory)
	.turbosound('1)                                 // sound buffer to play sound in turbo mode without sound pitched up
)
gba
(
	.clk100(clk_sys),
	.GBA_on(~reset),                  // switching from off to on = reset
	.GBA_lockspeed(~fast_forward),    // 1 = 100% speed, 0 = max speed
	.GBA_cputurbo(cpu_turbo),
	.GBA_flash_1m(flash_1m),          // 1 when string "FLASH1M_V" is anywhere in gamepak
	.CyclePrecalc(pause ? 16'd0 : 16'd100), // 100 seems to be ok to keep fullspeed for all games
	.MaxPakAddr(last_addr[26:2]),     // max byte address that will contain data, required for buggy games that read behind their own memory, e.g. zelda minish cap
	.CyclesMissing(),                 // debug only for speed measurement, keep open
	.CyclesVsyncSpeed(),              // debug only for speed measurement, keep open
	.SramFlashEnable(~sram_quirk),
	.memory_remap(memory_remap_quirk),
   .save_state(status[17]),
   .load_state(status[18]),

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
   .SAVE_out_done(ss_ack),           // should be one cycle high when write is done or read value is valid

	.save_eeprom(save_eeprom),
	.save_sram(save_sram),
	.save_flash(save_flash),

	.bios_wraddr(bios_wraddr),
	.bios_wrdata(bios_wrdata),
	.bios_wr(bios_wr),

	.cpu_addr(cpu_addr),
	.cpu_din(genie_ovr ? genie_data : cpu_frombus),
	.cpu_frombus(cpu_frombus),

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
	
	.pixel_out_addr(pixel_addr),      // integer range 0 to 38399;       -- address for framebuffer 
	.pixel_out_data(pixel_data),      // RGB data for framebuffer 
	.pixel_out_we(pixel_we),          // new pixel for framebuffer 

	.sound_out_left(AUDIO_L),
	.sound_out_right(AUDIO_R)
);

////////////////////////////  QUIRKS  //////////////////////////////////

reg sram_quirk = 0;
reg memory_remap_quirk = 0;
always @(posedge clk_sys) begin
	reg [95:0] cart_id;
	reg old_download;
	old_download <= cart_download;

	if(~old_download && cart_download) begin
      sram_quirk         <= 0;
      memory_remap_quirk <= 0;
   end

	// TODO: better to use game ID (fixed 6 bytes after name of game) - less data to check.
	if(ioctl_wr & cart_download) begin
		if(ioctl_addr[26:4] == 'hA) begin
			if(ioctl_addr[3:0] <  12) cart_id[{4'd10 - ioctl_addr[3:0], 3'd0} +:16] <= {ioctl_dout[7:0],ioctl_dout[15:8]};
			if(ioctl_addr[3:0] == 12) begin
				if(cart_id == {"ROCKY BOXING"} )              begin sram_quirk <= 1;                          end // Rocky US
				if(cart_id == {"ROCKY", 56'h00000000000000} ) begin sram_quirk <= 1;                          end // Rocky EU
				if(cart_id == {"DBZ LGCYGOKU"} )              begin sram_quirk <= 1;                          end // Dragon Ball Z - The Legacy of Goku US
				if(cart_id == {"DRAGONBALL Z"} )              begin sram_quirk <= 1;                          end // Dragon Ball Z - The Legacy of Goku EU
				if(cart_id == {"DBZ TAIKETSU"} )              begin sram_quirk <= 1;                          end // Dragon Ball Z - Taiketsu US
				if(cart_id == {"DRAGON BALLZ"} )              begin sram_quirk <= 1;                          end // Dragon Ball Z - Taiketsu EU
				if(cart_id == {"TOPGUN CZ", 24'h000000} )     begin sram_quirk <= 1;                          end // Top Gun - Combat Zones
				if(cart_id == {"IRIDIONII", 24'h000000} )     begin sram_quirk <= 1;                          end // Iridion II EU and US
				if(cart_id == {"BOMBER MAN", 16'h0000} )      begin sram_quirk <= 1; memory_remap_quirk <= 1; end // Classic NES Series Bomberman
				if(cart_id == {"CASTLEVANIA", 8'h00} )        begin sram_quirk <= 1; memory_remap_quirk <= 1; end // Classic NES Series Castlevania
				if(cart_id == {"DONKEY KONG", 8'h00} )        begin sram_quirk <= 1; memory_remap_quirk <= 1; end // Classic NES Series Donkey Kong
				if(cart_id == {"DR. MARIO", 24'h000000} )     begin sram_quirk <= 1; memory_remap_quirk <= 1; end // Classic NES Series DR. MARIO
				if(cart_id == {"EXCITEBIKE", 16'h0000} )      begin sram_quirk <= 1; memory_remap_quirk <= 1; end // Classic NES Series EXCITEBIKE
				if(cart_id == {"ICE CLIMBER", 8'h00} )        begin sram_quirk <= 1; memory_remap_quirk <= 1; end // Classic NES Series ICE CLIMBER
				if(cart_id == {"NES METROID", 8'h00} )        begin sram_quirk <= 1; memory_remap_quirk <= 1; end // Classic NES Series NES METROID
				if(cart_id == {"PAC-MAN", 40'h0000000000} )   begin sram_quirk <= 1; memory_remap_quirk <= 1; end // Classic NES Series PAC-MAN
				if(cart_id == {"SUPER MARIO", 8'h00} )        begin sram_quirk <= 1; memory_remap_quirk <= 1; end // Classic NES Series SUPER MARIO Bros
				if(cart_id == {"ZELDA 1", 40'h0000000000} )   begin sram_quirk <= 1; memory_remap_quirk <= 1; end // Classic NES Series The Legend of Zelda
				if(cart_id == {"XEVIOUS", 40'h0000000000} )   begin sram_quirk <= 1; memory_remap_quirk <= 1; end // Classic NES Series XEVIOUS
				if(cart_id == {"NES ZELDA 2", 8'h00} )        begin sram_quirk <= 1; memory_remap_quirk <= 1; end // Classic NES Series Zelda II - The Adventure of Link
			end
		end
	end
end

////////////////////////////  CODES  ///////////////////////////////////

wire        gg_available;
wire        genie_ovr;
wire [31:0] genie_data;

/*
// Code layout:
// {clock bit, code flags,     32'b address, 32'b compare, 32'b replace}
//  128        127:96          95:64         63:32         31:0
// Integer values are in BIG endian byte order, so it up to the loader
// or generator of the code to re-arrange them correctly.

reg [128:0] gg_code;
always_ff @(posedge clk_sys) begin
	gg_code[128] <= 0;

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
				gg_code[128]      <= 1;          // Clock it in
			end
		endcase
	end
end

CODES #(.ADDR_WIDTH(32), .DATA_WIDTH(32)) codes (
	.clk(clk_sys),
	.reset(code_download && ioctl_wr && !ioctl_addr),
	.enable(~status[6]),
	.addr_in(cpu_addr),
	.data_in(cpu_frombus),
	.code(gg_code),
	.available(gg_available),
	.genie_ovr(genie_ovr),
	.genie_data(genie_data)
);
*/

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

sdram sdram
(
	.*,
	.init(~pll_locked),
	.clk(clk_sys),

	.ch1_addr(cart_download ? ioctl_addr[26:1]+ROM_START[26:1] : {sdram_addr, 1'b0}),
	.ch1_din(ioctl_dout),
	.ch1_dout({sdr_sdram_dout2, sdr_sdram_dout1}),
	.ch1_req((cart_download ? ioctl_wr : sdram_req) & sdram_en),
	.ch1_rnw(cart_download ? 1'b0     : 1'b1     ),
	.ch1_ready(sdr_sdram_ack),

	.ch2_addr({bus_addr, 1'b0}),
	.ch2_din(bus_din),
	.ch2_dout(sdr_bus_dout),
	.ch2_req(~cart_download & bus_req & sdram_en),
	.ch2_rnw(bus_rd),
	.ch2_ready(sdr_bus_ack),

	.ch3_addr({sd_lba[7:0],bram_addr}),
	.ch3_din(bram_dout),
	.ch3_dout(sdr_bram_din),
	.ch3_req(bram_req & sdram_en),
	.ch3_rnw(~bk_loading),
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

wire [31:0] ss_dout, ss_din;
wire [24:2] ss_addr;
wire        ss_rnw, ss_req, ss_ack;

assign DDRAM_CLK = clk_sys;
ddram ddram
(
	.*,

	.ch1_addr(cart_download ? ioctl_addr[26:1]+ROM_START[26:1] : {sdram_addr, 1'b0}),
	.ch1_din(ioctl_dout),
	.ch1_dout({ddr_sdram_dout2, ddr_sdram_dout1}),
	.ch1_req((cart_download ? ioctl_wr : sdram_req) & ~sdram_en),
	.ch1_rnw(cart_download ? 1'b0     : 1'b1     ),
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
	.ch3_rnw(~bk_loading),
	.ch3_ready(ddr_bram_ack),
	
	.ch4_addr({ss_addr, 1'b0}),
	.ch4_din(ss_din),
	.ch4_dout(ss_dout),
	.ch4_req(ss_req),
	.ch4_rnw(ss_rnw),
	.ch4_ready(ss_ack)
);

wire [15:0] bram_dout;
wire [15:0] bram_din = sdram_en ? sdr_bram_din : ddr_bram_din;
wire        bram_ack = sdram_en ? sdr_bram_ack : ddr_bram_ack;

dpram #(8,16) bram
(
	.clock(clk_sys),

	.address_a(bram_addr),
	.wren_a(~bk_loading & bram_ack),
	.data_a(bram_din),
	.q_a(bram_dout),

	.address_b(sd_buff_addr),
	.wren_b(sd_buff_wr),
	.data_b(sd_buff_dout),
	.q_b(sd_buff_din)
);

reg [7:0] bram_addr;
reg bram_tx_start;
reg bram_tx_finish;
reg bram_req;
always @(posedge clk_sys) begin
	reg state;

	bram_req <= 0;

	if(~bram_tx_start) {bram_addr, state, bram_tx_finish} <= 0;
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
wire [14:0] pixel_data;
wire        pixel_we;

reg vsync;
always @(posedge clk_sys) begin
	reg [7:0] sync;

	sync <= sync << 1;
	if(pixel_we && pixel_addr == 0) sync <= 1;

	vsync <= |sync;
end

dpram_n #(16,15,38400) vram
(
	.clock_a(clk_sys),
	.address_a(pixel_addr),
	.data_a(pixel_data),
	.wren_a(pixel_we),

	.clock_b(CLK_VIDEO),
	.address_b(px_addr),
	.q_b(rgb)
);

wire [15:0] px_addr;
wire [14:0] rgb;
wire sync_core = status[11];

reg hs, vs, hbl, vbl, ce_pix;
reg [4:0] r,g,b;
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

wire [7:0] r_in = {r,r[4:2]};
wire [7:0] g_in = {g,g[4:2]};
wire [7:0] b_in = {b,b[4:2]};

//wire [7:0] luma = r_in[7:3] + g_in[7:1] + g_in[7:2] + b_in[7:3];
wire [7:0] luma = r_in[7:2] + g_in[7:1] + g_in[7:3] + b_in[7:3];

wire [7:0] r_out, g_out, b_out;
always_comb begin
	case(status[10:9])
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

video_mixer #(.LINE_LENGTH(520), .GAMMA(1)) video_mixer
(
	.*,

	.clk_vid(CLK_VIDEO),
	.ce_pix_out(CE_PIXEL),

	.scanlines(0),
	.hq2x(scale==1),
	.mono(0),

	.HSync(hs),
	.VSync(vs),
	.HBlank(hbl),
	.VBlank(vbl),
	.R(r_out),
	.G(g_out),
	.B(b_out)
);


/////////////////////////  STATE SAVE/LOAD  /////////////////////////////
wire bk_load     = status[12];
wire bk_save     = status[13];
wire bk_autosave = status[23];
wire bk_write    = (save_eeprom|save_sram|save_flash) && bus_req;

reg  bk_ena      = 0;
reg  bk_pending  = 0;
reg  bk_loading  = 0;


always @(posedge clk_sys) begin
	if (bk_write)      bk_pending <= 1;
	else if (bk_state) bk_pending <= 0;
end

reg [7:0] save_sz;
always @(posedge clk_sys) begin
	reg old_downloading;
	reg use_img;

	old_downloading <= cart_download;
	if(~old_downloading & cart_download) {use_img, save_sz} <= 0;

	if(bus_req & ~use_img) begin
		if(save_eeprom) save_sz <= save_sz | 8'hF;
		if(save_sram)   save_sz <= save_sz | 8'h3F;
		if(save_flash)  save_sz <= save_sz | {flash_1m, 7'h7F};
	end
	
	if(img_mounted && img_size && !img_readonly) begin
		use_img <= 1;
		save_sz <= img_size[16:9] - 1'd1;
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
					if(&sd_lba[7:0]) bk_state <= 0;
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
					sd_wr <= 1;
					state <= 2;
				end
			2: if(old_ack & ~sd_ack) begin
					state <= 0;
					sd_lba <= sd_lba + 1'd1;
					if(sd_lba[7:0] == save_sz) bk_state <= 0;
				end
		endcase
	end
end

endmodule
