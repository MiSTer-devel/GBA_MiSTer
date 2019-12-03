derive_pll_clocks
derive_clock_uncertainty

set clk_sdram_sys  {*|pll|pll_inst|altera_pll_i|*[0].*|divclk}
set_input_delay  -source_latency_included 14.0ns -clock $clk_sdram_sys [get_ports {SDRAM_DQ[*]}]
#set_output_delay -source_latency_included -8.0ns -clock $clk_sdram_sys [get_ports {SDRAM_D*}]
