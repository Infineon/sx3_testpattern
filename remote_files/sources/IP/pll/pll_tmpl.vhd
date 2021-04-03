--VHDL instantiation template

component pll is
    port (pll_clk_CLKI: in std_logic;
        pll_clk_CLKOP: out std_logic;
        pll_clk_LOCK: out std_logic
    );
    
end component pll; -- sbp_module=true 
_inst: pll port map (pll_clk_CLKI => __,pll_clk_CLKOP => __,pll_clk_LOCK => __);
