//////////////////////////////////////////////////////////////////////////////////
//	(c) 2020-2021, Cypress Semiconductor Corporation (an Infineon company) or an affiliate of Cypress Semiconductor Corporation.  All rights reserved.
//
//	This software, including source code, documentation and related materials ("Software") is owned by Cypress Semiconductor Corporation or one of its affiliates ("Cypress") and is protected by and subject to worldwide patent protection (United States and foreign), United States copyright laws and international treaty provisions.  Therefore, you may use this Software only as provided in the license agreement accompanying the software package from which you obtained this Software ("EULA").
//	If no EULA applies, Cypress hereby grants you a personal, non-exclusive, non-transferable license to copy, modify, and compile the Software source code solely for use in connection with Cypress's integrated circuit products.  Any reproduction, modification, translation, compilation, or representation of this Software except as specified above is prohibited without the express written permission of Cypress.
//
//	Disclaimer: THIS SOFTWARE IS PROVIDED AS-IS, WITH NO WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, NONINFRINGEMENT, IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. Cypress reserves the right to make changes to the Software without notice. Cypress does not assume any liability arising out of the application or use of the Software or any product or circuit described in the Software. Cypress does not authorize its products for use in any products where a malfunction or failure of the Cypress product may reasonably be expected to result in significant property damage, injury or death ("High Risk Product"). By including Cypress's product in a High Risk Product, the manufacturer of such system or application assumes all risk of such use and in doing so agrees to indemnify Cypress against all liability.
//
// Design Name:		testptrn 
// Module Name:		gpif_interface_mod
// Target Devices:	LFE5U-45F-8BG381i
// Description: This is the overall top module of the design. It integrates all the sub-modules.
//				The topmod supports 3 modes :
//					1. Slave FIFO interface - Video + Audio.
//					2. Slave FIFO interface - Audio only.
//					3. Camera Interface
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`include "parameters.v"

module topmod
(
	input	clk_i,
	input rst_i,
	input			flaga_i,
	input			flagb_i,
	output [31:0]	sldata_o,
	output			slclk_o,
	output			slwr_o,
	output			slrd_lv_o,
	output			sloe_fv_o,
	output			slcs_o,
	inout			fx3_i2c_sda_io,
	inout			fx3_i2c_scl_io,
	output			pktend_o,
	output [1:0]	sladdr_o	// Sladdr for Bus widths 32 and 16 BIT 
);

wire sys_clk;
wire pll_lock;
wire rstn_i;
wire rstn_sync_i;
reg rff1=1'd0;
reg rst_nr=1'd0;
reg rff1_sync=1'd0;
reg rst_nr_sync=1'd0;

//	Reset bridge of rst_i in sysclk domain Active LOW
always @(posedge sys_clk, posedge rst_i)
begin
  if (rst_i) begin
    rff1 <= 'd0;
    rst_nr <= 'd0;
  end
  else begin
    rff1 <= 'd1;
    rst_nr <= rff1;
  end
end
assign rstn_i = rst_nr;

always @(posedge sys_clk) begin
	rff1_sync <= !rst_i;
	rst_nr_sync <= rff1_sync;
end
assign rstn_sync_i = rst_nr_sync;

wire slrd_o;
wire sloe_o;
wire cam_app_en;
reg cam_app_en_r1='d0;
reg cam_app_en_r2='d0;
wire aud_app_en;
wire slfifo_st_vidrst_o;
wire yuv_420_en;
wire [15:0]img_wt_o;
wire [15:0]img_ht_o;
wire [31:0]img_size;
wire interleaved_en_o;
wire uvc_header_en;
wire [1:0]gpif_buf_wdt;
wire [15:0]slfifo_uvc_buf_size;

reg [31:0]data_pre_i='d0;
reg [31:0]data_i='d0;
reg data_vld_i='d0;
reg [31:0] data_cnt='d0;

wire [31:0] aud_fifo_data_o;
wire aud_pktend_i;
wire aud_fifo_almostempty_o;
wire aud_fifo_empty_o;
wire aud_fifo_rden;
wire vid_vsync_fall_i;
wire aud_pktend_o;
wire vid_pktend_o;
wire fifo_almostfull_o;
wire aud_stream_en_o;
wire [31:0]	tp_data_o;
wire tp_hsync_o;
wire tp_vsync_o;
wire vid_fifo_rst_o;
wire still_cap_en_o;
wire cam_int_en;
reg still_cap_en_r1='d0;
reg still_cap_en_r2='d0;
reg aud_app_en_r1='d0;
reg aud_app_en_rn='d0;
reg vsync_r='d0;
reg [23:0]vsync_rr='d0;
reg vsync_r1='d0;
reg vsync_r2='d0;

wire [31:0] gpif_top_sldata_o;
wire [1:0] sladdr;

reg vid_tp_en_r='d0;
reg vid_slfifo_en_r='d0;

wire buf_done_o;
wire fifo_rden_o;
wire pktend_g_o;
reg tp_busy_r='d0;
reg [1:0]sladdr_r='d0;
reg [1:0]sec_cnt_r='d0;
reg fifo_rden_r='d0;

reg [31:0] tp_data_cam_int_r='d0;
reg camint_vsync_r='d0;
reg camint_hsync_r='d0;

reg [1:0] sladdr_m0_r/* synthesis syn_keep = 1 */;
reg [1:0] sladdr_m1_r/* synthesis syn_keep = 1 */;
// Input PLL 
pll pll
(
	.pll_clk_CLKI(clk_i), 
	.pll_clk_CLKOP(sys_clk),
	.pll_clk_LOCK(pll_lock)
	);

// GPIF Clock out buffer
ODDRX1F FX3_CLOCK ( .D0(1'b1), .D1(1'b0), .SCLK(sys_clk), .RST(1'b0), .Q(slclk_o) );

`ifdef CAMERA_INTERFACE
always @(posedge sys_clk) begin
	camint_hsync_r <= tp_hsync_o;
	camint_vsync_r <= tp_vsync_o;
	tp_data_cam_int_r <= tp_data_o;
