//////////////////////////////////////////////////////////////////////////////////
//	(c) 2020-2021, Cypress Semiconductor Corporation (an Infineon company) or an affiliate of Cypress Semiconductor Corporation.  All rights reserved.
//
//	This software, including source code, documentation and related materials ("Software") is owned by Cypress Semiconductor Corporation or one of its affiliates ("Cypress") and is protected by and subject to worldwide patent protection (United States and foreign), United States copyright laws and international treaty provisions.  Therefore, you may use this Software only as provided in the license agreement accompanying the software package from which you obtained this Software ("EULA").
//	If no EULA applies, Cypress hereby grants you a personal, non-exclusive, non-transferable license to copy, modify, and compile the Software source code solely for use in connection with Cypress's integrated circuit products.  Any reproduction, modification, translation, compilation, or representation of this Software except as specified above is prohibited without the express written permission of Cypress.
//
//	Disclaimer: THIS SOFTWARE IS PROVIDED AS-IS, WITH NO WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, NONINFRINGEMENT, IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. Cypress reserves the right to make changes to the Software without notice. Cypress does not assume any liability arising out of the application or use of the Software or any product or circuit described in the Software. Cypress does not authorize its products for use in any products where a malfunction or failure of the Cypress product may reasonably be expected to result in significant property damage, injury or death ("High Risk Product"). By including Cypress's product in a High Risk Product, the manufacturer of such system or application assumes all risk of such use and in doing so agrees to indemnify Cypress against all liability.
//
// Design Name:		testptrn 
// Module Name:		gpif_interface_top
// Target Devices:	LFE5U-45F-8BG381I
// Description: gpif_interface_top receives the audio and video data.
//				It converts the 32BIT video and audio data to respective buswidths as specified in the I2C slave registers.
//				It controls the gpif_interface_mod to send the video and audio data alternately in the respective sockets.
//				The video and audio data is sent in sockets 0/1 and 2/3 respectively in the Slave FIFO interface - Video + Audio.
//				The audio data is sent in the sockets 0/1 in the Slave FIFO interface - Audio only mode.
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`include "parameters.v"

module gpif_interface_top
(
	input clk_i,
	input rstn_i,
	input rstn_sync_i,
	
	input cam_app_en_i,
	input aud_app_en_i,
	input vid_skt_rst_i,
	input aud_skt_rst_i,
	input flaga_i,
	input flagb_i,
	input [31:0]	data_i,
	input data_vld_i,
	input aud_fifo_pg_empty_i,
	input aud_fifo_empty_i,
	input [31:0]	aud_fifo_data_i,
	input [1:0]	gpif_buf_wdt_i,
	output fifo_rst_o,
	output aud_fifo_rd_en_o,
	output aud_pktend_o,
	output vid_pktend_o,
	output aud_stream_en_o,
	output fifo_almostfull_o,
	
	output [1:0]	sl_addr_o,
	output [31:0]	sldata_o,
	output slwr_o,
	output slrd_o,
	output sloe_o,
	output slcs_o,
	output pktend_o
);

wire pktend_g_o;
wire fifo_rden_o;
wire idle_st_f_o;
wire vid_buswdt_ready_o;
wire aud_buswdt_ready_o;
wire buf_done_o;

localparam [2:0] GPIF_IDLE_ST	=2'd0;
localparam [2:0] VID_COMMIT_ST	=2'd1;
localparam [2:0] AUD_COMMIT_ST	=2'd2;

reg gpif_rst_r='d0;
reg gpif_en_r='d0;
reg gpif_en_rw='d0;
reg [31:0] vid_temp_data='d0;
reg [31:0] aud_temp_data='d0;
reg [2:0] cur_gpif_st=GPIF_IDLE_ST;
reg [2:0] cur_gpif_st_r=GPIF_IDLE_ST;
reg [2:0] next_gpif_st;
reg curr_st_change=1'd0;
reg vid_skt_r=1'd0;
reg aud_skt_r=1'd0;
reg vid_stream_en_r=1'd0;
reg aud_stream_en_r=1'd0;
reg aud_fifo_rden_r=1'd0;
reg vid_fifo_rden_r=1'd0;
wire vid_data_vld;
wire aud_data_vld;

localparam fx3_watermark = 'd12;
reg [5:0]watermark='d0;

reg [1:0]sl_addr_r=2'd0;
reg [27:0] data_vld_cnt='d0;

reg	fifo_rst_r='d0;
reg	fifo_rst='d0;
wire [31:0] fifo_dout;
wire [31:0] vid_buswdt_data_o;
wire [31:0] aud_buswdt_data_o;
wire fifo_almostempty;
wire fifo_almostfull;
wire fifo_empty;
wire fifo_full;
wire fifo_rden;
wire fifo_valid;
wire pktend_st_o;
reg aud_buswdt_clear='d0;
reg vid_buswdt_clear='d0;

//	Number of clock cycles "slwr" to be asserted after the flagb goes LOW can be calculated from,
//	fx3_watermark x (32/bus width) – 4
//	For buswidths 8,16,32 SX3 handles the fx3_watermark value to keep the delay value to be 8
//	For buswidth 24 SX3 maintains the fx3_watermark value = 12
localparam fx3_watermark_32 = 'd8;		//	For BUSWIDTH = 32
localparam fx3_watermark_24 = fx3_watermark*4/3 - 'd4; // For BUSWIDTH = 24
localparam fx3_watermark_16 = 'd8;		//	For BUSWIDTH = 16
localparam fx3_watermark_8 = 'd8;		// For BUSWIDTH = 8

wire vid_rden_bufwdt;
wire aud_rden_bufwdt;


assign sl_addr_o = sl_addr_r;
assign fifo_almostfull_o = fifo_almostfull;
assign aud_pktend_o = pktend_g_o & aud_stream_en_r;
assign vid_pktend_o = pktend_g_o & vid_stream_en_r;

always @(posedge clk_i) begin
	case(gpif_buf_wdt_i)
		2'd3: watermark <= fx3_watermark_32;
		2'd2: watermark <= fx3_watermark_24;
		2'd1: watermark <= fx3_watermark_16;
		2'd0: watermark <= fx3_watermark_8;
	endcase
end

//	GPIF FIFO before the slfifo interface for video
gpif_fifo gpif_fifo
(
	.gpif_fifo_ip_Data(data_i),
	.gpif_fifo_ip_Q(fifo_dout),
	.gpif_fifo_ip_AlmostEmpty(fifo_almostempty),
	.gpif_fifo_ip_AlmostFull(fifo_almostfull), 
	.gpif_fifo_ip_Empty(fifo_empty), 
	.gpif_fifo_ip_Full(fifo_full), 
	.gpif_fifo_ip_RPReset(fifo_rst), 
	.gpif_fifo_ip_RdClock(clk_i), 
	.gpif_fifo_ip_RdEn(fifo_rden), 
	.gpif_fifo_ip_Reset(fifo_rst), 
	.gpif_fifo_ip_WrClock(clk_i), 
	.gpif_fifo_ip_WrEn(data_vld_i)
	);

always@(posedge clk_i) begin
	if(!vid_stream_en_r)
		data_vld_cnt <= 'd0;
	else if(data_vld_i)
		data_vld_cnt <= data_vld_cnt + 'd1;
end

//	Bus width controller - video
buswdt_conv_mod 
vid_buswdt_conv_mod 
(
	.clk_i(clk_i), 
	.rstn_sync_i(rstn_sync_i), 
	.clear_i(vid_buswdt_clear), 
	.rden_i(vid_rden_bufwdt), 
	.fifo_empty(fifo_empty), 
	.buswdt_sel(gpif_buf_wdt_i), 
	.data_i(fifo_dout), 
	.data_vld_o(vid_data_vld), 
	.rden_o(fifo_rden), 
	.data_o(vid_buswdt_data_o), 
	.ready_o(vid_buswdt_ready_o)
	);

//	Bus width controller - audio
buswdt_conv_mod 
aud_buswdt_conv_mod 
(
	.clk_i(clk_i), 
	.rstn_sync_i(rstn_sync_i), 
	.clear_i(aud_buswdt_clear), 
	.rden_i(aud_rden_bufwdt), 
	.fifo_empty(aud_fifo_empty_i), 
	.buswdt_sel(gpif_buf_wdt_i), 
	.data_i(aud_fifo_data_i), 
	.data_vld_o(aud_data_vld), 
	.rden_o(aud_fifo_rd_en_o), 
	.data_o(aud_buswdt_data_o), 
	.ready_o(aud_buswdt_ready_o)
	);

assign vid_rden_bufwdt = vid_stream_en_r & fifo_rden_o;
assign aud_stream_en_o = aud_stream_en_r;
assign aud_rden_bufwdt = aud_stream_en_r & fifo_rden_o;

always @(posedge clk_i) begin
	aud_buswdt_clear <= pktend_st_o & aud_stream_en_r;
end
always @(posedge clk_i) begin
	if(cam_app_en_i)
		vid_buswdt_clear <= pktend_st_o&vid_stream_en_r;
	else
		vid_buswdt_clear <= 'd1;
end
always @(posedge clk_i) begin
	if(!rstn_sync_i)
		fifo_rst <= 'd1;
	else if((pktend_st_o&vid_stream_en_r)||(!cam_app_en_i))
		fifo_rst <= 'd1;
	else
		fifo_rst <= 'd0;
	if(!rstn_sync_i)
		fifo_rst_r <= 'd1;
	else if(pktend_st_o&vid_stream_en_r)
		fifo_rst_r <= 'd1;
	else
		fifo_rst_r <= 'd0;
end
assign fifo_rst_o = fifo_rst_r;
always @(posedge clk_i) begin
	vid_stream_en_r <= (cur_gpif_st==VID_COMMIT_ST);
	aud_stream_en_r <= (cur_gpif_st==AUD_COMMIT_ST);
	gpif_rst_r <= (cur_gpif_st==VID_COMMIT_ST)&(!cam_app_en_i) || ((cur_gpif_st==AUD_COMMIT_ST)&(!aud_app_en_i));
end
always @(posedge clk_i) begin
	curr_st_change <= (cur_gpif_st!=cur_gpif_st_r);
	gpif_en_r <= gpif_en_rw;
end

always @(posedge clk_i) begin
	if(!rstn_sync_i)
		sl_addr_r <= 2'd0;
	else if((cur_gpif_st==VID_COMMIT_ST))
		sl_addr_r <= {1'b0,vid_skt_r};
`ifdef SLFIFO_INTERFACE_AUD
	else if((cur_gpif_st==AUD_COMMIT_ST))
		sl_addr_r <= {1'b0,aud_skt_r};
`else
	else if((cur_gpif_st==AUD_COMMIT_ST))
		sl_addr_r <= {1'b1,aud_skt_r};
`endif
end

always @(posedge clk_i) begin
	if((!rstn_sync_i) || vid_skt_rst_i || (!cam_app_en_i))
		vid_skt_r <= 'd0;
	else if((buf_done_o||pktend_g_o)&(cur_gpif_st==VID_COMMIT_ST))
		vid_skt_r <= !vid_skt_r;
end

always @(posedge clk_i) begin
	if((!rstn_sync_i) || aud_skt_rst_i || (!aud_app_en_i))
		aud_skt_r <= 'd0;
	else if((buf_done_o||pktend_g_o)&(cur_gpif_st==AUD_COMMIT_ST))
		aud_skt_r <= !aud_skt_r;
end

//	GPIF Interface controller state machine
always @(posedge clk_i) begin
	if(rstn_sync_i==1'd0)begin
		cur_gpif_st <= 'd0;
		cur_gpif_st_r <= 'd0;
	end else begin
		cur_gpif_st <= next_gpif_st;
		cur_gpif_st_r <= cur_gpif_st;
	end
end

always @(*) begin
	next_gpif_st = cur_gpif_st;
	gpif_en_rw = 'd0;
	case(cur_gpif_st)
		GPIF_IDLE_ST:begin
			gpif_en_rw = 1'd0;
`ifdef SLFIFO_INTERFACE_AUD
			if(aud_app_en_i)
				next_gpif_st = AUD_COMMIT_ST;
			else
				next_gpif_st = GPIF_IDLE_ST;
`else 
			if(cam_app_en_i)
				next_gpif_st = VID_COMMIT_ST;
			else if(aud_app_en_i)
				next_gpif_st = AUD_COMMIT_ST;
			else
				next_gpif_st = GPIF_IDLE_ST;
`endif
		end
		VID_COMMIT_ST:begin
			gpif_en_rw = 1'd1;
			if((!cam_app_en_i)/*&buf_done_o*/) begin
				next_gpif_st = GPIF_IDLE_ST;
			end else if(pktend_g_o) begin
				if(aud_app_en_i)
					next_gpif_st = AUD_COMMIT_ST;
				else
					next_gpif_st = GPIF_IDLE_ST;
			end else begin
				next_gpif_st = VID_COMMIT_ST;
			end
		end
		AUD_COMMIT_ST:begin
			gpif_en_rw = 1'd1;
`ifdef SLFIFO_INTERFACE_AUD
			if((!aud_app_en_i)) begin
				next_gpif_st = GPIF_IDLE_ST;
			end else if(pktend_g_o) begin
				next_gpif_st = GPIF_IDLE_ST;
			end else begin
				next_gpif_st = AUD_COMMIT_ST;
			end
`else
			if((!aud_app_en_i)/*&buf_done_o*/) begin
				next_gpif_st = GPIF_IDLE_ST;
			end else if(pktend_g_o) begin
				if(cam_app_en_i)
					next_gpif_st = VID_COMMIT_ST;
				else
					next_gpif_st = GPIF_IDLE_ST;
			end else begin
				next_gpif_st = AUD_COMMIT_ST;
			end
`endif
		end
	endcase
end

gpif_interface_mod gpif_interface_mod
(
	.clk_i(clk_i),
	.rstn_i(rstn_i),
	.en_i(gpif_en_r),
	.gpif_rst_i(gpif_rst_r),
	
	.flaga_i(flaga_i),
	.flagb_i(flagb_i),
	.fifo_pg_empty(aud_stream_en_r ? aud_fifo_pg_empty_i : (fifo_almostempty||(!vid_buswdt_ready_o))),
	.data_vld_i(aud_stream_en_r ? aud_data_vld : vid_data_vld),
	.aud_data_f(aud_stream_en_r),
	.data_pre_i(aud_stream_en_r ? aud_fifo_data_i : fifo_dout),
	.data_i(aud_stream_en_r ? {aud_buswdt_data_o,aud_buswdt_data_o} : vid_buswdt_data_o),
	.watermark_i(watermark),
	
	.buf_done_o(buf_done_o),
	.pktend_g_o(pktend_g_o),
	.idle_st_f_o(idle_st_f_o),
	.fifo_rden_o(fifo_rden_o),
	.pktend_st_o(pktend_st_o),
	.sldata_o(sldata_o),
	.slwr_o(slwr_o),
	.slrd_o(slrd_o),
	.sloe_o(sloe_o),
	.slcs_o(slcs_o),
	.pktend_o(pktend_o)
);

endmodule
