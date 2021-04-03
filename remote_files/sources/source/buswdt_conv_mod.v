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
// Description: buswdt_conv_mod converts the 32BIT input data to 8/16/24/32 BIT data as specified in buswdt_sel. It generates the fifo_rd_en to the input FIFO and qualifier for the output data. 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module buswdt_conv_mod
(
	input			clk_i,
	input			rstn_sync_i,
	
	input			clear_i,
	input			rden_i,
	input			fifo_empty,
	input [1:0]		buswdt_sel,	// BUSWIDTH Select :
								//		- '00' -> 8 BIT
								//		- '01' -> 16 BIT
								//		- '10' -> 24 BIT
								//		- '11' -> 32 BIT
	input [31:0]	data_i,
	
	output			data_vld_o,
	output			rden_o,
	output [31:0]	data_o,
	output			ready_o
);

reg [31:0] res_data_r=32'd0;
reg [31:0] var_len_data_r=32'd0;

reg [31:0] res_data_rn=32'd0;
reg [31:0] var_len_data_rn=32'd0;

reg fifo_dvld_r1='d0;
reg fifo_dvld_r2='d0;
reg ready_r='d0;
reg rden_i_r='d0;
reg rden_init_r='d0;
reg rden_r='d0;
reg data_vld_r='d0;
reg init_rden='d0;
reg init_rden_r='d0;
reg init_rden_rr='d0;
reg	fifo_rden_r='d0;
reg [31:0]	data_r='d0;
reg mask_r='d0;
reg mask_rn='d0;

//	Bus width Conversion States
localparam INIT_ST=3'd0;
localparam CLK1_ST=3'd1;
localparam CLK2_ST=3'd2;
localparam CLK3_ST=3'd3;
localparam CLK4_ST=3'd4;

reg [2:0] cur_data_st_r=INIT_ST/* synthesis syn_keep = 1 */;
reg [2:0] next_data_st_r=INIT_ST;
reg [2:0] cur_rden_st_r=INIT_ST/* synthesis syn_keep = 1 */;
reg [2:0] next_rden_st_r=INIT_ST;

localparam [1:0] BUSWDT_8 =2'b00;
localparam [1:0] BUSWDT_16=2'b01;
localparam [1:0] BUSWDT_24=2'b10;
localparam [1:0] BUSWDT_32=2'b11;
localparam [3:0] MASK_CLK1=4'b1100;
localparam [3:0] MASK_CLK2=4'b1110;
localparam [3:0] MASK_CLK3=4'b1000;
localparam [3:0] MASK_CLK4=4'b1111;

reg [26:0] rd_en_cnt='d0;

always @(posedge clk_i) begin
	if(clear_i)
		rd_en_cnt <= 'd0;
	else if(rden_i)
		rd_en_cnt <= rd_en_cnt + 'd1;
end
always @(posedge clk_i, posedge clear_i) begin
	if(clear_i)
		cur_rden_st_r <= INIT_ST;
	else begin
		cur_rden_st_r <= next_rden_st_r;
	end
end

always @* begin
	next_rden_st_r = cur_rden_st_r;
	mask_rn = mask_r;
	case(cur_rden_st_r)
		INIT_ST:begin
			if(!fifo_empty) begin
				mask_rn = MASK_CLK1[buswdt_sel];
				next_rden_st_r = CLK1_ST;
			end else begin
				next_rden_st_r = INIT_ST;
				mask_rn = 1'b0;
			end
		end
		CLK1_ST: begin
			if(rden_i&ready_r) begin
				mask_rn = MASK_CLK2[buswdt_sel];
				next_rden_st_r = CLK2_ST;					
			end else begin
				next_rden_st_r = CLK1_ST;
				mask_rn = mask_r;
			end
		end
		CLK2_ST: begin
			if(rden_i&ready_r) begin
				mask_rn = MASK_CLK3[buswdt_sel];
				next_rden_st_r = CLK3_ST;					
			end else begin
				next_rden_st_r = CLK2_ST;
				mask_rn = mask_r;
			end
		end
		CLK3_ST: begin
			if(rden_i&ready_r) begin
				mask_rn = MASK_CLK4[buswdt_sel];
				next_rden_st_r = CLK4_ST;					
			end else begin
				next_rden_st_r = CLK3_ST;
				mask_rn = mask_r;
			end
		end
		CLK4_ST: begin
			if(rden_i&ready_r) begin
				mask_rn = MASK_CLK1[buswdt_sel];
				next_rden_st_r = CLK1_ST;					
			end else begin
				next_rden_st_r = CLK4_ST;
				mask_rn = mask_r;
			end
		end
	endcase
