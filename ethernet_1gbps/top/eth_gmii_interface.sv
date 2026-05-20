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
  clocking mon_cb @(posedge TX_CLK);
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
  

endinterface
      
