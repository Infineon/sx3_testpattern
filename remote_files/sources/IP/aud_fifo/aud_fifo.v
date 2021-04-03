/* synthesis translate_off*/
`define SBP_SIMULATION
/* synthesis translate_on*/
`ifndef SBP_SIMULATION
`define SBP_SYNTHESIS
`endif

//
// Verific Verilog Description of module aud_fifo
//
module aud_fifo (aud_fifo_ip_Data, aud_fifo_ip_Q, aud_fifo_ip_AlmostEmpty, 
            aud_fifo_ip_AlmostFull, aud_fifo_ip_Clock, aud_fifo_ip_Empty, 
            aud_fifo_ip_Full, aud_fifo_ip_RdEn, aud_fifo_ip_Reset, aud_fifo_ip_WrEn) /* synthesis sbp_module=true */ ;
    input [15:0]aud_fifo_ip_Data;
    output [15:0]aud_fifo_ip_Q;
    output aud_fifo_ip_AlmostEmpty;
    output aud_fifo_ip_AlmostFull;
    input aud_fifo_ip_Clock;
    output aud_fifo_ip_Empty;
    output aud_fifo_ip_Full;
    input aud_fifo_ip_RdEn;
    input aud_fifo_ip_Reset;
    input aud_fifo_ip_WrEn;
    
    
    aud_fifo_ip aud_fifo_ip_inst (.Data({aud_fifo_ip_Data}), .Q({aud_fifo_ip_Q}), 
            .AlmostEmpty(aud_fifo_ip_AlmostEmpty), .AlmostFull(aud_fifo_ip_AlmostFull), 
            .Clock(aud_fifo_ip_Clock), .Empty(aud_fifo_ip_Empty), .Full(aud_fifo_ip_Full), 
            .RdEn(aud_fifo_ip_RdEn), .Reset(aud_fifo_ip_Reset), .WrEn(aud_fifo_ip_WrEn));
    
endmodule