end

always @(posedge clk_i, posedge clear_i)
	if(clear_i)
		ready_r <= 1'd0;
	else
		ready_r <= (cur_rden_st_r!=INIT_ST);

assign ready_o = ready_r;

always @(posedge clk_i) 
	if(clear_i)
		mask_r <= 1'd0;
	else
		mask_r <= mask_rn;
		
always @(posedge clk_i) 
	if(clear_i)
		rden_init_r <= 'd0;
	else if((cur_rden_st_r==INIT_ST)&(!fifo_empty))
		rden_init_r <= 'd1;
	else
		rden_init_r <= 'd0;
assign rden_o = (rden_i & mask_r) || rden_init_r;

always @(posedge clk_i) begin
	if(!rstn_sync_i)
		cur_data_st_r <= INIT_ST;
	else if(clear_i)
		cur_data_st_r <= INIT_ST;
	else begin
		cur_data_st_r <= next_data_st_r;
	end
end

always @(posedge clk_i) begin
	fifo_dvld_r1 <= rden_i||rden_init_r;
	fifo_dvld_r2 <= fifo_dvld_r1;
	rden_r <= rden_i;
	data_vld_r <= rden_r;
end

assign data_vld_o = data_vld_r;

always @(posedge clk_i) begin
	var_len_data_r <= var_len_data_rn;
	res_data_r <= res_data_rn;
end

assign data_o = var_len_data_r;