end
assign sladdr_o[0] = 'd1;
assign sladdr_o[1] = 'd1;
assign sloe_fv_o = camint_vsync_r;
assign slrd_lv_o = camint_hsync_r;
assign slwr_o = 'd1;
assign slcs_o = 'd1;
assign sldata_o = tp_data_cam_int_r;
reg [31:0] img_cnt='d0;
always @(posedge sys_clk)
	if(!camint_vsync_r)
		img_cnt <= 'd0;
	else if(camint_hsync_r)
			img_cnt <= img_cnt + 'd1;
`else
assign sladdr_o = sladdr_m0_r;
assign sloe_fv_o = sloe_o;
assign slrd_lv_o = slrd_o;
assign sldata_o[7:0]	= gpif_top_sldata_o[7:0];
assign sldata_o[15:10]	= (gpif_buf_wdt!=2'b00) ? gpif_top_sldata_o[15:10] : 6'd0;
assign sldata_o[23:16]	= (gpif_buf_wdt[1]) ? gpif_top_sldata_o[23:16] : 8'd0;
assign sldata_o[31:26]	= (gpif_buf_wdt==2'b11) ? gpif_top_sldata_o[31:26] : 6'd0;
assign sldata_o[25:24]	= ((gpif_buf_wdt==2'b10)) ? sladdr_m1_r : gpif_top_sldata_o[25:24];
assign sldata_o[9:8]	= ((gpif_buf_wdt==2'b00)) ? sladdr_m1_r : gpif_top_sldata_o[9:8];
`endif

aud_tp_mod aud_tp_mod (
    .clk_i(sys_clk), 
    .rstn_i(rstn_i), 
    .rstn_sync_i(rstn_sync_i), 
    .cam_app_en(cam_app_en), 
    .aud_fifo_rden_i(aud_fifo_rden), 
    .vid_vsync_fall_i(vid_vsync_fall_i), 
    .aud_fifo_data_o(aud_fifo_data_o), 
    .aud_fifo_empty_o(aud_fifo_empty_o), 
    .aud_fifo_almostempty_o(aud_fifo_almostempty_o), 
    .aud_pktend_i(aud_pktend_i)
    );

testpattern_mod 
#(	.BYTE_PER_PIX('d2) )
testpattern_mod
(
	.clk_i(sys_clk),
	
	.en_i(vid_tp_en_r),
	.busy_i(fifo_almostfull_o||tp_busy_r),
	.bus_wdt_i(gpif_buf_wdt),	//	Bus Width:
	.fr_width_i(img_wt_o),	// Max 8192
	.fr_height_i(img_ht_o),	// Max 8192
	
	.hsync_o(tp_hsync_o),
	.vsync_o(tp_vsync_o),
	.data_o(tp_data_o)
);

always@(posedge sys_clk) begin
	sladdr_m0_r <= sladdr;
	sladdr_m1_r <= sladdr;
end

always@(posedge sys_clk) begin
	still_cap_en_r1 <= still_cap_en_o;
	still_cap_en_r2 <= still_cap_en_r1;
	aud_app_en_r1 <= aud_app_en;
	aud_app_en_rn <= !aud_app_en;
end

reg still_cap_done='d0;
always@(posedge sys_clk) begin
	if(cam_app_en) begin
		if(still_cap_en_o)
			vid_tp_en_r <= !still_cap_done;
		else
			vid_tp_en_r <= 'd1;
	end
	else begin
		vid_tp_en_r <= 'd0;
	end
end

always@(posedge sys_clk) begin
	if(still_cap_en_o) begin
		if(cam_app_en&vid_pktend_o)
			still_cap_done <= 'd1;
	end
	else
		still_cap_done <= 'd0;
end


assign vid_vsync_fall_i = (vsync_r2) & (!vsync_r1);
assign aud_pktend_i = aud_pktend_o;

always @(posedge sys_clk) begin
	cam_app_en_r1 <= cam_app_en;
	cam_app_en_r2 <= cam_app_en_r1;
end

