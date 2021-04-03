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
// Target Devices:	LFE5U-45F-8BG381I
// Description: gpif_interface_mod implements the basic Slave FIFO interface protocol. It controls all the SlaveFIFO interface signals and can be controlled by a top mod to send data to SX3 via SlaveFIFO interface.
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`include "parameters.v"

module gpif_interface_mod
(
	input	clk_i,
	input	rstn_i,
	input	en_i,
	input	gpif_rst_i,
	
	input			flaga_i,
	input			flagb_i,
	input			fifo_pg_empty,
	input			data_vld_i,
	input			aud_data_f,
	input [31:0]	data_pre_i,
	input [31:0]	data_i,
	input [5:0]		watermark_i,
	
	output			buf_done_o,
	output			pktend_g_o,
	output			idle_st_f_o,
	output			fifo_rden_o,
	output			pktend_st_o,
	output [31:0]	sldata_o,
	output			slwr_o,
	output			slrd_o,
	output			sloe_o,
	output			slcs_o,
	output			pktend_o
);

reg [2:0]current_stream_in_state;
reg [2:0]next_stream_in_state;

reg	flaga_r='d0;
reg	flagb_r='d0;

reg [4:0] wm_cnt='d0;

reg idle_st_r='d0;
reg slwr_rw;
reg [31:0] sldata_r=32'hffffffff;
reg [25:0] slwr_cnt='d0;
reg slwr_r='d1;
reg slwr_gen_r='d1 /* synthesis syn_keep = 1 */; 
reg pktend_rw='d1;
reg pktend_gr='d1;
reg pktend_r='d1;
reg fifo_rden_rw;
reg fifo_rden_r='d0;
reg wr_xtra_data='d0;
reg buf_done_r='d0;
reg pktend_st_r='d0;
reg [4:0] watermark_r='d0;

//parameters for StreamIN mode state machine
parameter [2:0] STREAM_IN_IDLE              = 3'd0;
parameter [2:0] STREAM_IN_WAIT_FLAGB        = 3'd1;
parameter [2:0] STREAM_IN_WRITE             = 3'd2;
parameter [2:0] STREAM_IN_WRITE_WR_DELAY    = 3'd3;
parameter [2:0] STREAM_IN_PKTEND			= 3'd4;

parameter watermark = 'd12;	// 24BIT GPIF

assign buf_done_o = buf_done_r;
assign pktend_g_o = pktend_gr;
assign fifo_rden_o = fifo_rden_r;
assign sldata_o = sldata_r;
assign slwr_o	= slwr_r;
assign pktend_o	= pktend_r;
assign slrd_o	= 1'b1;
assign sloe_o	= 1'b1;
assign slcs_o	= 1'b0;

assign idle_st_f_o = idle_st_r;
assign pktend_st_o = pktend_st_r;


//register the input signals
always @(posedge clk_i) begin
	flaga_r <= flaga_i;
	flagb_r <= flagb_i;
end

//streamIN mode state machine
always @(posedge clk_i, negedge rstn_i)begin
	if(!rstn_i)begin 
		current_stream_in_state <= STREAM_IN_IDLE;
	end else begin
		current_stream_in_state <= next_stream_in_state;
	end	
end

//StreamIN mode state machine combo
always @(*)begin
	next_stream_in_state = current_stream_in_state;
	fifo_rden_rw = 1'b0;
	pktend_rw = 1'b1;
	case(current_stream_in_state)
		STREAM_IN_IDLE:begin
			pktend_rw = 1'b1;
			fifo_rden_rw = 1'b0;
			if(flaga_r&en_i)begin
				next_stream_in_state = STREAM_IN_WAIT_FLAGB; 
			end else begin
				next_stream_in_state = STREAM_IN_IDLE;
			end	
		end
		STREAM_IN_WAIT_FLAGB :begin
			pktend_rw = 1'b1;
			fifo_rden_rw = 1'b0;
			if (flagb_r)begin
				next_stream_in_state = STREAM_IN_WRITE; 
			end else begin
				next_stream_in_state = STREAM_IN_WAIT_FLAGB; 
			end
		end
		STREAM_IN_WRITE:begin
			if((data_pre_i==32'hff00ff00)&data_vld_i)
				pktend_rw = 'd0;
			else
				pktend_rw = 'd1;
			if(fifo_rden_r&aud_data_f) begin
				fifo_rden_rw = 1'b1;
			end
			else begin
				if(fifo_pg_empty)
					fifo_rden_rw = 'd0;
				else
					fifo_rden_rw = 'd1;
			end
			if((!flagb_r) & flaga_r)begin
				next_stream_in_state = STREAM_IN_WRITE_WR_DELAY;
			end else if((!flagb_r) & (!flaga_r))begin
				next_stream_in_state = STREAM_IN_IDLE;
			end else if((data_pre_i==32'hff00ff00)&data_vld_i) begin
				next_stream_in_state = STREAM_IN_PKTEND;
			end else begin
				next_stream_in_state = STREAM_IN_WRITE;
			end
		end
		STREAM_IN_WRITE_WR_DELAY:begin
			if((data_pre_i==32'hff00ff00)&data_vld_i)
				pktend_rw = 'd0;
			else
				pktend_rw = 'd1;
			if(wm_cnt<(watermark_r))
				fifo_rden_rw = 1'b1;
			else
				fifo_rden_rw = 1'b0;
			if(!flaga_r) begin
				next_stream_in_state = STREAM_IN_IDLE;
			end else if((data_pre_i==32'hff00ff00)&data_vld_i) begin
				next_stream_in_state = STREAM_IN_PKTEND;
			end else begin
				next_stream_in_state = STREAM_IN_WRITE_WR_DELAY;
			end
		end
		STREAM_IN_PKTEND:begin
			pktend_rw = 'd1;
			if(!flaga_r)
				next_stream_in_state = STREAM_IN_IDLE;
		end
	endcase
end

always @(posedge clk_i) begin
	if((current_stream_in_state == STREAM_IN_WRITE_WR_DELAY)&(!flaga_r))
		buf_done_r <= 'd1;
	else
		buf_done_r <= 'd0;
end

always @(posedge clk_i)begin
	idle_st_r <= (current_stream_in_state == STREAM_IN_IDLE);
end

always @(posedge clk_i) begin	// When slwr is not LOW during flagb_i negedge is asserted
	if(current_stream_in_state==STREAM_IN_IDLE)
		watermark_r <= watermark_i-'d4; //	1 Clock each for the flagb_reg, rd_en generation delays. 2cycle for slwr generation.
	else if((!flagb_i) & flagb_r & slwr_gen_r)
		watermark_r <= watermark_i-'d3;
end
always @(posedge clk_i) begin	// When slwr is not LOW during flagb_i negedge is asserted
	if(current_stream_in_state==STREAM_IN_IDLE)
		wr_xtra_data <= 1'd0;
	else if((!flagb_i) & flagb_r & slwr_gen_r)
		wr_xtra_data <= 1'd1;
end
always @(posedge clk_i) begin
	fifo_rden_r <= fifo_rden_rw;
end
always @(posedge clk_i) begin
	if(data_vld_i)
		sldata_r <= data_i;
end
always @(posedge clk_i) begin
	pktend_st_r <= (current_stream_in_state==STREAM_IN_PKTEND);
	pktend_gr <= ((current_stream_in_state==STREAM_IN_PKTEND)&(!flaga_r));
	pktend_r <= pktend_rw;
	if((current_stream_in_state==STREAM_IN_PKTEND)||gpif_rst_i)
		slwr_cnt <= 'd0;
	else if((!slwr_gen_r))
		slwr_cnt <= slwr_cnt + 'd1;
	slwr_r <= ((current_stream_in_state==STREAM_IN_WRITE_WR_DELAY)||(current_stream_in_state==STREAM_IN_WRITE)) ? (!data_vld_i) : 'd1;
	slwr_gen_r <= ((current_stream_in_state==STREAM_IN_WRITE_WR_DELAY)||(current_stream_in_state==STREAM_IN_WRITE)) ? (!data_vld_i) : 'd1;
end
always @(posedge clk_i) begin
	if(current_stream_in_state==STREAM_IN_IDLE)
		wm_cnt <= 3'd0;
	else if((!slwr_gen_r)&(!flagb_r)&flaga_r)	// Added as the flaga and flagb goes low inbetween bufefrs too.
		wm_cnt <= wm_cnt + 'd1;
end

endmodule