always @* begin
	next_data_st_r = cur_data_st_r;
	res_data_rn = res_data_r;
	var_len_data_rn = var_len_data_r;
	case(cur_data_st_r)
		INIT_ST:begin
			if(ready_r&fifo_dvld_r2) begin
				var_len_data_rn[31:0] = data_i[31:0];
				res_data_rn[31:24] = 8'd0;
				res_data_rn[23:16] = data_i[31:24];
				if(buswdt_sel[0])
					res_data_rn[15:8] = data_i[31:24];
				else
					res_data_rn[15:8] = data_i[23:16];
				case(buswdt_sel)
					BUSWDT_8:	res_data_rn[7:0] = data_i[15:8];
					BUSWDT_16:	res_data_rn[7:0] = data_i[23:16];
					BUSWDT_24:	res_data_rn[7:0] = data_i[31:24];
					BUSWDT_32:	res_data_rn[7:0] = data_i[15:8];
				endcase
				next_data_st_r = CLK2_ST;
			end else begin
				next_data_st_r = INIT_ST;
				var_len_data_rn = var_len_data_r;
				res_data_rn = res_data_r;
			end
		end
		CLK2_ST:begin
			if(fifo_dvld_r2) begin
				case(buswdt_sel)
					BUSWDT_8 : begin
						var_len_data_rn[31:8] = 'd0;
						var_len_data_rn[7:0] = res_data_r[7:0];
						res_data_rn[31:16] = 'd0;
						res_data_rn[15:0] = res_data_r[23:8];
					end
					BUSWDT_16 : begin
						var_len_data_rn[15:0] = res_data_r[15:0];
						var_len_data_rn[31:16] = 'd0;
						res_data_rn = 'd0;
					end
					BUSWDT_24 : begin
						var_len_data_rn[23:0] = {data_i[15:0],res_data_r[7:0]};
						res_data_rn[15:0] = data_i[31:16];
						res_data_rn[31:16] = 'd0;
						var_len_data_rn[31:24] = 'd0;
					end
					BUSWDT_32 : begin
						var_len_data_rn = data_i;
						res_data_rn = 'd0;
					end
				endcase
				next_data_st_r = CLK3_ST;
			end else begin
				next_data_st_r = CLK2_ST;
				var_len_data_rn = var_len_data_r;
				res_data_rn = res_data_r;
			end
		end
		CLK3_ST:begin
			if(fifo_dvld_r2) begin
				case(buswdt_sel)
					BUSWDT_8 : begin
						var_len_data_rn[7:0] = res_data_r[7:0];
						res_data_rn[7:0] = res_data_r[15:8];
						res_data_rn[31:8] = 'd0;
						var_len_data_rn[31:8] = 'd0;
					end
					BUSWDT_16 : begin
						var_len_data_rn[15:0] = data_i[15:0];
						res_data_rn[15:0] = data_i[31:16];
						var_len_data_rn[31:16] = 'd0;
						res_data_rn[31:16] = 'd0;
					end
					BUSWDT_24 : begin
						var_len_data_rn[23:0] = {data_i[7:0],res_data_r[15:0]};
						res_data_rn[23:0] = data_i[31:8];
						res_data_rn[31:24] = 'd0;
						var_len_data_rn[31:24] = 'd0;
					end
					BUSWDT_32 : begin
						var_len_data_rn = data_i;
						res_data_rn = 'd0;
					end
				endcase
				next_data_st_r = CLK4_ST;
			end else begin
				next_data_st_r = CLK3_ST;
				var_len_data_rn = var_len_data_r;
				res_data_rn = res_data_r;
			end
		end
		CLK4_ST:begin
			if(fifo_dvld_r2) begin
				case(buswdt_sel)
					BUSWDT_8 : begin
						var_len_data_rn[7:0] = res_data_r[7:0];
						res_data_rn[31:0] = 'd0;
						var_len_data_rn[31:8] = 'd0;
					end
					BUSWDT_16 : begin
						var_len_data_rn[15:0] = res_data_r[15:0];
						var_len_data_rn[31:16] = 'd0;
						res_data_rn = 'd0;
					end
					BUSWDT_24 : begin
						var_len_data_rn[23:0] = {res_data_r[23:0]};
						res_data_rn = 'd0;
						var_len_data_rn[31:24] = 'd0;
					end
					BUSWDT_32 : begin
						var_len_data_rn = data_i;
						res_data_rn = 'd0;
					end
				endcase
				next_data_st_r = CLK1_ST;
			end else begin
				next_data_st_r = CLK4_ST;
				var_len_data_rn = var_len_data_r;
				res_data_rn = res_data_r;
			end
		end
		CLK1_ST:begin
			if(fifo_dvld_r2) begin
				res_data_rn[31:24] = 8'd0;
				var_len_data_rn[31:0] = data_i[31:0];
				res_data_rn[23:16] = data_i[31:24];
				if(buswdt_sel[0])
					res_data_rn[15:8] = data_i[31:24];
				else
					res_data_rn[15:8] = data_i[23:16];
				case(buswdt_sel)
					BUSWDT_8:	res_data_rn[7:0] = data_i[15:8];
					BUSWDT_16:	res_data_rn[7:0] = data_i[23:16];
					BUSWDT_24:	res_data_rn[7:0] = data_i[31:24];
					BUSWDT_32:	res_data_rn[7:0] = data_i[15:8];
				endcase
				next_data_st_r = CLK2_ST;
			end else begin
				next_data_st_r = CLK1_ST;
				var_len_data_rn = var_len_data_r;
				res_data_rn = res_data_r;
			end
		end
	endcase
end

endmodule