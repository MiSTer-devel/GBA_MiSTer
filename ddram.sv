//
// ddram.v
// Copyright (c) 2019 Sorgelig
//
//
// This source file is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version. 
//
// This source file is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of 
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the 
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License 
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//
// ------------------------------------------
//

module ddram
(
	input         DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,
	
	input  [27:1] ch1_addr,
	output [63:0] ch1_dout,
	input  [15:0] ch1_din,
	input         ch1_req,
	input         ch1_rnw,
	output        ch1_ready,

	input  [27:1] ch2_addr,
	output [31:0] ch2_dout,
	input  [31:0] ch2_din,
	input         ch2_req,
	input         ch2_rnw,
	output        ch2_ready,

	// data is packed 64bit -> 16bit
	input  [25:1] ch3_addr,
	output [15:0] ch3_dout,
	input  [15:0] ch3_din,
	input         ch3_req,
	input         ch3_rnw,
	output        ch3_ready
);

assign DDRAM_BURSTCNT = ram_burst;
assign DDRAM_BE       = ram_read ? 8'hFF : ram_be;
assign DDRAM_ADDR     = {4'b0011, ram_address[27:3]}; // RAM at 0x30000000
assign DDRAM_RD       = ram_read;
assign DDRAM_DIN      = ram_data;
assign DDRAM_WE       = ram_write;

assign ch1_dout  = cache_addr1[2] ? {ram_q1[31:0], ram_q1[63:32]} : ram_q1;
assign ch2_dout  = cache_addr2[2] ? ram_q2[63:32] : ram_q2[31:0];
assign ch3_dout  = {ram_q3[39:32], ram_q3[7:0]};
assign ch1_ready = ready1;
assign ch2_ready = ready2;
assign ch3_ready = ready3;

reg  [7:0] ram_burst;
reg [63:0] ram_q1, next_q1, ram_q2, next_q2, ram_q3;
reg [63:0] ram_data;
reg [27:1] ram_address, cache_addr1, cache_addr2;
reg        ram_read = 0;
reg        ram_write = 0;
reg  [7:0] ram_be = 0;
reg        ready1, ready2, ready3;

always @(posedge DDRAM_CLK) begin
	reg  [1:0] state  = 0;
	reg  [1:0] ch = 0; 

	reg ch1_rq, ch2_rq, ch3_rq;

	ch1_rq <= ch1_rq | ch1_req;
	ch2_rq <= ch2_rq | ch2_req;
	ch3_rq <= ch3_rq | ch3_req;

	ready1 <= 0;
	ready2 <= 0;
	ready3 <= 0;

	if(!DDRAM_BUSY) begin
		ram_write <= 0;
		ram_read  <= 0;

		case(state)
			0,1: if(ch1_rq) begin
					ch1_rq  <= 0;
					ch      <= 0;
					if(~ch1_rnw) begin
						ram_address <= ch1_addr;
						ram_data    <= {4{ch1_din}};
						ram_be      <= 8'h03 << {ch1_addr[2:1],1'b0};
						ram_write   <= 1;
						ram_burst   <= 1;
						ready1      <= 1;
						cache_addr1 <= '1;
					end
					else if(cache_addr1[27:3] == ch1_addr[27:3]) begin
						ready1      <= 1;
						cache_addr1[2:1] <= ch1_addr[2:1];
					end
					else if((cache_addr1[27:3]+1'd1) == ch1_addr[27:3]) begin
						ram_q1      <= next_q1;
						cache_addr1 <= ch1_addr;
						ram_address <= ch1_addr + 8'd4;
						ram_read    <= 1;
						ram_burst   <= 1;
						ready1      <= 1;
						state       <= 3;
					end
					else begin
						ram_address <= ch1_addr;
						cache_addr1 <= ch1_addr;
						ram_read    <= 1;
						ram_burst   <= 2;
						state       <= 2;
					end
				end
			   else if(ch2_rq) begin
					ch2_rq  <= 0;
					ch      <= 1;
					if(~ch2_rnw) begin
						ram_address <= ch2_addr;
						ram_data    <= {2{ch2_din}};
						ram_be      <= ch2_addr[2] ? 8'hF0 : 8'h0F;
						ram_write   <= 1;
						ram_burst   <= 1;
						ready2      <= 1;
						cache_addr2 <= '1;
					end
					else if(cache_addr2[27:3] == ch2_addr[27:3]) begin
						ready2      <= 1;
						cache_addr2[2:1] <= ch2_addr[2:1];
					end
					else if((cache_addr2[27:3]+1'd1) == ch2_addr[27:3]) begin
						ram_q2      <= next_q2;
						cache_addr2 <= ch2_addr;
						ram_address <= ch2_addr + 8'd4;
						ram_read    <= 1;
						ram_burst   <= 1;
						ready2      <= 1;
						state       <= 3;
					end
					else begin
						ram_address <= ch2_addr;
						cache_addr2 <= ch2_addr;
						ram_read    <= 1;
						ram_burst   <= 2;
						state       <= 2;
					end
				end
			   else if(ch3_rq) begin
					ch3_rq      <= 0;
					ch          <= 2;
					ram_be      <= 8'h11;
					ram_burst   <= 1;
					ram_address <= {ch3_addr, 2'b00};
					if(~ch3_rnw) begin
						ram_data    <= {24'd0, ch3_din[15:8], 24'd0, ch3_din[7:0]};
						ram_write   <= 1;
						ready3      <= 1;
						cache_addr2 <= '1;
					end
					else begin
						ram_read    <= 1;
						state       <= 2;
					end
				end

			2: if(DDRAM_DOUT_READY) begin
					state <= 3;
					case(ch)
						0: begin
								ram_q1 <= DDRAM_DOUT;
								ready1 <= 1;
							end
						1: begin
								ram_q2 <= DDRAM_DOUT;
								ready2 <= 1;
							end
						2: begin
								ram_q3 <= DDRAM_DOUT;
								ready3 <= 1;
								state  <= 0;
							end
					endcase
				end

			3: if(DDRAM_DOUT_READY) begin
					case(ch)
						0: next_q1 <= DDRAM_DOUT;
						1: next_q2 <= DDRAM_DOUT;
					endcase
					state <= 0;
				end
		endcase
	end
end

endmodule
