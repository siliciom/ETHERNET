import uvm_pkg::*;
`include "uvm_macros.svh"
`include "../config/eth_pkg.sv"

module eth_top;
  bit clk;
  bit rst;

  parameter real HALF_PERIOD = 1000 / (2 * `FREQ_IN_MHZ);
  
  eth_gmii_interface gmii_if[`NO_OF_AGENTS](rst);
  eth_ui_interface ui_inf[`NO_OF_AGENTS]();

  genvar i;
  generate
    for (i = 0; i < `NO_OF_AGENTS; i++) begin : gen_config
      initial begin
        uvm_config_db#(virtual eth_gmii_interface)::set(
          null,
          $sformatf("uvm_test_top.env_h.agnt_mac[%0d]*", i),
          "vif",
          gmii_if[i]
        );
        uvm_config_db#(virtual eth_ui_interface)::set(
          null,
          $sformatf("uvm_test_top.env_h.agnt_mac[%0d]*", i),
          "ui_inf",
          ui_inf[i]   
        );
        
      end
      assign gmii_if[i].TX_CLK = clk;
      assign gmii_if[i].RX_CLK = clk;
    end

  endgenerate
  
  assign gmii_if[0].RXD = gmii_if[1].TXD;
  assign gmii_if[1].RXD = gmii_if[0].TXD;

  assign statistics::v_uif[0] = ui_inf[0];

  initial begin
    clk = 0;
    forever #(HALF_PERIOD) clk = ~clk; 
  end

  initial begin
    rst = 0;
    repeat (5) @(posedge clk);
    rst = 1;
  end
    
  initial begin    
    run_test("");
  end
  
endmodule
