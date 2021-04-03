//////////////////////////////////////////////////////////////////////////////////
//	(c) 2020-2021, Cypress Semiconductor Corporation (an Infineon company) or an affiliate of Cypress Semiconductor Corporation.  All rights reserved.
//
//	This software, including source code, documentation and related materials ("Software") is owned by Cypress Semiconductor Corporation or one of its affiliates ("Cypress") and is protected by and subject to worldwide patent protection (United States and foreign), United States copyright laws and international treaty provisions.  Therefore, you may use this Software only as provided in the license agreement accompanying the software package from which you obtained this Software ("EULA").
//	If no EULA applies, Cypress hereby grants you a personal, non-exclusive, non-transferable license to copy, modify, and compile the Software source code solely for use in connection with Cypress's integrated circuit products.  Any reproduction, modification, translation, compilation, or representation of this Software except as specified above is prohibited without the express written permission of Cypress.
//
//	Disclaimer: THIS SOFTWARE IS PROVIDED AS-IS, WITH NO WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, NONINFRINGEMENT, IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. Cypress reserves the right to make changes to the Software without notice. Cypress does not assume any liability arising out of the application or use of the Software or any product or circuit described in the Software. Cypress does not authorize its products for use in any products where a malfunction or failure of the Cypress product may reasonably be expected to result in significant property damage, injury or death ("High Risk Product"). By including Cypress's product in a High Risk Product, the manufacturer of such system or application assumes all risk of such use and in doing so agrees to indemnify Cypress against all liability.
//
// Design Name:		testptrn 
// Module Name:		testpattern_mod
// Target Devices:	LFE5U-45F-8BG381I
// Description: testpattern_mod generates the colorbar video data for both the SLFIFO_INTERFACE mode and the CAMERA_INTERFACE mode.
//				The Height and Width of the video frame can be controlled at the input.
//				The FPS for the SLFIFO_INTERFACE mode is restricted by the Slavefifo interface bandwidth.
//				The FPS for the CAMERA_INTERFACE mode is based on the blanking set.
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`include "parameters.v"

module testpattern_mod
#(	parameter [3:0] BYTE_PER_PIX='d2)
(
	input			clk_i,
	
	input			en_i,
	input			busy_i,
	input [1:0]		bus_wdt_i,	//	Bus Width:
	input [15:0]	fr_width_i,	// Max 8192
	input [15:0]	fr_height_i,	// Max 8192
	
	output			hsync_o,
	output			vsync_o,
	output [31:0]	data_o
);

reg [12:0] pix_cnt_r=13'd0;
reg [12:0] pix_cnt_max_r=13'd0;
reg [12:0] pix_cnt_max_r1=13'd0;
reg [12:0] pix_cnt_active_r=13'd0;
reg [12:0] line_cnt_r=13'd0;
reg [12:0] line_cnt_max_r=13'd0;
reg [31:0] data_r='d0;
reg [2:0] color_idx_r='d0;
reg [9:0] color_cnt_r='d0;
reg [31:0] color_r='d0;
reg [31:0] cb_data_r='d0;
wire [15:0] fr_width_w;
reg [15:0] fr_width_temp_r='d0;
reg [15:0] fr_width_div3_r='d0;
reg hsync_rr='d0;
reg hsync_r='d0;
reg vsync_rr='d0;
reg vsync_r='d0;
reg [1:0] byte_cnt='d0;

localparam FRAME_BLANK = 40;
localparam LINE_BLANK = 240;

localparam BUSWDT_8=2'd0;
localparam BUSWDT_16=2'd1;
localparam BUSWDT_24=2'd2;
localparam BUSWDT_32=2'd3;

localparam BAND1 = 3'd0;
localparam BAND2 = 3'd1;
localparam BAND3 = 3'd2;
localparam BAND4 = 3'd3;
localparam BAND5 = 3'd4;
localparam BAND6 = 3'd5;
localparam BAND7 = 3'd6;
localparam BAND8 = 3'd7;
localparam BAND1_COLOR = 32'hff80ff80;	// White
localparam BAND2_COLOR = 32'hff94ff00;	// Yellow
localparam BAND3_COLOR = 32'hc81ac8bf;	// Blue
localparam BAND4_COLOR = 32'hca4aca55;	// Green
localparam BAND5_COLOR = 32'h96f3969f;	// Pink
localparam BAND6_COLOR = 32'h4cff4c54;	// Red
localparam BAND7_COLOR = 32'h409e40d3;	// Violet
localparam BAND8_COLOR = 32'h00800080;	// Black
localparam BAND1_COLOR_YUYV = 32'h80ff80ff;	// White
localparam BAND2_COLOR_YUYV = 32'h94ff00ff;	// Yellow
localparam BAND3_COLOR_YUYV = 32'h1ac8bfc8;	// Blue
localparam BAND4_COLOR_YUYV = 32'h4aca55ca;	// Green
localparam BAND5_COLOR_YUYV = 32'hf3969f96;	// Pink
localparam BAND6_COLOR_YUYV = 32'hff4c544c;	// Red
localparam BAND7_COLOR_YUYV = 32'h9e40d340;	// Violet
localparam BAND8_COLOR_YUYV = 32'h80008000;	// Black

						  

generate
	if(BYTE_PER_PIX=='d4) begin
		assign fr_width_w = {fr_width_i,2'b00};
	end else if(BYTE_PER_PIX=='d3) begin
		assign fr_width_w = {1'b0,fr_width_i,1'b0} + fr_width_i;
	end else if(BYTE_PER_PIX=='d2) begin
		assign fr_width_w = {1'b0,fr_width_i,1'b0};
	end else begin
		assign fr_width_w = {2'b0,fr_width_i};
	end 
endgenerate

`ifdef CAMERA_INTERFACE
always @(posedge clk_i) begin
	case(bus_wdt_i)
		BUSWDT_32: cb_data_r <= color_r;
		
		BUSWDT_24: begin
			case(byte_cnt)
				2'd0:	cb_data_r <= color_r[23:0];
				2'd1:	cb_data_r <= {color_r[15:0],color_r[31:24]};
				2'd2:	cb_data_r <= {color_r[7:0],color_r[31:16]};
				2'd3:	cb_data_r <= color_r[31:8];
			endcase
		end

		BUSWDT_16: begin
			if(byte_cnt[0])
				cb_data_r <= color_r[31:16];
			else
				cb_data_r <= color_r[15:0];
		end
		
		BUSWDT_8: begin
			case(byte_cnt)
				2'd0:	cb_data_r <= color_r[7:0];
				2'd1:	cb_data_r <= color_r[15:8];
				2'd2:	cb_data_r <= color_r[23:16];
				2'd3:	cb_data_r <= color_r[31:24];
			endcase
		end
	endcase
