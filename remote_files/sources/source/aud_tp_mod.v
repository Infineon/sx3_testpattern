//////////////////////////////////////////////////////////////////////////////////
//	(c) 2020-2021, Cypress Semiconductor Corporation (an Infineon company) or an affiliate of Cypress Semiconductor Corporation.  All rights reserved.
//
//	This software, including source code, documentation and related materials ("Software") is owned by Cypress Semiconductor Corporation or one of its affiliates ("Cypress") and is protected by and subject to worldwide patent protection (United States and foreign), United States copyright laws and international treaty provisions.  Therefore, you may use this Software only as provided in the license agreement accompanying the software package from which you obtained this Software ("EULA").
//	If no EULA applies, Cypress hereby grants you a personal, non-exclusive, non-transferable license to copy, modify, and compile the Software source code solely for use in connection with Cypress's integrated circuit products.  Any reproduction, modification, translation, compilation, or representation of this Software except as specified above is prohibited without the express written permission of Cypress.
//
//	Disclaimer: THIS SOFTWARE IS PROVIDED AS-IS, WITH NO WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, NONINFRINGEMENT, IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. Cypress reserves the right to make changes to the Software without notice. Cypress does not assume any liability arising out of the application or use of the Software or any product or circuit described in the Software. Cypress does not authorize its products for use in any products where a malfunction or failure of the Cypress product may reasonably be expected to result in significant property damage, injury or death ("High Risk Product"). By including Cypress's product in a High Risk Product, the manufacturer of such system or application assumes all risk of such use and in doing so agrees to indemnify Cypress against all liability.
//
// Design Name:		testptrn 
// Module Name:		aud_tp_mod
// Target Devices:	LFE5U-45F-8BG381I
// Description: This module generates the test sine wave stereo audio data at 48KHz with 16BIT width. The generated audio data is written into the 2 audio buffers alternately as 192 byte bursts.
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`include "parameters.v"

module aud_tp_mod
(
	input	clk_i,
	input	rstn_i,	
	input	rstn_sync_i,	

	// Control signals
	input	en_i,
	input	aud_only_i,
	input	cam_app_en,
	input	aud_fifo_rden_i,
	input	vid_vsync_fall_i,
	output	[31:0]	aud_fifo_data_o,
	output	aud_fifo_empty_o,
	output	aud_fifo_almostempty_o,
	input	aud_pktend_i //	Indicates audio data's packetend in GPIF interface
	);

reg		wr_fifo_idx='d0;
reg [6:0]	mg_byte_wr_cnt='d0;
reg		mg_byte_wr_en_r='d0;

reg		aud_rdidx_r='d0;
wire 	aud_rd_idx;

wire[15:0]	aud_fifo_dout[1:0];
reg	[1:0]	i2s_wr_en;
wire[1:0]	aud_fifo_empty;
wire[1:0]	aud_fifo_rden;
wire[1:0]	aud_almostempty;
reg [1:0]	aud_almostempty_r='d0;
wire[1:0]	aud_almostfull;
reg	[1:0]	rst='d0;
genvar gi;

localparam CLOCK_FREQUENCY='d100000000;
localparam AUD_LRCLK_FZ='d48000;

localparam BIT_MODE_16='d1;

localparam	WR_IDLE	=2'd0;
localparam	WR_BUFSEL=2'd1;
localparam	WR_RST	=2'd2;
localparam	WR_INIT =2'd3;
reg [1:0]	wr_state='d0;
reg			rst_fifo='d0;
reg [15:0]	sine_wave_bram[23:0];
wire [15:0] sine_wave_w; 


localparam	MAGIC_BYTE=32'hff00ff00;
reg 		init_r='d0;
reg [15:0]	vsync_ris_cnt='d0;
reg [63:0]	sec_cnt='d0;
reg 		sec_cnt_f='d0;

reg [15:0]	aud_fifo_data_r='d0;

reg [31:0] sec_cnt_r='d0;
reg sec_60hz_f='d0;
reg sec_done_f='d0;
reg [15:0]data_overflow_f='d0;
reg [15:0]aud_datagen_cnt_r='d0;
reg [7:0]aud_bram_addr='d0/* synthesis syn_keep = 1 */;
reg aud_data_vld_r1='d0;
reg [15:0]sine_wave_r='d0;

reg [15:0] aud_data_tpcnt_r='d0;

reg cam_app_en_r1='d0;
reg cam_app_en_r2='d0;
reg vid_vsync_fall_s1='d0;
reg vid_vsync_fall_s2='d0;

reg [5:0] aud1_cnt_3='d0;
reg [5:0] aud2_cnt_3='d0;
reg i2s_wr_en_t1='d0;
reg i2s_wr_en_t2='d0;
reg [23:0]aud1_data_cnt='d0;
reg [23:0]aud2_data_cnt='d0;
reg overwrite_f='d0;

// Sine wave for audio
initial begin
	sine_wave_bram[0] = 16'h0;
	sine_wave_bram[1] = 16'h1090;
	sine_wave_bram[2] = 16'h2000;
	sine_wave_bram[3] = 16'h2d41;
	sine_wave_bram[4] = 16'h376c;
	sine_wave_bram[5] = 16'h3dd1;
	sine_wave_bram[6] = 16'h4000;
	sine_wave_bram[7] = 16'h3dd1;
	sine_wave_bram[8] = 16'h376c;
	sine_wave_bram[9] = 16'h2d41;
	sine_wave_bram[10] = 16'h2000;
	sine_wave_bram[11] = 16'h1090;
	sine_wave_bram[12] = 16'h0;
	sine_wave_bram[13] = 16'hef70;
	sine_wave_bram[14] = 16'he000;
	sine_wave_bram[15] = 16'hd2bf;
	sine_wave_bram[16] = 16'hc894;
	sine_wave_bram[17] = 16'hc22f;
	sine_wave_bram[18] = 16'hc000;
	sine_wave_bram[19] = 16'hc22f;
	sine_wave_bram[20] = 16'hc894;
	sine_wave_bram[21] = 16'hd2bf;
	sine_wave_bram[22] = 16'he000;
	sine_wave_bram[23] = 16'hef70;
end

reg write_mask='d1;
wire write_mask_w;
always @(posedge clk_i) begin
	cam_app_en_r1 <= cam_app_en;
	cam_app_en_r2 <= cam_app_en_r1;
end

// Sine wave generation
always @(posedge clk_i) begin
	if(!rstn_sync_i)
		aud_data_tpcnt_r <= 'd0;
	else if(aud_data_vld_r1 & (!write_mask_w))
		aud_data_tpcnt_r <= aud_data_tpcnt_r + 'd32;
	if(!rstn_sync_i)
		aud_bram_addr <= 'd0;
	else if(aud_data_vld_r1 & (!write_mask_w)) begin
		if(aud_data_vld_r1&(aud_bram_addr=='d23))
			aud_bram_addr <= 'd0;
		else if(aud_data_vld_r1)
			aud_bram_addr <= aud_bram_addr + 'd1;
	end
end

assign sine_wave_w = sine_wave_bram[aud_bram_addr];

always @(posedge clk_i) begin
	sine_wave_r <= sine_wave_w;
end
always @(posedge clk_i, negedge rstn_i) begin
	if(!rstn_i) begin
		aud_datagen_cnt_r <= 'd0;
		aud_data_vld_r1 <= 'd0;
	 end else if(aud_datagen_cnt_r>=((CLOCK_FREQUENCY/AUD_LRCLK_FZ)-'d1)) begin
		aud_datagen_cnt_r <= 'd0;
		aud_data_vld_r1 <= 'd1;
	end else begin
		aud_datagen_cnt_r <= aud_datagen_cnt_r + 'd1;
		aud_data_vld_r1 <= 'd0;
	end
end
always @(posedge clk_i) begin
	if(sec_cnt_r==((CLOCK_FREQUENCY/60)-'d1))
		sec_cnt_r <= 'd0;
	else
		sec_cnt_r <= sec_cnt_r + 'd1;
end
always @(posedge clk_i) begin
	if(sec_cnt_r==((CLOCK_FREQUENCY/60)-'d1))
		sec_60hz_f <= 'd1;
	else
		sec_60hz_f <= 'd0;
end

assign aud_rd_idx = aud_rdidx_r;

always @(posedge clk_i)  begin
	vid_vsync_fall_s1 <= vid_vsync_fall_i;
	vid_vsync_fall_s2 <= vid_vsync_fall_s1;
end
always @(posedge clk_i) 
	aud_almostempty_r <= aud_almostempty;
always @(posedge clk_i) begin
	if(!rstn_sync_i)
		aud_rdidx_r <= 'd0;
	else if(aud_pktend_i)begin
		aud_rdidx_r <= wr_fifo_idx;
	end
end
always @(posedge clk_i, negedge rstn_i) begin
	if(!rstn_i)
		write_mask <= 'd0;
	else if(wr_state==WR_IDLE) begin
		if(vid_vsync_fall_s1 & ((wr_fifo_idx&(aud2_cnt_3==6'd0))||((!wr_fifo_idx)&(aud1_cnt_3==6'd0))))
			write_mask <= 'd1;
		else
			write_mask <= 'd0;
	end
	else if((mg_byte_wr_cnt=='d80) & (wr_state==WR_RST))
		write_mask <= 'd0;
end
assign write_mask_w = write_mask | vid_vsync_fall_s1 | vid_vsync_fall_i;
always @(posedge clk_i, negedge rstn_i) begin
	if(!rstn_i)
		aud1_cnt_3 <= 'd0;
	else if(rst[0])
		aud1_cnt_3 <= 'd0;
	else if(i2s_wr_en_t1) begin
		if(aud1_cnt_3==6'd47)
			aud1_cnt_3 <= 'd0;
		else
			aud1_cnt_3 <= aud1_cnt_3 + 'd1;
	end
end
always @(posedge clk_i, negedge rstn_i) begin
	if(!rstn_i)
		aud2_cnt_3 <= 'd0;
	else if(rst[1])
		aud2_cnt_3 <= 'd0;
	else if(i2s_wr_en_t2) begin
		if(aud2_cnt_3==6'd47)
			aud2_cnt_3 <= 'd0;
		else
			aud2_cnt_3 <= aud2_cnt_3 + 'd1;
	end
end

always @(posedge clk_i) begin
	if((wr_fifo_idx!=aud_rdidx_r)&(wr_state==WR_BUFSEL))
		overwrite_f <= 'd1;
	else
		overwrite_f <= 'd0;
end
always @(posedge clk_i) begin
	i2s_wr_en_t1 <= (aud_data_vld_r1 & (!wr_fifo_idx) & (!aud_almostfull[0]) & (!write_mask_w)) ;
	i2s_wr_en_t2 <= (aud_data_vld_r1 & wr_fifo_idx & (!aud_almostfull[1]) & (!write_mask_w)) ;
end
//	Control to switch between the 2 audio buffers
always @(posedge clk_i) begin
	if(!rstn_i) begin
		wr_state <= WR_IDLE;
		wr_fifo_idx <= 'd0;
		mg_byte_wr_cnt <= 'd0;
	end
	else begin
		case(wr_state)
			WR_IDLE :	begin
				if(aud_only_i/*||(!cam_app_en)*/) begin
					if(sec_60hz_f)
						wr_state <= WR_BUFSEL;
					else
						wr_state <= WR_IDLE;
				end
				else if((!cam_app_en_r2) & cam_app_en_r1)begin
					wr_state <= WR_BUFSEL;
				end
				else begin
					if(vid_vsync_fall_s1)
						wr_state <= WR_BUFSEL;
					else
						wr_state <= WR_IDLE;
				end
			end
			WR_BUFSEL :	begin
				if((wr_fifo_idx&(aud2_cnt_3==6'd0))||((!wr_fifo_idx)&(aud1_cnt_3==6'd0))) begin
					if(aud_rdidx_r)
						wr_fifo_idx <= 'd0;
					else
						wr_fifo_idx <= 'd1;
					wr_state <= WR_RST;
				end
				else
					wr_state <= WR_BUFSEL;
					
			end
			WR_RST :	begin
				if(mg_byte_wr_cnt=='d80) begin
					mg_byte_wr_cnt <= 'd0;
					wr_state <= WR_IDLE;
				end
				else if(mg_byte_wr_cnt>'d52) begin
					mg_byte_wr_cnt <= mg_byte_wr_cnt + 'd1;
					wr_state <= WR_RST;
				end
				else begin
					mg_byte_wr_cnt <= mg_byte_wr_cnt + 'd1;
					wr_state <= WR_RST;
				end
			end
			
		endcase
	end
end
always @(posedge clk_i) begin
	if(!rstn_sync_i)
		mg_byte_wr_en_r <= 'd0;
	else if((wr_state==WR_RST)&(mg_byte_wr_cnt<'d52))
		mg_byte_wr_en_r <= 'd1;
	else
		mg_byte_wr_en_r <= 'd0;
	if(!rstn_sync_i)
		rst_fifo <= 'd0;
	else if((wr_state==WR_RST)&(mg_byte_wr_cnt<'d52))
		rst_fifo <= 'd1;
	else
		rst_fifo <= 'd0;
	if(!rstn_sync_i)
		init_r <= 'd0;
	else if(wr_state==WR_RST)
		init_r <= 'd1;
end

always @(posedge clk_i) begin
	if(!rstn_sync_i)
		rst <= 2'b11;
	else begin
		rst[0] <= ((rst_fifo) & (!wr_fifo_idx));
		rst[1] <= ((rst_fifo) & (wr_fifo_idx));
	end
end

always @(*)
	aud_fifo_data_r <= aud_rd_idx ? aud_fifo_dout[1] : aud_fifo_dout[0];
always @(*) begin
	i2s_wr_en[0] <= (aud_data_vld_r1 & (!wr_fifo_idx) & (!aud_almostfull[0]) & (!write_mask_w)) || (mg_byte_wr_en_r & wr_fifo_idx) ;
	i2s_wr_en[1] <= (aud_data_vld_r1 & wr_fifo_idx & (!aud_almostfull[1]) & (!write_mask_w))  || (mg_byte_wr_en_r & (!wr_fifo_idx));
end
assign	aud_fifo_data_o = {aud_fifo_data_r,aud_fifo_data_r};
assign	aud_fifo_empty_o = aud_rd_idx ? aud_fifo_empty[1] : aud_fifo_empty[0];
assign	aud_fifo_almostempty_o = aud_rd_idx ? aud_almostempty_r[1] : aud_almostempty_r[0];
assign	aud_fifo_rden[0] =  aud_fifo_rden_i & (!aud_rd_idx);
assign	aud_fifo_rden[1] =  aud_fifo_rden_i & (aud_rd_idx);

//	Audio Buffers
generate
	for(gi = 0; gi < 2; gi = gi + 1) begin: loop_fifo
		aud_fifo aud_fifo (
			.aud_fifo_ip_Data(mg_byte_wr_en_r ? MAGIC_BYTE : (sine_wave_r)),
			.aud_fifo_ip_Q(aud_fifo_dout[gi]),
			.aud_fifo_ip_AlmostEmpty(aud_almostempty[gi]),
			.aud_fifo_ip_AlmostFull(aud_almostfull[gi]),
			.aud_fifo_ip_Clock(clk_i),
			.aud_fifo_ip_Empty(aud_fifo_empty[gi]), 
			.aud_fifo_ip_Full(),
			.aud_fifo_ip_RdEn(aud_fifo_rden[gi]),
			.aud_fifo_ip_Reset(rst[gi]), 
			.aud_fifo_ip_WrEn(i2s_wr_en[gi])
		);
	end
endgenerate

endmodule
