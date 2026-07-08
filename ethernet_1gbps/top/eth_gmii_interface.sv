import uvm_pkg::*;
`include "uvm_macros.svh"
interface eth_gmii_interface(input bit rst);

  // Transmit path 
  logic [7:0] TXD;
  logic       TX_EN;
  logic       TX_ER;
  logic       TX_CLK;

  // Receive path 
  logic [7:0] RXD;
  logic       RX_ER;
  logic       RX_DV;
  logic       RX_CLK;

  // Carrier / Collision signals 
  logic       COL;
  logic       CRS;

  //========================================================
  // Clocking block for driver
  //========================================================
  clocking drv_cb @(posedge TX_CLK);
    output TXD;
    output TX_EN;
    output TX_ER;

    input  RXD;
    input  RX_ER;
    input  RX_DV;
    input  RX_CLK;
    input  COL;
    input  CRS;
  endclocking

  //========================================================
  // Clocking block for monitor
  //========================================================
  clocking mon_cb @(negedge TX_CLK);
    input TXD;
    input TX_EN;
    input TX_ER;
    input RXD;
    input RX_ER;
    input RX_DV;
    input RX_CLK;
    input COL;
    input CRS;
  endclocking

  //========================================================
  // Modports
  //========================================================

  // For UVM driver
  modport DRV_MP (
    clocking drv_cb);
  
  // For UVM monitor
  modport MON_MP (
    clocking mon_cb);

  //========================================================
  // Assertions
  //========================================================
  //TX_EN should be high whenever TX_ER goes high

  `ifndef HALF_DUPLEX
   property p_tx_er_only_when_tx_en;
     @(posedge TX_CLK) disable iff (!rst) 
       TX_ER |->TX_EN; 
   endproperty

   assert property (p_tx_er_only_when_tx_en)
     `uvm_info("ASSERT for tx_er_only_when_tx_en ", "Assertion passed", UVM_DEBUG)
    else
     `uvm_error("ASSERT tx_er_only_when_tx_en", "TX_ER asserted while TX_EN is LOW")
 
   //RX_EN should be high whenever RX_ER goes high
   property p_rx_er_only_when_rx_dv;
     @(posedge RX_CLK) disable iff (!rst)
       RX_ER |-> RX_DV;
   endproperty

   a_rx_er_only_when_rx_dv :
    assert property (p_rx_er_only_when_rx_dv)
      `uvm_info("ASSERT for rx_er_only_when_rx_dv", "Assertion passed", UVM_DEBUG)
     else
      `uvm_error("ASSERT for rx_er_only_when_rx_dv", "RX_ER asserted while RX_EN is LOW")
  `endif
 
  //IPG96 bit time 
    property p_ifg;
     @(posedge TX_CLK) disable iff (!rst)
       $fell(TX_EN) |=> !TX_EN[*11];
    endproperty

    a_ifg : assert property (p_ifg)
     `uvm_info("ASSERT for ifg","ifg is proper(passed)",UVM_DEBUG)
    else
     `uvm_error("ASSERT for ifg","IFG is less than 96 bit-times")
 
   // RX IFG = 96 bit-times (12 byte-times = 12 RX_CLK cycles)
    property p_rx_ifg;
     @(posedge RX_CLK) disable iff (!rst)
       $fell(RX_DV) |=> !RX_DV[*11];
    endproperty

    a_rx_ifg : assert property (p_rx_ifg)
     `uvm_info("ASSERT_RX_IFG","RX IFG is proper (passed)",UVM_DEBUG)
    else
     `uvm_error("ASSERT_RX_IFG","RX IFG is less than 96 bit-times")
 
    //CRS should be high when COL goes high
    property p_col_only_when_crs;
     @(posedge TX_CLK) disable iff (!rst)
       COL |-> CRS;
    endproperty

    a_col_only_when_crs : assert property (p_col_only_when_crs)
       `uvm_info("ASSERT FOR COLLISON","success",UVM_DEBUG)
     else
       `uvm_error("ASSERT FOR COLLISION","COL asserted while CRS is LOW")
 
    //Validate all the Interface Signals are not X/Z 
    property p_no_xz_on_interface;
    @(posedge TX_CLK) disable iff (!rst)
      !$isunknown({TXD, TX_EN, TX_ER, RXD, RX_DV, RX_ER, CRS, COL});
    endproperty

     a_no_xz_on_interface : assert property (p_no_xz_on_interface)
        `uvm_info("ASSERT FOR interface signals not x/z","success",UVM_DEBUG)
     else
       `uvm_error("ASSERT FOR interface signals not x/z", "One or more GMII interface signals contain X/Z")

    //TX_EN should be high for 72 clock cycles
    property p_min_tx_frame;
     @(posedge TX_CLK) disable iff (!rst)
      $rose(TX_EN) && !COL |-> (TX_EN || !COL)[*72];
    endproperty
 
    a_min_tx_frame : assert property (p_min_tx_frame)
     `uvm_info("ASSERT FOR min_tx_frame","success",UVM_DEBUG)
     else
    `uvm_error("ASSERT FOR min_tx_frame", "Frame length is less than 72 bytes (including preamble and SFD)")
 
     // RX_DV should be high for at least 72 clock cycles
     property p_min_rx_frame;
       @(posedge RX_CLK) disable iff (!rst)
         $rose(RX_DV) && !COL |->  (RX_DV && !COL)[*72] or ((RX_DV && !COL)[*0:71] ##1 COL);
     endproperty

     a_min_rx_frame : assert property (p_min_rx_frame)
       `uvm_info("ASSERT_MIN_RX_FRAME", "Minimum RX frame length satisfied", UVM_DEBUG)
     else
       `uvm_error("ASSERT_MIN_RX_FRAME", "Received frame length is less than 72 bytes (including preamble and SFD)")
     
     //TX signals are low during reset

     property p_tx_signals_low_during_reset;
       @(posedge TX_CLK)
         $rose(!rst) |=> (TXD == 8'h00 && TX_EN == 1'b0 && TX_ER == 1'b0);
     endproperty

     a_tx_signals_low_during_reset : assert property(p_tx_signals_low_during_reset)
     begin
       `uvm_info("TX_RESET_ASSERT", "TX signals are LOW during reset", UVM_DEBUG)
     end
     else
     begin
       `uvm_error("TX_RESET_ASSERT", "TX signals are not LOW during reset")
     end

     //RX_SIGNALS are low during reset 

     property p_rx_signals_low_during_reset;
       @(posedge RX_CLK)
         $rose(!rst) |=> (RXD == 8'h00 && RX_DV == 1'b0 && RX_ER == 1'b0 && CRS ==1'b0 && COL == 1'b0 );
     endproperty

     a_rx_signals_low_during_reset : assert property(p_rx_signals_low_during_reset)
     begin
       `uvm_info("RX_RESET_ASSERT", "RX signals are LOW during reset", UVM_DEBUG)
     end
     else
     begin
       `uvm_error("RX_RESET_ASSERT", "RX signals are not LOW during reset")
     end


     //Checking PREAMBLE is 55 in TX 
     property p_tx_preamble;
       @(posedge TX_CLK)
       disable iff(!rst)
         $rose(TX_EN) && (!COL) |-> (TXD == 8'h55)[*7];
     endproperty

     a_tx_preamble : assert property(p_tx_preamble)
     begin
       `uvm_info("TX_PREAMBLE_ASSERT","TX preamble is valid",UVM_DEBUG)
     end
     else begin
       `uvm_error("TX_PREAMBLE_ASSERT","Invalid TX preamble")
     end
    
    // Checking PREAMBLE is 55 in RX 
     property p_rx_preamble;
       @(posedge RX_CLK)
       disable iff(!rst)
         $rose(RX_DV) |-> (RXD == 8'h55)[*7];
     endproperty

     a_rx_preamble : assert property(p_rx_preamble)
     begin
       `uvm_info("RX_PREAMBLE_ASSERT", "RX preamble is valid",UVM_DEBUG)
     end
     else begin
       `uvm_error("RX_PREAMBLE_ASSERT", "Invalid RX preamble")
     end

     //Checking SFD is D5 in TX
     property p_tx_sfd;
       @(posedge TX_CLK)
       disable iff (!rst)
         $rose(TX_EN) && (!COL) |-> ##7 (TXD == 8'hD5);
     endproperty

     a_tx_sfd : assert property(p_tx_sfd)
     begin
       `uvm_info("TX_SFD_ASSERT","TX SFD is valid",UVM_DEBUG)
     end
     else begin
       `uvm_error("TX_SFD_ASSERT", "Invalid TX SFD. Expected 8'hD5 after 7-byte preamble")
     end

    //Checking SFD D5 in RX

     property p_rx_sfd;
       @(posedge RX_CLK)
       disable iff (!rst)
         $rose(RX_DV) |-> ##7 (RXD == 8'hD5);
     endproperty

     a_rx_sfd : assert property(p_rx_sfd)
     begin
       `uvm_info("RX_SFD_ASSERT","RX SFD is valid", UVM_DEBUG)
     end
     else begin
       `uvm_error("RX_SFD_ASSERT", "Invalid RX SFD. Expected 8'hD5 after 7-byte preamble")
     end

     //Carrier extension 
     property p_carrier_extension;
     @(posedge TX_CLK)
     disable iff(!rst)
       (TX_ER && !TX_EN) |-> (TXD == 8'h0F);
     endproperty

     a_carrier_extension : assert property(p_carrier_extension)
     begin
     `uvm_info("CARRIER_EXTENSION_ASSERT","Carrier Extension symbol transmitted correctly",UVM_DEBUG)
     end
     else
       begin
       `uvm_error("CARRIER_EXTENSION_ASSERT", $sformatf("Invalid Carrier Extension: Expected TX_EN=0, TX_ER=1, TXD=8'h0F, Got TX_EN=%0b, TX_ER=%0b,      TXD=%0h", TX_EN, TX_ER, TXD))
     end

     //Checking the clock frequency of 125Mhz 
     property p_tx_clk_freq;
       realtime current_time;
       @(posedge TX_CLK) disable iff(!rst) (1,current_time=$realtime) |=>( ($realtime-current_time inside {[7.99:8.01]}) )
     endproperty

     a_tx_clk_freq : assert property(p_tx_clk_freq)
     else
     begin
       `uvm_error("CLK_FREQ",$sformatf("Clock period mismatch"))
     end
     

     //Checking the 50% duty cycle 

     property p_tx_duty_cycle;
   	  realtime current_time;
   	  @(TX_CLK) (1,current_time=$realtime) |=> ($realtime-current_time inside {[3.99:4.01]}) 
     endproperty

     a_tx_duty_cycle : assert property(p_tx_duty_cycle)
      else
	`uvm_error("DUTY","Clock  width mismatch");

endinterface
      