end
always @(*) begin
	case(color_idx_r)
		BAND1 : color_r <= BAND1_COLOR_YUYV;
		BAND2 : color_r <= BAND2_COLOR_YUYV;
		BAND3 : color_r <= BAND3_COLOR_YUYV;
		BAND4 : color_r <= BAND4_COLOR_YUYV;
		BAND5 : color_r <= BAND5_COLOR_YUYV;
		BAND6 : color_r <= BAND6_COLOR_YUYV;
		BAND7 : color_r <= BAND7_COLOR_YUYV;
		BAND8 : color_r <= BAND8_COLOR_YUYV;
	endcase
end
always @(posedge clk_i) begin
	vsync_rr <= vsync_r;
	hsync_rr <= hsync_r;
end
always @(posedge clk_i) begin
	if(!hsync_r)
		byte_cnt <= 2'd0;
	else
		byte_cnt <= byte_cnt + 2'd1;
end

assign hsync_o = hsync_rr;
assign vsync_o = vsync_rr;
assign data_o = cb_data_r;
						  
`else

always @(*) begin
	case(color_idx_r)
		BAND1 : cb_data_r <= BAND1_COLOR;
		BAND2 : cb_data_r <= BAND2_COLOR;
		BAND3 : cb_data_r <= BAND3_COLOR;
		BAND4 : cb_data_r <= BAND4_COLOR;
		BAND5 : cb_data_r <= BAND5_COLOR;
		BAND6 : cb_data_r <= BAND6_COLOR;
		BAND7 : cb_data_r <= BAND7_COLOR;
		BAND8 : cb_data_r <= BAND8_COLOR;
	endcase
end

assign hsync_o = hsync_r;
assign vsync_o = vsync_r;
assign data_o = cb_data_r;

`endif