always @(posedge sys_clk) begin
	if(pll_lock) begin
		if(vid_pktend_o) begin
			data_vld_i <= 'd0;
			data_cnt <= 'd0;
			vsync_r <= 'd0;
		end
		else if(fifo_almostfull_o || (data_cnt=='d1382436)) begin
			data_vld_i <= 'd0;
			data_cnt <= data_cnt;
			if((data_cnt=='d1382436))
				vsync_r <= 'd0;
			else
				vsync_r <= 'd1;
		end
		else if(data_cnt<'d10)begin
			data_vld_i <= 'd0;
			data_cnt <= data_cnt + 'd1;
			vsync_r <= 'd0;
		end
		else begin
			data_vld_i <= 'd1;
			data_cnt <= data_cnt + 'd1;
			vsync_r <= 'd1;
		end
		if(vid_pktend_o)
			data_i <= 'd0;
		else if(data_vld_i)
			data_i <= (data_i + 'd1);
	end
	else begin
		data_vld_i <= 'd0;
		data_i <= 'd0;
		data_cnt <= 'd0;
	end
	vsync_rr <= {vsync_rr[22:0],tp_vsync_o};
	vsync_r1 <= tp_vsync_o;
	vsync_r2 <= vsync_r1;
end

reg vid_fifo_rst_1='d0;
reg vid_fifo_rst_2='d0;

always@(posedge sys_clk) begin
	vid_fifo_rst_1 <= vid_fifo_rst_o;
	vid_fifo_rst_2 <= vid_fifo_rst_1;
	if(!vid_tp_en_r)
		tp_busy_r <= 'd0;
	else if(!vsync_rr[0] & (vsync_rr[1]))
		tp_busy_r <= 'd1;
	else if((!vid_fifo_rst_1) & vid_fifo_rst_2)
		tp_busy_r <= 'd0;
end
assign magic_byte_wren = (!vsync_rr[0]) & vsync_rr[15];


gpif_interface_top gpif_interface_top (
	.clk_i(sys_clk), 
	.rstn_i(rstn_i), 
	.rstn_sync_i(rstn_sync_i), 
	.cam_app_en_i(vid_tp_en_r), 
	.aud_app_en_i(aud_app_en_r1), 
	.vid_skt_rst_i(slfifo_st_vidrst_o), 
	.aud_skt_rst_i(slfifo_st_audrst_o), 
	.flaga_i(flaga_i), 
	.flagb_i(flagb_i), 
	.data_i(magic_byte_wren ? 32'hff00ff00 : tp_data_o), 
	.data_vld_i(tp_hsync_o||magic_byte_wren), 
	.aud_fifo_pg_empty_i(aud_fifo_almostempty_o), 
	.aud_fifo_empty_i(aud_fifo_empty_o), 
	.aud_fifo_data_i(aud_fifo_data_o), 
	.gpif_buf_wdt_i(gpif_buf_wdt), 
	.fifo_rst_o(vid_fifo_rst_o),
	.aud_fifo_rd_en_o(aud_fifo_rden), 
	.aud_pktend_o(aud_pktend_o), 
	.vid_pktend_o(vid_pktend_o), 
	.fifo_almostfull_o(fifo_almostfull_o), 
	.aud_stream_en_o(aud_stream_en_o),			 
	.sl_addr_o(sladdr), 
	.sldata_o(gpif_top_sldata_o), 
`ifdef CAMERA_INTERFACE
	.slwr_o(), 
`else
	.slwr_o(slwr_o), 
`endif
	.slrd_o(slrd_o), 
	.sloe_o(sloe_o), 
`ifdef CAMERA_INTERFACE
	.slcs_o(), 
`else
	.slcs_o(slcs_o),
`endif
	.pktend_o(pktend_o)
);

//	I2C Slave module
i2c_slave
fx3_i2c_slave_if
(
	//	Interface Inouts
	.sl_sda_io(fx3_i2c_sda_io),// I2C SDA input
	.sl_scl_io(fx3_i2c_scl_io),	// I2C SCL input
	
	//	Global Inputs
	.reset_n_i(rstn_i),
	.clock_i(sys_clk),
	
	//	Control Signals
	.slfifo_st_vidrst_o(slfifo_st_vidrst_o),	// video channel reset
	.slfifo_st_audrst_o(slfifo_st_audrst_o),	// audio channel reset
	.yuv_420_en(yuv_420_en),	// YUV_420 Conversion enable
	.img_wt_o(img_wt_o),	// Number of pixels in a line
	.img_ht_o(img_ht_o),	// Number of lines ina  frame
	.img_size_o(img_size),	// Number of pixels in a frame
	.interleaved_en_o(interleaved_en_o),	// Interlaced Conversion enable
	.cam_app_en_o(cam_app_en),	// Video Streaming Applicaton enable
	.aud_app_en_o(aud_app_en),	// Audio Applicaton enable
	.uvc_header_en_o(uvc_header_en),	// UVC header padding Enable flag
	.slfifo_uvc_buf_size_o(slfifo_uvc_buf_size),	// Number of byte in a buffer in FX3
	.still_cap_en_o(still_cap_en_o),	// Still capture pin
	.gpif_buf_wdt_o(gpif_buf_wdt),	// SlaveFIFO bus width
	.cam_int_en_o(cam_int_en)
);
endmodule
