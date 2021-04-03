/* synthesis translate_off*/
`define SBP_SIMULATION
/* synthesis translate_on*/
`ifndef SBP_SIMULATION
`define SBP_SYNTHESIS
`endif

//
// Verific Verilog Description of module pll
//
module pll (pll_clk_CLKI, pll_clk_CLKOP, pll_clk_LOCK) /* synthesis sbp_module=true */ ;
    input pll_clk_CLKI;
    output pll_clk_CLKOP;
    output pll_clk_LOCK;
    
    
    pll_clk pll_clk_inst (.CLKI(pll_clk_CLKI), .CLKOP(pll_clk_CLKOP), .LOCK(pll_clk_LOCK));
    
endmodule