always @(posedge clk_i) begin
	if(!vsync_r)
		color_idx_r <= 'd0;
	else if((color_cnt_r==(pix_cnt_active_r[12:3]-'d1))&hsync_r)
		color_idx_r <= color_idx_r + 'd1;
	if(!vsync_r)
		color_cnt_r <= 'd0;
	else if((color_cnt_r==(pix_cnt_active_r[12:3]-'d1))&hsync_r)
		color_cnt_r <= 'd0;
	else if(hsync_r)
		color_cnt_r <= color_cnt_r + 'd1;
end

`ifdef CAMERA_INTERFACE
always @(posedge clk_i) begin	
	fr_width_temp_r <= fr_width_w;
	fr_width_div3_r <= fr_width_temp_r / 3;
end
always @(posedge clk_i) begin	
	if(!en_i)begin
		case(bus_wdt_i)
			BUSWDT_32:begin	
				pix_cnt_active_r <= fr_width_w[15:2];
				pix_cnt_max_r <= fr_width_w[15:2];
				line_cnt_max_r <= fr_height_i+FRAME_BLANK;
			end
			BUSWDT_24:begin	
				pix_cnt_active_r <= fr_width_div3_r;
				pix_cnt_max_r <= fr_width_div3_r;
				line_cnt_max_r <= fr_height_i+FRAME_BLANK;
			end
			BUSWDT_16:begin	
				pix_cnt_active_r <= fr_width_w[15:1];
				pix_cnt_max_r <= fr_width_w[15:1];
				line_cnt_max_r <= fr_height_i+FRAME_BLANK;
			end
			BUSWDT_8:begin	
				pix_cnt_active_r <= fr_width_w;
				pix_cnt_max_r <= fr_width_w;
				line_cnt_max_r <= fr_height_i+FRAME_BLANK;
			end
		endcase
	end
	pix_cnt_max_r1 <= pix_cnt_max_r + LINE_BLANK;
end
`else
always @(posedge clk_i) begin	
	if(!en_i)begin
		pix_cnt_active_r <= fr_width_w[15:2];
		pix_cnt_max_r1 <= fr_width_w[15:2];
		pix_cnt_max_r <= fr_width_w[15:2];
		line_cnt_max_r <= fr_height_i+FRAME_BLANK;
	end
end
`endif
always@(posedge clk_i) begin
	if(!en_i) begin
		pix_cnt_r <= 'd0;
		line_cnt_r <= 'd0;
	end
`ifdef CAMERA_INTERFACE
	else begin
`else
	else if(!busy_i)begin
`endif
		if(pix_cnt_r==(pix_cnt_max_r1-'d1)) begin
			pix_cnt_r <= 'd0;
			if(line_cnt_r == (line_cnt_max_r-'d1))
				line_cnt_r <= 'd0;
			else
				line_cnt_r <= line_cnt_r + 'd1;
		end
		else
			pix_cnt_r <= pix_cnt_r + 'd1;
	end
end

always@(posedge clk_i) begin
	if(!(en_i&vsync_r))
		data_r <= 'd0;
	else if(hsync_r)
		data_r <= data_r + 'd1;
end

`ifdef CAMERA_INTERFACE
always@(posedge clk_i) begin
	if(!en_i)begin
		hsync_r <=  1'd0;
		vsync_r <=  1'd0;
	end
	else begin
		if(line_cnt_r<(line_cnt_max_r-FRAME_BLANK+'d2))	// 2 line interval is back porch
			vsync_r <= 'd1;
		else
			vsync_r <= 'd0;
		if((pix_cnt_r>(LINE_BLANK-'d1))&(line_cnt_r<(line_cnt_max_r-FRAME_BLANK)))
			hsync_r <= 'd1;
		else
			hsync_r <= 'd0;
	end
end
`else
always@(posedge clk_i) begin
	if(!en_i)begin
		hsync_r <=  1'd0;
		vsync_r <=  1'd0;
	end
	else if(!busy_i)begin
		if(line_cnt_r<(line_cnt_max_r-FRAME_BLANK)) begin
			vsync_r <= 'd1;
			hsync_r <= 'd1;
		end
		else begin
			vsync_r <= 'd0;
			hsync_r <= 'd0;
		end
	end	
	else begin
		vsync_r <= vsync_r;
		hsync_r <= 'd0;
	end
end
`endif

endmodule
